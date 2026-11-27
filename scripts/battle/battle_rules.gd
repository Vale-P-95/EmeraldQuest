class_name BattleRules
extends RefCounted
## Le "formule" della battaglia, tutte in un posto: danno, precisione, fuga,
## velocità dei turni e difficoltà. Sono funzioni statiche: si chiamano con
## BattleRules.nome_funzione(...) senza creare nessun oggetto.
##
## Se vuoi bilanciare il gioco, i numeri da toccare sono le costanti qui sotto.

enum Difficulty { FACILE, NORMALE, DIFFICILE }

const BASIC_ATTACK_POWER := 35   ## potenza dell'Attacco base (gratis, senza elemento)
const RELAY_POWER := 60          ## potenza dell'attacco di entrata della Staffetta
const RELAY_BONUS := 1.5         ## la Staffetta fa il 50% di danno in più
const RELAY_AP_COST := 3         ## PA spesi dalla creatura che esce
const STAB_BONUS := 1.25         ## bonus se l'elemento dell'abilità è uno dei tipi di chi la usa
const CRIT_CHANCE := 0.0625      ## 1 colpo su 16 è critico
const CRIT_BONUS := 1.5
const DEFEND_AP_BONUS := 2       ## Difendi dà +2 PA (oltre all'1 di ogni turno)
const DEFEND_DAMAGE_MULT := 0.5  ## chi difende subisce metà danni
const BREAK_DAMAGE := 34         ## quanto scende la Rottura per ogni colpo sulla debolezza

## Tick CTB: più è alto questo numero, più "fine" è la coda dei turni.
## Il ritardo dopo un'azione è CTB_BASE * peso_azione / velocità.
const CTB_BASE := 10000.0
const RANK_NORMAL := 1.0         ## Attacco, abilità leggere, oggetti
const RANK_DEFEND := 0.7         ## Difendi: si torna a giocare prima
const RANK_HEAVY := 1.3          ## abilità da 4-5 PA: colpiscono forte ma rallentano
const RANK_SWITCH := 1.0         ## la creatura che entra aspetta un turno normale


## Quanto i danni del NEMICO vengono moltiplicati in base alla difficoltà.
static func enemy_damage_mult(d: Difficulty) -> float:
	match d:
		Difficulty.FACILE: return 0.75
		Difficulty.DIFFICILE: return 1.25
	return 1.0


## Quanto i danni del GIOCATORE vengono moltiplicati in base alla difficoltà.
static func player_damage_mult(d: Difficulty) -> float:
	match d:
		Difficulty.FACILE: return 1.15
	return 1.0


static func difficulty_name(d: Difficulty) -> String:
	match d:
		Difficulty.FACILE: return "Facile"
		Difficulty.DIFFICILE: return "Difficile"
	return "Normale"


## Ritardo CTB (in tick) dopo un'azione di un certo "peso".
static func ctb_delay(creature: BattleCreature, rank: float) -> int:
	return maxi(1, int(CTB_BASE * rank / creature.get_stat("speed")))


## Peso CTB di un'abilità: quelle costose rallentano chi le usa.
static func skill_rank(skill: SkillData) -> float:
	return RANK_HEAVY if skill.ap_cost >= 4 else RANK_NORMAL


## Il moltiplicatore di tipo (x2 forte, x0,5 debole, x0 immune) dalla tabella.
static func type_multiplier(chart: TypeChart, element: Element.Type, defender: BattleCreature) -> float:
	if chart == null:
		return 1.0
	return chart.get_multiplier_against(element, defender.get_types())


## Il danno "atteso" senza parte casuale né critico. L'IA lo usa per scegliere.
## element = -1 significa "nessun elemento" (l'Attacco base).
static func estimate_damage(attacker: BattleCreature, defender: BattleCreature, power: int,
		category: SkillData.Category, element: int, chart: TypeChart) -> float:
	if power <= 0 or category == SkillData.Category.SUPPORTO:
		return 0.0
	var atk: float
	var def: float
	if category == SkillData.Category.FISICA:
		atk = attacker.get_stat("attack")
		def = defender.get_stat("defense")
	else:
		atk = attacker.get_stat("magic")
		def = defender.get_stat("spirit")
	# Formula classica degli RPG a turni: cresce col livello e con il rapporto attacco/difesa.
	var dmg := ((2.0 * attacker.level / 5.0 + 2.0) * power * atk / def) / 50.0 + 2.0
	if element >= 0:
		if element in attacker.get_types():
			dmg *= STAB_BONUS
		dmg *= type_multiplier(chart, element, defender)
	if defender.is_defending:
		dmg *= DEFEND_DAMAGE_MULT
	return dmg


## Il danno vero: quello atteso, più una variazione casuale (85%-100%) e il critico.
## Restituisce {"damage": int, "crit": bool}.
static func roll_damage(attacker: BattleCreature, defender: BattleCreature, power: int,
		category: SkillData.Category, element: int, chart: TypeChart, extra_mult := 1.0) -> Dictionary:
	var dmg := estimate_damage(attacker, defender, power, category, element, chart) * extra_mult
	var crit := randf() < CRIT_CHANCE
	if crit:
		dmg *= CRIT_BONUS
	dmg *= randf_range(0.85, 1.0)
	var final := 0 if dmg <= 0.0 else maxi(1, int(dmg))
	return {"damage": final, "crit": crit}


## Probabilità (0-1) che un'abilità colpisca, contando gli indebolimenti di precisione.
static func hit_chance(attacker: BattleCreature, accuracy: int) -> float:
	var mult := BattleCreature.stage_multiplier(attacker.get_stage("accuracy"))
	return clampf(accuracy / 100.0 * mult, 0.0, 1.0)


## Probabilità di fuga: più sei veloce rispetto al nemico, più è facile.
## Ogni tentativo fallito la aumenta un po'.
static func flee_chance(runner: BattleCreature, enemy: BattleCreature, attempts: int) -> float:
	var ratio := runner.get_stat("speed") / enemy.get_stat("speed")
	return clampf(0.35 + 0.3 * ratio + 0.15 * attempts, 0.1, 0.95)


## Per i mostri grandi la fuga è più difficile.
static func flee_chance_large(runner: BattleCreature, enemy: BattleCreature, attempts: int) -> float:
	return flee_chance(runner, enemy, attempts) * 0.6
