extends Node3D
## Mappa di prova.
##
## Collega tutti i mostri (gruppo "monsters") al sistema di battaglia: quando il
## giocatore si avvicina a uno di loro la lotta parte sul posto, senza cambiare scena.
## Tasto F2: cambia la difficoltà delle battaglie.

@onready var _encounter_label: Label = $HUD/EncounterLabel
@onready var _difficulty_label: Label = $HUD/DifficultyLabel
@onready var _controls_label: Label = $HUD/Controls
@onready var _battle: Node = $BattleManager


func _ready() -> void:
	for monster in get_tree().get_nodes_in_group("monsters"):
		monster.encounter_started.connect(_on_encounter_started)
		monster.encounter_ended.connect(_on_encounter_ended)
	_battle.battle_started.connect(_on_battle_started)
	_battle.battle_finished.connect(_on_battle_finished)
	_update_difficulty_label()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).physical_keycode == KEY_F2 and not _battle.in_battle:
		_battle.cycle_difficulty()
		_update_difficulty_label()


func _update_difficulty_label() -> void:
	_difficulty_label.text = "Difficoltà: %s  (F2 per cambiare)" % BattleRules.difficulty_name(_battle.difficulty)


func _on_encounter_started(monster: Node3D) -> void:
	print("[Incontro] ", monster.display_name)
	_encounter_label.visible = false
	_battle.start_monster_battle(monster)


func _on_encounter_ended(_monster: Node3D) -> void:
	_encounter_label.visible = false


## Durante la lotta nascondiamo le scritte del mondo, che finirebbero sotto i pannelli.
func _on_battle_started() -> void:
	_controls_label.visible = false
	_difficulty_label.visible = false
	_encounter_label.visible = false


func _on_battle_finished(result: int, monster: Node3D, _story_id: String) -> void:
	_controls_label.visible = true
	_difficulty_label.visible = true
	match result:
		BattleEngine.Result.VITTORIA:
			_show_message("Hai sconfitto %s!" % monster.display_name if monster else "Hai vinto!")
			if monster and monster.has_method("defeat"):
				monster.defeat()
		BattleEngine.Result.SCONFITTA:
			_show_message("Sei stato sconfitto... Le tue creature si riprendono.")
		BattleEngine.Result.FUGA:
			_show_message("Sei scappato! Allontanati prima che ti noti di nuovo.")


## Mostra una scritta al centro per qualche secondo.
func _show_message(text: String) -> void:
	_encounter_label.text = text
	_encounter_label.visible = true
	await get_tree().create_timer(3.0).timeout
	if _encounter_label.text == text:
		_encounter_label.visible = false
