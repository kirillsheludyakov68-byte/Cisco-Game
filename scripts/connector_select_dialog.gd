extends Control
class_name ConnectorSelectDialog

signal connector_selected(interface_name: String)
signal cancelled

@onready var panel: PanelContainer = $Center/Panel
@onready var title_label: Label = $Center/Panel/Margin/VBox/Title
@onready var message_label: Label = $Center/Panel/Margin/VBox/Message
@onready var list_container: VBoxContainer = $Center/Panel/Margin/VBox/List
@onready var cancel_button: Button = $Center/Panel/Margin/VBox/Buttons/CancelButton

var device: Device = null
var source_device: Device = null
var target_device: Device = null
var cable_type: int = NetworkSimulator.CableType.STRAIGHT

func _ready() -> void:
	visible = false
	cancel_button.pressed.connect(_on_cancel)
	MenuStyles.apply_panel(panel, MenuStyles.BG, MenuStyles.GRAY)

func setup(
	device_value: Device,
	source_value: Device,
	target_value: Device,
	cable_type_value: int,
	title_value: String,
	message_value: String
) -> void:
	device = device_value
	source_device = source_value
	target_device = target_value
	cable_type = cable_type_value
	title_label.text = title_value
	message_label.text = message_value
	_refresh_buttons()
	visible = true
	cancel_button.grab_focus()

func get_connector_candidates(device_value: Device, cable_type_value: int) -> Array:
	var result: Array = []
	var kind := _cable_interface_kind(cable_type_value)
	if device_value == null or not is_instance_valid(device_value):
		return result

	for iface in device_value.interfaces:
		if iface == null:
			continue
		if not iface.enabled:
			continue
		if iface.interface_kind != kind:
			continue
		result.append({
			"interface_name": iface.interface_name,
			"label": _build_connector_label(iface),
			"kind": kind,
		})
	return result

func _refresh_buttons() -> void:
	for child in list_container.get_children():
		child.queue_free()

	var candidates: Array = get_connector_candidates(device, cable_type)
	for candidate in candidates:
		var button := Button.new()
		button.text = str(candidate.get("label", ""))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_connector_pressed.bind(str(candidate.get("interface_name", ""))))
		list_container.add_child(button)
		MenuStyles.apply_button(button, "secondary", 18, 12)

func _build_connector_label(iface) -> String:
	var module_name := str(iface.source_module)
	var slot_index := int(iface.slot_index)
	var label := str(iface.interface_name)
	if not module_name.is_empty():
		label = "%s · %s" % [str(iface.interface_name), module_name]
	if slot_index >= 0:
		label = "%s (слот %d)" % [label, slot_index]
	return label

func _cable_interface_kind(cable_type_value: int) -> String:
	match cable_type_value:
		NetworkSimulator.CableType.STRAIGHT, NetworkSimulator.CableType.CROSSOVER:
			return "ethernet"
		NetworkSimulator.CableType.FIBER:
			return "fiber"
		NetworkSimulator.CableType.WIRELESS:
			return "wireless"
	return ""

func _on_connector_pressed(interface_name: String) -> void:
	visible = false
	connector_selected.emit(interface_name)

func _on_cancel() -> void:
	visible = false
	cancelled.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_cancel()
		get_viewport().set_input_as_handled()
