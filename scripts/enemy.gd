extends CharacterBody3D

signal died(enemy: Node)

@export var move_speed: float = 4.0
@export var speed_per_health_point: float = 0.05
@export var max_move_speed: float = 12.0
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
@export var knockback_drag: float = 10.0
@export var knockback_upward_impulse: float = 6.0
@export_range(0.0, 1.57) var knockback_tilt_angle: float = deg_to_rad(75.0)
@export var contact_damage: float = 10.0
@export var contact_damage_cooldown: float = 0.75

var health: float = 20.0
var target: Node3D
var _stun_timer := 0.0
var _knockback_velocity := Vector3.ZERO
var _target_tilt := 0.0
var _knockback_vertical_timer := 0.0
var _contact_damage_timer := 0.0
var _base_move_speed: float = 0.0
var _initial_health: float = 0.0


func _ready() -> void:
	add_to_group("enemies")
	_base_move_speed = move_speed


func setup(initial_health: float, target_node: Node3D) -> void:
	_initial_health = max(initial_health, 0.0)
	health = initial_health
	target = target_node
	_update_move_speed()


func _physics_process(delta: float) -> void:
	if _stun_timer > 0.0:
		_stun_timer = max(0.0, _stun_timer - delta)
	if _contact_damage_timer > 0.0:
		_contact_damage_timer = max(0.0, _contact_damage_timer - delta)

	if _stun_timer > 0.0:
		_apply_knockback_motion(delta)
	else:
		_apply_chase_motion(delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if _knockback_vertical_timer <= 0.0:
			velocity.y = 0.0

	move_and_slide()
	_handle_contact_damage()
	_apply_tilt(delta)
	if _knockback_vertical_timer > 0.0:
		_knockback_vertical_timer = max(0.0, _knockback_vertical_timer - delta)


func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0.0:
		died.emit(self)
		queue_free()


func force_health(value: float) -> void:
	health = min(health, value)


func apply_knockback(direction: Vector3, force: float, stun_time: float) -> void:
	var dir := direction
	dir.y = 0.0
	if dir.length_squared() == 0.0:
		dir = Vector3.FORWARD
	dir = dir.normalized()
	_knockback_velocity = dir * force
	_stun_timer = max(_stun_timer, stun_time)
	_target_tilt = knockback_tilt_angle
	_knockback_vertical_timer = 0.2
	velocity.y = knockback_upward_impulse


func _apply_knockback_motion(delta: float) -> void:
	velocity.x = _knockback_velocity.x
	velocity.z = _knockback_velocity.z
	_knockback_velocity = _knockback_velocity.move_toward(Vector3.ZERO, knockback_drag * delta)
	_target_tilt = knockback_tilt_angle
	if _stun_timer <= 0.0 and _knockback_velocity.length_squared() < 0.01:
		_target_tilt = 0.0


func _apply_chase_motion(delta: float) -> void:
	if not target or not is_instance_valid(target):
		velocity.x = lerp(velocity.x, 0.0, delta * move_speed)
		velocity.z = lerp(velocity.z, 0.0, delta * move_speed)
		_target_tilt = 0.0
		return

	var move_direction := target.global_position - global_position
	move_direction.y = 0.0
	if move_direction.length() > 0.1:
		move_direction = move_direction.normalized()
		velocity.x = move_direction.x * move_speed
		velocity.z = move_direction.z * move_speed
		look_at(target.global_position, Vector3.UP)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	_target_tilt = 0.0


func _apply_tilt(delta: float) -> void:
	var target_angle := _target_tilt
	if _stun_timer <= 0.0 and _target_tilt == 0.0:
		target_angle = 0.0
	rotation.x = lerp(rotation.x, target_angle, 6.0 * delta)


func _handle_contact_damage() -> void:
	if contact_damage <= 0.0:
		return
	if _contact_damage_timer > 0.0:
		return
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		if collision == null:
			continue
		var collider := collision.get_collider()
		if collider == null:
			continue
		if target and is_instance_valid(target) and collider == target and collider.has_method("take_damage"):
			collider.take_damage(contact_damage)
			_contact_damage_timer = max(contact_damage_cooldown, 0.0)
			return


func _update_move_speed() -> void:
	var speed_bonus := _initial_health * speed_per_health_point
	move_speed = clamp(_base_move_speed + speed_bonus, _base_move_speed, max_move_speed)
