extends Node


func _ready() -> void:
	var scene: Node = load("res://scenes/level_1.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	print("before open")
	scene.cable_panel.handle_device_click(scene.devices_by_id.get("pc2"))
	await get_tree().process_frame
	print("after open")
	await get_tree().create_timer(1.0).timeout
	print("after 1s")
	get_tree().quit()
