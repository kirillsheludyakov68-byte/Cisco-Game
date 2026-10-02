extends Node2D

@onready var cable_panel: CanvasLayer = $CablePanel

func _ready() -> void:
	# Регистрируем всё в симуляторе
	NetworkSimulator.clear()
	for child in get_children():
		if child is Device:
			NetworkSimulator.register_device(child)
			child.device_clicked.connect(_on_device_clicked)
			child.reset_highlight()

func _on_device_clicked(device: Device) -> void:
	cable_panel.handle_device_click(device)
