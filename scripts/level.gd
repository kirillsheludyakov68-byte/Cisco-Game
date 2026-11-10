extends Node2D

signal level_completed(level_id: String, score: int, result: Dictionary)

const DEVICE_SCENE := preload("res://scenes/Device.tscn")
const CONNECTION_SCENE := preload("res://scenes/Connection.tscn")

@export_file("*.json") var level_path: String = "res://data/levels/level_1.json"

@onready var cable_panel = $CablePanel
@onready var task_panel: TaskPanel = $TaskPanel

var devices_by_id: Dictionary = {}
var level_title := "Задание"
var level_description := ""
var level_id := ""
var objectives: Array = []
var hints_available := -1

# Пинг считается выполненным только после реальной команды в Command Prompt.
# Ключ — "id_источника|цель", цель может быть IPv4-адресом или именем.
var _ping_results: Dictionary = {}

var _level_started_msec := 0
var _completion_recorded := false
var _score_config: Dictionary = {}


func _ready() -> void:
	_level_started_msec = Time.get_ticks_msec()
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
	var raw_level_id = data.get("id", "")
	if raw_level_id is float and raw_level_id == floor(raw_level_id):
		level_id = str(int(raw_level_id))
	else:
		level_id = str(raw_level_id)
	hints_available = int(data.get("hints", -1))
	var score_data = data.get("score", {})
	if score_data is Dictionary:
		_score_config = score_data
	var raw_objectives = data.get("objectives", [])
	if raw_objectives is Array:
		objectives = (raw_objectives as Array).duplicate(true)

	for dev_data in data.get("devices", []):
		_spawn_device(dev_data)

	# Предустановленные модули: { "pc1": ["PT-HOST-NM-1CE"] }.
	# Для коммутатора и хаба массив заполняет слоты по порядку.
	var presets = data.get("module_presets", {})
	if presets is Dictionary:
		_apply_module_presets(presets)

	# Сеть применяем после модулей: интерфейсы уже должны существовать.
	_apply_network_configs(data.get("devices", []))

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
			if ResourceLoader.exists("res://assets/fix levl2/Router.svg"):
				device.texture_router = load("res://assets/fix levl2/Router.svg")
		"AccessPoint":
			if ResourceLoader.exists("res://assets/fix levl2/AccessPoint.svg"):
				device.texture_ap = load("res://assets/fix levl2/AccessPoint.svg")
		"Hub":
			# Hub.png обрезан по краям рисунка, поэтому кабели сходятся
			# точно в визуальном центре корпуса.
			device.texture_hub = load("res://assets/devices/Hub.png")
		"Server":
			device.texture_server_on = load("res://assets/fix levl2/Server.svg")
			device.texture_server_off = load("res://assets/devices/Server_off.png")
		"Printer":
			device.texture_printer_on = load("res://assets/fix levl2/Printer.svg")
			device.texture_printer_off = load("res://assets/devices/Printer_off.png")
		"Laptop":
			device.texture_laptop_on = load("res://assets/fix levl2/Laptop.svg")
			device.texture_laptop_off = load("res://assets/devices/Laptop_off.png")
		"Tablet":
			device.texture_tablet_on = load("res://assets/fix levl2/Tablet PC-PT.svg")
			device.texture_tablet_off = load("res://assets/devices/Tablet_off.png")


func _apply_module_presets(presets: Dictionary) -> void:
	for device_id in presets:
		if not devices_by_id.has(device_id):
			push_warning("module_presets: устройство не найдено: " + str(device_id))
			continue

		var dev: Device = devices_by_id[device_id]
		var value = presets[device_id]

		if ModuleCatalog.is_slot_device(dev.device_type):
			_apply_slot_module_preset(dev, device_id, value)
			continue

		var module_name := ""
		if value is String:
			module_name = value
		elif value is Array and value.size() > 0:
			module_name = str(value[0])
			if value.size() > 1:
				push_warning("module_presets: у ПК только один слот, беру первый модуль для " + str(device_id))

		if module_name == "":
			continue

		dev.set_initial_module(module_name)


