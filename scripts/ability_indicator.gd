extends Control
class_name AbilityIndicator

@export var line_width: float = 6.0
@export var background_color: Color = Color(1, 1, 1, 0.15)
@export var progress_color: Color = Color(0.4, 0.8, 1.0, 0.85)

var _progress: float = 1.0
var _label_text: String = ""

@onready var _label: Label = _create_label()


func _init() -> void:
	custom_minimum_size = Vector2(110, 140)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _ready() -> void:
	add_child(_label)
	_label.text = _label_text


func set_label(text: String) -> void:
	_label_text = text
	if is_instance_valid(_label):
		_label.text = text


func set_progress(value: float) -> void:
	_progress = clamp(value, 0.0, 1.0)
	queue_redraw()


func set_indicator_active(active: bool) -> void:
	visible = active
	if active:
		queue_redraw()


func set_colors(foreground: Color, background: Color) -> void:
	progress_color = foreground
	background_color = background
	queue_redraw()


func _draw() -> void:
	if not visible:
		return

	var circle_area_height: float = size.y - 32.0
	var radius: float = min(size.x, circle_area_height) * 0.5 - line_width
	radius = max(radius, 4.0)
	var center: Vector2 = Vector2(size.x * 0.5, circle_area_height * 0.5 + 4.0)

	draw_arc(center, radius, -PI / 2.0, -PI / 2.0 + TAU, 64, background_color, line_width)

	if _progress > 0.0:
		var arc_length: float = clamp(_progress, 0.0, 1.0) * TAU
		draw_arc(center, radius, -PI / 2.0, -PI / 2.0 + arc_length, 64, progress_color, line_width)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()


func _create_label() -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchor_left = 0.0
	label.anchor_right = 1.0
	label.anchor_top = 1.0
	label.anchor_bottom = 1.0
	label.offset_top = -28.0
	label.offset_bottom = -4.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
