extends Node2D

const DEVICE_SCENE := preload("res://scenes/Device.tscn")
const CONNECTION_SCENE := preload("res://scenes/Connection.tscn")

@export_file("*.json") var level_path: String = "res://data/levels/level_1.json"

@onready var cable_panel = $CablePanel
@onready var task_panel: TaskPanel = $TaskPanel

var devices_by_id: Dictionary = {}
var level_title := "Задание"
var level_description := ""
var objectives: Array = []
var hints_available := 3

# Пинг считается выполненным только после реальной команды в Command Prompt.
# При изменении питания/кабеля шаг перепроверяется через ping_ipv4().
var _ping_succeeded := false


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
	if not data is Dictionary:
		push_error("Ошибка парсинга JSON: " + path)
		return

	level_title = str(data.get("title", "Задание"))
	level_description = str(data.get("description", ""))
	hints_available = int(data.get("hints", 3))
	var raw_objectives = data.get("objectives", [])
	if raw_objectives is Array:
		objectives = (raw_objectives as Array).duplicate(true)

	for dev_data in data.get("devices", []):
		_spawn_device(dev_data)

	# Предустановленные модули: { "pc1": ["PT-HOST-NM-1CE"] }
	var presets = data.get("module_presets", {})
	if presets is Dictionary:
		_apply_module_presets(presets)

	for conn_data in data.get("connections", []):
		_spawn_connection(conn_data)

	_connect_level_signals()
	if task_panel != null:
		task_panel.setup(self, level_title, level_description, objectives, hints_available)
	_refresh_objectives()


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


# --- Сигналы уровня ---

func _connect_level_signals() -> void:
	if not NetworkSimulator.connections_changed.is_connected(_on_level_state_changed):
		NetworkSimulator.connections_changed.connect(_on_level_state_changed)
	if not NetworkSimulator.connection_activated.is_connected(_on_connection_activated):
		NetworkSimulator.connection_activated.connect(_on_connection_activated)
	if not NetworkSimulator.ping_checked.is_connected(_on_ping_checked):
		NetworkSimulator.ping_checked.connect(_on_ping_checked)

	for device in devices_by_id.values():
		if device == null or not is_instance_valid(device):
			continue
		if not device.power_changed.is_connected(_on_device_power_changed):
			device.power_changed.connect(_on_device_power_changed)
		if not device.boot_state_changed.is_connected(_on_device_boot_state_changed):
			device.boot_state_changed.connect(_on_device_boot_state_changed)
		if not device.configuration_changed.is_connected(_on_level_state_changed):
			device.configuration_changed.connect(_on_level_state_changed)
		if not device.interfaces_changed.is_connected(_on_level_state_changed):
			device.interfaces_changed.connect(_on_level_state_changed)
		if not device.modules_applied.is_connected(_on_device_modules_applied):
			device.modules_applied.connect(_on_device_modules_applied)


func _on_level_state_changed() -> void:
	if not is_inside_tree() or task_panel == null:
		return
	_refresh_objectives()


func _on_device_power_changed(_is_on: bool) -> void:
	_on_level_state_changed()


func _on_device_boot_state_changed(_is_booting: bool) -> void:
	_on_level_state_changed()


func _on_device_modules_applied(_changed_device: Device, _module_name: String) -> void:
	_on_level_state_changed()


func _on_connection_activated(_connection) -> void:
	_on_level_state_changed()


func _on_ping_checked(source, target_address, ok) -> void:
	var ping_objective := _get_ping_objective()
	if ping_objective.is_empty():
		return
	var source_device := _device(str(ping_objective.get("from", "")))
	if source_device == null or source != source_device:
		return
	if str(target_address) != str(ping_objective.get("target", "")):
		return
	_ping_succeeded = bool(ok)
	_refresh_objectives()


# --- Проверка шагов ---

func _refresh_objectives() -> void:
	if task_panel == null:
		return
	var states: Array[bool] = []
	for objective in objectives:
		states.append(evaluate_objective(objective))
	task_panel.set_states(states)