func _apply_slot_module_preset(dev: Device, device_id: String, value) -> void:
	if value is Dictionary:
		for slot_value in value:
			dev.set_initial_switch_module(str(value[slot_value]), int(slot_value))
		return

	if value is String:
		dev.set_initial_switch_module(value, 0)
		return

	if not (value is Array):
		push_warning("module_presets: некорректный список модулей для " + str(device_id))
		return

	for slot_index in range(value.size()):
		dev.set_initial_switch_module(str(value[slot_index]), slot_index)


func _apply_network_configs(device_data: Array) -> void:
	for raw_data in device_data:
		if not raw_data is Dictionary:
			continue
		var data: Dictionary = raw_data
		var dev := _device(str(data.get("id", "")))
		if dev == null:
			continue
		var network_interface := dev.get_primary_interface()
		if network_interface == null:
			continue

		var ip_mode := str(data.get("ip_mode", ""))
		if ip_mode == "dhcp":
			dev.set_interface_ipv4_mode(network_interface.interface_name, NetworkSettings.IPV4_DHCP)
			dev.set_ipv4_mode(NetworkSettings.IPV4_DHCP)
			network_interface.ipv4_address = ""
		elif ip_mode == "static" or data.has("ip"):
			dev.set_interface_ipv4_mode(network_interface.interface_name, NetworkSettings.IPV4_STATIC)
			dev.set_ipv4_mode(NetworkSettings.IPV4_STATIC)
			var ip := str(data.get("ip", ""))
			var mask := str(data.get("mask", "255.255.255.0"))
			if not ip.is_empty():
				dev.set_interface_ipv4_config(network_interface.interface_name, ip, mask)

		var gateway := str(data.get("gateway", ""))
		var dns := str(data.get("dns", ""))
		if not gateway.is_empty() or not dns.is_empty():
			dev.set_ipv4_gateway_dns(gateway, dns)


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
	var source_id := _device_id(source)
	if source_id.is_empty():
		return
	_ping_results[_ping_key(source_id, str(target_address))] = bool(ok)
	_refresh_objectives()


# --- Проверка шагов ---

func _refresh_objectives() -> void:
	if task_panel == null:
		return
	NetworkSimulator.refresh_dhcp_leases()
	var states: Array[bool] = []
	for objective in objectives:
		states.append(evaluate_objective(objective))
	task_panel.set_states(states)

	var all_done := not states.is_empty()
	for state in states:
		if not state:
			all_done = false
			break

	if all_done and not _completion_recorded:
		_completion_recorded = true
		_finish_level()


func _finish_level() -> void:
	var elapsed := float(Time.get_ticks_msec() - _level_started_msec) / 1000.0
	var hints_used := 0
	if task_panel != null and task_panel.has_method("get_hints_used"):
		hints_used = task_panel.get_hints_used()

	var score := _calculate_score(elapsed, hints_used)
	var result := ProgressManager.record_completion(
		level_id,
		score,
		{"time": elapsed, "hints_used": hints_used}
	)

	if task_panel != null and task_panel.has_method("show_score_result"):
		task_panel.show_score_result(score, result)
	level_completed.emit(level_id, score, result)


