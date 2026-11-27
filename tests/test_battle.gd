extends SceneTree
## Test automatici della logica di battaglia (non serve aprire l'editor).
## Si lanciano dalla radice del progetto con:
##   godot --headless --path . -s res://tests/test_battle.gd
## Stampa "TUTTI I TEST PASSATI" oppure l'elenco dei test falliti (ed esce con codice 1).

var _failures: Array[String] = []
var _chart: TypeChart = load("res://data/types/type_chart.tres")


func _initialize() -> void:
	seed(12345)
	_test_stats_and_skills()
	_test_type_chart_damage()
	_test_ctb_order()
	_test_ap_and_defend()
	_test_relay()
	_test_forced_switch_and_defeat()
	_test_full_battles_all_difficulties()
	_test_break_gauge()
	_test_boss_balance()
	_test_items_and_flee()
	if _failures.is_empty():
		print("TUTTI I TEST PASSATI")
		quit(0)
	else:
		for f in _failures:
			printerr("FALLITO: ", f)
		quit(1)


func _check(cond: bool, what: String) -> void:
	if not cond:
		_failures.append(what)


func _make(id: String, lvl: int) -> BattleCreature:
	return BattleCreature.create(load("res://data/creatures/%s.tres" % id), lvl)


func _engine(p: Array[BattleCreature], e: Array[BattleCreature],
		d := BattleRules.Difficulty.NORMALE) -> BattleEngine:
	var eng := BattleEngine.new()
	eng.setup(p, e, _chart, d, {&"pozione": 2, &"etere": 1})
	return eng


func _test_stats_and_skills() -> void:
	var c := _make("fiammolo", 10)
	_check(c.hp == c.max_hp and c.max_hp > 20, "PS iniziali pieni")
	_check(c.skills.size() == 3, "Fiammolo Lv10 conosce 3 abilità (ne ha %d)" % c.skills.size())
	var big := _make("selvarbo", 50)
	_check(big.skills.size() <= BattleCreature.MAX_SKILLS, "al massimo 4 abilità")
	_check(c.change_stage("defense", 1) and c.get_stat("defense") > c.defense, "potenziamento Difesa")
	for i in BattleCreature.BUFF_TURNS:
		c.tick_stages()
	_check(c.get_stage("defense") == 0, "il potenziamento dura 3 turni")


func _test_type_chart_damage() -> void:
	var fire := _make("fiammolo", 10)
	var grass := _make("germoglio", 10)
	var water := _make("gocciolo", 10)
	var on_grass := BattleRules.estimate_damage(fire, grass, 40, SkillData.Category.MAGICA, Element.Type.FUOCO, _chart)
	var on_water := BattleRules.estimate_damage(fire, water, 40, SkillData.Category.MAGICA, Element.Type.FUOCO, _chart)
	_check(on_grass > on_water * 2.0, "Fuoco è forte su Flora e debole su Acqua")
	grass.is_defending = true
	var defended := BattleRules.estimate_damage(fire, grass, 40, SkillData.Category.MAGICA, Element.Type.FUOCO, _chart)
	_check(absf(defended - on_grass * 0.5) < 0.01, "Difendi dimezza i danni")


func _test_ctb_order() -> void:
	var fast := _make("fulgurala", 20)   # velocità 110
	var slow := _make("selvarbo", 20)    # velocità 40
	var eng := _engine([fast], [slow])
	eng.start()
	var queue := eng.predict_turns(8)
	_check(queue.size() == 8, "la coda mostra 8 turni")
	var fast_turns := queue.count(fast)
	_check(fast_turns >= 5, "il più veloce agisce più spesso (%d su 8)" % fast_turns)
	_check(eng.state == BattleEngine.State.ATTESA_GIOCATORE, "il veloce agisce per primo e il tempo si ferma")


