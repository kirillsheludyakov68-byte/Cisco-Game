extends PanelContainer
class_name SwitchInterfaceConfigPage

@onready var header_panel: PanelContainer = $Root/VBox/HeaderPanel
@onready var header_label: Label = $Root/VBox/HeaderPanel/HeaderLabel
@onready var status_label: Label = $Root/VBox/StatusLabel
@onready var port_status_check: CheckBox = $Root/VBox/BodyScroll/Body/Fields/PortStatusCheck
@onready var bandwidth_option: OptionButton = $Root/VBox/BodyScroll/Body/Fields/BandwidthOption
@onready var duplex_option: OptionButton = $Root/VBox/BodyScroll/Body/Fields/DuplexOption
@onready var hint_label: Label = $Root/VBox/BodyScroll/Body/HintLabel
@onready var equivalent_panel: PanelContainer = $Root/VBox/EquivalentPanel
@onready var equivalent_header: Label = $Root/VBox/EquivalentPanel/EquivalentVBox/EquivalentHeader
@onready var ios_output: TextEdit = $Root/VBox/EquivalentPanel/EquivalentVBox/IOSOutput

const DUPLEX_VALUES: Array[String] = [
	DeviceInterface.DUPLEX_HALF,
	DeviceInterface.DUPLEX_FULL,
	DeviceInterface.DUPLEX_AUTO,
]

var device: Device = null
var network_interface: DeviceInterface = null
var module_name: String = ""

var _updating := false
var _bandwidth_values: Array[String] = []


func _ready() -> void:
	_apply_styles()
	duplex_option.clear()
	duplex_option.add_item("Half Duplex")
	duplex_option.add_item("Full Duplex")
	duplex_option.add_item("Auto")
	port_status_check.toggled.connect(_on_port_status_toggled)
	bandwidth_option.item_selected.connect(_on_bandwidth_selected)
	duplex_option.item_selected.connect(_on_duplex_selected)


func setup(dev: Device, iface: DeviceInterface, source_module: String = "") -> void:
	_connect_device(dev)
	device = dev
	network_interface = iface
	module_name = source_module if not source_module.is_empty() else iface.source_module
	_populate_bandwidth_options()
	refresh()


func refresh() -> void:
	_updating = true
	_set_status("")

	if network_interface == null:
		header_label.text = "Интерфейс"
		port_status_check.button_pressed = false
		port_status_check.disabled = true
		bandwidth_option.disabled = true
		duplex_option.disabled = true
		_update_console()
		_updating = false
		return

	header_label.text = network_interface.interface_name
	port_status_check.disabled = false
	port_status_check.button_pressed = network_interface.enabled
	bandwidth_option.disabled = false
	duplex_option.disabled = false

	_select_bandwidth(network_interface.bandwidth_mode)
	_select_duplex(network_interface.duplex_mode)
	_update_console()
	_updating = false


func commit_pending() -> void:
	# Все изменения применяются сразу при выборе значения.
	pass


func _populate_bandwidth_options() -> void:
	bandwidth_option.clear()
	_bandwidth_values.clear()
	var options := ModuleCatalog.get_switch_bandwidth_options(module_name)
	for option in options:
		bandwidth_option.add_item(str(option.get("label", "")))
		_bandwidth_values.append(str(option.get("value", "")))


func _select_bandwidth(mode: String) -> void:
	var index := _bandwidth_values.find(mode)
	if index < 0:
		index = _bandwidth_values.find(DeviceInterface.BANDWIDTH_AUTO)
	bandwidth_option.select(maxi(index, 0))


func _select_duplex(mode: String) -> void:
	var index := DUPLEX_VALUES.find(mode)
	duplex_option.select(maxi(index, 0))


func _on_port_status_toggled(pressed: bool) -> void:
	if _updating or device == null or network_interface == null:
		return
	device.set_interface_enabled(network_interface.interface_name, pressed)
	_set_status(
		"Порт включён." if pressed else "Порт выключен.",
		false,
		pressed
	)


func _on_bandwidth_selected(index: int) -> void:
	if _updating or device == null or network_interface == null:
		return
	if index < 0 or index >= _bandwidth_values.size():
		return

	var mode := _bandwidth_values[index]
	var mbps := _bandwidth_to_mbps(mode)
	device.set_interface_bandwidth(network_interface.interface_name, mode, mbps)
	_set_status("Bandwidth: %s." % bandwidth_option.get_item_text(index), false, true)


