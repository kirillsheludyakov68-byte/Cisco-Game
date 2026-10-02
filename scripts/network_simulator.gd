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
	return {"ok": true, "reason": ""}
