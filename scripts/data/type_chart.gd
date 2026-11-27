class_name TypeChart
extends Resource
## Tabella dei 9 elementi: chi è forte o debole contro chi.
## "effectiveness" contiene solo i casi speciali; la chiave è Vector2i(attaccante, difensore)
## con gli indici di Element.Type, il valore è il moltiplicatore (2.0 forte, 0.5 debole, 0.0 immune).
## Le coppie non elencate valgono 1.0 (danno normale).
## I dati stanno in data/types/type_chart.tres.

@export var effectiveness: Dictionary[Vector2i, float] = {}

## Moltiplicatore di un'abilità contro un singolo elemento.
func get_multiplier(attacker: Element.Type, defender: Element.Type) -> float:
	return effectiveness.get(Vector2i(attacker, defender), 1.0)

## Moltiplicatore totale contro una creatura con 1 o 2 elementi (si moltiplicano).
func get_multiplier_against(attacker: Element.Type, defender_types: Array[Element.Type]) -> float:
	var m := 1.0
	for t in defender_types:
		m *= get_multiplier(attacker, t)
	return m
