extends PanelContainer
class_name Modem0ConfigPage

@onready var header_panel: PanelContainer = $Root/VBox/HeaderPanel
@onready var header_label: Label = $Root/VBox/HeaderPanel/HeaderLabel
@onready var status_label: Label = $Root/VBox/StatusLabel

@onready var port_status_check: CheckBox = $Root/VBox/BodyScroll/Body/TopGrid/PortStatusRow/PortStatusCheck
@onready var bandwidth_value: Label = $Root/VBox/BodyScroll/Body/TopGrid/BandwidthValue
@onready var duplex_check: CheckBox = $Root/VBox/BodyScroll/Body/TopGrid/DuplexRow/DuplexCheck

@onready var ipv4_panel: PanelContainer = $Root/VBox/BodyScroll/Body/IPv4Panel
@onready var ipv4_edit: LineEdit = $Root/VBox/BodyScroll/Body/IPv4Panel/IPv4Margin/IPv4VBox/IPv4Fields/IPv4Edit
@onready var mask_edit: LineEdit = $Root/VBox/BodyScroll/Body/IPv4Panel/IPv4Margin/IPv4VBox/IPv4Fields/MaskEdit

@onready var ipv6_panel: PanelContainer = $Root/VBox/BodyScroll/Body/IPv6Panel
@onready var ipv6_automatic: CheckBox = $Root/VBox/BodyScroll/Body/IPv6Panel/IPv6Margin/IPv6VBox/IPv6ModeRow/IPv6Automatic
@onready var ipv6_static: CheckBox = $Root/VBox/BodyScroll/Body/IPv6Panel/IPv6Margin/IPv6VBox/IPv6ModeRow/IPv6Static
@onready var ipv6_edit: LineEdit = $Root/VBox/BodyScroll/Body/IPv6Panel/IPv6Margin/IPv6VBox/IPv6Fields/IPv6AddressRow/IPv6Edit
@onready var prefix_edit: LineEdit = $Root/VBox/BodyScroll/Body/IPv6Panel/IPv6Margin/IPv6VBox/IPv6Fields/IPv6AddressRow/PrefixEdit
@onready var link_local_edit: LineEdit = $Root/VBox/BodyScroll/Body/IPv6Panel/IPv6Margin/IPv6VBox/IPv6Fields/LinkLocalEdit

var device: Device = null
var network_interface: DeviceInterface = null
var module_name: String = ""

var _updating := false
var _ipv6_group: ButtonGroup


func _ready() -> void:
	_apply_styles()
	_setup_groups()
	_connect_signals()


func setup(dev: Device, iface: DeviceInterface, source_module: String = "") -> void:
	device = dev
	network_interface = iface
	module_name = source_module
	refresh()


func refresh() -> void:
	_updating = true
	clear_field_errors()
	_set_status("")

	if network_interface == null:
		header_label.text = "Интерфейс"
		port_status_check.button_pressed = false
		port_status_check.disabled = true
		bandwidth_value.text = ""
		duplex_check.text = "Full Duplex"
		duplex_check.button_pressed = false
		duplex_check.disabled = true
		ipv4_edit.text = ""
		mask_edit.text = ""
		ipv6_automatic.button_pressed = false
		ipv6_static.button_pressed = false
		ipv6_edit.text = ""
		prefix_edit.text = ""
		link_local_edit.text = ""
		_set_ipv4_editable(false)
		_set_ipv6_editable(false)
		_updating = false
		return

	header_label.text = network_interface.interface_name
	port_status_check.disabled = false
	port_status_check.button_pressed = network_interface.enabled

	bandwidth_value.text = _format_bandwidth(network_interface)
	duplex_check.disabled = true
	duplex_check.button_pressed = false
	duplex_check.text = _duplex_label(network_interface.duplex_mode)

	ipv4_edit.text = network_interface.ipv4_address
	mask_edit.text = network_interface.subnet_mask

	ipv6_automatic.button_pressed = network_interface.ipv6_mode == NetworkSettings.IPV6_AUTOMATIC
	ipv6_static.button_pressed = network_interface.ipv6_mode == NetworkSettings.IPV6_STATIC
	ipv6_edit.text = network_interface.ipv6_address
	prefix_edit.text = str(network_interface.ipv6_prefix)
	link_local_edit.text = network_interface.link_local_ipv6

	_set_ipv4_editable(true)
	_set_ipv6_editable(network_interface.ipv6_mode == NetworkSettings.IPV6_STATIC)
	_updating = false


func commit_pending() -> void:
	if device == null or network_interface == null:
		return
	_commit_ipv4()
	if network_interface.ipv6_mode == NetworkSettings.IPV6_STATIC:
		_commit_ipv6()


