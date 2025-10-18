extends CharacterBody3D

signal died(enemy: Node)

@export var move_speed: float = 4.0
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

var health: float = 20.0
var target: Node3D


func setup(initial_health: float, target_node: Node3D) -> void:
	health = initial_health
	target = target_node


func _physics_process(delta: float) -> void:
	if not target:
		velocity = Vector3.ZERO
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

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	move_and_slide()


func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0.0:
		died.emit(self)
		queue_free()
