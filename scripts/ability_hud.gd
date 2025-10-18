extends CanvasLayer
class_name AbilityHUD

const DEFAULT_COLORS := {
	"dash": Color(0.2, 0.6, 1.0, 0.9),
	"double_jump": Color(0.35, 0.9, 0.6, 0.9),
	"grapple": Color(0.7, 0.5, 1.0, 0.9),
	"multi_shot": Color(1.0, 0.85, 0.3, 0.9),
	"fast_fire": Color(1.0, 0.45, 0.45, 0.9),
	"weaken_enemies": Color(1.0, 0.55, 0.85, 0.9)
}

const AbilityIndicatorScene := preload("res://scripts/ability_indicator.gd")

var _indicators: Dictionary = {}
var _active_statuses: Dictionary = {}

@onready var _container: VBoxContainer = %AbilityIndicatorContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)


func start_progress(id: StringName, duration: float, label: String, color: Variant = null) -> void:
	if duration <= 0.0:
		return

	var key := StringName(id)
	var indicator = _get_indicator(key)
	indicator.set_label(label)

	var foreground: Color = _resolve_color(key, color)
	var background := Color(foreground.r, foreground.g, foreground.b, 0.2)
	indicator.set_colors(foreground, background)
	indicator.set_progress(1.0)
	indicator.set_indicator_active(true)
	_move_indicator_to_bottom(indicator)

	_active_statuses[key] = {
		"total_time": max(duration, 0.01),
		"remaining_time": duration
	}


func stop_progress(id: StringName) -> void:
	var key := StringName(id)
	if not _active_statuses.has(key):
		return
	var indicator = _indicators.get(key, null)
	if indicator:
		indicator.set_indicator_active(false)
	_active_statuses.erase(key)


func _process(delta: float) -> void:
	if _active_statuses.is_empty():
		return

	var finished: Array = []
	for key in _active_statuses.keys():
		var status: Dictionary = _active_statuses[key]
		status["remaining_time"] = max(0.0, status["remaining_time"] - delta)
		_active_statuses[key] = status

		var ratio := 0.0
		if status["total_time"] > 0.0:
			ratio = status["remaining_time"] / status["total_time"]

		var indicator = _indicators.get(key, null)
		if indicator:
			indicator.set_progress(ratio)

		if status["remaining_time"] <= 0.0:
			finished.append(key)

	for key in finished:
		var indicator = _indicators.get(key, null)
		if indicator:
			indicator.set_progress(0.0)
			indicator.set_indicator_active(false)
		_active_statuses.erase(key)


func _get_indicator(id: StringName):
	if _indicators.has(id):
		return _indicators[id]

	var indicator := AbilityIndicatorScene.new()
	indicator.name = String(id)
	_container.add_child(indicator)
	indicator.set_indicator_active(false)
	_indicators[id] = indicator
	return indicator


func _resolve_color(id: StringName, override_color: Variant) -> Color:
	if override_color is Color:
		return override_color

	var key := String(id)
	if DEFAULT_COLORS.has(key):
		return DEFAULT_COLORS[key]

	return Color(0.45, 0.85, 1.0, 0.9)


func _move_indicator_to_bottom(indicator) -> void:
	if indicator.get_parent() != _container:
		return
	var child_count := _container.get_child_count()
	if child_count <= 1:
		return
	_container.move_child(indicator, child_count - 1)
