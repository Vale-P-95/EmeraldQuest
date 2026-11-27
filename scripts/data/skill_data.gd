class_name SkillData
extends Resource
## Un'abilità usabile in battaglia. Ogni abilità è un file .tres in data/skills/.
## Crea un nuovo file da FileSystem > tasto destro > Nuova risorsa > SkillData.

enum Category { FISICA, MAGICA, SUPPORTO }

@export var id: StringName              ## identificativo unico, es. &"fiammata"
@export var display_name := ""          ## nome mostrato al giocatore
@export_multiline var description := ""
@export var element: Element.Type = Element.Type.FUOCO
@export var category: Category = Category.FISICA
@export_range(0, 200) var power := 40   ## 0 per le abilità di supporto
@export_range(0, 100) var accuracy := 100
@export_range(0, 5) var ap_cost := 1    ## punti azione (PA) spesi
@export var status_effect: StringName   ## es. &"bruciatura", vuoto se nessuno
@export_range(0, 100) var status_chance := 0
