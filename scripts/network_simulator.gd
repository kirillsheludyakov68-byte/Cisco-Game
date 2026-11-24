extends Node

# Типы кабелей
enum CableType {
	STRAIGHT,   # прямой (PC↔Switch, Switch↔Router)
	CROSSOVER,  # кроссовер (PC↔PC, Switch↔Switch, Router↔Router)
	WIRELESS,   # беспроводной (к Wi-Fi точке)
	FIBER       # оптоволокно
}

# Таблица совместимости: тип устройства + тип устройства -> допустимые кабели.
# Ключ пары строится по алфавиту, поэтому порядок кликов не важен.
# Значения: straight, crossover, wireless, fiber.
const CABLE_RULES := {
	"PC|PC": {
		"straight": false,
		"crossover": true,
		"wireless": false,
		"fiber": false,
	},
	"PC|Switch": {
		"straight": true,
		"crossover": false,
		"wireless": false,
		"fiber": false,
	},
	"PC|Router": {
		"straight": false,
		"crossover": true,
		"wireless": false,
		"fiber": false,
	},
	"Switch|Switch": {
		"straight": false,
		"crossover": true,
		"wireless": false,
		"fiber": false,
	},
	"Router|Switch": {
		"straight": true,
		"crossover": false,
		"wireless": false,
		"fiber": true,
	},
	"Router|Router": {
		"straight": false,
		"crossover": true,
		"wireless": false,
		"fiber": false,
	},
	"AccessPoint|PC": {
		"straight": false,
		"crossover": false,
		"wireless": true,
		"fiber": false,
	},
	"AccessPoint|Switch": {
		"straight": true,
		"crossover": false,
		"wireless": false,
		"fiber": false,
	},
	"AccessPoint|Router": {
		"straight": true,
		"crossover": false,
		"wireless": false,
		"fiber": false,
	},
	"AccessPoint|AccessPoint": {
		"straight": false,
		"crossover": true,
		"wireless": false,
		"fiber": false,
	},
}

# Список всех устройств уровня
var devices: Array = []

# Список всех связей уровня
var connections: Array = []

# Сигналы
signal devices_changed
signal connections_changed
signal connection_activated(connection)
# Испускается только Command Prompt после команды ping.
# Уровень использует его для галочки в задании; служебные проверки пути
# вызывают ping_ipv4() напрямую и сигнал не создают.
signal ping_checked(source, target_address, ok)

# Command Prompt сообщает уровню о реальной команде ping через этот метод.
# Сигнал остаётся публичным для других слушателей.
func notify_ping_checked(source, target_address: String, ok: bool) -> void:
	ping_checked.emit(source, target_address, ok)

func register_device(device) -> void:
	if device not in devices:
		devices.append(device)
		devices_changed.emit()

func unregister_device(device) -> void:
	devices.erase(device)
	devices_changed.emit()

func add_connection(connection) -> void:
	if connection not in connections:
		connections.append(connection)
		if connection.has_signal("connection_activated"):
			connection.connection_activated.connect(_on_connection_activated.bind(connection))
		connections_changed.emit()

func _on_connection_activated(connection) -> void:
	connection_activated.emit(connection)

func remove_connection(connection) -> void:
	connections.erase(connection)
	connections_changed.emit()

# Очистить всё (при загрузке нового уровня)
func clear() -> void:
	devices.clear()
	connections.clear()
	devices_changed.emit()
	connections_changed.emit()

# Найти связь между двумя устройствами (если есть)
func find_connection(a, b):
	for c in connections:
		if not is_instance_valid(c):
			continue
		if (c.from_device == a and c.to_device == b) or \
		   (c.from_device == b and c.to_device == a):
			return c
	return null

# Найти уже активную связь (беспроводная связь появляется не сразу)
func find_active_connection(a, b):
	var c = find_connection(a, b)
	if c == null:
		return null
	if c.has_method("is_active") and not c.is_active():
		return null
	return c

