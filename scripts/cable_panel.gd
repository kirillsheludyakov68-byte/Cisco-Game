extends CanvasLayer

# Какой кабель выбран (или -1, если ничего)
var selected_cable: int = -1

# Первое устройство, с которого начали тянуть кабель
var first_device: Device = null

# Временная "резиновая" линия за курсором
var rubber_line: Line2D = null

signal cable_selected(cable_type: int)

func _ready() -> void:
	$PanelContainer/HBoxContainer/ButtonStraight.pressed.connect(
		func(): _select(NetworkSimulator.CableType.STRAIGHT))
	$PanelContainer/HBoxContainer/ButtonCrossover.pressed.connect(
		func(): _select(NetworkSimulator.CableType.CROSSOVER))
	$PanelContainer/HBoxContainer/ButtonWireless.pressed.connect(
		func(): _select(NetworkSimulator.CableType.WIRELESS))
	
	# Создаём временную линию, но скрываем её
	rubber_line = Line2D.new()
	rubber_line.width = 3.0
	rubber_line.default_color = Color(0.5, 0.5, 0.5, 0.7)
	rubber_line.visible = false
	add_child(rubber_line)

func _select(cable_type: int) -> void:
	selected_cable = cable_type
	# Если уже начали соединение — сбросим
	_cancel_connection()
	print("Выбран кабель: ", cable_type)
	cable_selected.emit(cable_type)

func _cancel_connection() -> void:
	first_device = null
	rubber_line.visible = false
	_reset_all_highlights()

func _process(_delta: float) -> void:
	if first_device != null and rubber_line.visible:
		rubber_line.points = PackedVector2Array([
			first_device.global_position,
			get_viewport().get_mouse_position()   # ← координаты в CanvasLayer
		])

# Устройство кликнуто — вызывается из level.gd
func handle_device_click(device: Device) -> void:
	if selected_cable == -1:
		return  # кабель не выбран — ничего не делаем
	
	if first_device == null:
		# Первый клик — начинаем тянуть
		first_device = device
		rubber_line.visible = true
		print("Начали тянуть от ", device.device_name)
	else:
		# Второй клик — пытаемся соединить
		if first_device == device:
			# Кликнули на то же устройство — отмена
			_cancel_connection()
			return
		
		var check := NetworkSimulator.can_connect(first_device, device)
		if not check.ok:
			print("Нельзя соединить: ", check.reason)
			_cancel_connection()
			return
		
		# Создаём связь
		_create_connection(first_device, device, selected_cable)
		_cancel_connection()
		# После соединения выключаем режим (Вариант A)
		selected_cable = -1

func _create_connection(a: Device, b: Device, cable_type: int) -> void:
	var scene := load("res://scenes/Connection.tscn")
	var conn = scene.instantiate()
	# Добавляем в тот же родитель, где лежат устройства
	get_tree().current_scene.add_child(conn)
	conn.setup(a, b, cable_type)
	NetworkSimulator.add_connection(conn)
	print("Соединено: ", a.device_name, " ↔ ", b.device_name)

func _reset_all_highlights() -> void:
	for d in NetworkSimulator.devices:
		if is_instance_valid(d):
			d.reset_highlight()
