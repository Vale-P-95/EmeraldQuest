class_name BattleEngine
extends RefCounted
## Il "cervello" della battaglia: decide di chi è il turno, applica le azioni
## e capisce quando la lotta è finita. Non disegna niente: è la scena
## BattleManager (scenes/battle/) a mostrare a schermo quello che succede.
##
## Come funziona, in breve:
##   1. setup(...) prepara le due squadre; start() fa partire la battaglia.
##   2. Il motore fa agire da solo il nemico finché non tocca al giocatore.
##      A quel punto si ferma: state diventa ATTESA_GIOCATORE (il tempo è fermo!).
##   3. L'interfaccia chiama submit_action(...) con la scelta del giocatore,
##      e il motore riparte fino al prossimo turno del giocatore.
##   4. Tutto quello che succede finisce nella lista `events`: l'interfaccia la
##      legge con take_events() e la "racconta" un messaggio alla volta.
##
## Turni CTB (Conditional Turn-Based): ogni creatura in campo ha un contatore.
## Agisce chi ha il contatore più basso; dopo l'azione il contatore riparte da
## un valore che dipende dalla Velocità e dal "peso" dell'azione. Per questo
## una creatura molto veloce può agire due volte di fila.

enum State { PRONTO, ATTESA_GIOCATORE, CAMBIO_OBBLIGATO, FINITA }
enum Result { NESSUNO, VITTORIA, SCONFITTA, FUGA }

## Oggetti usabili in battaglia in M2 (più avanti diventeranno Resource in data/items/).
const ITEMS := {
	&"pozione": {"name": "Pozione", "desc": "Cura il 40% dei PS.", "heal_pct": 0.4},
	&"etere": {"name": "Etere", "desc": "Ridà 3 PA.", "ap": 3},
	&"panacea": {"name": "Panacea", "desc": "Guarisce da ogni stato.", "cure": true},
}

## Da nome dell'effetto (campo status_effect di SkillData) a stato grave.
const STATUS_EFFECTS := {
	&"bruciatura": BattleCreature.Status.BRUCIATURA,
	&"veleno": BattleCreature.Status.VELENO,
	&"sonno": BattleCreature.Status.SONNO,
	&"paralisi": BattleCreature.Status.PARALISI,
	&"congelamento": BattleCreature.Status.GELO,
	&"gelo": BattleCreature.Status.GELO,
	&"confusione": BattleCreature.Status.CONFUSIONE,
}

## Da nome dell'effetto a [statistica, variazione, su chi]. "self" = chi usa l'abilità.
const STAGE_EFFECTS := {
	&"attacco_su": ["attack", 1, "self"],
	&"difesa_su": ["defense", 1, "self"],
	&"magia_su": ["magic", 1, "self"],
	&"spirito_su": ["spirit", 1, "self"],
	&"velocita_su": ["speed", 1, "self"],
	&"attacco_giu": ["attack", -1, "target"],
	&"difesa_giu": ["defense", -1, "target"],
	&"magia_giu": ["magic", -1, "target"],
	&"spirito_giu": ["spirit", -1, "target"],
	&"velocita_giu": ["speed", -1, "target"],
	&"precisione_giu": ["accuracy", -1, "target"],
}

const STAT_NAMES := {
	"attack": "Attacco", "defense": "Difesa", "magic": "Magia",
	"spirit": "Spirito", "speed": "Velocità", "accuracy": "Precisione",
}

var player_party: Array[BattleCreature] = []
var enemy_party: Array[BattleCreature] = []
var player_index := 0     ## chi è in campo per il giocatore
var enemy_index := 0      ## chi è in campo per il nemico
var chart: TypeChart
var difficulty: BattleRules.Difficulty = BattleRules.Difficulty.NORMALE
var inventory: Dictionary = {}   ## id oggetto -> quantità (viene modificato!)
var is_wild := true              ## dagli incontri selvatici si può fuggire
var ai := BattleAI.new()

var state: State = State.PRONTO
var result: Result = Result.NESSUNO
var turn_count := 0
var flee_attempts := 0
var current_actor: BattleCreature = null

## Eventi da mostrare. Ognuno è un Dictionary con almeno "text"; può avere
## anche "kind" (es. "damage", "switch") e "target", "hp", "ap".
var events: Array[Dictionary] = []


