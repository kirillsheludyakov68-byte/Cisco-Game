extends Node2D
class_name Connection

signal connection_activated

const DEFAULT_WIRELESS_DELAY := 6.0
const WIRELESS_TICK_SPACING := 8.0
const WIRELESS_TICK_LENGTH := 10.0
const WIRELESS_TICK_WIDTH := 2.0
const WIRELESS_COLOR := Color(0.08, 0.08, 0.08)
const WIRELESS_TRIM := 42.0
const COLLISION_TRIM := 42.0
const COLLISION_RADIUS := 10.0
const CROSSOVER_COLOR := Color(0.9, 0.5, 0.1)
const FIBER_COLOR := Color(0.9, 0.08, 0.08)

# Ссылки на устройства, которые соединяем
var from_device: Node2D
var to_device: Node2D

# Тип кабеля (из NetworkSimulator.CableType)
var cable_type: int = NetworkSimulator.CableType.STRAIGHT

var _wireless_delay := DEFAULT_WIRELESS_DELAY
var _wireless_elapsed := 0.0
var _active := true

@onready var click_area: Area2D = $ClickArea
@onready var collision_shape: CollisionShape2D = $ClickArea/CollisionShape2D

func _ready() -> void:
	click_area.input_event.connect(_on_click_area_input_event)
	if collision_shape.shape == null:
		collision_shape.shape = CapsuleShape2D.new()
	_redraw()

func _process(delta: float) -> void:
	if not _devices_valid():
		collision_shape.disabled = true
		return

	if cable_type == NetworkSimulator.CableType.WIRELESS and not _active:
		_wireless_elapsed += delta
		if _wireless_elapsed >= _wireless_delay:
			_wireless_elapsed = _wireless_delay
			_active = true
			connection_activated.emit()

	# Перерисовываем каждый кадр — устройства могут двигаться,
	# а беспроводная связь плавно "прорастает".
	_redraw()

func setup(a: Node2D, b: Node2D, type: int, wireless_delay: float = -1.0) -> void:
	from_device = a
	to_device = b
	cable_type = type
	_wireless_elapsed = 0.0
	_active = true
	_wireless_delay = 0.0

	if type == NetworkSimulator.CableType.WIRELESS:
		_wireless_delay = DEFAULT_WIRELESS_DELAY if wireless_delay < 0.0 else clampf(wireless_delay, 0.0, 60.0)
		_active = _wireless_delay <= 0.0

	if is_node_ready():
		_redraw()

func is_active() -> bool:
	return _active

func is_connecting() -> bool:
	return cable_type == NetworkSimulator.CableType.WIRELESS and not _active

func get_wireless_progress() -> float:
	if cable_type != NetworkSimulator.CableType.WIRELESS or _wireless_delay <= 0.0:
		return 1.0
	return clampf(_wireless_elapsed / _wireless_delay, 0.0, 1.0)

func _devices_valid() -> bool:
	return is_instance_valid(from_device) and is_instance_valid(to_device)

func _redraw() -> void:
	if not _devices_valid():
		return
	queue_redraw()
	_update_collision()

func _draw() -> void:
	if not _devices_valid():
		return

	var a := to_local(from_device.global_position)
	var b := to_local(to_device.global_position)

	match cable_type:
		NetworkSimulator.CableType.STRAIGHT:
			draw_line(a, b, Color(0.1, 0.1, 0.1), 3.0, true)
		NetworkSimulator.CableType.CROSSOVER:
			draw_dashed_line(a, b, CROSSOVER_COLOR, 3.0, 10.0, true, true)
		NetworkSimulator.CableType.FIBER:
			# Тёмная подложка + яркая красная жила — так кабель читается на белом фоне.
			draw_line(a, b, Color(0.55, 0.0, 0.0), 4.0, true)
			draw_line(a, b, FIBER_COLOR, 2.0, true)
		NetworkSimulator.CableType.WIRELESS:
			_draw_wireless(a, b)

func _draw_wireless(a: Vector2, b: Vector2) -> void:
	var length := a.distance_to(b)
	if length < 1.0:
		return

	var dir := (b - a) / length
	var trim := minf(WIRELESS_TRIM, length * 0.22)
	var start := a + dir * trim
	var end := b - dir * trim
	var span := start.distance_to(end)
	if span < 1.0:
		return

	var perp := Vector2(-dir.y, dir.x)

	# Палочки идут через равные промежутки. Количество подбираем так,
	# чтобы фактический шаг был близок к WIRELESS_TICK_SPACING.
	var tick_count := maxi(1, int(round(span / WIRELESS_TICK_SPACING)))
	var progress := get_wireless_progress()
	var visible_count := int(floor(float(tick_count) * progress))

	for i in range(visible_count + 1):
		var t := float(i) / float(tick_count)
		var center := start.lerp(end, t)
		var tick_start := center - perp * (WIRELESS_TICK_LENGTH * 0.5)
		var tick_end := center + perp * (WIRELESS_TICK_LENGTH * 0.5)
		draw_line(tick_start, tick_end, WIRELESS_COLOR, WIRELESS_TICK_WIDTH, true)

func _update_collision() -> void:
	if not _devices_valid():
		collision_shape.disabled = true
		return

	var a := to_local(from_device.global_position)
	var b := to_local(to_device.global_position)
	var length := a.distance_to(b)
	if length < 1.0:
		collision_shape.disabled = true
		return

	# Не перекрываем клики по устройствам: зона клика только на середине кабеля.
	var dir := (b - a) / length
	var trim := minf(COLLISION_TRIM, length * 0.28)
	var start := a + dir * trim
	var end := b - dir * trim
	var span := start.distance_to(end)
	if span < 1.0:
		collision_shape.disabled = true
		return

	var capsule: CapsuleShape2D = collision_shape.shape
	if capsule == null:
		capsule = CapsuleShape2D.new()
		collision_shape.shape = capsule

	capsule.radius = COLLISION_RADIUS
	capsule.height = maxf(span, COLLISION_RADIUS * 2.0)
	collision_shape.disabled = false
	collision_shape.position = (start + end) * 0.5
	# У CapsuleShape2D длинная ось идёт по Y, поэтому добавляем 90°,
	# чтобы зона клика совпадала с направлением кабеля.
	collision_shape.rotation = (end - start).angle() + PI / 2.0

func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		NetworkSimulator.remove_connection(self)
		queue_free()
