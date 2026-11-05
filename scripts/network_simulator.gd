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


# Ограниченная проверка IPv4-доступности для Command Prompt.
# Это не ICMP: успех означает, что адрес принадлежит включённому интерфейсу,
# между устройствами есть путь по текущей топологии и адреса входят в одну
# подсеть. Маршрутизация и ARP в симуляторе пока не реализованы.
func ping_ipv4(source: Device, target_address: String) -> Dictionary:
	if source == null or not is_instance_valid(source):
		return {"ok": false, "reason": "Устройство недоступно."}
	if not NetworkValidation.is_valid_ipv4(target_address):
		return {"ok": false, "reason": "Некорректный IPv4-адрес."}
	if not _is_operational(source):
		return {"ok": false, "reason": "Устройство выключено или ещё загружается."}

	var source_interface := _find_source_ipv4_interface(source)
	if source_interface == null:
		return {"ok": false, "reason": "У текущего устройства нет включённого IPv4-интерфейса."}
	if not NetworkValidation.is_valid_ipv4(source_interface.ipv4_address):
		return {"ok": false, "reason": "У исходного интерфейса некорректный IPv4-адрес."}
	if not NetworkValidation.is_valid_subnet_mask(source_interface.subnet_mask):
		return {"ok": false, "reason": "У исходного интерфейса не задана корректная маска подсети."}

	var target_device: Device = null
	var target_interface: DeviceInterface = null
	for candidate in devices:
		if candidate == null or not is_instance_valid(candidate):
			continue
		if not candidate.has_method("get_interface_names"):
			continue
		for interface_name in candidate.get_interface_names():
			var candidate_interface: DeviceInterface = candidate.get_interface(interface_name)
			if candidate_interface == null or not candidate_interface.enabled:
				continue
			if candidate_interface.ipv4_address == target_address:
				target_device = candidate
				target_interface = candidate_interface
				break
		if target_device != null:
			break

	if target_device == null or target_interface == null:
		return {"ok": false, "reason": "Хост с таким IPv4-адресом не найден."}
	if target_device == source:
		return {"ok": false, "reason": "Адрес принадлежит самому устройству; проверка loopback не реализована."}
	if not _is_operational(target_device):
		return {"ok": false, "reason": "Хост с таким IPv4-адресом выключен или ещё загружается."}
	if not are_devices_connected(source, target_device):
		return {"ok": false, "reason": "Нет пути между устройствами в текущей топологии."}

	var mask := NetworkValidation.ipv4_to_int(source_interface.subnet_mask)
	if mask == 0 and source_interface.subnet_mask.is_empty():
		return {"ok": false, "reason": "У исходного интерфейса не задана маска подсети."}
	var source_ip := NetworkValidation.ipv4_to_int(source_interface.ipv4_address)
	var target_ip := NetworkValidation.ipv4_to_int(target_address)
	if (source_ip & mask) != (target_ip & mask):
		return {"ok": false, "reason": "Адрес назначения находится в другой подсети."}

	return {
		"ok": true,
		"reason": "",
		"source_interface": source_interface,
		"target_device": target_device,
		"target_interface": target_interface,
	}


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