func _setup_groups() -> void:
	_ipv6_group = ButtonGroup.new()
	_ipv6_group.allow_unpress = false
	ipv6_automatic.button_group = _ipv6_group
	ipv6_static.button_group = _ipv6_group


func _connect_signals() -> void:
	port_status_check.toggled.connect(_on_port_status_toggled)
	ipv6_automatic.toggled.connect(_on_ipv6_mode_toggled.bind(NetworkSettings.IPV6_AUTOMATIC))
	ipv6_static.toggled.connect(_on_ipv6_mode_toggled.bind(NetworkSettings.IPV6_STATIC))

	ipv4_edit.text_submitted.connect(_on_ipv4_submitted)
	ipv4_edit.focus_exited.connect(_on_ipv4_focus_exited)
	mask_edit.text_submitted.connect(_on_ipv4_submitted)
	mask_edit.focus_exited.connect(_on_ipv4_focus_exited)
	ipv6_edit.text_submitted.connect(_on_ipv6_submitted)
	ipv6_edit.focus_exited.connect(_on_ipv6_focus_exited)
	prefix_edit.text_submitted.connect(_on_ipv6_submitted)
	prefix_edit.focus_exited.connect(_on_ipv6_focus_exited)


func _on_port_status_toggled(pressed: bool) -> void:
	if _updating or device == null or network_interface == null:
		return
	device.set_interface_enabled(network_interface.interface_name, pressed)
	_set_status(
		"Интерфейс включён." if pressed else "Интерфейс выключен.",
		false,
		pressed
	)


func _on_ipv6_mode_toggled(pressed: bool, mode: String) -> void:
	if _updating or not pressed or device == null or network_interface == null:
		return
	device.set_interface_ipv6_mode(network_interface.interface_name, mode)
	_set_ipv6_editable(mode == NetworkSettings.IPV6_STATIC)
	if mode == NetworkSettings.IPV6_AUTOMATIC:
		_set_status("Режим IPv6: Automatic. Автоматическая настройка IPv6 не моделируется.", false, true)
	else:
		_set_status("Режим IPv6: Static.", false, true)


func _on_ipv4_submitted(_text: String) -> void:
	_commit_ipv4()


func _on_ipv4_focus_exited() -> void:
	_commit_ipv4()


func _on_ipv6_submitted(_text: String) -> void:
	_commit_ipv6()


func _on_ipv6_focus_exited() -> void:
	_commit_ipv6()


func _commit_ipv4() -> void:
	if device == null or network_interface == null:
		return

	var ipv4 := ipv4_edit.text.strip_edges()
	var mask := mask_edit.text.strip_edges()
	var ipv4_error := not ipv4.is_empty() and not NetworkValidation.is_valid_ipv4(ipv4)
	var mask_error := not mask.is_empty() and not NetworkValidation.is_valid_subnet_mask(mask)
	var mask_missing := not ipv4.is_empty() and mask.is_empty()
	_set_ipv4_field_errors(ipv4_error, mask_error or mask_missing)

	if ipv4_error or mask_error or mask_missing:
		_set_status(
			"Проверьте IPv4-адрес и маску: нужны четыре октета 0–255, маска должна быть непрерывной.",
			true
		)
		return

	if not device.set_interface_ipv4_config(network_interface.interface_name, ipv4, mask):
		_set_status("Не удалось сохранить IPv4-настройки модема.", true)
		return

	network_interface = device.get_interface(network_interface.interface_name)
	ipv4_edit.text = ipv4
	mask_edit.text = mask
	_set_status("Настройки IPv4 сохранены.", false, true)


func _commit_ipv6() -> void:
	if device == null or network_interface == null:
		return
	if network_interface.ipv6_mode != NetworkSettings.IPV6_STATIC:
		return

	var ipv6 := ipv6_edit.text.strip_edges()
	var prefix_text := prefix_edit.text.strip_edges()
	var ipv6_error := not ipv6.is_empty() and not NetworkValidation.is_valid_ipv6(ipv6)
	var prefix_error := not prefix_text.is_empty() and not NetworkValidation.is_valid_ipv6_prefix(prefix_text)
	_set_ipv6_field_errors(ipv6_error, prefix_error)

	if ipv6_error or prefix_error:
		_set_status("Проверьте IPv6-адрес и префикс (0–128).", true)
		return

	var prefix := network_interface.ipv6_prefix
	if not prefix_text.is_empty():
		prefix = int(prefix_text)

	if not device.set_interface_ipv6_config(network_interface.interface_name, ipv6, prefix):
		_set_status("Не удалось сохранить IPv6-настройки модема.", true)
		return

	network_interface = device.get_interface(network_interface.interface_name)
	ipv6_edit.text = ipv6
	prefix_edit.text = str(network_interface.ipv6_prefix)
	_set_status("Настройки IPv6 сохранены.", false, true)


