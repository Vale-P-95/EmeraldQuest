class_name BattleCreature
extends RefCounted
## Una creatura "viva", con i suoi PS attuali, i PA e gli stati.
##
## CreatureData (in scripts/data/) è la scheda della SPECIE, uguale per tutti
## i Fiammolo del mondo. BattleCreature invece è UN esemplare preciso: ha un
## livello, ha perso dei PS, magari è bruciato. È un RefCounted (un oggetto
## semplice, non un nodo) così la logica della battaglia si può provare anche
## nei test, senza aprire nessuna scena.

const MAX_AP := 5          ## i PA vanno da 0 a 5
const START_AP := 1        ## PA con cui si entra in battaglia
const MAX_SKILLS := 4      ## abilità usabili in battaglia (le ultime imparate)
const BUFF_TURNS := 3      ## quanti turni durano potenziamenti e indebolimenti
const BREAK_MAX := 100     ## barra di Rottura dei mostri grandi
const LARGE_HP_MULT := 2.5 ## i mostri grandi hanno molti più PS

## Gli stati "gravi": se ne può avere uno solo alla volta, come nei classici.
enum Status { NESSUNO, BRUCIATURA, VELENO, SONNO, PARALISI, GELO, CONFUSIONE }

var data: CreatureData
var level := 5
var nickname := ""

# Statistiche calcolate dal livello (vedi _compute_stats).
var max_hp := 1
var hp := 1
var attack := 1
var defense := 1
var magic := 1
var spirit := 1
var speed := 1

var ap := START_AP
var skills: Array[SkillData] = []

var status: Status = Status.NESSUNO
var status_turns := 0       ## turni rimasti (sonno e confusione); 0 = finché non guarisce

## Potenziamenti/indebolimenti. Chiave = nome statistica ("attack", "defense",
## "magic", "spirit", "speed", "accuracy"), valore = {"stage": int, "turns": int}.
## stage va da -2 a +2.
var stat_stages := {}

var is_defending := false    ## ha scelto Difendi: dimezza i danni fino al suo prossimo turno
var last_action_skill: SkillData = null  ## abilità usata nel suo ultimo turno (serve alla Staffetta)

## Contatore CTB: quanti "tick" mancano al suo prossimo turno. Chi ha il valore
## più basso agisce per primo. Lo gestisce BattleEngine.
var ctb_counter := 0

## Barra di Rottura (solo mostri grandi): quando arriva a 0 il mostro salta un turno.
var break_gauge := BREAK_MAX
var break_count := 0         ## quante volte è stato "rotto" (servirà per i materiali extra)


## Crea un esemplare di una specie a un certo livello, con PS e PA pieni.
static func create(species: CreatureData, lvl: int, nick := "") -> BattleCreature:
	var c := BattleCreature.new()
	c.data = species
	c.level = clampi(lvl, 1, 100)
	c.nickname = nick
	c._compute_stats()
	c.hp = c.max_hp
	c._pick_skills()
	return c


## Nome mostrato a schermo: il soprannome se c'è, altrimenti il nome della specie.
func get_display_name() -> String:
	if nickname != "":
		return nickname
	return data.display_name


func is_ko() -> bool:
	return hp <= 0


func is_large() -> bool:
	return data.is_large_monster


func get_types() -> Array[Element.Type]:
	return data.types


## Formula semplice e leggibile: le statistiche crescono in modo lineare col livello.
## (Valori di base 50 al livello 50 danno circa 55; i PS sono un po' più alti.)
func _compute_stats() -> void:
	max_hp = int(data.hp * 2 * level / 100.0) + level + 10
	if data.is_large_monster:
		max_hp = int(max_hp * LARGE_HP_MULT)
	attack = int(data.attack * 2 * level / 100.0) + 5
	defense = int(data.defense * 2 * level / 100.0) + 5
	magic = int(data.magic * 2 * level / 100.0) + 5
	spirit = int(data.spirit * 2 * level / 100.0) + 5
	speed = int(data.speed * 2 * level / 100.0) + 5


