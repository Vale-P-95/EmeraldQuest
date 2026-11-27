extends Node
## Il regista della battaglia: collega il motore (BattleEngine) all'interfaccia
## (battle_ui.gd), ferma il mondo mentre si lotta e tiene la squadra del giocatore.
##
## Le battaglie si fanno sul posto, stile Monster Hunter: non si cambia scena.
## Quando parte una lotta il mondo va in pausa (get_tree().paused = true), così
## mostri e protagonista si fermano: "il tempo si ferma mentre scegli".
## Questo nodo e l'interfaccia hanno process_mode = ALWAYS, quindi continuano
## a funzionare anche con il mondo in pausa.
##
## Due modi per far partire una lotta:
##   - un mostro nel mondo emette encounter_started (lo collega test_world.gd);
##   - un dialogo della storia manda [signal arg="battaglia:id"] e l'autoload
##     Storia emette battaglia_richiesta (vedi STORY_BATTLES qui sotto).

## Emesso quando parte una lotta (utile per nascondere l'interfaccia del mondo).
signal battle_started
## Emesso a lotta finita. result è un valore di BattleEngine.Result.
signal battle_finished(result: int, monster: Node3D, story_id: String)

## La squadra iniziale del prototipo (massimo 6). In M3 arriverà da cattura e salvataggi.
@export var starting_party: Array[CreatureData] = []
@export_range(1, 100) var starting_level := 14
@export var difficulty: BattleRules.Difficulty = BattleRules.Difficulty.NORMALE
## Quanto aspettare tra un messaggio e l'altro (secondi).
@export var message_delay := 0.7

const MAX_PARTY := 6
const TYPE_CHART_PATH := "res://data/types/type_chart.tres"

## Le lotte chieste dai dialoghi: id del segnale -> [creature, livello, si può fuggire?].
## Alcune creature della storia non esistono ancora come .tres: finché non ci
## sono, il gioco usa un "sostituto" (scritto tra parentesi nel commento).
const STORY_BATTLES := {
	"fauceverde": [["fauceverde"], 16, false],
	"ciottolotto_sasso": [["ciottolotto", "selvarbo"], 10, true],       # sostituto: Selvarbo
	"branco_saltarupe_mulino": [["saltarupe", "fulgurala"], 9, true],  # sostituto: Fulgurala
	"saltarupe_smanioso": [["saltarupe", "fulgurala"], 10, true],
}
## Quante creature ha il nemico nelle lotte "a branco".
const STORY_PACK_SIZE := {"branco_saltarupe_mulino": 2}

var player_party: Array[BattleCreature] = []
## Oggetti da battaglia nella borsa. In futuro li prenderemo dalla borsa di Storia.
var inventory := {&"pozione": 3, &"etere": 1, &"panacea": 1}
var in_battle := false

var _engine: BattleEngine
var _monster: Node3D
var _story_id := ""
var _chart: TypeChart

@onready var _ui := $BattleUI


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_chart = load(TYPE_CHART_PATH)
	for species in starting_party.slice(0, MAX_PARTY):
		if species != null:
			player_party.append(BattleCreature.create(species, starting_level))
	_ui.action_chosen.connect(_on_action_chosen)
	_ui.forced_switch_chosen.connect(_on_forced_switch_chosen)
	# get_node_or_null: se un giorno questa scena viene usata senza l'autoload Storia, non si rompe.
	var storia := get_node_or_null("/root/Storia")
	if storia and storia.has_signal("battaglia_richiesta"):
		storia.battaglia_richiesta.connect(_on_story_battle_requested)


## Fa partire una lotta contro un mostro del mondo.
func start_monster_battle(monster: Node3D) -> void:
	var species: CreatureData = monster.get("creature")
	if species == null:
		push_warning("Il mostro %s non ha una CreatureData: niente battaglia." % monster.name)
		return
	var lvl: int = monster.get("level") if monster.get("level") != null else starting_level
	var enemy: Array[BattleCreature] = [BattleCreature.create(species, lvl)]
	start_battle(enemy, monster, true)