func cable_type_name(cable_type: int) -> String:
	match cable_type:
		CableType.STRAIGHT:
			return "straight"
		CableType.CROSSOVER:
			return "crossover"
		CableType.WIRELESS:
			return "wireless"
		CableType.FIBER:
			return "fiber"
	return ""


func cable_type_label(cable_type: int) -> String:
	match cable_type:
		CableType.STRAIGHT:
			return "прямой"
		CableType.CROSSOVER:
			return "кроссовер"
		CableType.WIRELESS:
			return "беспроводной"
		CableType.FIBER:
			return "оптоволоконный"
	return "неизвестный"


func cable_type_instrumental(cable_type: int) -> String:
	match cable_type:
		CableType.STRAIGHT:
			return "прямым"
		CableType.CROSSOVER:
			return "кроссоверным"
		CableType.WIRELESS:
			return "беспроводным"
		CableType.FIBER:
			return "оптоволоконным"
	return "неизвестным"


func _pair_key(a, b) -> String:
	var types: Array[String] = [str(a.device_type), str(b.device_type)]
	types.sort()
	return "%s|%s" % [types[0], types[1]]


# Проверить: можно ли соединить эти два устройства выбранным кабелем?
# Возвращает Dictionary: {ok: bool, reason: String}.
# Проверка двухуровневая:
# 1) таблица типов устройств;
# 2) наличие подходящего физического интерфейса у обоих устройств.
func can_connect(a, b, cable_type: int = CableType.STRAIGHT) -> Dictionary:
	if a == null or b == null or not is_instance_valid(a) or not is_instance_valid(b):
		return {"ok": false, "reason": "Устройство недоступно"}
	if a == b:
		return {"ok": false, "reason": "Нельзя соединить устройство с самим собой"}
	var existing = find_connection(a, b)
	if existing != null:
		if existing.has_method("is_connecting") and existing.is_connecting():
			return {"ok": false, "reason": "Соединение уже устанавливается"}
		return {"ok": false, "reason": "Уже соединены"}

	var cable_name := cable_type_name(cable_type)
	if cable_name.is_empty():
		return {"ok": false, "reason": "Неизвестный тип кабеля"}

	var pair_rules: Dictionary = CABLE_RULES.get(_pair_key(a, b), {})
	if pair_rules.is_empty():
		return {
			"ok": false,
			"reason": "Неверный кабель: для пары %s ↔ %s нет подходящего правила." % [
				a.device_name, b.device_name
			],
		}
	if not bool(pair_rules.get(cable_name, false)):
		return {
			"ok": false,
			"reason": "Неверный кабель: %s ↔ %s нельзя соединять %s кабелем." % [
				a.device_name, b.device_name, cable_type_instrumental(cable_type)
			],
		}

	var interface_error := _validate_cable_interfaces(a, b, cable_type)
	if not interface_error.is_empty():
		return {"ok": false, "reason": interface_error}
	return {"ok": true, "reason": ""}


func _validate_cable_interfaces(a, b, cable_type: int) -> String:
	match cable_type:
		CableType.STRAIGHT, CableType.CROSSOVER:
			if not _has_enabled_interface_kind(a, "ethernet"):
				return "Неверный кабель: у %s нет Ethernet-порта. Установите Ethernet-модуль." % a.device_name
			if not _has_enabled_interface_kind(b, "ethernet"):
				return "Неверный кабель: у %s нет Ethernet-порта. Установите Ethernet-модуль." % b.device_name
		CableType.FIBER:
			if not _has_enabled_interface_kind(a, "fiber"):
				return "Неверный кабель: у %s нет Fiber-порта." % a.device_name
			if not _has_enabled_interface_kind(b, "fiber"):
				return "Неверный кабель: у %s нет Fiber-порта." % b.device_name
		CableType.WIRELESS:
			if not _is_wireless_capable(a):
				return "Неверный кабель: у %s нет беспроводного интерфейса." % a.device_name
			if not _is_wireless_capable(b):
				return "Неверный кабель: у %s нет беспроводного интерфейса." % b.device_name
	return ""