func _calculate_score(elapsed: float, hints_used: int) -> int:
	var base := int(_score_config.get("base", 100))
	var par_time := float(_score_config.get("par_time", 120.0))
	var max_time_bonus := int(_score_config.get("time_bonus", 50))
	var hint_penalty := int(_score_config.get("hint_penalty", 10))
	var min_score := int(_score_config.get("min", 25))

	var time_bonus := 0
	if par_time > 0.0:
		var ratio := clampf((par_time - elapsed) / par_time, 0.0, 1.0)
		time_bonus = int(round(ratio * float(max_time_bonus)))

	return maxi(min_score, base + time_bonus - hints_used * hint_penalty)


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
			var cable_name := str(objective.get("cable", "straight"))
			if not _connection_matches_cable(connection, cable_name):
				return false
			var required_kind := str(objective.get("interface_kind", "ethernet"))
			if not required_kind.is_empty():
				if not from_device.has_enabled_interface_kind(required_kind):
					return false
				if not to_device.has_enabled_interface_kind(required_kind):
					return false
			if cable_name == "wireless":
				if not NetworkSimulator.is_wireless_link_secure(from_device, to_device):
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

		"static_ip":
			var static_device := _device(str(objective.get("device", "")))
			if static_device == null:
				return false
			var interface_name := str(objective.get("interface", ""))
			var network_interface := (
				static_device.get_interface(interface_name)
				if not interface_name.is_empty()
				else static_device.get_primary_interface()
			)
			if network_interface == null:
				return false
			if network_interface.ipv4_mode != NetworkSettings.IPV4_STATIC:
				return false
			var required_ip := str(objective.get("ip", ""))
			var required_mask := str(objective.get("mask", "255.255.255.0"))
			return (
				network_interface.ipv4_address == required_ip
				and network_interface.subnet_mask == required_mask
			)

		"dns_record":
			var dns_device := _device(str(objective.get("device", "")))
			if dns_device == null or not dns_device.dns_service_enabled:
				return false
			var record_name := str(objective.get("name", "")).to_lower()
			var record_address := str(objective.get("address", ""))
			return str(dns_device.dns_records.get(record_name, "")) == record_address

		"dhcp_config":
			var dhcp_device := _device(str(objective.get("device", "")))
			if dhcp_device == null or not dhcp_device.dhcp_service_enabled:
				return false
			var required_start := str(objective.get("start_ip", dhcp_device.dhcp_start_ip))
			var required_mask := str(
				objective.get("mask", objective.get("subnet_mask", dhcp_device.dhcp_subnet_mask))
			)
			var required_gateway := str(objective.get("gateway", dhcp_device.dhcp_gateway))
			var required_dns := str(objective.get("dns", dhcp_device.dhcp_dns))
			if dhcp_device.dhcp_start_ip != required_start:
				return false
			if dhcp_device.dhcp_subnet_mask != required_mask:
				return false
			if dhcp_device.dhcp_gateway != required_gateway:
				return false
			if dhcp_device.dhcp_dns != required_dns:
				return false
			var required_users := int(objective.get("users", -1))
			if required_users >= 0 and dhcp_device.dhcp_max_users != required_users:
				return false
			return true

		"dhcp_lease":
			var lease_devices = objective.get("devices", [])
			if not lease_devices is Array or (lease_devices as Array).is_empty():
				return false
			for device_id in lease_devices:
				var lease_device := _device(str(device_id))
				if lease_device == null or not lease_device.is_operational():
					return false
				var lease_interface := lease_device.get_primary_interface()
				if lease_interface == null:
					return false
				if lease_interface.ipv4_mode != NetworkSettings.IPV4_DHCP:
					return false
				if not NetworkValidation.is_valid_ipv4(lease_interface.ipv4_address):
					return false
			return true

		"ping":
			var ping_source := _device(str(objective.get("from", "")))
			var target_address := str(objective.get("target", ""))
			if ping_source == null or target_address.is_empty():
				return false
			var key := _ping_key(_device_id(ping_source), target_address)
			if not bool(_ping_results.get(key, false)):
				return false
			var result: Dictionary = NetworkSimulator.ping_host(ping_source, target_address)
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


func _device_id(device: Device) -> String:
	if device == null:
		return ""
	for device_id in devices_by_id:
		if devices_by_id[device_id] == device:
			return str(device_id)
	return ""


func _ping_key(source_id: String, target: String) -> String:
	return "%s|%s" % [source_id, target.strip_edges()]


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
		"static_ip":
			return _hint_for_static_ip(objective)
		"dns_record":
			return _hint_for_dns_record(objective)
		"dhcp_config":
			return _hint_for_dhcp_config(objective)
		"dhcp_lease":
			return _hint_for_dhcp_lease(objective)
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

	var cable_name := str(objective.get("cable", "straight"))
	if cable_name == "wireless" \
			and not NetworkSimulator.is_wireless_link_secure(from_device, to_device):
		return _hint_for_wireless_security(objective, from_device, to_device)

	var existing = NetworkSimulator.find_connection(from_device, to_device)
	if existing != null:
		if existing.has_method("is_connecting") and existing.is_connecting():
			return _hint(
				"Дождитесь установления беспроводного соединения.",
				_world_target(to_device)
			)
		if not _connection_matches_cable(existing, cable_name):
			return _hint(
				"Удалите неверный кабель: кликните по линии между %s и %s." % [
					from_device.device_name, to_device.device_name
				],
				{"kind": "connection", "connection": existing}
			)
		if cable_name == "wireless" \
				and not NetworkSimulator.is_wireless_link_secure(from_device, to_device):
			return _hint_for_wireless_security(objective, from_device, to_device)
		return _hint(
			"Соединение уже установлено. Проверьте, что оба устройства включены.",
			_world_target(to_device)
		)

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


