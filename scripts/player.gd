extends CharacterBody3D

signal health_changed(current_health: float, max_health: float)
signal died(player: CharacterBody3D)

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
@export var jump_speed: float = 8.0
@export var double_jump_cooldown: float = 10.0
@export var dash_speed: float = 28.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 10.0
@export var grapple_cooldown: float = 60.0
@export var grapple_max_distance: float = 50.0
@export var dash_knockback_radius: float = 6.0
@export var dash_knockback_force: float = 12.0
@export var dash_knockback_stun: float = 1.0
@export var max_health: float = 100.0
@export var damage_invulnerability_time: float = 0.35

@onready var bullet_spawn: Marker3D = %BulletSpawn
@onready var spring_arm: SpringArm3D = %SpringArm3D
@onready var camera: Camera3D = spring_arm.get_node_or_null("Camera3D") if spring_arm else null
@onready var ability_hud: Node = get_tree().current_scene.get_node_or_null("%AbilityHUD")

var _velocity_target := Vector3.ZERO
var _fire_timer := 0.0
var _camera_yaw := 0.0
var _camera_pitch := -0.25
var _base_fire_interval := 0.25
var _fire_interval_multiplier := 1.0
var _multi_shot_active := false
var _active_power_ups: Dictionary = {}
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") * 2.5
var _double_jump_cooldown_timer := 0.0
var _double_jump_available := true
var _double_jump_performed_this_jump := false
var _dash_cooldown_timer := 0.0
var _dash_time_remaining := 0.0
var _dash_direction := Vector3.ZERO
var _grapple_cooldown_timer := 0.0
var _health: float = 0.0
var _damage_invulnerability_timer := 0.0


func _ready() -> void:
	add_to_group("player")
	_base_fire_interval = fire_interval
	_fire_timer = _current_fire_interval()
	_ensure_input_actions()
	_camera_yaw = rotation.y
	if spring_arm:
		_camera_pitch = spring_arm.rotation.x
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if max_health <= 0.0:
		max_health = 1.0
	_health = max_health
	emit_signal("health_changed", _health, max_health)


func _physics_process(delta: float) -> void:
	if _damage_invulnerability_timer > 0.0:
		_damage_invulnerability_timer = max(0.0, _damage_invulnerability_timer - delta)
	_update_power_ups(delta)
	_update_cooldowns(delta)
	_handle_dash_input()
	_handle_grapple_input()
	_handle_jump_input()
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

	if _dash_time_remaining > 0.0 and _dash_direction.length_squared() > 0.0:
		_dash_time_remaining = max(0.0, _dash_time_remaining - delta)
		var dash_velocity := _dash_direction.normalized() * dash_speed
		velocity.x = dash_velocity.x
		velocity.z = dash_velocity.z
		if _dash_time_remaining <= 0.0:
			_dash_direction = Vector3.ZERO
	else:
		velocity.x = lerp(velocity.x, _velocity_target.x, acceleration * delta)
		velocity.z = lerp(velocity.z, _velocity_target.z, acceleration * delta)

	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		if velocity.y < 0.0:
			velocity.y = 0.0
		_double_jump_performed_this_jump = false

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
	_add_key_to_action("jump", Key.KEY_SPACE)
	_add_key_to_action("dash", Key.KEY_SHIFT)
	_add_key_to_action("grapple", Key.KEY_E)


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
			_start_ability_progress(&"multi_shot", duration, "Multi Shot Power Up")
		POWER_TYPE_FAST_FIRE:
			_fire_interval_multiplier = 0.5
			_fire_timer = min(_fire_timer, _current_fire_interval())
			_active_power_ups[power_type] = duration
			_start_ability_progress(&"fast_fire", duration, "Fast Fire Power Up")
		POWER_TYPE_WEAKEN_ENEMIES:
			var main := get_tree().current_scene
			if main and main.has_method("apply_enemy_health_override"):
				main.apply_enemy_health_override(duration)
			_start_ability_progress(&"weaken_enemies", duration, "Weaken Enemies Power Up")


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