## Fa partire una lotta qualsiasi. enemy_party = le creature del nemico (1-6).
func start_battle(enemy_party: Array[BattleCreature], monster: Node3D = null, wild := true,
		story_id := "") -> void:
	if in_battle or player_party.is_empty():
		return
	if player_party.all(func(c): return c.is_ko()):
		_heal_party()
	in_battle = true
	_monster = monster
	_story_id = story_id
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # il mouse serve per i menu
	_engine = BattleEngine.new()
	_engine.setup(player_party, enemy_party, _chart, difficulty, inventory, wild)
	_ui.open(_engine)
	battle_started.emit()
	_engine.start()
	_play_events()


## Racconta uno alla volta gli eventi del motore, poi mostra il menu giusto.
func _play_events() -> void:
	for ev in _engine.take_events():
		_ui.show_event(ev)
		if ev["text"] != "":
			# true = il timer funziona anche col mondo in pausa.
			await get_tree().create_timer(message_delay, true).timeout
	_ui.sync_with_engine()
	match _engine.state:
		BattleEngine.State.ATTESA_GIOCATORE:
			_ui.show_main_menu()
		BattleEngine.State.CAMBIO_OBBLIGATO:
			_ui.show_forced_switch()
		BattleEngine.State.FINITA:
			await get_tree().create_timer(message_delay * 1.5, true).timeout
			_end_battle()


func _on_action_chosen(action: BattleAction) -> void:
	if not _engine.submit_action(action):
		_ui.show_main_menu()   # azione non valida (non dovrebbe succedere: i pulsanti sono disattivati)
		return
	_play_events()


func _on_forced_switch_chosen(index: int) -> void:
	if _engine.submit_forced_switch(index):
		_play_events()
	else:
		_ui.show_forced_switch()


func _end_battle() -> void:
	var result := _engine.result
	# Fauceverde: la storia vuole sapere se la sua Rottura è stata svuotata.
	for c in _engine.enemy_party:
		if c.data.id == &"fauceverde" and c.break_count > 0:
			_set_story_variable("Cap1.FauceRotta", true)
	if result == BattleEngine.Result.SCONFITTA:
		# Per ora, dopo una sconfitta la squadra viene curata e si riparte da dove si era.
		_heal_party()
	_ui.close()
	in_battle = false
	get_tree().paused = false
	var monster := _monster
	_monster = null
	var story_id := _story_id
	_story_id = ""
	if story_id != "":
		_resume_dialogue()
	battle_finished.emit(result, monster, story_id)


func _heal_party() -> void:
	for c in player_party:
		c.full_restore()


## Cambia la difficoltà passando alla successiva (Facile -> Normale -> Difficile -> Facile).
func cycle_difficulty() -> void:
	difficulty = ((difficulty + 1) % 3) as BattleRules.Difficulty


# =============================================================================
#  Lotte chieste dalla storia
# =============================================================================

func _on_story_battle_requested(id: String, _capture: bool) -> void:
	# _capture: la cattura arriverà in M3, per ora è una lotta normale.
	if not STORY_BATTLES.has(id):
		push_warning("[Battaglia] Lotta della storia sconosciuta: %s" % id)
		return
	var info: Array = STORY_BATTLES[id]
	var species := _first_existing_creature(info[0])
	if species == null:
		push_warning("[Battaglia] Nessuna creatura trovata per la lotta %s" % id)
		return
	var enemy: Array[BattleCreature] = []
	for i in STORY_PACK_SIZE.get(id, 1):
		enemy.append(BattleCreature.create(species, info[1]))
	_pause_dialogue()
	# Aspettiamo un attimo: il segnale arriva mentre Dialogic sta ancora elaborando la riga.
	await get_tree().process_frame
	start_battle(enemy, null, info[2], id)


func _first_existing_creature(ids: Array) -> CreatureData:
	for id in ids:
		var path := "res://data/creatures/%s.tres" % id
		if ResourceLoader.exists(path):
			return load(path)
	return null


func _pause_dialogue() -> void:
	var dialogic := get_node_or_null("/root/Dialogic")
	if dialogic:
		dialogic.paused = true


func _resume_dialogue() -> void:
	var dialogic := get_node_or_null("/root/Dialogic")
	if dialogic:
		dialogic.paused = false


func _set_story_variable(var_name: String, value: Variant) -> void:
	var storia := get_node_or_null("/root/Storia")
	if storia:
		storia.imposta_variabile(var_name, value)