func _hint_for_wireless_security(
	_objective: Dictionary,
	from_device: Device,
	to_device: Device
) -> Dictionary:
	var ap: Device = from_device if from_device.device_type == "AccessPoint" else to_device
	if ap == null or ap.device_type != "AccessPoint":
		return _hint("Для беспроводного соединения нужна точка доступа.", {})
	var client: Device = to_device if ap == from_device else from_device
	if not ap.is_powered_on:
		return _hint("Включите точку доступа %s." % ap.device_name, _world_target(ap))

	var fix_device := _wireless_device_to_fix(ap, client)
	var window = _open_window(fix_device)
	if window == null:
		return _hint(
			"Кликните по %s, чтобы открыть окно устройства." % fix_device.device_name,
			_world_target(fix_device)
		)
	if not fix_device.is_powered_on:
		return _hint(
			"Включите %s." % fix_device.device_name,
			_window_rect_target(window, window.get_power_hint_rect())
		)
	if not window.page_config.visible:
		return _hint(
			"Перейдите на вкладку Config.",
			_window_node_target(window, window.tab_config)
		)

	var wireless_interface := fix_device.get_wireless_interface(false)
	var interface_name := (
		wireless_interface.interface_name if wireless_interface != null else "Wireless0"
	)
	window.show_config_interface(interface_name)
	var page = window.config_panel.get_interface_page()
	return _hint(
		"Настройте SSID, WPA2-PSK и AES на %s. SSID и пароль должны совпадать у точки доступа и клиента." % fix_device.device_name,
		_window_node_target(window, page if page != null else window.config_panel)
	)


func _wireless_device_to_fix(ap: Device, client: Device) -> Device:
	var ap_interface := ap.get_wireless_interface(false)
	if ap_interface == null:
		return ap
	var wireless := ap_interface.wireless
	if wireless.ssid.strip_edges().is_empty() \
			or wireless.authentication_mode != WirelessSettings.AUTH_WPA2_PSK \
			or wireless.encryption_type != WirelessSettings.ENCRYPTION_AES \
			or wireless.psk_passphrase.is_empty():
		return ap
	return client


func _hint_for_static_ip(objective: Dictionary) -> Dictionary:
	var dev := _device(str(objective.get("device", "")))
	if dev == null:
		return _hint("Устройство для этого шага не найдено.", {})
	var interface_name := str(objective.get("interface", ""))
	var network_interface := (
		dev.get_interface(interface_name) if not interface_name.is_empty() else dev.get_primary_interface()
	)
	if network_interface == null:
		return _hint("У устройства нет подходящего интерфейса.", _world_target(dev))

	var window = _open_window(dev)
	if window == null:
		return _hint(
			"Кликните по %s, чтобы открыть окно устройства." % dev.device_name,
			_world_target(dev)
		)
	if not dev.is_powered_on:
		return _hint(
			"Включите %s." % dev.device_name,
			_window_rect_target(window, window.get_power_hint_rect())
		)
	if not window.page_config.visible:
		return _hint("Перейдите на вкладку Config.", _window_node_target(window, window.tab_config))

	window.show_config_interface(network_interface.interface_name)
	var page = window.config_panel.get_interface_page()
	return _hint(
		"Укажите статический IPv4-адрес %s и маску %s." % [
			str(objective.get("ip", "")), str(objective.get("mask", "255.255.255.0"))
		],
		_window_node_target(window, page if page != null else window.config_panel)
	)


func _hint_for_dns_record(objective: Dictionary) -> Dictionary:
	var dev := _device(str(objective.get("device", "")))
	if dev == null:
		return _hint("Сервер для этого шага не найден.", {})
	var window = _open_window(dev)
	if window == null:
		return _hint(
			"Кликните по %s, чтобы открыть окно сервера." % dev.device_name,
			_world_target(dev)
		)
	if not dev.is_powered_on:
		return _hint(
			"Включите %s." % dev.device_name,
			_window_rect_target(window, window.get_power_hint_rect())
		)
	if not window.page_services.visible:
		return _hint(
			"Перейдите на вкладку Services.",
			_window_node_target(window, window.tab_services)
		)
	var target_node: Control = (
		window.services_page.dns_name_edit if window.services_page != null else window.services_page
	)
	return _hint(
		"Включите DNS и добавьте запись %s → %s." % [
			str(objective.get("name", "")), str(objective.get("address", ""))
		],
		_window_node_target(window, target_node)
	)