func evaluate_objective(objective: Dictionary) -> bool:
	match str(objective.get("type", "")):
		"module":
			var dev := _device(str(objective.get("device", "")))
			if dev == null:
				return false
			var required_module := str(objective.get("module", ""))
			if not required_module.is_empty() and dev.installed_module != required_module:
				return false
			var kind := str(objective.get("interface_kind", ""))
			if not kind.is_empty():
				return dev.has_enabled_interface_kind(kind)
			return not dev.installed_module.is_empty()

		"connection":
			var from_device := _device(str(objective.get("from", "")))
			var to_device := _device(str(objective.get("to", "")))
			if from_device == null or to_device == null:
				return false
			var connection = NetworkSimulator.find_connection(from_device, to_device)
			if connection == null:
				return false
			if connection.has_method("is_active") and not connection.is_active():
				return false
			if not _connection_matches_cable(connection, str(objective.get("cable", "straight"))):
				return false
			var required_kind := str(objective.get("interface_kind", "ethernet"))
			if not required_kind.is_empty():
				if not from_device.has_enabled_interface_kind(required_kind):
					return false
				if not to_device.has_enabled_interface_kind(required_kind):
					return false
			return true

		"power":
			var power_device := _device(str(objective.get("device", "")))
			if power_device == null:
				return false
			var want_on := bool(objective.get("on", true))
			if power_device.is_powered_on != want_on:
				return false
			if want_on and bool(objective.get("booted", false)):
				if power_device.device_type == "Switch" and power_device.is_booting:
					return false
			return true

		"ping":
			if not _ping_succeeded:
				return false
			var ping_source := _device(str(objective.get("from", "")))
			var target_address := str(objective.get("target", ""))
			if ping_source == null or target_address.is_empty():
				return false
			var result: Dictionary = NetworkSimulator.ping_ipv4(ping_source, target_address)
			return bool(result.get("ok", false))
	return false


func _connection_matches_cable(connection, cable_name: String) -> bool:
	var cable_type := _cable_type_from_name(cable_name)
	if cable_type < 0:
		return false
	return int(connection.cable_type) == cable_type


func _cable_type_from_name(cable_name: String) -> int:
	match cable_name:
		"straight":
			return NetworkSimulator.CableType.STRAIGHT
		"crossover":
			return NetworkSimulator.CableType.CROSSOVER
		"wireless":
			return NetworkSimulator.CableType.WIRELESS
		"fiber":
			return NetworkSimulator.CableType.FIBER
	return -1


func _device(device_id: String) -> Device:
	var value = devices_by_id.get(device_id)
	if value is Device and is_instance_valid(value):
		return value
	return null


func _get_ping_objective() -> Dictionary:
	for objective in objectives:
		if objective is Dictionary and str(objective.get("type", "")) == "ping":
			return objective
	return {}


# --- Подсказки ---

func request_hint() -> Dictionary:
	if objectives.is_empty():
		return {"text": "В этом уровне нет шагов.", "target": {}}

	for objective in objectives:
		if objective is Dictionary and not evaluate_objective(objective):
			return _hint_for_objective(objective)
	return {"text": "Все шаги выполнены. Задание завершено!", "target": {}}


func _hint_for_objective(objective: Dictionary) -> Dictionary:
	match str(objective.get("type", "")):
		"module":
			return _hint_for_module(objective)
		"connection":
			return _hint_for_connection(objective)
		"power":
			return _hint_for_power(objective)
		"ping":
			return _hint_for_ping(objective)
	return {"text": "Выполните следующий шаг задания.", "target": {}}