func _test_ap_and_defend() -> void:
	var p := _make("fiammolo", 10)
	var e := _make("selvarbo", 12)
	var eng := _engine([p], [e])
	eng.start()
	var before := p.ap
	eng.take_events()
	_check(eng.submit_action(BattleAction.defend()), "Difendi è sempre valido")
	# Al nuovo turno: +2 da Difendi e +1 di inizio turno.
	_check(p.ap == mini(before + 3, BattleCreature.MAX_AP), "PA dopo Difendi (%d -> %d)" % [before, p.ap])
	var expensive := SkillData.new()
	expensive.ap_cost = 6
	p.skills.append(expensive)
	_check(not eng.submit_action(BattleAction.use_skill(expensive)), "abilità rifiutata senza PA")


func _test_relay() -> void:
	var fire := _make("fiammolo", 10)
	var fire2 := _make("ardolupo", 16)
	var water := _make("gocciolo", 10)
	var enemy := _make("coralunghi", 8)   # lento e resistente al Fuoco
	var eng := _engine([fire, water, fire2], [enemy])
	eng.start()
	var braciere: SkillData = load("res://data/skills/braciere.tres")
	fire.ap = 5
	eng.submit_action(BattleAction.use_skill(braciere))
	if eng.state != BattleEngine.State.ATTESA_GIOCATORE:
		_check(false, "il test della Staffetta si aspettava il turno del giocatore")
		return
	_check(eng.player_active() == fire, "Fiammolo è ancora in campo")
	_check(eng.can_relay(2), "Staffetta verso un'altra creatura di Fuoco")
	_check(not eng.can_relay(1), "niente Staffetta verso una creatura d'Acqua")
	var hp_before := enemy.hp
	eng.submit_action(BattleAction.switch_to(2))
	var texts := eng.take_events().map(func(ev): return ev["text"])
	_check(texts.any(func(t): return t.begins_with("STAFFETTA")), "il messaggio di Staffetta appare")
	_check(enemy.hp < hp_before, "la Staffetta infligge danni")
	_check(eng.player_active() == fire2, "Ardolupo è entrato")


func _test_forced_switch_and_defeat() -> void:
	var a := _make("germoglio", 5)
	var b := _make("gocciolo", 5)
	var boss := _make("infernolupo", 40)
	var eng := _engine([a, b], [boss], BattleRules.Difficulty.DIFFICILE)
	eng.start()
	_play(eng, 200)
	_check(eng.state == BattleEngine.State.FINITA, "la battaglia impossibile finisce")
	_check(eng.result == BattleEngine.Result.SCONFITTA, "contro un mostro di livello 40 si perde")


func _test_full_battles_all_difficulties() -> void:
	for d in [BattleRules.Difficulty.FACILE, BattleRules.Difficulty.NORMALE, BattleRules.Difficulty.DIFFICILE]:
		var wins := 0
		for i in 20:
			var party: Array[BattleCreature] = [_make("fiammolo", 12), _make("gocciolo", 12), _make("germoglio", 12)]
			var eng := _engine(party, [_make("scintilla", 11)], d)
			eng.start()
			_play(eng, 300)
			_check(eng.state == BattleEngine.State.FINITA, "battaglia completa (%s)" % BattleRules.difficulty_name(d))
			if eng.result == BattleEngine.Result.VITTORIA:
				wins += 1
		print("  %s: %d vittorie su 20 (3 contro 1, livelli simili)" % [BattleRules.difficulty_name(d), wins])
		_check(wins >= 10, "con 3 creature contro 1 si vince spesso anche in %s" % BattleRules.difficulty_name(d))
		# 1 contro 1 alla pari: qui si vede quanto pesa la difficoltà.
		var duel_wins := 0
		for i in 40:
			var eng := _engine([_make("gocciolo", 12)], [_make("fiammolo", 12)], d)
			eng.start()
			_play_random(eng, 300)
			if eng.result == BattleEngine.Result.VITTORIA:
				duel_wins += 1
		print("  %s: %d vittorie su 40 (1 contro 1, giocatore che attacca a caso)" % [BattleRules.difficulty_name(d), duel_wins])


