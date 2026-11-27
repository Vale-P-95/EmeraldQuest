extends CharacterBody3D
## Un mostro che vaga per la zona, stile Monster Hunter.
##
## Comportamento (una piccola "macchina a stati"):
##   IDLE   -> sta fermo qualche secondo
##   WANDER -> cammina verso un punto a caso vicino alla sua "tana"
##   ALERT  -> il giocatore è vicino: si gira verso di lui e parte l'incontro
##
## Il segnale `encounter_started` fa partire la battaglia a turni (vedi test_world.gd).

## Emesso quando il giocatore entra nel raggio di avvistamento.
signal encounter_started(monster: Node3D)
## Emesso quando il giocatore si allontana.
signal encounter_ended(monster: Node3D)

@export var display_name := "Fauceverde"   ## nome mostrato a schermo
@export var creature: CreatureData         ## la specie con cui si lotta (data/creatures/)
@export_range(1, 100) var level := 10      ## livello in battaglia
@export var wander_radius := 12.0          ## quanto si allontana dalla tana (m)
@export var move_speed := 2.5              ## velocità camminando (m/s)
@export var idle_time_min := 1.5           ## secondi minimi da fermo
@export var idle_time_max := 4.0           ## secondi massimi da fermo
@export var max_wander_time := 8.0         ## se non arriva entro questo tempo, si ferma

enum State { IDLE, WANDER, ALERT }

var state: State = State.IDLE
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _home: Vector3
var _target: Vector3
var _timer := 0.0
var _player: Node3D = null

@onready var _model: Node3D = $Model
@onready var _detection: Area3D = $DetectionArea


func _ready() -> void:
	_home = global_position
	_detection.body_entered.connect(_on_body_entered)
	_detection.body_exited.connect(_on_body_exited)
	_enter_idle()


func _physics_process(delta: float) -> void:
	var horizontal := Vector3.ZERO

	match state:
		State.IDLE:
			_timer -= delta
			if _timer <= 0.0:
				_enter_wander()
		State.WANDER:
			_timer -= delta
			var to_target := _target - global_position
			to_target.y = 0.0
			if to_target.length() < 0.5 or _timer <= 0.0 or is_on_wall():
				_enter_idle()
			else:
				horizontal = to_target.normalized() * move_speed
				_face(horizontal, delta)
		State.ALERT:
			if _player:
				var to_player := _player.global_position - global_position
				to_player.y = 0.0
				_face(to_player, delta)

	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()


func _enter_idle() -> void:
	state = State.IDLE
	_timer = randf_range(idle_time_min, idle_time_max)


func _enter_wander() -> void:
	state = State.WANDER
	_timer = max_wander_time
	# Punto a caso dentro un cerchio intorno alla tana.
	var angle := randf() * TAU
	var distance := sqrt(randf()) * wander_radius
	_target = _home + Vector3(cos(angle), 0.0, sin(angle)) * distance


## Gira dolcemente il modello verso una direzione orizzontale.
func _face(direction: Vector3, delta: float) -> void:
	if direction.length() < 0.01:
		return
	var target_yaw := atan2(-direction.x, -direction.z)
	_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, 6.0 * delta)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player = body
		state = State.ALERT
		encounter_started.emit(self)


func _on_body_exited(body: Node3D) -> void:
	if body == _player:
		_player = null
		_enter_idle()
		encounter_ended.emit(self)


## Chiamata quando il giocatore lo sconfigge: sparisce dalla mappa.
## (Più avanti qui lascerà cadere i materiali e tornerà dopo un po' di tempo.)
func defeat() -> void:
	_detection.monitoring = false
	set_physics_process(false)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.6)
	tw.tween_callback(queue_free)