func _hint_for_module(objective: Dictionary) -> Dictionary:
	var dev := _device(str(objective.get("device", "")))
	if dev == null:
		return _hint("Устройство для этого шага не найдено.", {})

	var window = _open_window(dev)
	if window == null:
		if cable_panel != null and int(cable_panel.selected_cable) != -1:
			return _hint(
				"Сначала выключите режим прокладки кабеля: нажмите выбранную иконку ещё раз.",
				{"kind": "cable_button", "cable": int(cable_panel.selected_cable)}
			)
		return _hint(
			"Кликните по %s, чтобы открыть окно устройства." % dev.device_name,
			_world_target(dev)
		)

	if not window.page_physical.visible:
		return _hint("Перейдите на вкладку Physical.", _window_node_target(window, window.tab_physical))

	if dev.is_powered_on:
		return _hint(
			"Выключите %s: нажмите кнопку питания на изображении." % dev.device_name,
			_window_rect_target(window, window.get_power_hint_rect())
		)

	if not dev.has_enabled_interface_kind("ethernet"):
		var required_module := str(objective.get("module", ModuleCatalog.PT_HOST_NM_1CE))
		if not dev.installed_module.is_empty():
			return _hint(
				"В слоте установлен не тот модуль. Извлеките его и поставьте %s." % required_module,
				_window_node_target(window, window.module_slot)
			)
		if not window.modules_panel.is_list_visible():
			return _hint(
				"Разверните список модулей.",
				_window_node_target(window, window.modules_panel.header_button)
			)
		var module_button = window.modules_panel.get_module_button(required_module)
		if module_button != null:
			return _hint(
				"Перетащите %s в слот модуля." % required_module,
				_window_node_target(window, module_button)
			)
		return _hint(
			"Перетащите Ethernet-модуль в слот.",
			_window_node_target(window, window.module_slot)
		)

	return _hint("Ethernet-модуль уже установлен.", _world_target(dev))


func _hint_for_connection(objective: Dictionary) -> Dictionary:
	var from_device := _device(str(objective.get("from", "")))
	var to_device := _device(str(objective.get("to", "")))
	if from_device == null or to_device == null:
		return _hint("Устройства для этого шага не найдены.", {})

	var existing = NetworkSimulator.find_connection(from_device, to_device)
	if existing != null:
		if existing.has_method("is_connecting") and existing.is_connecting():
			return _hint(
				"Дождитесь установления беспроводного соединения.",
				_world_target(to_device)
			)
		return _hint(
			"Удалите неверный кабель: кликните по линии между %s и %s." % [
				from_device.device_name, to_device.device_name
			],
			{"kind": "connection", "connection": existing}
		)

	var cable_name := str(objective.get("cable", "straight"))
	var cable_type := _cable_type_from_name(cable_name)
	if cable_type < 0:
		cable_type = NetworkSimulator.CableType.STRAIGHT

	if cable_panel == null:
		return _hint("Панель кабелей недоступна.", {})

	if int(cable_panel.selected_cable) != cable_type:
		return _hint(
			"Выберите %s кабель на панели сверху." % NetworkSimulator.cable_type_label(cable_type),
			{"kind": "cable_button", "cable": cable_type}
		)

	if cable_panel.first_device == null:
		return _hint(
			"Кликните по %s, чтобы начать соединение." % from_device.device_name,
			_world_target(from_device)
		)
	if cable_panel.first_device == from_device:
		return _hint(
			"Теперь кликните по %s." % to_device.device_name,
			_world_target(to_device)
		)
	return _hint(
		"Начните соединение с %s: кликните по нему." % from_device.device_name,
		_world_target(from_device)
	)


func _hint_for_power(objective: Dictionary) -> Dictionary:
	var dev := _device(str(objective.get("device", "")))
	if dev == null:
		return _hint("Устройство для этого шага не найдено.", {})

	var window = _open_window(dev)
	var want_on := bool(objective.get("on", true))

	if dev.is_powered_on != want_on:
		if window == null:
			return _hint(
				"Кликните по %s, чтобы открыть окно, и нажмите кнопку питания." % dev.device_name,
				_world_target(dev)
			)
		return _hint(
			"Нажмите кнопку питания на изображении %s." % dev.device_name,
			_window_rect_target(window, window.get_power_hint_rect())
		)

	if want_on and dev.device_type == "Switch" and dev.is_booting:
		if window == null:
			return _hint(
				"Switch1 загружается. Подождите около 10 секунд.",
				_world_target(dev)
			)
		return _hint(
			"Switch1 загружается. Подождите около 10 секунд.",
			_window_node_target(window, window.device_image)
		)

	return _hint("Состояние питания уже верное.", _world_target(dev))


