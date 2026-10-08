extends Node2D
class_name Connection

# Ссылки на устройства, которые соединяем
var from_device: Node2D
var to_device: Node2D

# Тип кабеля (из NetworkSimulator.CableType)
var cable_type: int = NetworkSimulator.CableType.STRAIGHT

# Внутренние ссылки
@onready var line: Line2D = $Line
@onready var click_area: Area2D = $ClickArea
@onready var collision_shape: CollisionShape2D = $ClickArea/CollisionShape2D
@onready var cross_ticks: Node2D = $CrossTicks

const TICK_SPACING = 18.0   # расстояние между "палочками" для wireless
const TICK_LENGTH = 10.0    # длина каждой "палочки"

func _ready() -> void:
	click_area.input_event.connect(_on_click_area_input_event)
	# Первая отрисовка
	_redraw()

func _process(_delta: float) -> void:
	# Каждый кадр перерисовываем — на случай, если устройство сдвинулось
	_redraw()

func setup(a: Node2D, b: Node2D, type: int) -> void:
	from_device = a
	to_device = b
	cable_type = type
	if is_node_ready():
		_redraw()

func _redraw() -> void:
	if from_device == null or to_device == null:
		return
	
	var a_local := to_local(from_device.global_position)
	var b_local := to_local(to_device.global_position)
	
	line.points = PackedVector2Array([a_local, b_local])
	
	match cable_type:
		NetworkSimulator.CableType.STRAIGHT:
			line.default_color = Color(0.1, 0.1, 0.1)
			line.width = 3.0
			_clear_ticks()
		NetworkSimulator.CableType.CROSSOVER:
			line.default_color = Color(0.9, 0.5, 0.1)
			line.width = 3.0
			_clear_ticks()
		NetworkSimulator.CableType.WIRELESS:
			line.default_color = Color(0.2, 0.2, 0.2, 0.6)
			line.width = 2.0
			_draw_ticks(a_local, b_local)
	
	_update_collision(a_local, b_local)

func _update_collision(a_pos: Vector2, b_pos: Vector2) -> void:
	var mid := (a_pos + b_pos) / 2.0
	var length := a_pos.distance_to(b_pos)
	var angle := (b_pos - a_pos).angle()
	
	var capsule: CapsuleShape2D = collision_shape.shape
	if capsule == null:
		capsule = CapsuleShape2D.new()
		collision_shape.shape = capsule
	capsule.radius = 12.0
	capsule.height = length
	
	# Локальные координаты, не global!
	collision_shape.position = mid
	collision_shape.rotation = angle

func _clear_ticks() -> void:
	for child in cross_ticks.get_children():
		child.queue_free()

# Рисуем "палочки" поперёк линии — как в Cisco для wireless
func _draw_ticks(a_pos: Vector2, b_pos: Vector2) -> void:
	_clear_ticks()
	
	var dir := (b_pos - a_pos).normalized()
	var perp := Vector2(-dir.y, dir.x)   # перпендикуляр
	var length := a_pos.distance_to(b_pos)
	var num_ticks := int(length / TICK_SPACING)
	
	for i in range(1, num_ticks):
		var t := float(i) / float(num_ticks)
		var center := a_pos.lerp(b_pos, t)
		var tick := Line2D.new()
		tick.points = PackedVector2Array([
			center - perp * TICK_LENGTH / 2.0,
			center + perp * TICK_LENGTH / 2.0
		])
		tick.width = 2.0
		tick.default_color = Color(0.2, 0.2, 0.2, 0.6)
		cross_ticks.add_child(tick)

func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Клик по кабелю — удаляем")
		NetworkSimulator.remove_connection(self)
		queue_free()
