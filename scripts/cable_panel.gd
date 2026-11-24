extends CanvasLayer

# Какой кабель выбран (или -1, если ничего)
var selected_cable: int = -1

# Первое устройство, с которого начали тянуть кабель
var first_device: Device = null

# Временная "резиновая" линия за курсором
var rubber_line: Line2D = null

# Текущее открытое окно устройства
var current_device_window: DeviceWindow = null

signal cable_selected(cable_type: int)

func _ready() -> void:
	$PanelContainer/HBoxContainer/ButtonStraight.pressed.connect(_on_straight)
	$PanelContainer/HBoxContainer/ButtonCrossover.pressed.connect(_on_crossover)
	$PanelContainer/HBoxContainer/ButtonWireless.pressed.connect(_on_wireless)
	
	rubber_line = Line2D.new()
	rubber_line.width = 3.0
	rubber_line.default_color = Color(0.5, 0.5, 0.5, 0.7)
	rubber_line.visible = false
	add_child(rubber_line)

func _on_straight() -> void:
	_select(NetworkSimulator.CableType.STRAIGHT)

func _on_crossover() -> void:
	_select(NetworkSimulator.CableType.CROSSOVER)

func _on_wireless() -> void:
	_select(NetworkSimulator.CableType.WIRELESS)

func _select(cable_type: int) -> void:
	selected_cable = cable_type
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
			get_viewport().get_mouse_position()
		])

func handle_device_click(device: Device) -> void:
	if selected_cable == -1:
		_open_device_window(device)
		return
	
	if first_device == null:
		first_device = device
		rubber_line.visible = true
		print("Начали тянуть от ", device.device_name)
	else:
		if first_device == device:
			_cancel_connection()
			return
		
		var check := NetworkSimulator.can_connect(first_device, device)
		if not check.ok:
			print("Нельзя соединить: ", check.reason)
			_cancel_connection()
			return
		
		_create_connection(first_device, device, selected_cable)
		_cancel_connection()
		selected_cable = -1

func _create_connection(a: Device, b: Device, cable_type: int) -> void:
	var scene := load("res://scenes/Connection.tscn")
	var conn = scene.instantiate()
	get_tree().current_scene.add_child(conn)
	conn.setup(a, b, cable_type)
	NetworkSimulator.add_connection(conn)
	print("Соединено: ", a.device_name, " ↔ ", b.device_name)

func _open_device_window(device: Device) -> void:
	if current_device_window and is_instance_valid(current_device_window):
		current_device_window.queue_free()
	
	var scene := load("res://scenes/DeviceWindow.tscn")
	if scene == null:
		push_error("Не удалось загрузить DeviceWindow.tscn")
		return
	
	current_device_window = scene.instantiate()
	
	# ВАЖНО: Сначала добавляем в дерево
	get_tree().current_scene.add_child(current_device_window)
	
	# Только потом передаем устройство и открываем
	current_device_window.open_for(device)
	current_device_window.popup_centered(Vector2i(850, 670))

func _reset_all_highlights() -> void:
	for d in NetworkSimulator.devices:
		if is_instance_valid(d):
			d.reset_highlight()
