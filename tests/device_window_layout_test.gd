extends Node

# Headless-тест адаптивной раскладки окна устройства.
# Запуск:
#   godot --headless --path . res://tests/device_window_layout_test.tscn

var _failures: Array[String] = []


func _ready() -> void:
	await _test_physical_shell()
	_finish()


func _test_physical_shell() -> void:
	var device: Device = await _make_device("PC", "PC1")
	var window := await _open_window(device, Vector2i(1600, 900))

	var main: Control = window.get_node("MainPanel")
	var page: Control = window.get_node("MainPanel/ContentPanel/PagePhysical")
	var modules: Control = window.get_node("MainPanel/ContentPanel/PagePhysical/PhysicalLayout/ModulesPanel")
	var viewer: Control = window.get_node("MainPanel/ContentPanel/PagePhysical/PhysicalLayout/ViewerPanel")
	var info: Control = window.get_node("MainPanel/ContentPanel/PagePhysical/ModuleInfoPanel")

	_expect(main.size.x >= 1500.0, "MainPanel должен растягиваться по ширине окна")
	_expect(main.size.y >= 800.0, "MainPanel должен растягиваться по высоте окна")
	_expect(modules.size.x == 200.0, "Панель модулей должна сохранять ширину 200 px")
	_expect(viewer.size.x > modules.size.x, "Область просмотра должна занимать остаток ширины")
	_expect(info.visible, "Для PC панель информации о модуле должна быть видима")
	_expect(
		info.get_global_rect().end.y <= page.get_global_rect().end.y + 1.0,
		"Панель информации о модуле должна оставаться внутри страницы"
	)

	await _close_window(window, device)


func _make_device(device_type: String, device_name: String) -> Device:
	var device = load("res://scenes/Device.tscn").instantiate()
	device.device_name = device_name
	device.device_type = device_type
	add_child(device)
	await get_tree().process_frame
	return device


func _open_window(device: Device, size: Vector2i) -> DeviceWindow:
	var scene := load("res://scenes/DeviceWindow.tscn")
	var window: DeviceWindow = scene.instantiate()
	add_child(window)
	window.open_for(device)
	window.popup_centered(Vector2i(850, 670))
	window.size = size
	await _wait_frames(2)
	return window


func _close_window(window: Window, device: Device) -> void:
	window.queue_free()
	device.queue_free()
	await _wait_frames(2)


func _wait_frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: адаптивная раскладка окна устройства")
		get_tree().quit(0)
		return
	for failure in _failures:
		push_error("FAIL: " + failure)
	get_tree().quit(1)
