extends Area3D

const POWER_TYPE_MULTI_SHOT := &"multi_shot"
const POWER_TYPE_FAST_FIRE := &"fast_fire"
const POWER_TYPE_WEAKEN_ENEMIES := &"weaken_enemies"

@export var power_type: StringName = POWER_TYPE_MULTI_SHOT
@export var duration: float = 5.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not body:
		return
	if body.has_method("apply_power_up"):
		body.apply_power_up(power_type, duration)
		queue_free()
