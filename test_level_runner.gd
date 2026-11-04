extends Node


func _ready() -> void:
	var scene: Node = load("res://scenes/level_1.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame

	var level = scene
	var pc1: Device = level.devices_by_id.get("pc1")
	var pc2: Device = level.devices_by_id.get("pc2")
	var sw1: Device = level.devices_by_id.get("sw1")
	print("TITLE=", level.level_title)
	print("OBJECTIVES=", level.objectives.size(), " HINTS=", level.hints_available)
	print("PC1 power=", pc1.is_powered_on, " module=", pc1.installed_module, " eth=", pc1.has_enabled_interface_kind("ethernet"))
	print("PC2 power=", pc2.is_powered_on, " module=", pc2.installed_module, " eth=", pc2.has_enabled_interface_kind("ethernet"))
	print("SW1 power=", sw1.is_powered_on, " booting=", sw1.is_booting)
	print("initial states=", _states(level))
	var initial_hint: Dictionary = level.request_hint()
	var initial_target: Dictionary = initial_hint.get("target", {})
	print("initial hint=", initial_hint.get("text"), " kind=", initial_target.get("kind"))
	level.show_hint_target(initial_target)
	await get_tree().process_frame

	level.cable_panel.handle_device_click(pc2)
	await get_tree().process_frame
	var module_hint: Dictionary = level.request_hint()
	var module_target: Dictionary = module_hint.get("target", {})
	print("module hint=", module_hint.get("text"), " kind=", module_target.get("kind"))
	level.show_hint_target(module_target)
	await get_tree().process_frame

	print("straight without module=", NetworkSimulator.can_connect(pc2, sw1, NetworkSimulator.CableType.STRAIGHT))
	print("crossover pc2-sw=", NetworkSimulator.can_connect(pc2, sw1, NetworkSimulator.CableType.CROSSOVER))
	print("fiber pc2-sw=", NetworkSimulator.can_connect(pc2, sw1, NetworkSimulator.CableType.FIBER))

	var install_result: Dictionary = pc2.install_module("PT-HOST-NM-1CE")
	print("install module=", install_result)
	print("after module states=", _states(level))
	var cable_hint: Dictionary = level.request_hint()
	var cable_target: Dictionary = cable_hint.get("target", {})
	print("cable hint=", cable_hint.get("text"), " kind=", cable_target.get("kind"))
	level.show_hint_target(cable_target)
	await get_tree().process_frame
	print("straight after module=", NetworkSimulator.can_connect(pc2, sw1, NetworkSimulator.CableType.STRAIGHT))
	print("crossover after module=", NetworkSimulator.can_connect(pc2, sw1, NetworkSimulator.CableType.CROSSOVER))

	var conn = load("res://scenes/Connection.tscn").instantiate()
	level.add_child(conn)
	conn.setup(pc2, sw1, NetworkSimulator.CableType.STRAIGHT)
	NetworkSimulator.add_connection(conn)
	await get_tree().process_frame
	print("after cable states=", _states(level))
	var power_hint: Dictionary = level.request_hint()
	var power_target: Dictionary = power_hint.get("target", {})
	print("power hint=", power_hint.get("text"), " kind=", power_target.get("kind"))
	level.show_hint_target(power_target)
	await get_tree().process_frame
	print("ping before power=", NetworkSimulator.ping_ipv4(pc2, "192.168.1.1"))

	sw1.set_power(true)
	print("switch on booting=", sw1.is_booting)
	await get_tree().create_timer(10.3).timeout
	print("switch booted=", not sw1.is_booting, " power=", sw1.is_powered_on)
	print("after switch boot states=", _states(level))

	pc2.set_power(true)
	await get_tree().process_frame
	print("after pc2 power states=", _states(level))
	var ping_hint: Dictionary = level.request_hint()
	var ping_target: Dictionary = ping_hint.get("target", {})
	print("ping hint=", ping_hint.get("text"), " kind=", ping_target.get("kind"))
	level.show_hint_target(ping_target)
	await get_tree().process_frame

	var pc2_window = level.cable_panel.current_device_window
	if pc2_window != null:
		pc2_window._show_page("desktop")
		await get_tree().process_frame
		var desktop_hint: Dictionary = level.request_hint()
		var desktop_target: Dictionary = desktop_hint.get("target", {})
		print("desktop hint=", desktop_hint.get("text"), " kind=", desktop_target.get("kind"))
		level.show_hint_target(desktop_target)
		await get_tree().process_frame

		pc2_window.desktop_page.call("_open_app", "command_prompt")
		await get_tree().process_frame
		var cmd_hint: Dictionary = level.request_hint()
		var cmd_target: Dictionary = cmd_hint.get("target", {})
		print("cmd hint=", cmd_hint.get("text"), " kind=", cmd_target.get("kind"))
		level.show_hint_target(cmd_target)
		await get_tree().process_frame

	var ping_result: Dictionary = NetworkSimulator.ping_ipv4(pc2, "192.168.1.1")
	print("ping result=", ping_result)
	NetworkSimulator.ping_checked.emit(pc2, "192.168.1.1", bool(ping_result.get("ok", false)))
	await get_tree().process_frame
	print("after ping states=", _states(level))
	print("task completed=", level.task_panel._completed)

	sw1.set_power(false)
	await get_tree().process_frame
	print("after switch off states=", _states(level))

	get_tree().quit()


func _states(level) -> Array:
	var result: Array = []
	for objective in level.objectives:
		result.append(level.evaluate_objective(objective))
	return result