func _has_enabled_interface_kind(device, kind: String) -> bool:
	if device == null or not is_instance_valid(device):
		return false
	if device.has_method("has_enabled_interface_kind"):
		return device.has_enabled_interface_kind(kind)
	return false


func _is_wireless_capable(device) -> bool:
	if device == null or not is_instance_valid(device):
		return false
	if str(device.device_type) == "AccessPoint":
		return true
	return _has_enabled_interface_kind(device, "wireless")


func _is_operational(device) -> bool:
	if device == null or not is_instance_valid(device):
		return false
	if device.has_method("is_operational"):
		return device.is_operational()
	return bool(device.is_powered_on)


# Рассчитать маршрут ping для Command Prompt и анимации пакета.
# Возвращает { success, path, error_msg, ... }. В path лежат устройства
# от источника до цели. При ошибке path обрезается до проблемного
# устройства, чтобы пакет мог долететь именно до него и взорваться.
func calculate_ping_route(source: Device, target_address: String) -> Dictionary:
	var path: Array = []
	if source == null or not is_instance_valid(source):
		return _route_result(false, path, "Устройство недоступно.")
	path = [source]

	if not NetworkValidation.is_valid_ipv4(target_address):
		return _route_result(false, path, "Некорректный IPv4-адрес.")
	if not _is_operational(source):
		return _route_result(false, path, "Устройство выключено или ещё загружается.")

	var source_interface := _find_source_ipv4_interface(source)
	if source_interface == null:
		return _route_result(false, path, "У текущего устройства нет включённого IPv4-интерфейса.")
	if not NetworkValidation.is_valid_ipv4(source_interface.ipv4_address):
		return _route_result(false, path, "У исходного интерфейса некорректный IPv4-адрес.")
	if not NetworkValidation.is_valid_subnet_mask(source_interface.subnet_mask):
		return _route_result(false, path, "У исходного интерфейса не задана корректная маска подсети.")

	var target_info := _find_target_interface(target_address)
	if target_info.is_empty():
		return _route_result(false, path, "Хост с таким IPv4-адресом не найден.")

	var target_device: Device = target_info.get("device") as Device
	var target_interface: DeviceInterface = target_info.get("interface") as DeviceInterface
	var extra := {
		"source_interface": source_interface,
		"target_device": target_device,
		"target_interface": target_interface,
	}
	if target_device == source:
		return _route_result(
			false,
			path,
			"Адрес принадлежит самому устройству; проверка loopback не реализована.",
			extra
		)

	var physical_path := _find_route_path(source, target_device, false)
	if physical_path.is_empty():
		return _route_result(
			false,
			path,
			"Нет пути между устройствами в текущей топологии.",
			extra
		)

	if not _is_operational(target_device):
		return _route_result(false, physical_path, _device_operational_error(target_device), extra)
	if target_interface == null or not target_interface.enabled:
		return _route_result(
			false,
			physical_path,
			"Интерфейс %s на %s выключен." % [
				target_interface.interface_name if target_interface != null else "IPv4",
				target_device.device_name,
			],
			extra
		)

	var mask := NetworkValidation.ipv4_to_int(source_interface.subnet_mask)
	if mask == 0 and source_interface.subnet_mask.is_empty():
		return _route_result(false, physical_path, "У исходного интерфейса не задана маска подсети.", extra)
	var source_ip := NetworkValidation.ipv4_to_int(source_interface.ipv4_address)
	var target_ip := NetworkValidation.ipv4_to_int(target_address)
	if (source_ip & mask) != (target_ip & mask):
		return _route_result(false, physical_path, "Адрес назначения находится в другой подсети.", extra)

	# Сначала ищем полностью рабочий путь. Если он есть, не нужно
	# останавливаться на выключенном устройстве в альтернативной ветке.
	var valid_path := _find_route_path(source, target_device, true)
	if not valid_path.is_empty():
		return _route_result(true, valid_path, "", extra)

	# Рабочего пути нет: ищем физический путь и сообщаем о первой проблеме.
	var validation := _validate_route_path(physical_path)
	if not bool(validation.get("ok", false)):
		var error_index := int(validation.get("index", 0))
		var error_path := physical_path.slice(0, error_index + 1)
		var error_extra := extra.duplicate()
		if not error_path.is_empty():
			error_extra["error_device"] = error_path.back()
		return _route_result(
			false,
			error_path,
			str(validation.get("message", "Маршрут недоступен.")),
			error_extra
		)

	return _route_result(false, physical_path, "Не удалось построить рабочий маршрут.", extra)


