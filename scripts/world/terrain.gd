@tool
class_name ProceduralTerrain
extends StaticBody3D
## Terreno collinare generato da un "rumore" (noise): colline morbide, laghetti
## nelle zone basse e una radura piatta al centro dove parte il giocatore.
##
## È uno strumento (@tool): lo vedi anche nell'editor. Cambia i valori
## nell'Inspector (seed, altezza, dimensione) e il terreno si rigenera.

@export var size := 160                ## lato del terreno in metri
@export var height := 7.0              ## altezza massima delle colline
@export var noise_seed := 7:           ## cambia per avere colline diverse
	set(v):
		noise_seed = v
		_rebuild_if_ready()
@export var clearing_radius := 14.0    ## radura piatta intorno al centro
@export var water_level := -0.8        ## sotto questa quota c'è acqua

@export_group("Colori")
@export var grass_color := Color(0.33, 0.62, 0.22)
@export var grass_color_2 := Color(0.22, 0.48, 0.18)
@export var sand_color := Color(0.88, 0.80, 0.55)
@export var rock_color := Color(0.55, 0.52, 0.48)

var _noise := FastNoiseLite.new()
var _detail := FastNoiseLite.new()


func _ready() -> void:
	_rebuild()


func _rebuild_if_ready() -> void:
	if is_inside_tree():
		_rebuild()


## Altezza del terreno nel punto (x, z). La usano anche alberi e mostri.
func height_at(x: float, z: float) -> float:
	var h := _noise.get_noise_2d(x, z) * height
	var d := Vector2(x, z).length()
	# Radura: vicino al centro il terreno si appiattisce a quota 0.
	var t := smoothstep(clearing_radius, clearing_radius * 2.0, d)
	# Bordi: la mappa si alza verso i lati, come una valle chiusa da colline.
	var edge := smoothstep(size * 0.32, size * 0.5, maxf(absf(x), absf(z)))
	return lerpf(0.0, h, t) + edge * height * 1.6


func _rebuild() -> void:
	_noise.seed = noise_seed
	_noise.frequency = 0.018
	_noise.fractal_octaves = 4
	_detail.seed = noise_seed + 1
	_detail.frequency = 0.15

	for c in get_children():
		if c.has_meta("generated"):
			c.free()

	var n := size  # un vertice ogni metro
	var half := size / 2.0
	var heights := PackedFloat32Array()
	heights.resize((n + 1) * (n + 1))
	for iz in n + 1:
		for ix in n + 1:
			heights[iz * (n + 1) + ix] = height_at(ix - half, iz - half)

	# --- Mesh visibile con colori per vertice ---
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in n:
		for ix in n:
			var quad: Array[Vector2i] = [Vector2i(ix, iz), Vector2i(ix + 1, iz), Vector2i(ix, iz + 1),
				Vector2i(ix + 1, iz), Vector2i(ix + 1, iz + 1), Vector2i(ix, iz + 1)]
			for q in quad:
				var y: float = heights[q.y * (n + 1) + q.x]
				var x: float = q.x - half
				var z: float = q.y - half
				st.set_color(_color_at(x, y, z, heights, n, q))
				st.add_vertex(Vector3(x, y, z))
	st.generate_normals()
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mesh.surface_set_material(0, mat)

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.set_meta("generated", true)
	add_child(mi)

	# --- Collisione (HeightMapShape3D: una griglia di altezze) ---
	var shape := HeightMapShape3D.new()
	shape.map_width = n + 1
	shape.map_depth = n + 1
	shape.map_data = heights
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.set_meta("generated", true)
	add_child(cs)

	# --- Acqua ---
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.2, 0.55, 0.85, 0.75)
	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wmat.roughness = 0.1
	wmat.metallic_specular = 0.9
	plane.material = wmat
	water.mesh = plane
	water.position.y = water_level
	water.set_meta("generated", true)
	add_child(water)


func _color_at(x: float, y: float, z: float, heights: PackedFloat32Array, n: int, q: Vector2i) -> Color:
	# Pendenza approssimata: differenza con il vertice vicino.
	var qx := mini(q.x + 1, n)
	var qz := mini(q.y + 1, n)
	var slope := maxf(absf(heights[q.y * (n + 1) + qx] - y), absf(heights[qz * (n + 1) + q.x] - y))
	if y < water_level + 0.5:
		return sand_color
	if slope > 0.9:
		return rock_color
	var mix := (_detail.get_noise_2d(x, z) + 1.0) * 0.5
	return grass_color.lerp(grass_color_2, mix)
