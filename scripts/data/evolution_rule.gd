class_name EvolutionRule
extends Resource
## Un "ramo" di evoluzione: in cosa si evolve e a quale condizione.
## Una creatura può averne più di uno (evoluzioni a rami).

enum Condition { LIVELLO, OGGETTO, LUOGO, ORA_DEL_GIORNO, AMICIZIA, REPUTAZIONE }

@export var evolves_into: CreatureData
@export var condition: Condition = Condition.LIVELLO
@export var min_level := 16             ## usato con LIVELLO (e come minimo per le altre)
@export var required_item: StringName   ## usato con OGGETTO
@export var required_location: StringName  ## usato con LUOGO
@export_enum("giorno", "notte") var time_of_day := "giorno"  ## usato con ORA_DEL_GIORNO
@export var required_value := 0         ## soglia per AMICIZIA / REPUTAZIONE
@export var faction: StringName         ## fazione per REPUTAZIONE, es. &"gilda"