func _hint_for_dhcp_config(objective: Dictionary) -> Dictionary:
	var dev := _device(str(objective.get("device", "")))
	if dev == null:
		return _hint("Сервер для этого шага не найден.", {})
	var window = _open_window(dev)
	if window == null:
		return _hint(
			"Кликните по %s, чтобы открыть окно сервера." % dev.device_name,
			_world_target(dev)
		)
	if not dev.is_powered_on:
		return _hint(
			"Включите %s." % dev.device_name,
			_window_rect_target(window, window.get_power_hint_rect())
		)
	if not window.page_services.visible:
		return _hint(
			"Перейдите на вкладку Services.",
			_window_node_target(window, window.tab_services)
		)
	var target_node: Control = (
		window.services_page.dhcp_start_edit if window.services_page != null else window.services_page
	)
	return _hint(
		"Включите DHCP: Start IP %s, маска %s, шлюз %s, DNS %s, Maximum Users %s." % [
			str(objective.get("start_ip", "")),
			str(objective.get("mask", "255.255.255.0")),
			str(objective.get("gateway", "")),
			str(objective.get("dns", "")),
			str(objective.get("users", "")),
		],
		_window_node_target(window, target_node)
	)


func _hint_for_dhcp_lease(objective: Dictionary) -> Dictionary:
	var lease_devices = objective.get("devices", [])
	var first_failed: Device = null
	if lease_devices is Array:
		for device_id in lease_devices:
			var candidate := _device(str(device_id))
			if candidate == null:
				continue
			var candidate_interface := candidate.get_primary_interface()
			if not candidate.is_operational() \
					or candidate_interface == null \
					or candidate_interface.ipv4_mode != NetworkSettings.IPV4_DHCP \
					or not NetworkValidation.is_valid_ipv4(candidate_interface.ipv4_address):
				first_failed = candidate
				break
	if first_failed == null:
		return _hint("Все клиенты уже получили адреса по DHCP.", {})

	var server := _find_configured_dhcp_server()
	if server == null or server.get_dhcp_pool().is_empty():
		if server == null:
			for candidate in devices_by_id.values():
				if candidate is Device and candidate.device_type == "Server":
					server = candidate
					break
		if server != null:
			var server_window = _open_window(server)
			if server_window == null:
				return _hint(
					"Кликните по %s, чтобы открыть окно сервера." % server.device_name,
					_world_target(server)
				)
			if not server_window.page_services.visible:
				return _hint(
					"Перейдите на вкладку Services.",
					_window_node_target(server_window, server_window.tab_services)
				)
			var server_target: Control = (
				server_window.services_page.dhcp_start_edit
				if server_window.services_page != null
				else server_window.services_page
			)
			return _hint(
				"Включите DHCP и настройте пул адресов.",
				_window_node_target(server_window, server_target)
			)

	var window = _open_window(first_failed)
	if window == null:
		return _hint(
			"Кликните по %s, чтобы открыть окно устройства." % first_failed.device_name,
			_world_target(first_failed)
		)
	if not first_failed.is_powered_on:
		return _hint(
			"Включите %s." % first_failed.device_name,
			_window_rect_target(window, window.get_power_hint_rect())
		)
	if not window.page_config.visible:
		return _hint("Перейдите на вкладку Config.", _window_node_target(window, window.tab_config))

	var failed_interface := first_failed.get_primary_interface()
	if failed_interface != null:
		window.show_config_interface(failed_interface.interface_name)
	var page = window.config_panel.get_interface_page()
	return _hint(
		"Проверьте, что интерфейс в режиме DHCP и что есть рабочий путь до DHCP-сервера.",
		_window_node_target(window, page if page != null else window.config_panel)
	)


