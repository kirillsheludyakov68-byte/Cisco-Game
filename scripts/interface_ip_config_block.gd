extends VBoxContainer
class_name InterfaceIpConfigBlock

signal status_changed(text: String, is_error: bool, success: bool)

@onready var ipv4_panel: PanelContainer = $IPv4Panel
@onready var ipv4_dhcp: CheckBox = $IPv4Panel/IPv4Margin/IPv4VBox/IPv4ModeRow/IPv4Dhcp
@onready var ipv4_static: CheckBox = $IPv4Panel/IPv4Margin/IPv4VBox/IPv4ModeRow/IPv4Static
@onready var ipv4_edit: LineEdit = $IPv4Panel/IPv4Margin/IPv4VBox/IPv4Fields/IPv4Edit
@onready var mask_edit: LineEdit = $IPv4Panel/IPv4Margin/IPv4VBox/IPv4Fields/MaskEdit

@onready var ipv6_panel: PanelContainer = $IPv6Panel
@onready var ipv6_automatic: CheckBox = $IPv6Panel/IPv6Margin/IPv6VBox/IPv6ModeRow/IPv6Automatic
@onready var ipv6_static: CheckBox = $IPv6Panel/IPv6Margin/IPv6VBox/IPv6ModeRow/IPv6Static
@onready var ipv6_edit: LineEdit = $IPv6Panel/IPv6Margin/IPv6VBox/IPv6Fields/IPv6Edit
@onready var link_local_edit: LineEdit = $IPv6Panel/IPv6Margin/IPv6VBox/IPv6Fields/LinkLocalEdit

var device: Device = null
var network_interface: DeviceInterface = null

var _updating := false
var _ipv4_group: ButtonGroup
var _ipv6_group: ButtonGroup


func _ready() -> void:
	_apply_styles()
	_setup_groups()
	_connect_signals()


func setup(dev: Device, iface: DeviceInterface) -> void:
	device = dev
	network_interface = iface
	refresh()


func refresh() -> void:
	_updating = true
	clear_field_errors()
	_set_status("")

	if network_interface == null:
		ipv4_dhcp.button_pressed = false
		ipv4_static.button_pressed = false
		ipv4_edit.text = ""
		mask_edit.text = ""
		ipv6_automatic.button_pressed = false
		ipv6_static.button_pressed = false
		ipv6_edit.text = ""
		link_local_edit.text = ""
		_set_ipv4_editable(false)
		_set_ipv6_editable(false)
		_updating = false
		return

	ipv4_dhcp.button_pressed = network_interface.ipv4_mode == NetworkSettings.IPV4_DHCP
	ipv4_static.button_pressed = network_interface.ipv4_mode == NetworkSettings.IPV4_STATIC
	ipv4_edit.text = network_interface.ipv4_address
	mask_edit.text = network_interface.subnet_mask

	ipv6_automatic.button_pressed = network_interface.ipv6_mode == NetworkSettings.IPV6_AUTOMATIC
	ipv6_static.button_pressed = network_interface.ipv6_mode == NetworkSettings.IPV6_STATIC
	ipv6_edit.text = network_interface.ipv6_address
	link_local_edit.text = network_interface.link_local_ipv6

	_set_ipv4_editable(network_interface.ipv4_mode == NetworkSettings.IPV4_STATIC)
	_set_ipv6_editable(network_interface.ipv6_mode == NetworkSettings.IPV6_STATIC)
	_updating = false


func commit_pending() -> void:
	if device == null or network_interface == null:
		return
	if network_interface.ipv4_mode == NetworkSettings.IPV4_STATIC:
		_commit_ipv4()
	if network_interface.ipv6_mode == NetworkSettings.IPV6_STATIC:
		_commit_ipv6()


func clear_field_errors() -> void:
	_set_ipv4_field_errors(false, false)
	_set_ipv6_field_error(false)


func _setup_groups() -> void:
	_ipv4_group = _make_button_group()
	_ipv6_group = _make_button_group()
	ipv4_dhcp.button_group = _ipv4_group
	ipv4_static.button_group = _ipv4_group
	ipv6_automatic.button_group = _ipv6_group
	ipv6_static.button_group = _ipv6_group


func _make_button_group() -> ButtonGroup:
	var group := ButtonGroup.new()
	group.allow_unpress = false
	return group