func _test_break_gauge() -> void:
	var monster_data: CreatureData = load("res://data/creatures/fauceverde.tres")
	_check(monster_data.is_large_monster, "Fauceverde è un mostro grande")
	var boss := BattleCreature.create(monster_data, 10)
	var fire := _make("ardolupo", 20)
	var eng := _engine([fire], [boss])
	eng.start()
	var braciere: SkillData = load("res://data/skills/braciere.tres")
	for i in 6:
		if eng.state != BattleEngine.State.ATTESA_GIOCATORE:
			break
		eng.submit_action(BattleAction.use_skill(braciere))
	_check(boss.break_count >= 1 or boss.is_ko(), "colpire la debolezza causa la Rottura")


## Non è un vero controllo: stampa quante volte la squadra del prototipo batte Fauceverde.
func _test_boss_balance() -> void:
	var boss_data: CreatureData = load("res://data/creatures/fauceverde.tres")
	for d in [BattleRules.Difficulty.FACILE, BattleRules.Difficulty.NORMALE, BattleRules.Difficulty.DIFFICILE]:
		var wins := 0
		for i in 30:
			var party: Array[BattleCreature] = [_make("fiammolo", 14), _make("gocciolo", 14),
				_make("germoglio", 14), _make("scintilla", 14)]
			var eng := _engine(party, [BattleCreature.create(boss_data, 16)], d)
			eng.start()
			_play(eng, 400)
			if eng.result == BattleEngine.Result.VITTORIA:
				wins += 1
		print("  Boss Fauceverde Lv16, %s: %d vittorie su 30" % [BattleRules.difficulty_name(d), wins])


func _test_items_and_flee() -> void:
	var p := _make("fiammolo", 10)
	var e := _make("scintilla", 10)
	var eng := _engine([p], [e])
	eng.start()
	p.hp = 5
	eng.submit_action(BattleAction.use_item(&"pozione"))
	var healed := eng.take_events().any(func(ev): return ev["kind"] == "heal" and ev["target"] == p)
	_check(healed, "la Pozione cura")
	_check(eng.inventory[&"pozione"] == 1, "la Pozione viene consumata")
	var fled := false
	for i in 20:
		if eng.state != BattleEngine.State.ATTESA_GIOCATORE:
			break
		eng.submit_action(BattleAction.flee())
		if eng.result == BattleEngine.Result.FUGA:
			fled = true
	_check(fled or eng.state == BattleEngine.State.FINITA, "prima o poi si riesce a fuggire")


## Gioca una battaglia in automatico: il "giocatore" usa la stessa IA del nemico.
func _play(eng: BattleEngine, max_turns: int) -> void:
	for i in max_turns:
		match eng.state:
			BattleEngine.State.ATTESA_GIOCATORE:
				# Il "giocatore" gioca sempre come l'IA in Normale, qualunque sia la difficoltà.
				var action := eng.ai.choose_action(eng, eng.player_active(), eng.enemy_active(),
					BattleRules.Difficulty.NORMALE)
				if not eng.submit_action(action):
					eng.submit_action(BattleAction.basic_attack())
			BattleEngine.State.CAMBIO_OBBLIGATO:
				for j in eng.player_party.size():
					if eng.submit_forced_switch(j):
						break
			_:
				return


## Come _play, ma il "giocatore" sceglie a caso tra attacco e abilità che può pagare.
func _play_random(eng: BattleEngine, max_turns: int) -> void:
	for i in max_turns:
		if eng.state != BattleEngine.State.ATTESA_GIOCATORE:
			return
		var p := eng.player_active()
		var choices: Array[BattleAction] = [BattleAction.basic_attack()]
		for s in p.skills:
			if p.can_use(s):
				choices.append(BattleAction.use_skill(s))
		eng.submit_action(choices.pick_random())
