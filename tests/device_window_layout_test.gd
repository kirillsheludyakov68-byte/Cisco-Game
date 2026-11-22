extends Node

# Headless-тест адаптивной раскладки окна устройства.
# Запуск:
#   godot --headless --path . res://tests/device_window_layout_test.tscn

var _failures: Array[String] = []


func _ready() -> void:
	await _test_physical_shell()
	await _test_pages_fill()
	await _test_pc_scaling()
	await _test_preferred_size()
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


func _test_pages_fill() -> void:
	var server: Device = await _make_device("Server", "Server0")
	var server_window := await _open_window(server, Vector2i(1600, 900))
	var server_page: Control = server_window.get_node("MainPanel/ContentPanel/PagePhysical")
	for page_name in ["config", "desktop", "services"]:
		server_window._show_page(page_name)
		await _wait_frames(1)
		var page_node = _get_page_node(server_window, page_name)
		_expect(page_node != null, "Страница %s должна существовать" % page_name)
		if page_node != null:
			_expect(page_node.is_visible_in_tree(), "Страница %s должна быть видима" % page_name)
			_expect(
				_rect_size_close(page_node.size, server_page.size),
				"Страница %s должна заполнять ContentPanel" % page_name
			)
	await _close_window(server_window, server)

	var switch: Device = await _make_device("Switch", "Switch1")
	var switch_window := await _open_window(switch, Vector2i(1600, 900))
	var switch_page: Control = switch_window.get_node("MainPanel/ContentPanel/PagePhysical")
	switch_window._show_page("cli")
	await _wait_frames(1)
	var cli_page = _get_page_node(switch_window, "cli")
	_expect(cli_page != null, "Страница CLI должна существовать")
	if cli_page != null:
		_expect(cli_page.is_visible_in_tree(), "Страница CLI должна быть видима")
		_expect(
			_rect_size_close(cli_page.size, switch_page.size),
			"Страница CLI должна заполнять ContentPanel"
		)
	await _close_window(switch_window, switch)


func _test_pc_scaling() -> void:
	var device: Device = await _make_device("PC", "PC1")
	var window := await _open_window(device, Vector2i(1600, 900))
	var device_view := window.device_view
	var initial_size := window.device_image.size

	_expect(
		absf(initial_size.y - device_view.size.y) <= 2.0,
		"PC должен вписываться по высоте в область просмотра"
	)
	_expect(
		absf(
			window.device_image.position.x
			- (device_view.size.x - initial_size.x) * 0.5
		) <= 2.0,
		"PC должен центрироваться по горизонтали"
	)

	var power_rect: Rect2 = window._get_power_base_rect()
	_expect(power_rect.size.x > 14.0, "Кнопка питания PC должна масштабироваться вместе с картинкой")
	_expect(
		Rect2(Vector2.ZERO, initial_size).encloses(power_rect),
		"Кнопка питания PC должна оставаться внутри картинки"
	)

	window.size = Vector2i(1920, 1080)
	await _wait_frames(2)
	_expect(
		window.device_image.size.y > initial_size.y,
		"При увеличении окна картинка PC должна увеличиваться"
	)

	await _close_window(window, device)


func _test_preferred_size() -> void:
	var device: Device = await _make_device("Tablet", "Tablet1")
	var window := await _open_window(device, Vector2i(1680, 920))
	await _wait_frames(2)
	await _close_window(window, device)

	_expect(
		DeviceWindow.get_preferred_window_size() == Vector2i(1680, 920),
		"Окно устройства должно запоминать последний размер"
	)


func _get_page_node(window: DeviceWindow, page_name: String) -> Control:
	match page_name:
		"config":
			return window.config_panel
		"desktop":
			return window.desktop_page
		"services":
			return window.services_page
		"cli":
			return window.cli_page
	return null


func _rect_size_close(a: Vector2, b: Vector2) -> bool:
	return absf(a.x - b.x) <= 1.0 and absf(a.y - b.y) <= 1.0


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
