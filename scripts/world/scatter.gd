@tool
extends Node3D
## Sparge alberi, cespugli, erba e nuvole sul terreno in modo casuale ma
## ripetibile (stesso seed = stessa disposizione). Lascia libera la radura
## centrale e non mette niente sott'acqua.

@export var terrain: ProceduralTerrain
@export var scatter_seed := 42
@export var tree_count := 140
@export var bush_count := 0   ## i cespugli Kenney hanno una base quadrata: per ora spenti
@export var grass_count := 400
@export var cloud_count := 14

const TREES := [
	preload("res://assets/kenney/arena/tree.glb"),
]
const BUSHES := [
	preload("res://assets/kenney/city/grass-trees.glb"),
	preload("res://assets/kenney/city/grass-trees-tall.glb"),
]
const GRASS := [
	preload("res://assets/kenney/platformer/grass.glb"),
	preload("res://assets/kenney/platformer/grass-small.glb"),
]
const CLOUD := preload("res://assets/kenney/platformer/cloud.glb")
const RUINS := [
	preload("res://assets/kenney/arena/column-damaged.glb"),
	preload("res://assets/kenney/arena/statue.glb"),
]


func _ready() -> void:
	# Aspetta che il terreno sia pronto (è un nodo fratello).
	await get_tree().process_frame
	_scatter()


func _scatter() -> void:
	if terrain == null:
		return
	for c in get_children():
		c.free()
	var rng := RandomNumberGenerator.new()
	rng.seed = scatter_seed
	var half := terrain.size * 0.45

	_place(rng, TREES, tree_count, half, Vector2(3.0, 4.5), 16.0, true)
	_place(rng, BUSHES, bush_count, half, Vector2(2.5, 4.0), 12.0, false)
	_place(rng, GRASS, grass_count, half, Vector2(2.0, 3.5), 3.0, false)
	_place(rng, RUINS, 6, 30.0, Vector2(2.5, 3.0), 16.0, true)

	for i in cloud_count:
		var c: Node3D = CLOUD.instantiate()
		c.position = Vector3(rng.randf_range(-half, half), rng.randf_range(22, 32), rng.randf_range(-half, half))
		c.scale = Vector3.ONE * rng.randf_range(5.0, 10.0)
		c.scale.y *= 0.5
		# Le nuvole non devono proiettare ombre giganti sul terreno.
		for mi in c.find_children("*", "MeshInstance3D", true, false):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(c)


func _place(rng: RandomNumberGenerator, scenes: Array, count: int, half: float,
		scale_range: Vector2, min_center_dist: float, solid: bool) -> void:
	for i in count:
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		if Vector2(x, z).length() < min_center_dist:
			continue
		var y := terrain.height_at(x, z)
		if y < terrain.water_level + 0.4:
			continue
		var node: Node3D = scenes[rng.randi() % scenes.size()].instantiate()
		node.position = Vector3(x, y - 0.05, z)
		node.rotation.y = rng.randf() * TAU
		node.scale = Vector3.ONE * rng.randf_range(scale_range.x, scale_range.y)
		add_child(node)
		if solid:
			# Un cilindro invisibile, così non si attraversano tronchi e statue.
			var body := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			var shape := CylinderShape3D.new()
			shape.radius = 0.12
			shape.height = 1.0
			cs.shape = shape
			cs.position.y = 0.5
			body.add_child(cs)
			node.add_child(body)
