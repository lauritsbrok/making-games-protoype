extends CharacterBody3D

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


func _ready() -> void:
	_fire_timer = fire_interval
	_ensure_input_actions()
	_camera_yaw = rotation.y
	if spring_arm:
		_camera_pitch = spring_arm.rotation.x
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_update_aim_orientation(delta)
	_fire_timer -= delta
	if _fire_timer <= 0.0 and bullet_scene:
		_fire_timer += fire_interval
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
	var bullet: Node3D = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_transform = bullet_spawn.global_transform
	if bullet.has_method("set_launch_direction"):
		bullet.set_launch_direction(-bullet.global_transform.basis.z)
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
