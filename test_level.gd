extends SceneTree


func _initialize() -> void:
	var scene: Node = load("res://scenes/level_1.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

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
	print("straight without module=", NetworkSimulator.can_connect(pc2, sw1, NetworkSimulator.CableType.STRAIGHT))
	print("crossover pc2-sw=", NetworkSimulator.can_connect(pc2, sw1, NetworkSimulator.CableType.CROSSOVER))
	print("fiber pc2-sw=", NetworkSimulator.can_connect(pc2, sw1, NetworkSimulator.CableType.FIBER))

	var install_result: Dictionary = pc2.install_module("PT-HOST-NM-1CE")
	print("install module=", install_result)
	print("after module states=", _states(level))
	print("straight after module=", NetworkSimulator.can_connect(pc2, sw1, NetworkSimulator.CableType.STRAIGHT))
	print("crossover after module=", NetworkSimulator.can_connect(pc2, sw1, NetworkSimulator.CableType.CROSSOVER))

	var conn = load("res://scenes/Connection.tscn").instantiate()
	level.add_child(conn)
	conn.setup(pc2, sw1, NetworkSimulator.CableType.STRAIGHT)
	NetworkSimulator.add_connection(conn)
	await process_frame
	print("after cable states=", _states(level))
	print("ping before power=", NetworkSimulator.ping_ipv4(pc2, "192.168.1.1"))

	sw1.set_power(true)
	print("switch on booting=", sw1.is_booting)
	await create_timer(10.3).timeout
	print("switch booted=", not sw1.is_booting, " power=", sw1.is_powered_on)
	print("after switch boot states=", _states(level))

	pc2.set_power(true)
	await process_frame
	print("after pc2 power states=", _states(level))
	var ping_result: Dictionary = NetworkSimulator.ping_ipv4(pc2, "192.168.1.1")
	print("ping result=", ping_result)
	NetworkSimulator.ping_checked.emit(pc2, "192.168.1.1", bool(ping_result.get("ok", false)))
	await process_frame
	print("after ping states=", _states(level))
	print("task completed=", level.task_panel._completed)

	sw1.set_power(false)
	await process_frame
	print("after switch off states=", _states(level))

	quit()


func _states(level) -> Array:
	var result: Array = []
	for objective in level.objectives:
		result.append(level.evaluate_objective(objective))
	return result