# Ограниченная проверка IPv4-доступности для Command Prompt.
# Это не ICMP: успех означает, что адрес принадлежит включённому интерфейсу,
# между устройствами есть путь по текущей топологии и адреса входят в одну
# подсеть. Маршрутизация и ARP в симуляторе пока не реализованы.
func ping_ipv4(source: Device, target_address: String) -> Dictionary:
	var route := calculate_ping_route(source, target_address)
	return {
		"ok": bool(route.get("success", false)),
		"reason": str(route.get("error_msg", "")),
		"source_interface": route.get("source_interface"),
		"target_device": route.get("target_device"),
		"target_interface": route.get("target_interface"),
		"path": route.get("path", []),
		"error_device": route.get("error_device"),
	}


func _find_target_interface(target_address: String) -> Dictionary:
	var fallback: Dictionary = {}
	for candidate in devices:
		if candidate == null or not is_instance_valid(candidate):
			continue
		if not candidate.has_method("get_interface_names"):
			continue
		for interface_name in candidate.get_interface_names():
			var candidate_interface: DeviceInterface = candidate.get_interface(interface_name)
			if candidate_interface == null or candidate_interface.ipv4_address != target_address:
				continue
			var entry := {"device": candidate, "interface": candidate_interface}
			# Включённый интерфейс рабочего устройства важнее выключенного:
			# так мы находим реальную цель, даже если тот же адрес сохранён
			# на другом, уже отключённом интерфейсе.
			if candidate_interface.enabled and _is_operational(candidate):
				return entry
			if fallback.is_empty():
				fallback = entry
	return fallback


# BFS по топологии. only_valid=true учитывает питание, активность кабеля,
# совместимость кабеля и наличие нужных интерфейсов. only_valid=false нужен,
# чтобы найти физический путь и показать, где именно он ломается.
func _find_route_path(start: Device, goal: Device, only_valid: bool) -> Array:
	if start == null or goal == null or not is_instance_valid(start) or not is_instance_valid(goal):
		return []
	if start == goal:
		return [start]

	var queue: Array = [start]
	var parents: Dictionary = {start: null}
	while not queue.is_empty():
		var current = queue.pop_front()
		if current == goal:
			break
		for connection in connections:
			if connection == null or not is_instance_valid(connection):
				continue
			var next = null
			if connection.from_device == current:
				next = connection.to_device
			elif connection.to_device == current:
				next = connection.from_device
			if next == null or not is_instance_valid(next) or parents.has(next):
				continue
			if only_valid:
				if not _is_operational(next):
					continue
				if connection.has_method("is_active") and not connection.is_active():
					continue
				if not _connection_interface_error(current, next, int(connection.cable_type)).is_empty():
					continue
			parents[next] = current
			queue.append(next)

	if not parents.has(goal):
		return []
	var path: Array = []
	var node = goal
	while node != null:
		path.push_front(node)
		node = parents.get(node, null)
	return path


func _validate_route_path(path: Array) -> Dictionary:
	if path.size() < 2:
		return {"ok": true}

	for index in range(path.size() - 1):
		var a: Device = path[index]
		var b: Device = path[index + 1]
		if not _is_operational(b):
			return {
				"ok": false,
				"index": index + 1,
				"message": _device_operational_error(b),
			}
		var connection = find_connection(a, b)
		if connection == null:
			return {
				"ok": false,
				"index": index,
				"message": "Нет кабеля между %s и %s." % [a.device_name, b.device_name],
			}
		if connection.has_method("is_active") and not connection.is_active():
			return {
				"ok": false,
				"index": index,
				"message": "Соединение %s ↔ %s ещё устанавливается." % [a.device_name, b.device_name],
			}
		var interface_error := _connection_interface_error(a, b, int(connection.cable_type))
		if not interface_error.is_empty():
			return {
				"ok": false,
				"index": index,
				"message": interface_error,
			}
	return {"ok": true}


