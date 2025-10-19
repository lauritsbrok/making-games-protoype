extends Area3D

@export var speed: float = 30.0
@export var damage: float = 10.0
@export var max_distance: float = 80.0

var _direction: Vector3 = -Vector3.FORWARD
var _start_position: Vector3


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_start_position = global_position


func _physics_process(delta: float) -> void:
	global_position += _direction * speed * delta
	if global_position.distance_to(_start_position) >= max_distance:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		return
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()


func set_speed(value: float) -> void:
	speed = value


func set_launch_direction(direction: Vector3) -> void:
	if direction.length() > 0.0:
		_direction = direction.normalized()