# =============================================================================
#  Preparazione
# =============================================================================

func setup(p_party: Array[BattleCreature], e_party: Array[BattleCreature], type_chart: TypeChart,
		diff: BattleRules.Difficulty = BattleRules.Difficulty.NORMALE, items: Dictionary = {},
		wild := true) -> void:
	player_party = p_party
	enemy_party = e_party
	chart = type_chart
	difficulty = diff
	inventory = items
	is_wild = wild
	player_index = _first_alive(player_party)
	enemy_index = _first_alive(enemy_party)


func start() -> void:
	assert(player_index >= 0 and enemy_index >= 0, "Servono creature in grado di lottare")
	for c in player_party + enemy_party:
		c.reset_battle_state()
	var p := player_active()
	var e := enemy_active()
	# All'inizio i contatori partono da un turno "normale": il più veloce agisce per primo.
	p.ctb_counter = BattleRules.ctb_delay(p, BattleRules.RANK_NORMAL)
	e.ctb_counter = BattleRules.ctb_delay(e, BattleRules.RANK_NORMAL)
	if e.is_large():
		_say("Un %s enorme ti sbarra la strada!" % e.get_display_name())
	else:
		_say("Un %s selvatico ti attacca!" % e.get_display_name() if is_wild
			else "%s scende in campo!" % e.get_display_name())
	_say("Vai, %s!" % p.get_display_name(), {"kind": "switch", "target": p})
	_advance()


func player_active() -> BattleCreature:
	return player_party[player_index]


func enemy_active() -> BattleCreature:
	return enemy_party[enemy_index]


## Restituisce e svuota la lista degli eventi accumulati.
func take_events() -> Array[Dictionary]:
	var out: Array[Dictionary] = events.duplicate()
	events.clear()
	return out


# =============================================================================
#  Coda dei turni (CTB)
# =============================================================================

## Chi agisce tra i due in campo: il contatore più basso; a parità, il giocatore.
func _pick_next(p_counter: int, e_counter: int) -> bool:
	return p_counter <= e_counter   # true = tocca al giocatore


## Previsione dei prossimi n turni (per la barra in alto). Restituisce le creature in ordine.
## È una stima: suppone che tutti facciano azioni "normali".
func predict_turns(n := 8) -> Array[BattleCreature]:
	var out: Array[BattleCreature] = []
	if state == State.FINITA:
		return out
	var p := player_active()
	var e := enemy_active()
	if p.is_ko() or e.is_ko():
		return out   # si sta aspettando un cambio: la coda si ricalcola dopo
	var pc := p.ctb_counter
	var ec := e.ctb_counter
	# Se qualcuno sta già agendo, è il primo della coda.
	if current_actor != null:
		out.append(current_actor)
		if current_actor == p:
			pc = BattleRules.ctb_delay(p, BattleRules.RANK_NORMAL) + pc
		else:
			ec = BattleRules.ctb_delay(e, BattleRules.RANK_NORMAL) + ec
	while out.size() < n:
		if _pick_next(pc, ec):
			out.append(p)
			ec -= pc
			pc = BattleRules.ctb_delay(p, BattleRules.RANK_NORMAL)
		else:
			out.append(e)
			pc -= ec
			ec = BattleRules.ctb_delay(e, BattleRules.RANK_NORMAL)
	return out


## Fa andare avanti la battaglia finché non tocca al giocatore o finisce.
func _advance() -> void:
	# Il limite evita cicli infiniti se qualcosa va storto.
	for _safety in 200:
		if state == State.FINITA or state == State.CAMBIO_OBBLIGATO:
			return
		var p := player_active()
		var e := enemy_active()
		var player_turn := _pick_next(p.ctb_counter, e.ctb_counter)
		var actor := p if player_turn else e
		# Il tempo scorre: tutti i contatori scendono di quanto mancava all'attore.
		var elapsed := actor.ctb_counter
		p.ctb_counter -= elapsed
		e.ctb_counter -= elapsed
		if not _begin_turn(actor):
			continue   # ha saltato il turno (sonno, paralisi...)
		if player_turn:
			state = State.ATTESA_GIOCATORE
			return     # il tempo si ferma: aspettiamo la scelta del giocatore
		var action := ai.choose_action(self, e, p)
		_execute(e, p, action)
		_end_turn(e)