func _set_ipv4_editable(enabled: bool) -> void:
	ConfigStyles.set_line_edit_editable(ipv4_edit, enabled)
	ConfigStyles.set_line_edit_editable(mask_edit, enabled)


func _set_ipv6_editable(enabled: bool) -> void:
	ConfigStyles.set_line_edit_editable(ipv6_edit, enabled)
	ConfigStyles.set_line_edit_editable(prefix_edit, enabled)


func clear_field_errors() -> void:
	_set_ipv4_field_errors(false, false)
	_set_ipv6_field_errors(false, false)


func _set_ipv4_field_errors(ipv4_error: bool, mask_error: bool) -> void:
	ConfigStyles.mark_line_edit_error(ipv4_edit, ipv4_error)
	ConfigStyles.mark_line_edit_error(mask_edit, mask_error)


func _set_ipv6_field_errors(ipv6_error: bool, prefix_error: bool) -> void:
	ConfigStyles.mark_line_edit_error(ipv6_edit, ipv6_error)
	ConfigStyles.mark_line_edit_error(prefix_edit, prefix_error)


func _format_bandwidth(iface: DeviceInterface) -> String:
	if iface.bandwidth_kbps > 0:
		return "%d Kbps" % iface.bandwidth_kbps
	if iface.bandwidth_mbps > 0:
		return "%d Mbps" % iface.bandwidth_mbps
	return ""


func _duplex_label(mode: String) -> String:
	match mode:
		DeviceInterface.DUPLEX_HALF:
			return "Half Duplex"
		DeviceInterface.DUPLEX_AUTO:
			return "Auto"
		_:
			return "Full Duplex"


func _set_status(text: String, is_error: bool = false, success: bool = false) -> void:
	ConfigStyles.set_status(status_label, text, is_error, success)


func _apply_styles() -> void:
	add_theme_stylebox_override("panel", ConfigStyles.content_panel())
	header_panel.add_theme_stylebox_override("panel", ConfigStyles.header_panel())
	ipv4_panel.add_theme_stylebox_override("panel", ConfigStyles.section_panel())
	ipv6_panel.add_theme_stylebox_override("panel", ConfigStyles.section_panel())

	ConfigStyles.apply_bold_label(header_label, 16)
	ConfigStyles.apply_status_label(status_label)
	ConfigStyles.apply_bold_label(
		$Root/VBox/BodyScroll/Body/IPv4Panel/IPv4Margin/IPv4VBox/IPv4Title,
		13
	)
	ConfigStyles.apply_bold_label(
		$Root/VBox/BodyScroll/Body/IPv6Panel/IPv6Margin/IPv6VBox/IPv6Title,
		13
	)

	for label in _get_labels():
		ConfigStyles.apply_label(label)
	ConfigStyles.apply_label(bandwidth_value, 13, true)

	ConfigStyles.apply_plain_checkbox(port_status_check)
	ConfigStyles.apply_checkbox(duplex_check)
	ConfigStyles.apply_checkbox(ipv6_automatic)
	ConfigStyles.apply_checkbox(ipv6_static)

	for edit in [ipv4_edit, mask_edit, ipv6_edit, prefix_edit, link_local_edit]:
		ConfigStyles.apply_line_edit(edit)


func _get_labels() -> Array[Label]:
	return [
		$Root/VBox/BodyScroll/Body/TopGrid/PortStatusLabel,
		$Root/VBox/BodyScroll/Body/TopGrid/BandwidthLabel,
		$Root/VBox/BodyScroll/Body/TopGrid/DuplexLabel,
		$Root/VBox/BodyScroll/Body/IPv4Panel/IPv4Margin/IPv4VBox/IPv4Fields/IPv4Label,
		$Root/VBox/BodyScroll/Body/IPv4Panel/IPv4Margin/IPv4VBox/IPv4Fields/MaskLabel,
		$Root/VBox/BodyScroll/Body/IPv6Panel/IPv6Margin/IPv6VBox/IPv6Fields/IPv6Label,
		$Root/VBox/BodyScroll/Body/IPv6Panel/IPv6Margin/IPv6VBox/IPv6Fields/LinkLocalLabel,
		$Root/VBox/BodyScroll/Body/IPv6Panel/IPv6Margin/IPv6VBox/IPv6Fields/IPv6AddressRow/PrefixSlash,
	]
