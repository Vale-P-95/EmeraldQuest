class_name BattleAction
extends RefCounted
## Un'azione scelta per un turno: dal menu (giocatore) o dall'IA (nemico).
## Si crea con le funzioni statiche qui sotto, es. BattleAction.use_skill(fiammata).

enum Type { ATTACCO, ABILITA, DIFENDI, CAMBIO, OGGETTO, CATTURA, FUGA }

var type: Type = Type.ATTACCO
var skill: SkillData = null      ## per ABILITA
var switch_index := -1           ## per CAMBIO: indice nella squadra della creatura che entra
var item_id: StringName = &""    ## per OGGETTO


static func basic_attack() -> BattleAction:
	var a := BattleAction.new()
	a.type = Type.ATTACCO
	return a


static func use_skill(s: SkillData) -> BattleAction:
	var a := BattleAction.new()
	a.type = Type.ABILITA
	a.skill = s
	return a


static func defend() -> BattleAction:
	var a := BattleAction.new()
	a.type = Type.DIFENDI
	return a


## Cambio di creatura. Se in quel momento la Staffetta è possibile, il motore
## la lancia da solo (vedi BattleEngine.can_relay).
static func switch_to(index: int) -> BattleAction:
	var a := BattleAction.new()
	a.type = Type.CAMBIO
	a.switch_index = index
	return a


static func use_item(id: StringName) -> BattleAction:
	var a := BattleAction.new()
	a.type = Type.OGGETTO
	a.item_id = id
	return a


static func flee() -> BattleAction:
	var a := BattleAction.new()
	a.type = Type.FUGA
	return a