## Inizio turno: +1 PA, finisce la Difesa, si controllano gli stati.
## Restituisce false se la creatura salta il turno.
func _begin_turn(actor: BattleCreature) -> bool:
	turn_count += 1
	current_actor = actor
	actor.is_defending = false
	actor.gain_ap(1)
	var name := actor.get_display_name()
	match actor.status:
		BattleCreature.Status.SONNO:
			actor.status_turns -= 1
			if actor.status_turns <= 0:
				actor.cure_status()
				_say("%s si è svegliato!" % name, _info(actor))
			else:
				_say("%s dorme profondamente..." % name)
				_skip_turn(actor)
				return false
		BattleCreature.Status.GELO:
			if randf() < 0.25:
				actor.cure_status()
				_say("%s si è scongelato!" % name, _info(actor))
			else:
				_say("%s è congelato e non si muove!" % name)
				_skip_turn(actor)
				return false
		BattleCreature.Status.PARALISI:
			if randf() < 0.25:
				_say("%s è paralizzato! Non riesce a muoversi." % name)
				_skip_turn(actor)
				return false
		BattleCreature.Status.CONFUSIONE:
			actor.status_turns -= 1
			if actor.status_turns <= 0:
				actor.cure_status()
				_say("%s non è più confuso." % name, _info(actor))
			elif randf() < 0.33:
				_say("%s è confuso e si colpisce da solo!" % name)
				var hit := BattleRules.roll_damage(actor, actor, BattleRules.BASIC_ATTACK_POWER,
					SkillData.Category.FISICA, -1, chart)
				actor.take_damage(hit["damage"])
				_say("", _info(actor, "damage"))
				_skip_turn(actor)
				return false
	return true


func _skip_turn(actor: BattleCreature) -> void:
	actor.last_action_skill = null
	_end_turn(actor, BattleRules.RANK_NORMAL)


## Fine turno: danni da bruciatura/veleno, durata dei potenziamenti, nuovo contatore.
func _end_turn(actor: BattleCreature, rank := -1.0) -> void:
	current_actor = null
	if state == State.FINITA:
		return
	# Se l'attore è stato cambiato durante l'azione, chi è entrato ha già il suo contatore.
	if actor != player_active() and actor != enemy_active():
		_check_ko()
		return
	if not actor.is_ko():
		var name := actor.get_display_name()
		if actor.status == BattleCreature.Status.BRUCIATURA:
			actor.take_damage(maxi(1, actor.max_hp / 16))
			_say("%s soffre per la bruciatura." % name, _info(actor, "damage"))
		elif actor.status == BattleCreature.Status.VELENO:
			actor.take_damage(maxi(1, actor.max_hp / 8))
			_say("%s soffre per il veleno." % name, _info(actor, "damage"))
		for stat in actor.tick_stages():
			_say("%s: %s torna normale." % [name, STAT_NAMES[stat]], _info(actor))
	if rank >= 0.0:
		actor.ctb_counter += BattleRules.ctb_delay(actor, rank)
	_check_ko()


# =============================================================================
#  Azioni del giocatore
# =============================================================================

## Il giocatore ha scelto un'azione. Restituisce false se non è valida (es. PA insufficienti).
func submit_action(action: BattleAction) -> bool:
	if state != State.ATTESA_GIOCATORE:
		return false
	if not is_action_valid(action):
		return false
	state = State.PRONTO
	var p := player_active()
	_execute(p, enemy_active(), action)
	_end_turn(p)
	_advance()
	return true


## Dopo un KO il giocatore deve scegliere chi mandare in campo. Non costa il turno.
func submit_forced_switch(index: int) -> bool:
	if state != State.CAMBIO_OBBLIGATO or not can_enter(index):
		return false
	var incoming := player_party[index]
	player_index = index
	incoming.reset_battle_state()
	incoming.ctb_counter = BattleRules.ctb_delay(incoming, BattleRules.RANK_SWITCH)
	_say("Vai, %s!" % incoming.get_display_name(), {"kind": "switch", "target": incoming})
	state = State.PRONTO
	_advance()
	return true


