extends Control
class_name HintArrow

# Стрелка-подсказка. Может рисоваться поверх игрового мира (CanvasLayer)
# и внутри окна устройства. Не перехватывает мышь.

const HINT_DURATION_MS := 10000
const ARROW_COLOR := Color(1.0, 0.48, 0.05, 1.0)
const ARROW_OUTLINE := Color(0.18, 0.12, 0.04, 0.85)
const RING_COLOR := Color(1.0, 0.62, 0.12, 0.95)
const RING_SOFT := Color(1.0, 0.72, 0.25, 0.28)

var _mode := ""
var _device: Node2D = null
var _control: Control = null
var _world_point := Vector2.ZERO
var _rect := Rect2()
var _expires_at := 0
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	set_process(false)


func show_world_device(device: Node2D) -> void:
	_mode = "device"
	_device = device
	_control = null
	_activate()


func show_control(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		hide_hint()
		return
	_mode = "control"
	_control = control
	_device = null
	_activate()


func show_world_point(point: Vector2) -> void:
	_mode = "point"
	_world_point = point
	_device = null
	_control = null
	_activate()


func show_rect(rect: Rect2) -> void:
	_mode = "rect"
	_rect = rect
	_device = null
	_control = null
	_activate()


func hide_hint() -> void:
	_mode = ""
	_device = null
	_control = null
	visible = false
	set_process(false)
	queue_redraw()


func _activate() -> void:
	_time = 0.0
	_expires_at = Time.get_ticks_msec() + HINT_DURATION_MS
	visible = true
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	if Time.get_ticks_msec() >= _expires_at:
		hide_hint()
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	if not visible:
		return

	var target_center := Vector2.ZERO
	var ring_radius := 30.0

	match _mode:
		"device":
			if _device == null or not is_instance_valid(_device):
				hide_hint()
				return
			target_center = _to_local_canvas(_device.get_global_transform_with_canvas().origin)
			ring_radius = 52.0
		"control":
			if _control == null or not is_instance_valid(_control) or not _control.is_visible_in_tree():
				hide_hint()
				return
			var control_rect := _to_local_rect(_control.get_global_rect())
			target_center = control_rect.get_center()
			ring_radius = maxf(24.0, minf(control_rect.size.x, control_rect.size.y) * 0.5 + 8.0)
		"point":
			target_center = _to_local_canvas(
				get_viewport().get_canvas_transform() * _world_point
			)
			ring_radius = 30.0
		"rect":
			var target_rect := _to_local_rect(_rect)
			target_center = target_rect.get_center()
			ring_radius = maxf(24.0, minf(target_rect.size.x, target_rect.size.y) * 0.5 + 8.0)
		_:
			return

	var pulse := 0.5 + 0.5 * sin(_time * 4.0)
	draw_arc(target_center, ring_radius + 4.0, 0.0, TAU, 48, RING_SOFT, 5.0, true)
	draw_arc(target_center, ring_radius, 0.0, TAU, 48, RING_COLOR, 2.0, true)

	_draw_arrow(target_center, ring_radius, pulse)


# Все цели приходят в координатах canvas/viewport. Переводим их
# в локальные координаты стрелки, чтобы она не смещалась при
# масштабировании и не указывала на собственный угол.
func _to_local_canvas(point: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * point


func _to_local_rect(rect: Rect2) -> Rect2:
	var top_left := _to_local_canvas(rect.position)
	var bottom_right := _to_local_canvas(rect.end)
	return Rect2(top_left, bottom_right - top_left).abs()


func _draw_arrow(target_center: Vector2, ring_radius: float, pulse: float) -> void:
	var bob := sin(_time * 5.0) * 5.0
	var tip: Vector2
	var tail: Vector2
	var head: PackedVector2Array

	# У верхней кромки экрана/окна вертикальная стрелка обрезалась бы.
	# В этом случае рисуем горизонтальную стрелку сбоку.
	var near_top := target_center.y < ring_radius + 92.0
	if near_top:
		var direction := 1.0 if target_center.x < size.x * 0.5 else -1.0
		tip = target_center + Vector2(direction * (ring_radius + 10.0), 0.0)
		tail = tip + Vector2(direction * 52.0, 0.0)
		head = PackedVector2Array([
			tip,
			tip + Vector2(-direction * 17.0, -13.0),
			tip + Vector2(-direction * 17.0, 13.0),
		])
	else:
		tip = target_center + Vector2(0.0, -ring_radius - 10.0 + bob)
		tail = tip + Vector2(0.0, -52.0)
		head = PackedVector2Array([
			tip,
			tip + Vector2(-14.0, -17.0),
			tip + Vector2(14.0, -17.0),
		])

	# Не даём хвосту и наконечнику уехать за пределы экрана/окна.
	var margin := 8.0
	var bounds := Rect2(Vector2(margin, margin), size - Vector2(margin * 2.0, margin * 2.0))
	tip = tip.clamp(bounds.position, bounds.end)
	tail = tail.clamp(bounds.position, bounds.end)
	for index in head.size():
		head[index] = head[index].clamp(bounds.position, bounds.end)

	# Тёмная подложка делает стрелку читаемой на светлом фоне.
	draw_line(tail, tip, ARROW_OUTLINE, 9.0, true)
	draw_colored_polygon(head, ARROW_OUTLINE)
	draw_line(tail, tip, ARROW_COLOR, 4.0, true)
	draw_colored_polygon(head, ARROW_COLOR)

	var outline := PackedVector2Array([head[0], head[1], head[2], head[0]])
	draw_polyline(outline, ARROW_OUTLINE, 1.5, true)

	# Пульсирующая точка у острия.
	draw_circle(tip, 4.0 + pulse * 2.0, Color(1.0, 0.85, 0.35, 0.9))
