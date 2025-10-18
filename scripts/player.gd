extends CharacterBody3D

const POWER_TYPE_MULTI_SHOT := &"multi_shot"
const POWER_TYPE_FAST_FIRE := &"fast_fire"
const POWER_TYPE_WEAKEN_ENEMIES := &"weaken_enemies"
const POWER_UP_DURATION := 5.0
const MULTI_SHOT_BULLET_COUNT := 8

@export var move_speed: float = 8.0
@export var acceleration: float = 10.0
@export var fire_interval: float = 0.25
@export var bullet_scene: PackedScene
@export var bullet_speed: float = 30.0
@export var mouse_sensitivity: float = 0.15
@export var rotation_speed: float = 10.0
@export var camera_pitch_limits: Vector2 = Vector2(-0.75, 0.35)

@onready var bullet_spawn: Marker3D = %BulletSpawn
@onready var spring_arm: SpringArm3D = %SpringArm3D

var _velocity_target := Vector3.ZERO
var _fire_timer := 0.0
var _camera_yaw := 0.0
var _camera_pitch := -0.25
var _base_fire_interval := 0.25
var _fire_interval_multiplier := 1.0
var _multi_shot_active := false
var _active_power_ups: Dictionary = {}


func _ready() -> void:
	_base_fire_interval = fire_interval
	_fire_timer = _current_fire_interval()
	_ensure_input_actions()
	_camera_yaw = rotation.y
	if spring_arm:
		_camera_pitch = spring_arm.rotation.x
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _physics_process(delta: float) -> void:
	_update_power_ups(delta)
	_handle_movement(delta)
	_update_aim_orientation(delta)
	_fire_timer -= delta
	if _fire_timer <= 0.0 and bullet_scene:
		_fire_timer += _current_fire_interval()
		_spawn_bullet()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_camera_yaw -= deg_to_rad(event.relative.x * mouse_sensitivity)
		_camera_pitch = clamp(_camera_pitch - deg_to_rad(event.relative.y * mouse_sensitivity), camera_pitch_limits.x, camera_pitch_limits.y)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif event is InputEventMouseButton and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _handle_movement(delta: float) -> void:
	var input_vector := Vector2.ZERO
	input_vector.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_vector.y = Input.get_action_strength("move_forward") - Input.get_action_strength("move_backward")
	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()

	var yaw_basis := Basis(Vector3.UP, _camera_yaw)
	var forward := -yaw_basis.z
	var right := yaw_basis.x
	var direction := (forward * input_vector.y) + (right * input_vector.x)
	direction.y = 0.0

	_velocity_target = direction.normalized() * move_speed
	velocity = velocity.lerp(_velocity_target, acceleration * delta)

	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	else:
		velocity.y = 0.0

	move_and_slide()


func _spawn_bullet() -> void:
	if not bullet_scene:
		return
	var directions := [_get_forward_direction()]
	if _multi_shot_active:
		directions = _get_multi_shot_directions(MULTI_SHOT_BULLET_COUNT)
	for direction in directions:
		var bullet: Node3D = bullet_scene.instantiate()
		get_tree().current_scene.add_child(bullet)
		bullet.global_transform = bullet_spawn.global_transform
		if bullet.has_method("set_launch_direction"):
			bullet.set_launch_direction(direction)
		if bullet.has_method("set_speed"):
			bullet.set_speed(bullet_speed)


func _update_aim_orientation(delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, _camera_yaw, rotation_speed * delta)
	if spring_arm:
		spring_arm.rotation = Vector3(_camera_pitch, 0.0, 0.0)


func _ensure_input_actions() -> void:
	_add_key_to_action("move_forward", Key.KEY_W)
	_add_key_to_action("move_forward", Key.KEY_UP)
	_add_key_to_action("move_backward", Key.KEY_S)
	_add_key_to_action("move_backward", Key.KEY_DOWN)
	_add_key_to_action("move_left", Key.KEY_A)
	_add_key_to_action("move_left", Key.KEY_LEFT)
	_add_key_to_action("move_right", Key.KEY_D)
	_add_key_to_action("move_right", Key.KEY_RIGHT)


func _add_key_to_action(action_name: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for existing_event in InputMap.action_get_events(action_name):
		if existing_event is InputEventKey and existing_event.physical_keycode == keycode:
			return
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	InputMap.action_add_event(action_name, event)


func apply_power_up(power_type: StringName, duration: float = POWER_UP_DURATION) -> void:
	match power_type:
		POWER_TYPE_MULTI_SHOT:
			_multi_shot_active = true
			_active_power_ups[power_type] = duration
		POWER_TYPE_FAST_FIRE:
			_fire_interval_multiplier = 0.5
			_fire_timer = min(_fire_timer, _current_fire_interval())
			_active_power_ups[power_type] = duration
		POWER_TYPE_WEAKEN_ENEMIES:
			var main := get_tree().current_scene
			if main and main.has_method("apply_enemy_health_override"):
				main.apply_enemy_health_override(duration)


func _update_power_ups(delta: float) -> void:
	if _active_power_ups.is_empty():
		return
	var expired: Array = []
	for power_type in _active_power_ups.keys():
		_active_power_ups[power_type] -= delta
		if _active_power_ups[power_type] <= 0.0:
			expired.append(power_type)
	for power_type in expired:
		match power_type:
			POWER_TYPE_MULTI_SHOT:
				_multi_shot_active = false
			POWER_TYPE_FAST_FIRE:
				_fire_interval_multiplier = 1.0
			_:
				pass
		_active_power_ups.erase(power_type)


func _current_fire_interval() -> float:
	return _base_fire_interval * _fire_interval_multiplier


func _get_forward_direction() -> Vector3:
	var forward := -bullet_spawn.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() == 0.0:
		forward = -global_transform.basis.z
	return forward.normalized()


func _get_multi_shot_directions(count: int) -> Array:
	var directions: Array = []
	var yaw_basis := Basis(Vector3.UP, _camera_yaw)
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		var dir2d := Vector2(cos(angle), sin(angle))
		var forward := -yaw_basis.z
		var right := yaw_basis.x
		var dir := (forward * dir2d.y) + (right * dir2d.x)
		dir.y = 0.0
		if dir.length_squared() > 0.0:
			directions.append(dir.normalized())
	if directions.is_empty():
		directions.append(_get_forward_direction())
	return directions