func _handle_jump_input() -> void:
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = jump_speed
			_double_jump_performed_this_jump = false
		elif _double_jump_available and not _double_jump_performed_this_jump:
			velocity.y = jump_speed
			_double_jump_performed_this_jump = true
			_double_jump_available = false
			_double_jump_cooldown_timer = double_jump_cooldown
			_start_ability_progress(&"double_jump", double_jump_cooldown, "Double Jump")


func _handle_dash_input() -> void:
	if Input.is_action_just_pressed("dash") and _dash_cooldown_timer <= 0.0:
		var forward := _get_forward_direction()
		forward.y = 0.0
		if forward.length_squared() == 0.0:
			return
		_dash_direction = forward.normalized()
		_dash_time_remaining = dash_duration
		_dash_cooldown_timer = dash_cooldown
		_start_ability_progress(&"dash", dash_cooldown, "Dash")
		_apply_dash_knockback()


func _handle_grapple_input() -> void:
	if Input.is_action_just_pressed("grapple") and _grapple_cooldown_timer <= 0.0:
		_perform_grapple()


func _apply_dash_knockback() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return
	for enemy in enemies:
		if enemy is Node3D:
			var node := enemy as Node3D
			var offset := node.global_position - global_position
			var distance := offset.length()
			if distance <= dash_knockback_radius:
				var direction := offset.normalized()
				if direction.length_squared() == 0.0:
					direction = _get_forward_direction()
				if node.has_method("apply_knockback"):
					node.apply_knockback(direction, dash_knockback_force, dash_knockback_stun)
func _perform_grapple() -> void:
	if not camera:
		return
	var from := camera.global_position
	var direction := -camera.global_transform.basis.z
	if direction.length_squared() == 0.0:
		return
	var to := from + direction.normalized() * grapple_max_distance
	var params := PhysicsRayQueryParameters3D.create(from, to)
	params.exclude = [self]
	var result := get_world_3d().direct_space_state.intersect_ray(params)
	if result.is_empty():
		return
	if not result.has("collider") or not result.has("position"):
		return
	var collider: Object = result["collider"]
	if collider is Node3D and collider.is_in_group("grapple_target"):
		var hit_position: Vector3 = result["position"]
		global_position = hit_position + Vector3.UP * 2.0
		velocity = Vector3.ZERO
		_dash_time_remaining = 0.0
		_dash_direction = Vector3.ZERO
		_grapple_cooldown_timer = grapple_cooldown
		_start_ability_progress(&"grapple", grapple_cooldown, "Grapple Teleport")


func _update_cooldowns(delta: float) -> void:
	if _double_jump_cooldown_timer > 0.0:
		_double_jump_cooldown_timer = max(0.0, _double_jump_cooldown_timer - delta)
		if _double_jump_cooldown_timer <= 0.0:
			_double_jump_available = true
	if _dash_cooldown_timer > 0.0:
		_dash_cooldown_timer = max(0.0, _dash_cooldown_timer - delta)
	if _grapple_cooldown_timer > 0.0:
		_grapple_cooldown_timer = max(0.0, _grapple_cooldown_timer - delta)


func _start_ability_progress(id: StringName, duration: float, label: String) -> void:
	if not ability_hud:
		return
	if ability_hud.has_method("start_progress"):
		ability_hud.start_progress(id, duration, label)


func take_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	if _damage_invulnerability_timer > 0.0:
		return
	_apply_damage(amount)
	_damage_invulnerability_timer = max(damage_invulnerability_time, 0.0)


func heal(amount: float) -> void:
	if amount <= 0.0 or _health <= 0.0:
		return
	_health = clamp(_health + amount, 0.0, max_health)
	emit_signal("health_changed", _health, max_health)


func current_health() -> float:
	return _health


func _apply_damage(amount: float) -> void:
	if _health <= 0.0:
		return
	_health = clamp(_health - amount, 0.0, max_health)
	emit_signal("health_changed", _health, max_health)
	if _health <= 0.0:
		emit_signal("died", self)
		queue_free()
