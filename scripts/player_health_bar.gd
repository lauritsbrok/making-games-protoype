extends VBoxContainer
class_name PlayerHealthBar

@onready var _progress_bar: ProgressBar = %HealthProgressBar
@onready var _value_label: Label = %HealthValueLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_health(current: float, maximum: float) -> void:
	var max_value: float = max(maximum, 1.0)
	var clamped: float = clamp(current, 0.0, max_value)
	_progress_bar.max_value = max_value
	_progress_bar.value = clamped
	_value_label.text = "%d / %d" % [roundi(clamped), roundi(max_value)]