func is_action_valid(action: BattleAction) -> bool:
	var p := player_active()
	match action.type:
		BattleAction.Type.ABILITA:
			return action.skill != null and action.skill in p.skills and p.can_use(action.skill)
		BattleAction.Type.CAMBIO:
			return can_enter(action.switch_index)
		BattleAction.Type.OGGETTO:
			return ITEMS.has(action.item_id) and inventory.get(action.item_id, 0) > 0
		BattleAction.Type.FUGA:
			return is_wild
		BattleAction.Type.CATTURA:
			return false   # la cattura arriva in M3
	return true


func can_enter(index: int) -> bool:
	return index >= 0 and index < player_party.size() and index != player_index \
		and not player_party[index].is_ko()


## La Staffetta: il cambio diventa una Staffetta se
##   - nel suo ultimo turno la creatura in campo ha usato un'abilità d'attacco,
##   - quell'abilità è di un elemento che anche la creatura che ENTRA possiede,
##   - la creatura in campo ha almeno 3 PA (li spende per il "passaggio").
## Chi entra attacca subito con un colpo potenziato, invece di aspettare.
func can_relay(index: int) -> bool:
	if not can_enter(index):
		return false
	var p := player_active()
	var last := p.last_action_skill
	if last == null or last.category == SkillData.Category.SUPPORTO:
		return false
	if p.ap < BattleRules.RELAY_AP_COST:
		return false
	return last.element in player_party[index].get_types()


# =============================================================================
#  Esecuzione delle azioni (vale per giocatore e nemico)
# =============================================================================

func _execute(actor: BattleCreature, target: BattleCreature, action: BattleAction) -> void:
	var name := actor.get_display_name()
	if action.type == BattleAction.Type.CAMBIO:
		# Il cambio va gestito prima di dimenticare l'ultima abilità: serve alla Staffetta.
		_do_switch(actor, action.switch_index)
		return   # il contatore di chi entra viene impostato in _do_switch
	actor.last_action_skill = null
	var rank := BattleRules.RANK_NORMAL
	match action.type:
		BattleAction.Type.ATTACCO:
			_say("%s attacca!" % name)
			_do_damage(actor, target, BattleRules.BASIC_ATTACK_POWER, _best_category(actor), -1, 100)
		BattleAction.Type.ABILITA:
			var s := action.skill
			actor.ap -= s.ap_cost
			_say("%s usa %s!" % [name, s.display_name], _info(actor))
			_use_skill(actor, target, s)
			actor.last_action_skill = s
			rank = BattleRules.skill_rank(s)
		BattleAction.Type.DIFENDI:
			actor.is_defending = true
			actor.gain_ap(BattleRules.DEFEND_AP_BONUS)
			_say("%s si difende e raccoglie energie (+%d PA)." % [name, BattleRules.DEFEND_AP_BONUS], _info(actor))
			rank = BattleRules.RANK_DEFEND
		BattleAction.Type.OGGETTO:
			_use_item(actor, action.item_id)
		BattleAction.Type.FUGA:
			_try_flee(actor, target)
	if state != State.FINITA:
		actor.ctb_counter += BattleRules.ctb_delay(actor, rank)


## Fisico o magico? L'Attacco base usa la statistica più alta delle due.
func _best_category(c: BattleCreature) -> SkillData.Category:
	return SkillData.Category.FISICA if c.attack >= c.magic else SkillData.Category.MAGICA


func _use_skill(actor: BattleCreature, target: BattleCreature, s: SkillData) -> void:
	if s.category == SkillData.Category.SUPPORTO:
		var on_self := _effect_targets_self(s.status_effect)
		if not on_self and randf() >= BattleRules.hit_chance(actor, s.accuracy):
			_say("Ma fallisce!")
			return
		if not _apply_effect(actor, target, s.status_effect, 0):
			_say("Non ha alcun effetto.")
		return
	var dealt := _do_damage(actor, target, s.power, s.category, s.element, s.accuracy)
	if dealt > 0 and s.status_effect != &"" and randf() * 100.0 < s.status_chance:
		_apply_effect(actor, target, s.status_effect, dealt)


