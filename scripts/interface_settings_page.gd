extends PanelContainer
class_name InterfaceSettingsPage

@onready var header_panel: PanelContainer = $Root/VBox/HeaderPanel
@onready var header_label: Label = $Root/VBox/HeaderPanel/HeaderLabel
@onready var status_label: Label = $Root/VBox/StatusLabel
@onready var port_status_check: CheckBox = $Root/VBox/BodyScroll/Body/Fields/PortStatusCheck
@onready var mac_edit: LineEdit = $Root/VBox/BodyScroll/Body/Fields/MacEdit
@onready var ipv4_edit: LineEdit = $Root/VBox/BodyScroll/Body/Fields/IPv4Edit
@onready var mask_edit: LineEdit = $Root/VBox/BodyScroll/Body/Fields/MaskEdit
@onready var ipv6_edit: LineEdit = $Root/VBox/BodyScroll/Body/Fields/IPv6Edit
@onready var hint_label: Label = $Root/VBox/BodyScroll/Body/HintLabel

var device: Device = null
var network_interface: DeviceInterface = null
var _updating := false


func _ready() -> void:
	_apply_styles()
	port_status_check.toggled.connect(_on_port_status_toggled)
	ipv4_edit.text_submitted.connect(_on_field_submitted)
	ipv4_edit.focus_exited.connect(_on_field_focus_exited)
	mask_edit.text_submitted.connect(_on_field_submitted)
	mask_edit.focus_exited.connect(_on_field_focus_exited)
	ipv6_edit.text_submitted.connect(_on_field_submitted)
	ipv6_edit.focus_exited.connect(_on_field_focus_exited)


func setup(dev: Device, iface: DeviceInterface, _module_name: String = "") -> void:
	device = dev
	network_interface = iface
	refresh()


func refresh() -> void:
	_updating = true
	clear_field_errors()
	_set_status("")

	if network_interface == null:
		header_label.text = "Интерфейс"
		port_status_check.button_pressed = false
		port_status_check.disabled = true
		mac_edit.text = ""
		ipv4_edit.text = ""
		mask_edit.text = ""
		ipv6_edit.text = ""
		_set_editable(false)
		_updating = false
		return

	header_label.text = network_interface.interface_name
	port_status_check.disabled = false
	port_status_check.button_pressed = network_interface.enabled
	mac_edit.text = network_interface.get_mac_cisco()
	ipv4_edit.text = network_interface.ipv4_address
	mask_edit.text = network_interface.subnet_mask
	ipv6_edit.text = network_interface.ipv6_address
	_set_editable(true)
	_updating = false


func _set_editable(enabled: bool) -> void:
	ipv4_edit.editable = enabled
	mask_edit.editable = enabled
	ipv6_edit.editable = enabled


func commit_pending() -> void:
	if device == null or network_interface == null:
		return
	_commit_addresses()


func _on_port_status_toggled(pressed: bool) -> void:
	if _updating or device == null or network_interface == null:
		return

	device.set_interface_enabled(network_interface.interface_name, pressed)
	_set_status("Интерфейс включён." if pressed else "Интерфейс выключен.", false, not pressed)


func _on_field_submitted(_text: String) -> void:
	_commit_addresses()


func _on_field_focus_exited() -> void:
	_commit_addresses()


func _commit_addresses() -> void:
	if device == null or network_interface == null:
		return

	var ipv4 := ipv4_edit.text.strip_edges()
	var mask := mask_edit.text.strip_edges()
	var ipv6 := ipv6_edit.text.strip_edges()

	var ipv4_error := not ipv4.is_empty() and not NetworkValidation.is_valid_ipv4(ipv4)
	var mask_error := not mask.is_empty() and not NetworkValidation.is_valid_subnet_mask(mask)
	var ipv6_error := not ipv6.is_empty() and not NetworkValidation.is_valid_ipv6(ipv6)
	_set_field_errors(ipv4_error, mask_error, ipv6_error)

	if ipv4_error or mask_error or ipv6_error:
		_set_status("Проверьте IPv4/IPv6-адреса и маску подсети.", true)
		return

	device.set_interface_addresses(network_interface.interface_name, ipv4, mask, ipv6)
	network_interface = device.get_interface(network_interface.interface_name)
	ipv4_edit.text = ipv4
	mask_edit.text = mask
	ipv6_edit.text = ipv6
	_set_status("Настройки интерфейса сохранены.", false, true)


func _set_field_errors(ipv4_error: bool, mask_error: bool, ipv6_error: bool) -> void:
	ConfigStyles.mark_line_edit_error(ipv4_edit, ipv4_error)
	ConfigStyles.mark_line_edit_error(mask_edit, mask_error)
	ConfigStyles.mark_line_edit_error(ipv6_edit, ipv6_error)


func clear_field_errors() -> void:
	_set_field_errors(false, false, false)


func _set_status(text: String, is_error: bool = false, success: bool = false) -> void:
	ConfigStyles.set_status(status_label, text, is_error, success)


func _apply_styles() -> void:
	add_theme_stylebox_override("panel", ConfigStyles.content_panel())
	header_panel.add_theme_stylebox_override("panel", ConfigStyles.header_panel())
	ConfigStyles.apply_bold_label(header_label, 16)
	ConfigStyles.apply_label($Root/VBox/BodyScroll/Body/Fields/PortStatusLabel)
	ConfigStyles.apply_label($Root/VBox/BodyScroll/Body/Fields/MacLabel)
	ConfigStyles.apply_label($Root/VBox/BodyScroll/Body/Fields/IPv4Label)
	ConfigStyles.apply_label($Root/VBox/BodyScroll/Body/Fields/MaskLabel)
	ConfigStyles.apply_label($Root/VBox/BodyScroll/Body/Fields/IPv6Label)
	ConfigStyles.apply_label(hint_label, 11, true)
	ConfigStyles.apply_status_label(status_label)
	ConfigStyles.apply_plain_checkbox(port_status_check)
	ConfigStyles.apply_line_edit(mac_edit)
	ConfigStyles.apply_line_edit(ipv4_edit)
	ConfigStyles.apply_line_edit(mask_edit)
	ConfigStyles.apply_line_edit(ipv6_edit)