func _find_configured_dhcp_server() -> Device:
	for candidate in devices_by_id.values():
		if candidate is Device \
				and candidate.device_type == "Server" \
				and candidate.dhcp_service_enabled \
				and candidate.is_operational():
			return candidate
	return null


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
		# Во время загрузки подсказка только текстовая: стрелка и
		# кольцо здесь отвлекают и не помогают игроку.
		return _hint(
			"%s загружается. Подождите около 10 секунд." % dev.device_name,
			{}
		)

	return _hint("Состояние питания уже верное.", _world_target(dev))


func _hint_for_ping(objective: Dictionary) -> Dictionary:
	var dev := _device(str(objective.get("from", "")))
	var target_address := str(objective.get("target", ""))
	if dev == null:
		return _hint("Устройство для ping не найдено.", {})

	var key := _ping_key(_device_id(dev), target_address)
	var attempted := _ping_results.has(key)
	if attempted and not bool(_ping_results.get(key, false)):
		if not NetworkValidation.is_valid_ipv4(target_address):
			var resolved := NetworkSimulator.resolve_hostname(dev, target_address)
			if not bool(resolved.get("ok", false)):
				return _hint_for_dns_failure(dev, target_address)
		return _hint(
			"Пакет не прошёл. Проверьте питание, кабели и адреса, затем повторите ping %s." % target_address,
			_world_target(dev)
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


func _hint_for_dns_failure(dev: Device, target: String) -> Dictionary:
	var server := _find_configured_dns_server()
	if server == null:
		for candidate in devices_by_id.values():
			if candidate is Device and candidate.device_type == "Server":
				server = candidate
				break
	if server == null:
		return _hint(
			"Настройте DNS-сервер, DNS-записи и DNS-сервер в DHCP, затем повторите ping %s." % target,
			_world_target(dev)
		)

	var window = _open_window(server)
	if window == null:
		return _hint(
			"Кликните по %s, чтобы открыть окно сервера." % server.device_name,
			_world_target(server)
		)
	if not server.is_powered_on:
		return _hint(
			"Включите %s." % server.device_name,
			_window_rect_target(window, window.get_power_hint_rect())
		)
	if not window.page_services.visible:
		return _hint(
			"Перейдите на вкладку Services.",
			_window_node_target(window, window.tab_services)
		)
	var target_node: Control = (
		window.services_page.dns_name_edit if window.services_page != null else window.services_page
	)
	return _hint(
		"Проверьте службу DNS, запись %s и DNS-сервер, выдаваемый DHCP." % target,
		_window_node_target(window, target_node)
	)


func _find_configured_dns_server() -> Device:
	for candidate in devices_by_id.values():
		if candidate is Device \
				and candidate.device_type == "Server" \
				and candidate.dns_service_enabled \
				and candidate.is_operational():
			return candidate
	return null


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
	if task_panel == null:
		return
	task_panel.hide_hint_arrow()
	hide_device_window_hint()
	if target.is_empty():
		return

	match str(target.get("kind", "")):
		"world":
			var device = target.get("device")
			if device is Node2D and is_instance_valid(device):
				_focus_main_window()
				task_panel.show_world_hint(device)
		"cable_button":
			if cable_panel != null:
				var button = cable_panel.get_cable_button(int(target.get("cable", -1)))
				if button != null:
					_focus_main_window()
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
					_focus_main_window()
					task_panel.show_world_point(point)
		"window":
			var window = target.get("window")
			var node = target.get("node")
			if window != null and is_instance_valid(window) and node is Control:
				_focus_hint_window(window)
				window.show_hint_node(node)
		"window_rect":
			var window = target.get("window")
			var rect: Rect2 = target.get("rect", Rect2())
			if window != null and is_instance_valid(window):
				_focus_hint_window(window)
				window.show_hint_rect(rect)


func _focus_main_window() -> void:
	var main_window := get_window()
	if main_window != null and is_instance_valid(main_window):
		main_window.grab_focus()


# Окно с подсказкой должно оказаться поверх остальных окон устройства.
func _focus_hint_window(window: Window) -> void:
	if window == null or not is_instance_valid(window):
		return
	# grab_focus() одновременно поднимает окно поверх остальных.
	window.grab_focus()


func hide_device_window_hint() -> void:
	if cable_panel == null:
		return
	var window = cable_panel.current_device_window
	if window != null and is_instance_valid(window) and window.has_method("hide_hint"):
		window.hide_hint()