## Applica un colpo con danno. Restituisce i PS tolti (0 se manca il bersaglio).
func _do_damage(actor: BattleCreature, target: BattleCreature, power: int,
		category: SkillData.Category, element: int, accuracy: int, extra := 1.0) -> int:
	if randf() >= BattleRules.hit_chance(actor, accuracy):
		_say("Il colpo va a vuoto!")
		return 0
	var mult := BattleRules.type_multiplier(chart, element, target) if element >= 0 else 1.0
	if mult == 0.0:
		_say("Non ha effetto su %s..." % target.get_display_name())
		return 0
	extra *= _difficulty_mult(actor)
	var hit := BattleRules.roll_damage(actor, target, power, category, element, chart, extra)
	var dealt := target.take_damage(hit["damage"])
	var text := ""
	if hit["crit"]:
		text = "Colpo critico! "
	if mult > 1.0:
		text += "È superefficace!"
	elif mult < 1.0:
		text += "Non è molto efficace..."
	var ev := _info(target, "damage")
	ev["amount"] = dealt
	ev["mult"] = mult
	_say(text.strip_edges(), ev)
	if mult > 1.0 and target.is_large() and not target.is_ko():
		_hit_break_gauge(target)
	return dealt


## I danni del nemico cambiano con la difficoltà (e un pochino quelli del giocatore in Facile).
func _difficulty_mult(actor: BattleCreature) -> float:
	if actor in enemy_party:
		return BattleRules.enemy_damage_mult(difficulty)
	return BattleRules.player_damage_mult(difficulty)


## Rottura: colpire un mostro grande sulla debolezza svuota la sua barra.
## Quando arriva a zero il mostro perde un turno (e più avanti lascerà un materiale extra).
func _hit_break_gauge(target: BattleCreature) -> void:
	target.break_gauge -= BattleRules.BREAK_DAMAGE
	if target.break_gauge <= 0:
		target.break_count += 1
		target.break_gauge = BattleCreature.BREAK_MAX
		target.ctb_counter += BattleRules.ctb_delay(target, BattleRules.RANK_NORMAL)
		_say("ROTTURA! %s barcolla e perde un turno!" % target.get_display_name(),
			_info(target, "break"))
	else:
		_say("", _info(target, "break"))


func _effect_targets_self(effect: StringName) -> bool:
	if effect == &"cura_25" or effect == &"assorbimento":
		return true
	if STAGE_EFFECTS.has(effect):
		return STAGE_EFFECTS[effect][2] == "self"
	return false


## Applica l'effetto di un'abilità. Restituisce false se non ha fatto nulla.
## `dealt` = danno appena inflitto (serve ad "assorbimento").
func _apply_effect(actor: BattleCreature, target: BattleCreature, effect: StringName, dealt: int) -> bool:
	if effect == &"":
		return false
	if STATUS_EFFECTS.has(effect):
		if target.is_ko():
			return false
		var st: BattleCreature.Status = STATUS_EFFECTS[effect]
		if target.apply_status(st):
			_say("%s: %s!" % [target.get_display_name(), BattleCreature.status_name(st)], _info(target))
			return true
		return false
	if STAGE_EFFECTS.has(effect):
		var info: Array = STAGE_EFFECTS[effect]
		var who := actor if info[2] == "self" else target
		if who.is_ko() or not who.change_stage(info[0], info[1]):
			return false
		var verb := "aumenta" if info[1] > 0 else "diminuisce"
		_say("%s: %s %s!" % [who.get_display_name(), STAT_NAMES[info[0]], verb], _info(who))
		return true
	match effect:
		&"cura_25":
			var healed := actor.heal(actor.max_hp / 4)
			if healed <= 0:
				return false
			_say("%s recupera %d PS." % [actor.get_display_name(), healed], _info(actor, "heal"))
			return true
		&"assorbimento":
			var healed := actor.heal(maxi(1, dealt / 4))
			if healed <= 0:
				return false
			_say("%s assorbe %d PS." % [actor.get_display_name(), healed], _info(actor, "heal"))
			return true
		&"tentennamento":
			# In un sistema CTB "tentennare" significa perdere tempo: il turno arriva più tardi.
			if target.is_ko():
				return false
			target.ctb_counter += BattleRules.ctb_delay(target, 0.4)
			_say("%s tentenna e perde tempo!" % target.get_display_name())
			return true
	push_warning("Effetto sconosciuto: %s" % effect)
	return false