func _hint_for_ping(objective: Dictionary) -> Dictionary:
	var dev := _device(str(objective.get("from", "")))
	var target_address := str(objective.get("target", ""))
	if dev == null:
		return _hint("Устройство для ping не найдено.", {})

	if _ping_succeeded:
		var result: Dictionary = NetworkSimulator.ping_ipv4(dev, target_address)
		if not bool(result.get("ok", false)):
			var switch_device := _device("sw1")
			if switch_device == null:
				switch_device = dev
			return _hint(
				"Связь потеряна. Проверьте питание Switch1 и PC2, затем повторите ping.",
				_world_target(switch_device)
			)

	var window = _open_window(dev)
	if window == null:
		return _hint(
			"Кликните по %s, откройте Desktop и Command Prompt." % dev.device_name,
			_world_target(dev)
		)

	if not window.page_desktop.visible:
		return _hint("Перейдите на вкладку Desktop.", _window_node_target(window, window.tab_desktop))

	var command_prompt = window.desktop_page.get_app_content("command_prompt")
	if command_prompt == null:
		var tile = window.desktop_page.get_tile_control("command_prompt")
		if tile != null:
			return _hint(
				"Откройте Command Prompt двойным кликом по иконке.",
				_window_node_target(window, tile)
			)
		return _hint(
			"Откройте Command Prompt на рабочем столе.",
			_window_node_target(window, window.desktop_page)
		)

	var input = command_prompt.get_node_or_null(
		"TerminalPanel/TerminalMargin/TerminalVBox/PromptRow/Input"
	)
	if input is Control:
		return _hint(
			"Введите ping %s и нажмите Enter." % target_address,
			_window_node_target(window, input)
		)
	return _hint(
		"Введите ping %s в Command Prompt." % target_address,
		_window_node_target(window, command_prompt)
	)


func _hint(text: String, target: Dictionary) -> Dictionary:
	return {"text": text, "target": target}


func _world_target(device: Device) -> Dictionary:
	return {"kind": "world", "device": device}


func _window_node_target(window: DeviceWindow, node: Control) -> Dictionary:
	return {"kind": "window", "window": window, "node": node}


func _window_rect_target(window: DeviceWindow, rect: Rect2) -> Dictionary:
	return {"kind": "window_rect", "window": window, "rect": rect}


func _open_window(device: Device) -> DeviceWindow:
	if cable_panel == null:
		return null
	var window = cable_panel.current_device_window
	if window == null or not is_instance_valid(window):
		return null
	if not window is DeviceWindow:
		return null
	if window.device != device:
		return null
	return window


func show_hint_target(target: Dictionary) -> void:
	if task_panel == null or target.is_empty():
		return
	task_panel.hide_hint_arrow()
	hide_device_window_hint()

	match str(target.get("kind", "")):
		"world":
			var device = target.get("device")
			if device is Node2D and is_instance_valid(device):
				task_panel.show_world_hint(device)
		"cable_button":
			if cable_panel != null:
				var button = cable_panel.get_cable_button(int(target.get("cable", -1)))
				if button != null:
					task_panel.show_control_hint(button)
		"connection":
			var connection = target.get("connection")
			if connection != null and is_instance_valid(connection):
				var from_device = connection.from_device
				var to_device = connection.to_device
				if from_device != null and to_device != null:
					var point: Vector2 = (
						from_device.global_position + to_device.global_position
					) * 0.5
					task_panel.show_world_point(point)
		"window":
			var window = target.get("window")
			var node = target.get("node")
			if window != null and is_instance_valid(window) and node is Control:
				window.show_hint_node(node)
		"window_rect":
			var window = target.get("window")
			var rect: Rect2 = target.get("rect", Rect2())
			if window != null and is_instance_valid(window):
				window.show_hint_rect(rect)


func hide_device_window_hint() -> void:
	if cable_panel == null:
		return
	var window = cable_panel.current_device_window
	if window != null and is_instance_valid(window) and window.has_method("hide_hint"):
		window.hide_hint()