func _on_duplex_selected(index: int) -> void:
	if _updating or device == null or network_interface == null:
		return
	if index < 0 or index >= DUPLEX_VALUES.size():
		return

	var mode := DUPLEX_VALUES[index]
	device.set_interface_duplex(network_interface.interface_name, mode)
	_set_status("Duplex: %s." % duplex_option.get_item_text(index), false, true)


func _bandwidth_to_mbps(mode: String) -> int:
	match mode:
		DeviceInterface.BANDWIDTH_10MBPS:
			return 10
		DeviceInterface.BANDWIDTH_100MBPS:
			return 100
		DeviceInterface.BANDWIDTH_1000MBPS:
			return 1000
		_:
			return network_interface.bandwidth_mbps if network_interface != null else 10


func _connect_device(dev: Device) -> void:
	if device == dev:
		return
	_disconnect_device()
	device = dev
	if device == null:
		return
	if not device.console.line_added.is_connected(_on_console_line_added):
		device.console.line_added.connect(_on_console_line_added)
	if not device.console.cleared.is_connected(_on_console_cleared):
		device.console.cleared.connect(_on_console_cleared)
	if not device.boot_finished.is_connected(_on_console_cleared):
		device.boot_finished.connect(_on_console_cleared)
	if not device.boot_state_changed.is_connected(_on_boot_state_changed):
		device.boot_state_changed.connect(_on_boot_state_changed)
	if not device.hostname_changed.is_connected(_on_hostname_changed):
		device.hostname_changed.connect(_on_hostname_changed)


func _disconnect_device() -> void:
	if device == null:
		return
	if device.console.line_added.is_connected(_on_console_line_added):
		device.console.line_added.disconnect(_on_console_line_added)
	if device.console.cleared.is_connected(_on_console_cleared):
		device.console.cleared.disconnect(_on_console_cleared)
	if device.boot_finished.is_connected(_on_console_cleared):
		device.boot_finished.disconnect(_on_console_cleared)
	if device.boot_state_changed.is_connected(_on_boot_state_changed):
		device.boot_state_changed.disconnect(_on_boot_state_changed)
	if device.hostname_changed.is_connected(_on_hostname_changed):
		device.hostname_changed.disconnect(_on_hostname_changed)


func _on_console_line_added(_line: String) -> void:
	_update_console()


func _on_console_cleared() -> void:
	_update_console()


func _on_boot_state_changed(_is_booting: bool) -> void:
	_update_console()


func _on_hostname_changed(_new_hostname: String) -> void:
	_update_console()


func _update_console() -> void:
	if device == null or ios_output == null:
		return
	ios_output.text = device.get_console_text()
	_scroll_console_to_end()


func _scroll_console_to_end() -> void:
	if ios_output == null or not is_inside_tree():
		return
	ios_output.scroll_vertical = ios_output.get_line_count()
	# После первого кадра TextEdit пересчитывает высоту и полосу прокрутки,
	# поэтому прокручиваем ещё раз, чтобы последняя строка лога была видна.
	await get_tree().process_frame
	if is_instance_valid(ios_output):
		ios_output.scroll_vertical = ios_output.get_line_count()


func _set_status(text: String, is_error: bool = false, success: bool = false) -> void:
	ConfigStyles.set_status(status_label, text, is_error, success)


func _apply_styles() -> void:
	add_theme_stylebox_override("panel", ConfigStyles.content_panel())
	header_panel.add_theme_stylebox_override("panel", ConfigStyles.header_panel())
	equivalent_panel.add_theme_stylebox_override("panel", ConfigStyles.section_panel())
	ConfigStyles.apply_bold_label(header_label, 16)
	ConfigStyles.apply_bold_label(equivalent_header, 13)
	ConfigStyles.apply_label($Root/VBox/BodyScroll/Body/Fields/PortStatusLabel)
	ConfigStyles.apply_label($Root/VBox/BodyScroll/Body/Fields/BandwidthLabel)
	ConfigStyles.apply_label($Root/VBox/BodyScroll/Body/Fields/DuplexLabel)
	ConfigStyles.apply_label(hint_label, 11, true)
	ConfigStyles.apply_status_label(status_label)
	ConfigStyles.apply_plain_checkbox(port_status_check)
	ConfigStyles.apply_option_button(bandwidth_option)
	ConfigStyles.apply_option_button(duplex_option)
	ConfigStyles.apply_text_edit(ios_output)
	ios_output.editable = false
	ios_output.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	ios_output.scroll_fit_content_height = false
