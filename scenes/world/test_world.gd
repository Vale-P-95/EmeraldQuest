extends Node3D
## Mappa di prova di M1.
##
## Collega tutti i mostri (gruppo "monsters") all'interfaccia: quando il
## giocatore si avvicina a uno di loro compare la scritta dell'incontro.
## In M2 qui partirà la battaglia a turni vera e propria.

@onready var _encounter_label: Label = $HUD/EncounterLabel


func _ready() -> void:
	for monster in get_tree().get_nodes_in_group("monsters"):
		monster.encounter_started.connect(_on_encounter_started)
		monster.encounter_ended.connect(_on_encounter_ended)


func _on_encounter_started(monster: Node3D) -> void:
	_encounter_label.text = "Un %s selvatico ti ha notato!\n(la battaglia arriverà in M2)" % monster.display_name
	_encounter_label.visible = true
	print("[Incontro] ", monster.display_name)


func _on_encounter_ended(_monster: Node3D) -> void:
	_encounter_label.visible = false