func _connect_signals() -> void:
	ipv4_dhcp.toggled.connect(_on_ipv4_mode_toggled.bind(NetworkSettings.IPV4_DHCP))
	ipv4_static.toggled.connect(_on_ipv4_mode_toggled.bind(NetworkSettings.IPV4_STATIC))
	ipv6_automatic.toggled.connect(_on_ipv6_mode_toggled.bind(NetworkSettings.IPV6_AUTOMATIC))
	ipv6_static.toggled.connect(_on_ipv6_mode_toggled.bind(NetworkSettings.IPV6_STATIC))

	ipv4_edit.text_submitted.connect(_on_ipv4_submitted)
	ipv4_edit.focus_exited.connect(_on_ipv4_focus_exited)
	mask_edit.text_submitted.connect(_on_ipv4_submitted)
	mask_edit.focus_exited.connect(_on_ipv4_focus_exited)
	ipv6_edit.text_submitted.connect(_on_ipv6_submitted)
	ipv6_edit.focus_exited.connect(_on_ipv6_focus_exited)


func _on_ipv4_mode_toggled(pressed: bool, mode: String) -> void:
	if _updating or not pressed or device == null or network_interface == null:
		return
	device.set_interface_ipv4_mode(network_interface.interface_name, mode)
	_set_ipv4_editable(mode == NetworkSettings.IPV4_STATIC)
	if mode == NetworkSettings.IPV4_DHCP:
		_set_status("Режим IPv4: DHCP. Получение адреса по DHCP не моделируется.", false, true)
	else:
		_set_status("Режим IPv4: Static.", false, true)


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
	if network_interface.ipv4_mode != NetworkSettings.IPV4_STATIC:
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
		_set_status("Не удалось сохранить IPv4-настройки интерфейса.", true)
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
	var ipv6_error := not ipv6.is_empty() and not NetworkValidation.is_valid_ipv6(ipv6)
	_set_ipv6_field_error(ipv6_error)

	if ipv6_error:
		_set_status("Проверьте IPv6-адрес: поддерживается полная и сокращённая запись через «::».", true)
		return

	if not device.set_interface_ipv6_config(network_interface.interface_name, ipv6):
		_set_status("Не удалось сохранить IPv6-настройки интерфейса.", true)
		return

	network_interface = device.get_interface(network_interface.interface_name)
	ipv6_edit.text = ipv6
	_set_status("Настройки IPv6 сохранены.", false, true)


func _set_ipv4_editable(enabled: bool) -> void:
	ConfigStyles.set_line_edit_editable(ipv4_edit, enabled)
	ConfigStyles.set_line_edit_editable(mask_edit, enabled)


func _set_ipv6_editable(enabled: bool) -> void:
	ConfigStyles.set_line_edit_editable(ipv6_edit, enabled)


func _set_ipv4_field_errors(ipv4_error: bool, mask_error: bool) -> void:
	ConfigStyles.mark_line_edit_error(ipv4_edit, ipv4_error)
	ConfigStyles.mark_line_edit_error(mask_edit, mask_error)


func _set_ipv6_field_error(ipv6_error: bool) -> void:
	ConfigStyles.mark_line_edit_error(ipv6_edit, ipv6_error)


func _set_status(text: String, is_error: bool = false, success: bool = false) -> void:
	status_changed.emit(text, is_error, success)


func _apply_styles() -> void:
	ipv4_panel.add_theme_stylebox_override("panel", ConfigStyles.section_panel())
	ipv6_panel.add_theme_stylebox_override("panel", ConfigStyles.section_panel())

	ConfigStyles.apply_bold_label(
		$IPv4Panel/IPv4Margin/IPv4VBox/IPv4Title, 13
	)
	ConfigStyles.apply_bold_label(
		$IPv6Panel/IPv6Margin/IPv6VBox/IPv6Title, 13
	)

	for label in _get_labels():
		ConfigStyles.apply_label(label)
	for check in [ipv4_dhcp, ipv4_static, ipv6_automatic, ipv6_static]:
		ConfigStyles.apply_checkbox(check)
	for edit in [ipv4_edit, mask_edit, ipv6_edit, link_local_edit]:
		ConfigStyles.apply_line_edit(edit)


func _get_labels() -> Array[Label]:
	return [
		$IPv4Panel/IPv4Margin/IPv4VBox/IPv4Fields/IPv4Label,
		$IPv4Panel/IPv4Margin/IPv4VBox/IPv4Fields/MaskLabel,
		$IPv6Panel/IPv6Margin/IPv6VBox/IPv6Fields/IPv6Label,
		$IPv6Panel/IPv6Margin/IPv6VBox/IPv6Fields/LinkLocalLabel,
	]
