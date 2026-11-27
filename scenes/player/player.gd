extends CharacterBody3D
## Il protagonista (il domatore).
##
## Si muove liberamente sul terreno: la direzione dipende da dove guarda la
## camera, come nei giochi 3D in terza persona. La camera gira con il mouse
## (clicca nella finestra per "agganciarlo", Esc per liberarlo), con le frecce
## oppure con lo stick destro del controller.
##
## Il corpo fisico non ruota mai: ruota solo il "Model" (la parte visibile),
## così la camera, che è figlia del corpo, non viene trascinata in giro.

# --- Valori modificabili dall'Inspector dell'editor (pannello a destra) ---
@export_group("Movimento")
@export var walk_speed := 5.0        ## metri al secondo camminando
@export var run_speed := 9.0         ## metri al secondo correndo (Shift / tasto B)
@export var acceleration := 12.0     ## quanto in fretta raggiunge la velocità
@export var turn_speed := 10.0       ## quanto in fretta il modello si gira

@export_group("Camera")
@export var mouse_sensitivity := 0.003
@export var stick_sensitivity := 2.5   ## radianti al secondo con stick/frecce
@export var min_pitch_deg := -70.0     ## quanto si può guardare dall'alto
@export var max_pitch_deg := 20.0      ## quanto si può guardare dal basso

## Se il giocatore cade sotto questa quota torna al punto di partenza.
@export var fall_limit := -20.0

# Gravità presa dalle impostazioni del progetto.
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _spawn_position: Vector3

@onready var _model: Node3D = $Model
@onready var _camera_pivot: Node3D = $CameraPivot
@onready var _spring_arm: SpringArm3D = $CameraPivot/SpringArm3D


func _ready() -> void:
	_spawn_position = global_position
	# La "molla" della camera non deve sbattere contro il protagonista stesso.
	_spring_arm.add_excluded_object(get_rid())


func _unhandled_input(event: InputEvent) -> void:
	# Durante un dialogo il mouse serve per le risposte: la camera non lo usa.
	if Storia.dialogo_attivo:
		return
	# Click nella finestra: il mouse viene catturato e controlla la camera.
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Esc (azione predefinita "ui_cancel"): libera il mouse.
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Movimento del mouse mentre è catturato: ruota la camera.
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotate_camera(-event.relative.x * mouse_sensitivity, -event.relative.y * mouse_sensitivity)


func _physics_process(delta: float) -> void:
	# Durante un dialogo il protagonista resta fermo ("Storia" è in autoload/storia.gd).
	if Storia.dialogo_attivo:
		return
	# 1) Camera con stick destro o frecce.
	var look := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	if look != Vector2.ZERO:
		_rotate_camera(-look.x * stick_sensitivity * delta, -look.y * stick_sensitivity * delta)

	# 2) Direzione di movimento relativa alla camera (solo la rotazione orizzontale).
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var camera_yaw := Basis(Vector3.UP, _camera_pivot.rotation.y)
	var direction := (camera_yaw * Vector3(input.x, 0.0, input.y))
	if direction.length() > 1.0:
		direction = direction.normalized()

	# 3) Velocità orizzontale che si avvicina dolcemente a quella desiderata.
	var speed := run_speed if Input.is_action_pressed("sprint") else walk_speed
	var target_velocity := direction * speed
	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * speed * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * speed * delta)

	# 4) Gravità.
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0

	move_and_slide()

	# 5) Il modello guarda verso dove sta andando.
	if direction.length() > 0.1:
		var target_yaw := atan2(-direction.x, -direction.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, turn_speed * delta)

	# 6) Rete di sicurezza: se cade fuori dalla mappa, torna al via.
	if global_position.y < fall_limit:
		global_position = _spawn_position
		velocity = Vector3.ZERO


## Ruota la camera: yaw = sinistra/destra, pitch = su/giù (limitato).
func _rotate_camera(yaw: float, pitch: float) -> void:
	_camera_pivot.rotation.y += yaw
	_camera_pivot.rotation.x = clampf(
		_camera_pivot.rotation.x + pitch,
		deg_to_rad(min_pitch_deg),
		deg_to_rad(max_pitch_deg)
	)
