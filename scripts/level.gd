extends Node2D

const DEVICE_SCENE := preload("res://scenes/Device.tscn")
const CONNECTION_SCENE := preload("res://scenes/Connection.tscn")

@export_file("*.json") var level_path: String = "res://data/levels/level_1.json"

@onready var cable_panel: CanvasLayer = $CablePanel

var devices_by_id: Dictionary = {}

func _ready() -> void:
	NetworkSimulator.clear()
	_load_level(level_path)

func _load_level(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_error("Файл уровня не найден: " + path)
		return
	
	var file := FileAccess.open(path, FileAccess.READ)
	var json_text := file.get_as_text()
	file.close()
	
	var data = JSON.parse_string(json_text)
	if data == null:
		push_error("Ошибка парсинга JSON: " + path)
		return
	
	# 1. Создаём устройства
	for dev_data in data.get("devices", []):
		_spawn_device(dev_data)
	
	# 2. Создаём связи
	for conn_data in data.get("connections", []):
		_spawn_connection(conn_data)

func _spawn_device(data: Dictionary) -> void:
	var device: Device = DEVICE_SCENE.instantiate()
	add_child(device)
	
	# Позиция
	var pos: Array = data.get("position", [0, 0])
	device.position = Vector2(pos[0], pos[1])
	
	# Имя и IP
	device.device_name = data.get("name", "Device")
	device.ip_address = data.get("ip", "")
	device.subnet_mask = data.get("mask", "255.255.255.0")
	
	# ВАЖНО: сначала задаём текстуры, потом тип.
	# Сеттер device_type вызовет _apply_texture_by_type()
	# и применит нужную текстуру к спрайту.
	_apply_textures(device)
	device.device_type = data.get("type", "PC")
	
	# Подключаем сигнал и регистрируем
	device.device_clicked.connect(_on_device_clicked)
	NetworkSimulator.register_device(device)
	device.reset_highlight()
	
	# Сохраняем по id
	var id: String = data.get("id", "")
	devices_by_id[id] = device

func _apply_textures(device: Device) -> void:
	# Загружаем все текстуры заранее. Какая нужна — применит сеттер device_type.
	device.texture_pc = load("res://assets/PC.svg")
	device.texture_switch = load("res://assets/Switch.svg")
	device.texture_router = load("res://assets/Router.svg")
	device.texture_ap = load("res://assets/AccessPoint.svg")

func _spawn_connection(data: Dictionary) -> void:
	var from_id: String = data.get("from", "")
	var to_id: String = data.get("to", "")
	var cable_name: String = data.get("cable", "straight")
	
	if not from_id in devices_by_id or not to_id in devices_by_id:
		push_warning("Не найдены устройства для связи: " + from_id + " → " + to_id)
		return
	
	var from_dev: Device = devices_by_id[from_id]
	var to_dev: Device = devices_by_id[to_id]
	
	var cable_type: int = NetworkSimulator.CableType.STRAIGHT
	match cable_name:
		"straight":  cable_type = NetworkSimulator.CableType.STRAIGHT
		"crossover": cable_type = NetworkSimulator.CableType.CROSSOVER
		"wireless":  cable_type = NetworkSimulator.CableType.WIRELESS
	
	var conn = CONNECTION_SCENE.instantiate()
	add_child(conn)
	conn.setup(from_dev, to_dev, cable_type)
	NetworkSimulator.add_connection(conn)

func _on_device_clicked(device: Device) -> void:
	cable_panel.handle_device_click(device)
