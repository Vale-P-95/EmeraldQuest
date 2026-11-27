class_name CreatureData
extends Resource
## La "scheda" di una specie di creatura. Ogni specie è un file .tres in
## data/creatures/: per crearne o modificarne una non serve toccare il codice.
## Apri il file nell'editor e cambia i valori nell'Inspector.

@export var id: StringName              ## identificativo unico, es. &"brasolo"
@export var display_name := ""          ## nome mostrato al giocatore
@export_multiline var description := ""
@export var types: Array[Element.Type] = []   ## 1 o 2 elementi

@export_group("Statistiche base")
@export_range(1, 255) var hp := 45
@export_range(1, 255) var attack := 50
@export_range(1, 255) var defense := 45
@export_range(1, 255) var magic := 50
@export_range(1, 255) var spirit := 45
@export_range(1, 255) var speed := 50

@export_group("Crescita e abilità")
@export_enum("veloce", "media", "lenta") var growth := "media"
## Chiave = livello, valore = abilità imparata a quel livello.
@export var learnset: Dictionary[int, SkillData] = {}
@export var evolutions: Array[EvolutionRule] = []

@export_group("Mondo")
@export_range(0, 255) var catch_rate := 45   ## più alto = più facile da catturare
@export var is_large_monster := false        ## i mostri grandi si cacciano, non si catturano
@export var drops: Dictionary[StringName, float] = {}  ## materiale -> probabilità (0-1)
@export var field_skill: StringName          ## abilità sul campo, es. &"bruciare_rovi"
@export var model_scene: PackedScene         ## modello 3D della creatura
@export var icon: Texture2D                  ## icona per menu e squadra
