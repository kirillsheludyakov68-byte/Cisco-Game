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
	if file == null:
		push_error("Не удалось открыть файл уровня: " + path)
		return

	var json_text := file.get_as_text()
	file.close()
	
	var data = JSON.parse_string(json_text)
	if data == null:
		push_error("Ошибка парсинга JSON: " + path)
		return
	
	for dev_data in data.get("devices", []):
		_spawn_device(dev_data)
	
	# Предустановленные модули: { "pc1": ["PT-HOST-NM-1CE"] }
	var presets = data.get("module_presets", {})
	if presets is Dictionary:
		_apply_module_presets(presets)
	
	for conn_data in data.get("connections", []):
		_spawn_connection(conn_data)

func _spawn_device(data: Dictionary) -> void:
	var device: Device = DEVICE_SCENE.instantiate()
	add_child(device)
	
	var pos: Array = data.get("position", [0, 0])
	device.position = Vector2(pos[0], pos[1])
	
	device.device_name = data.get("name", "Device")
	device.ip_address = data.get("ip", "")
	device.subnet_mask = data.get("mask", "255.255.255.0")
	
	# ВАЖНО: сначала задаём текстуры, потом тип.
	# Сеттер device_type вызовет _apply_texture_by_type()
	# и применит нужную текстуру к спрайту.
	var device_type: String = data.get("type", "PC")
	_apply_textures(device, device_type)
	device.device_type = device_type
	if data.has("power"):
		device.set_initial_power(bool(data.get("power")))
	
	device.device_clicked.connect(_on_device_clicked)
	NetworkSimulator.register_device(device)
	device.reset_highlight()
	
	var id: String = data.get("id", "")
	devices_by_id[id] = device

func _apply_textures(device: Device, device_type: String) -> void:
	# Загружаем только текстуру нужного типа, чтобы не требовать
	# несуществующие ассеты для устройств, которых нет на уровне.
	match device_type:
		"PC":
			device.texture_pc = load("res://assets/PC.svg")
		"Switch":
			device.texture_switch = load("res://assets/Switch.svg")
		"Router":
			if ResourceLoader.exists("res://assets/Router.svg"):
				device.texture_router = load("res://assets/Router.svg")
		"AccessPoint":
			if ResourceLoader.exists("res://assets/AccessPoint.svg"):
				device.texture_ap = load("res://assets/AccessPoint.svg")

func _apply_module_presets(presets: Dictionary) -> void:
	for device_id in presets:
		if not devices_by_id.has(device_id):
			push_warning("module_presets: устройство не найдено: " + str(device_id))
			continue
		
		var value = presets[device_id]
		var module_name := ""
		if value is String:
			module_name = value
		elif value is Array and value.size() > 0:
			module_name = str(value[0])
			if value.size() > 1:
				push_warning("module_presets: у ПК только один слот, беру первый модуль для " + str(device_id))
		
		if module_name == "":
			continue
		
		var dev: Device = devices_by_id[device_id]
		dev.set_initial_module(module_name)


# Формат связи:
# { "from": "pc1", "to": "ap1", "cable": "straight|crossover|wireless|fiber", "delay": 6.0 }
# delay используется только для wireless; по умолчанию 6 секунд.
func _spawn_connection(data: Dictionary) -> void:
	var from_id: String = data.get("from", "")
	var to_id: String = data.get("to", "")
	var cable_name: String = data.get("cable", "straight")
	
	if not devices_by_id.has(from_id) or not devices_by_id.has(to_id):
		push_warning("Не найдены устройства для связи: " + from_id + " → " + to_id)
		return
	
	var from_dev: Device = devices_by_id[from_id]
	var to_dev: Device = devices_by_id[to_id]
	
	var cable_type: int = NetworkSimulator.CableType.STRAIGHT
	match cable_name:
		"straight":  cable_type = NetworkSimulator.CableType.STRAIGHT
		"crossover": cable_type = NetworkSimulator.CableType.CROSSOVER
		"wireless":  cable_type = NetworkSimulator.CableType.WIRELESS
		"fiber":     cable_type = NetworkSimulator.CableType.FIBER
	
	var delay: float = float(data.get("delay", -1.0))
	var conn = CONNECTION_SCENE.instantiate()
	add_child(conn)
	conn.setup(from_dev, to_dev, cable_type, delay)
	NetworkSimulator.add_connection(conn)

func _on_device_clicked(device: Device) -> void:
	cable_panel.handle_device_click(device)