## Prende le ultime 4 abilità imparate fino al livello attuale.
func _pick_skills() -> void:
	skills.clear()
	var levels := data.learnset.keys()
	levels.sort()
	for lv in levels:
		if lv <= level and data.learnset[lv] != null:
			skills.append(data.learnset[lv])
	while skills.size() > MAX_SKILLS:
		skills.pop_front()


# --- Statistiche effettive (con potenziamenti e stati) ----------------------

## Moltiplicatore di uno stadio: +1 = x1,5, +2 = x2, -1 = x0,67, -2 = x0,5.
static func stage_multiplier(stage: int) -> float:
	if stage >= 0:
		return 1.0 + 0.5 * stage
	return 1.0 / (1.0 - 0.5 * stage)


func get_stage(stat: String) -> int:
	if stat_stages.has(stat):
		return stat_stages[stat]["stage"]
	return 0


## Restituisce la statistica con potenziamenti, indebolimenti e stati applicati.
func get_stat(stat: String) -> float:
	var base := float(get(stat))
	var value := base * stage_multiplier(get_stage(stat))
	if stat == "attack" and status == Status.BRUCIATURA:
		value *= 0.75   # la bruciatura indebolisce gli attacchi fisici
	if stat == "speed" and status == Status.PARALISI:
		value *= 0.5    # la paralisi rallenta
	return maxf(value, 1.0)


## Cambia lo stadio di una statistica (es. +1 Difesa). Dura BUFF_TURNS turni.
## Restituisce false se era già al massimo/minimo.
func change_stage(stat: String, amount: int) -> bool:
	var old := get_stage(stat)
	var new_stage := clampi(old + amount, -2, 2)
	if new_stage == old:
		return false
	if new_stage == 0:
		stat_stages.erase(stat)
	else:
		stat_stages[stat] = {"stage": new_stage, "turns": BUFF_TURNS}
	return true


## Alla fine di ogni suo turno i potenziamenti perdono un turno di durata.
## Restituisce i nomi delle statistiche tornate normali.
func tick_stages() -> Array[String]:
	var expired: Array[String] = []
	for stat in stat_stages.keys():
		stat_stages[stat]["turns"] -= 1
		if stat_stages[stat]["turns"] <= 0:
			expired.append(stat)
	for stat in expired:
		stat_stages.erase(stat)
	return expired


# --- PS e PA ----------------------------------------------------------------

## Toglie PS e restituisce quanti ne ha tolti davvero.
func take_damage(amount: int) -> int:
	var dealt := mini(amount, hp)
	hp -= dealt
	return dealt


## Cura e restituisce quanti PS ha recuperato davvero.
func heal(amount: int) -> int:
	var healed := mini(amount, max_hp - hp)
	hp += healed
	return healed


func gain_ap(amount: int) -> void:
	ap = clampi(ap + amount, 0, MAX_AP)


func can_use(skill: SkillData) -> bool:
	return skill.ap_cost <= ap


## Prova a dare uno stato grave. Non funziona se ne ha già uno.
func apply_status(new_status: Status) -> bool:
	if status != Status.NESSUNO or is_ko():
		return false
	status = new_status
	match new_status:
		Status.SONNO:
			status_turns = randi_range(1, 3)
		Status.CONFUSIONE:
			status_turns = randi_range(2, 4)
		_:
			status_turns = 0
	return true


func cure_status() -> void:
	status = Status.NESSUNO
	status_turns = 0


## Rimette la creatura come nuova (dopo una sconfitta o al centro cure).
func full_restore() -> void:
	hp = max_hp
	ap = START_AP
	cure_status()
	reset_battle_state()


## Toglie ciò che vale solo dentro una battaglia (potenziamenti, difesa, Rottura).
## Si chiama quando la creatura esce dal campo o finisce la lotta.
func reset_battle_state() -> void:
	stat_stages.clear()
	is_defending = false
	last_action_skill = null
	break_gauge = BREAK_MAX


static func status_name(s: Status) -> String:
	match s:
		Status.BRUCIATURA: return "Bruciatura"
		Status.VELENO: return "Veleno"
		Status.SONNO: return "Sonno"
		Status.PARALISI: return "Paralisi"
		Status.GELO: return "Gelo"
		Status.CONFUSIONE: return "Confusione"
	return ""
