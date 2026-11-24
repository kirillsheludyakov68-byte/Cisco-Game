extends Node

# Типы кабелей
enum CableType {
	STRAIGHT,   # прямой (PC↔Switch, Switch↔Router)
	CROSSOVER,  # кроссовер (PC↔PC, Switch↔Switch, Router↔Router)
	WIRELESS    # беспроводной (к Wi-Fi точке)
}

# Список всех устройств уровня
var devices: Array = []

# Список всех связей уровня
var connections: Array = []

# Сигналы
signal devices_changed
signal connections_changed

func register_device(device) -> void:
	if device not in devices:
		devices.append(device)
		devices_changed.emit()

func unregister_device(device) -> void:
	devices.erase(device)
	devices_changed.emit()

func add_connection(connection) -> void:
	connections.append(connection)
	connections_changed.emit()

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
		if (c.from_device == a and c.to_device == b) or \
		   (c.from_device == b and c.to_device == a):
			return c
	return null

# Проверить: можно ли соединить эти два устройства?
# Возвращает Dictionary: {ok: bool, reason: String}
func can_connect(a, b) -> Dictionary:
	if a == b:
		return {"ok": false, "reason": "Нельзя соединить устройство с самим собой"}
	if find_connection(a, b) != null:
		return {"ok": false, "reason": "Уже соединены"}
	if a.has_method("is_network_ready") and not a.is_network_ready():
		return {"ok": false, "reason": "Сетевой интерфейс первого устройства недоступен или отключён"}
	if b.has_method("is_network_ready") and not b.is_network_ready():
		return {"ok": false, "reason": "Сетевой интерфейс второго устройства недоступен или отключён"}
	return {"ok": true, "reason": ""}


# Ограниченная проверка IPv4-доступности для Command Prompt.
# Это не ICMP: успех означает, что адрес принадлежит включённому интерфейсу,
# между устройствами есть путь по текущей топологии и адреса входят в одну
# подсеть. Маршрутизация и ARP в симуляторе пока не реализованы.
func ping_ipv4(source: Device, target_address: String) -> Dictionary:
	if source == null or not is_instance_valid(source):
		return {"ok": false, "reason": "Устройство недоступно."}
	if not NetworkValidation.is_valid_ipv4(target_address):
		return {"ok": false, "reason": "Некорректный IPv4-адрес."}

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
	var queue: Array = [a]
	var visited: Dictionary = {a: true}
	while not queue.is_empty():
		var current = queue.pop_front()
		if current == b:
			return true
		for connection in connections:
			if connection == null or not is_instance_valid(connection):
				continue
			var next = null
			if connection.from_device == current:
				next = connection.to_device
			elif connection.to_device == current:
				next = connection.from_device
			if next == null or visited.has(next):
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
