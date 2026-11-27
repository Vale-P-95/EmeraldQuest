class_name BattleAI
extends RefCounted
## L'intelligenza del nemico. Per ogni azione possibile calcola un "punteggio"
## (quanto gli conviene) e poi sceglie in base alla difficoltà:
##   Facile    -> spesso sceglie a caso, non sfrutta bene le debolezze
##   Normale   -> sceglie tra le due azioni migliori, con un po' di fortuna
##   Difficile -> sceglie sempre la migliore, risparmia PA per i colpi forti


## `level` = con quale "bravura" scegliere; -1 = usa la difficoltà della battaglia.
## (I test la usano per far giocare il giocatore sempre allo stesso livello.)
func choose_action(engine: BattleEngine, actor: BattleCreature, target: BattleCreature,
		level: int = -1) -> BattleAction:
	var skill_level: int = engine.difficulty if level < 0 else level
	var options := _score_options(engine, actor, target, skill_level)
	# Dal punteggio più alto al più basso.
	options.sort_custom(func(a, b): return a["score"] > b["score"])
	match skill_level:
		BattleRules.Difficulty.FACILE:
			if randf() < 0.5:
				return options.pick_random()["action"]
			return options[0]["action"]
		BattleRules.Difficulty.NORMALE:
			if options.size() > 1 and randf() < 0.3:
				return options[1]["action"]
			return options[0]["action"]
	return options[0]["action"]


## Quando la creatura nemica in campo va KO, chi manda? -1 = nessuno (il giocatore vince).
## In Difficile sceglie quella con il miglior vantaggio di tipo.
func choose_replacement(engine: BattleEngine) -> int:
	var best := -1
	var best_score := -INF
	for i in engine.enemy_party.size():
		var c := engine.enemy_party[i]
		if c.is_ko():
			continue
		if engine.difficulty != BattleRules.Difficulty.DIFFICILE:
			return i
		var score := _matchup(engine, c, engine.player_active())
		if score > best_score:
			best_score = score
			best = i
	return best


## Restituisce una lista di {"action": BattleAction, "score": float}.
func _score_options(engine: BattleEngine, actor: BattleCreature, target: BattleCreature,
		skill_level: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var basic_cat := SkillData.Category.FISICA if actor.attack >= actor.magic else SkillData.Category.MAGICA
	var basic := BattleRules.estimate_damage(actor, target, BattleRules.BASIC_ATTACK_POWER, basic_cat, -1, engine.chart)
	out.append({"action": BattleAction.basic_attack(), "score": _damage_score(basic, target)})

	var best_unaffordable := 0.0   # il danno della migliore abilità che non può ancora permettersi
	for s in actor.skills:
		var score := _skill_score(engine, actor, target, s, basic, skill_level)
		if actor.can_use(s):
			out.append({"action": BattleAction.use_skill(s), "score": score})
		else:
			best_unaffordable = maxf(best_unaffordable, score)

	# Difendere conviene se così, tra poco, potrà usare un colpo molto più forte.
	var defend_score := basic * 0.4
	if skill_level == BattleRules.Difficulty.DIFFICILE and best_unaffordable > basic * 2.0 \
			and target.hp > basic * 2.0:
		defend_score = basic * 1.2
	out.append({"action": BattleAction.defend(), "score": defend_score})
	return out


func _skill_score(engine: BattleEngine, actor: BattleCreature, target: BattleCreature,
		s: SkillData, basic: float, skill_level: int) -> float:
	var effect := s.status_effect
	if s.category == SkillData.Category.SUPPORTO:
		var hit := s.accuracy / 100.0
		if effect == &"cura_25":
			# Curarsi vale molto solo se è ferito.
			var missing := 1.0 - float(actor.hp) / actor.max_hp
			return basic * 3.0 * missing
		if BattleEngine.STATUS_EFFECTS.has(effect):
			return basic * 1.3 * hit if target.status == BattleCreature.Status.NESSUNO else 0.0
		if BattleEngine.STAGE_EFFECTS.has(effect):
			var info: Array = BattleEngine.STAGE_EFFECTS[effect]
			var who := actor if info[2] == "self" else target
			# Un potenziamento già attivo non serve a nulla.
			return basic * 0.9 * hit if who.get_stage(info[0]) == 0 else 0.0
		return 0.0
	var dmg := BattleRules.estimate_damage(actor, target, s.power, s.category, s.element, engine.chart)
	dmg *= s.accuracy / 100.0
	# In Facile l'IA "non conosce" la tabella dei tipi: ignora i vantaggi.
	if skill_level == BattleRules.Difficulty.FACILE:
		var mult := BattleRules.type_multiplier(engine.chart, s.element, target)
		if mult > 0.0:
			dmg /= mult
	return _damage_score(dmg, target) - s.ap_cost * 0.5


## Un colpo che manda KO vale molto di più del suo danno.
func _damage_score(dmg: float, target: BattleCreature) -> float:
	if dmg >= target.hp:
		return dmg + 100.0
	return dmg


## Quanto una creatura è avvantaggiata (positivo) o svantaggiata contro un'altra.
func _matchup(engine: BattleEngine, c: BattleCreature, opponent: BattleCreature) -> float:
	var score := 0.0
	for t in c.get_types():
		score += BattleRules.type_multiplier(engine.chart, t, opponent)
	for t in opponent.get_types():
		score -= BattleRules.type_multiplier(engine.chart, t, c)
	return score