func _connection_interface_error(a: Device, b: Device, cable_type: int) -> String:
	var cable_name := cable_type_name(cable_type)
	if cable_name.is_empty():
		return "Неизвестный тип кабеля."
	var pair_rules: Dictionary = CABLE_RULES.get(_pair_key(a, b), {})
	if pair_rules.is_empty() or not bool(pair_rules.get(cable_name, false)):
		return "Неверный кабель между %s и %s." % [a.device_name, b.device_name]

	var kind := ""
	match cable_type:
		CableType.STRAIGHT, CableType.CROSSOVER:
			kind = "ethernet"
		CableType.FIBER:
			kind = "fiber"
		CableType.WIRELESS:
			kind = "wireless"
	if kind.is_empty():
		return "Неизвестный тип кабеля."
	if not _has_enabled_interface_kind(a, kind):
		return _missing_port_message(a, kind)
	if not _has_enabled_interface_kind(b, kind):
		return _missing_port_message(b, kind)
	return ""


func _missing_port_message(device: Device, kind: String) -> String:
	if kind == "wireless":
		return "Беспроводной интерфейс на %s выключен или отсутствует." % device.device_name
	var port_name := "Fiber" if kind == "fiber" else "Ethernet"
	if device.device_type == "Switch":
		return "Порт %s на коммутаторе %s выключен или отсутствует." % [port_name, device.device_name]
	return "Порт %s на %s выключен или отсутствует." % [port_name, device.device_name]


func _device_operational_error(device: Device) -> String:
	if device.device_type == "Switch" and device.is_booting:
		return "Коммутатор %s загружается." % device.device_name
	return "Устройство %s выключено." % device.device_name


func _route_result(
	success: bool,
	path: Array,
	error_msg: String,
	extra: Dictionary = {}
) -> Dictionary:
	var result := {
		"success": success,
		"path": path,
		"error_msg": error_msg,
	}
	for key in extra.keys():
		result[key] = extra[key]
	if not success and not result.has("error_device") and not path.is_empty():
		result["error_device"] = path.back()
	return result


func are_devices_connected(a: Device, b: Device) -> bool:
	if a == null or b == null or a == b:
		return a == b
	# Выключенное устройство или коммутатор во время загрузки не может
	# быть частью рабочего пути, даже если кабели физически подключены.
	if not _is_operational(a) or not _is_operational(b):
		return false
	var queue: Array = [a]
	var visited: Dictionary = {a: true}
	while not queue.is_empty():
		var current = queue.pop_front()
		if current == b:
			return true
		if not _is_operational(current):
			continue
		for connection in connections:
			if connection == null or not is_instance_valid(connection):
				continue
			# Связь, которая ещё устанавливается (wireless), пока не считается путём.
			if connection.has_method("is_active") and not connection.is_active():
				continue
			var next = null
			if connection.from_device == current:
				next = connection.to_device
			elif connection.to_device == current:
				next = connection.from_device
			if next == null or visited.has(next):
				continue
			if not _is_operational(next):
				continue
			visited[next] = true
			queue.append(next)
	return false


func _find_source_ipv4_interface(source: Device) -> DeviceInterface:
	var primary: DeviceInterface = source.get_primary_interface()
	if primary != null and primary.enabled and not primary.ipv4_address.is_empty():
		return primary
	for interface_name in source.get_interface_names():
		var network_interface: DeviceInterface = source.get_interface(interface_name)
		if network_interface != null and network_interface.enabled and not network_interface.ipv4_address.is_empty():
			return network_interface
	return null
