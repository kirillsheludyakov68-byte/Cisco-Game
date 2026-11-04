extends Node


func _ready() -> void:
	NetworkSimulator.clear()
	var pc_a := _make("PC")
	var pc_b := _make("PC")
	pc_a.set_initial_module("PT-HOST-NM-1CE")
	pc_b.set_initial_module("PT-HOST-NM-1CE")
	_check("PC-PC crossover", NetworkSimulator.can_connect(pc_a, pc_b, NetworkSimulator.CableType.CROSSOVER), true)
	_check("PC-PC straight", NetworkSimulator.can_connect(pc_a, pc_b, NetworkSimulator.CableType.STRAIGHT), false)

	var sw_a := _make("Switch")
	var sw_b := _make("Switch")
	_check("Switch-Switch crossover", NetworkSimulator.can_connect(sw_a, sw_b, NetworkSimulator.CableType.CROSSOVER), true)
	_check("Switch-Switch straight", NetworkSimulator.can_connect(sw_a, sw_b, NetworkSimulator.CableType.STRAIGHT), false)

	var router := _make("Router")
	_check("Router-Switch straight", NetworkSimulator.can_connect(router, sw_a, NetworkSimulator.CableType.STRAIGHT), true)
	_check("Router-Switch crossover", NetworkSimulator.can_connect(router, sw_a, NetworkSimulator.CableType.CROSSOVER), false)
	_check("Router-Switch fiber", NetworkSimulator.can_connect(router, sw_a, NetworkSimulator.CableType.FIBER), true)

	var pc_wireless := _make("PC")
	pc_wireless.set_initial_module("WMP300N")
	var pc_switch_result: Dictionary = NetworkSimulator.can_connect(pc_wireless, sw_a, NetworkSimulator.CableType.STRAIGHT)
	print("PC(WMP300N)-Switch straight: ", pc_switch_result)
	_check("PC(WMP300N)-Switch straight rejected", pc_switch_result, false)

	var pc_modem := _make("PC")
	pc_modem.set_initial_module("PT-HOST-NM-1AM")
	_check("PC(1AM)-Switch straight rejected", NetworkSimulator.can_connect(pc_modem, sw_a, NetworkSimulator.CableType.STRAIGHT), false)

	var ap := _make("AccessPoint")
	var pc_wifi := _make("PC")
	pc_wifi.set_initial_module("PT-HOST-NM-1W")
	_check("AP-PC wireless", NetworkSimulator.can_connect(ap, pc_wifi, NetworkSimulator.CableType.WIRELESS), true)
	_check("AP-PC straight", NetworkSimulator.can_connect(ap, pc_wifi, NetworkSimulator.CableType.STRAIGHT), false)

	var sw_fiber_only := _make("Switch")
	sw_fiber_only.set_initial_power(false)
	for slot in sw_fiber_only.installed_switch_modules.keys():
		if str(sw_fiber_only.installed_switch_modules[slot]) == "PT-SWITCH-NM-1CE":
			sw_fiber_only.remove_module_from_slot(int(slot))
	_check("Fiber-only Switch-Router fiber", NetworkSimulator.can_connect(sw_fiber_only, router, NetworkSimulator.CableType.FIBER), true)
	_check("Fiber-only Switch-Router straight rejected", NetworkSimulator.can_connect(sw_fiber_only, router, NetworkSimulator.CableType.STRAIGHT), false)

	get_tree().quit()


func _make(device_type: String) -> Device:
	var device: Device = load("res://scenes/Device.tscn").instantiate()
	add_child(device)
	device.device_type = device_type
	device.set_initial_power(true)
	return device


func _check(label: String, result: Dictionary, expected: bool) -> void:
	var ok := bool(result.get("ok", false))
	print(label, ": ", "PASS" if ok == expected else "FAIL", " -> ", result)