func _do_switch(actor: BattleCreature, index: int) -> void:
	var relay := can_relay(index)
	var outgoing := actor
	var incoming := player_party[index]
	var shared_element := outgoing.last_action_skill.element if relay else -1
	if relay:
		outgoing.ap -= BattleRules.RELAY_AP_COST
	outgoing.reset_battle_state()
	player_index = index
	incoming.reset_battle_state()
	_say("Torna, %s!" % outgoing.get_display_name())
	_say("Vai, %s!" % incoming.get_display_name(), {"kind": "switch", "target": incoming})
	if relay:
		# Staffetta: chi entra attacca subito con un colpo potenziato dello stesso elemento.
		_say("STAFFETTA! %s entra all'attacco!" % incoming.get_display_name(), {"kind": "relay", "target": incoming})
		_do_damage(incoming, enemy_active(), BattleRules.RELAY_POWER, _best_category(incoming),
			shared_element, 100, BattleRules.RELAY_BONUS)
	incoming.ctb_counter = BattleRules.ctb_delay(incoming, BattleRules.RANK_SWITCH)


func _use_item(actor: BattleCreature, id: StringName) -> void:
	inventory[id] -= 1
	var item: Dictionary = ITEMS[id]
	_say("Usi %s su %s." % [item["name"], actor.get_display_name()])
	if item.has("heal_pct"):
		var healed := actor.heal(int(actor.max_hp * item["heal_pct"]))
		_say("%s recupera %d PS." % [actor.get_display_name(), healed], _info(actor, "heal"))
	if item.has("ap"):
		actor.gain_ap(item["ap"])
		_say("%s ha ora %d PA." % [actor.get_display_name(), actor.ap], _info(actor))
	if item.get("cure", false):
		actor.cure_status()
		_say("%s sta di nuovo bene." % actor.get_display_name(), _info(actor))


func _try_flee(actor: BattleCreature, enemy: BattleCreature) -> void:
	var chance := BattleRules.flee_chance_large(actor, enemy, flee_attempts) if enemy.is_large() \
		else BattleRules.flee_chance(actor, enemy, flee_attempts)
	flee_attempts += 1
	if randf() < chance:
		_say("Sei fuggito!")
		_finish(Result.FUGA)
	else:
		_say("Non riesci a fuggire!")


# =============================================================================
#  KO e fine battaglia
# =============================================================================

func _check_ko() -> void:
	if state == State.FINITA:
		return
	var e := enemy_active()
	if e.is_ko():
		_say("%s è esausto!" % e.get_display_name(), {"kind": "ko", "target": e})
		var next := ai.choose_replacement(self)
		if next < 0:
			_finish(Result.VITTORIA)
			return
		enemy_index = next
		var ne := enemy_active()
		ne.reset_battle_state()
		ne.ctb_counter = BattleRules.ctb_delay(ne, BattleRules.RANK_SWITCH)
		_say("Il nemico manda in campo %s!" % ne.get_display_name(), {"kind": "switch", "target": ne})
	var p := player_active()
	if p.is_ko():
		_say("%s è esausto!" % p.get_display_name(), {"kind": "ko", "target": p})
		if _first_alive(player_party) < 0:
			_finish(Result.SCONFITTA)
		else:
			state = State.CAMBIO_OBBLIGATO
			_say("Scegli chi mandare in campo.", {"kind": "forced_switch"})


func _finish(r: Result) -> void:
	result = r
	state = State.FINITA
	current_actor = null
	match r:
		Result.VITTORIA:
			_say("Hai vinto!", {"kind": "end"})
		Result.SCONFITTA:
			_say("Tutte le tue creature sono esauste...", {"kind": "end"})
		Result.FUGA:
			_say("", {"kind": "end"})
	for c in player_party + enemy_party:
		c.reset_battle_state()


func _first_alive(party: Array[BattleCreature]) -> int:
	for i in party.size():
		if not party[i].is_ko():
			return i
	return -1


# =============================================================================
#  Eventi
# =============================================================================

## Aggiunge un evento alla lista. I messaggi vuoti servono solo ad aggiornare le barre.
func _say(text: String, extra: Dictionary = {}) -> void:
	var ev := extra.duplicate()
	ev["text"] = text
	if not ev.has("kind"):
		ev["kind"] = "message"
	events.append(ev)


## Fotografia dei valori di una creatura in questo istante, per animare le barre.
func _info(c: BattleCreature, kind := "update") -> Dictionary:
	return {"kind": kind, "target": c, "hp": c.hp, "ap": c.ap, "status": c.status,
		"break": c.break_gauge}
