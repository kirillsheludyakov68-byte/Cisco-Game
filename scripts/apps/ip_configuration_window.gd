extends ScrollContainer
class_name IPConfigurationWindow

@onready var content: VBoxContainer = $Content
@onready var interface_panel: PanelContainer = $Content/InterfacePanel
@onready var interface_label: Label = $Content/InterfacePanel/InterfaceMargin/InterfaceRow/InterfaceLabel
@onready var interface_option: OptionButton = $Content/InterfacePanel/InterfaceMargin/InterfaceRow/InterfaceOption
@onready var ipv4_panel: PanelContainer = $Content/IPv4Panel
@onready var ipv4_title: Label = $Content/IPv4Panel/IPv4Margin/IPv4VBox/IPv4Title
@onready var ipv4_dhcp: CheckBox = $Content/IPv4Panel/IPv4Margin/IPv4VBox/IPv4ModeRow/IPv4Dhcp
@onready var ipv4_static: CheckBox = $Content/IPv4Panel/IPv4Margin/IPv4VBox/IPv4ModeRow/IPv4Static
@onready var ipv4_address_label: Label = $Content/IPv4Panel/IPv4Margin/IPv4VBox/IPv4Grid/IPv4AddressLabel
@onready var ipv4_address_edit: LineEdit = $Content/IPv4Panel/IPv4Margin/IPv4VBox/IPv4Grid/IPv4AddressEdit
@onready var subnet_mask_label: Label = $Content/IPv4Panel/IPv4Margin/IPv4VBox/IPv4Grid/SubnetMaskLabel
@onready var subnet_mask_edit: LineEdit = $Content/IPv4Panel/IPv4Margin/IPv4VBox/IPv4Grid/SubnetMaskEdit
@onready var gateway_label: Label = $Content/IPv4Panel/IPv4Margin/IPv4VBox/IPv4Grid/GatewayLabel
@onready var gateway_edit: LineEdit = $Content/IPv4Panel/IPv4Margin/IPv4VBox/IPv4Grid/GatewayEdit
@onready var dns_label: Label = $Content/IPv4Panel/IPv4Margin/IPv4VBox/IPv4Grid/DnsLabel
@onready var dns_edit: LineEdit = $Content/IPv4Panel/IPv4Margin/IPv4VBox/IPv4Grid/DnsEdit

@onready var ipv6_panel: PanelContainer = $Content/IPv6Panel
@onready var ipv6_title: Label = $Content/IPv6Panel/IPv6Margin/IPv6VBox/IPv6Title
@onready var ipv6_automatic: CheckBox = $Content/IPv6Panel/IPv6Margin/IPv6VBox/IPv6ModeRow/IPv6Automatic
@onready var ipv6_static: CheckBox = $Content/IPv6Panel/IPv6Margin/IPv6VBox/IPv6ModeRow/IPv6Static
@onready var ipv6_address_label: Label = $Content/IPv6Panel/IPv6Margin/IPv6VBox/IPv6Grid/IPv6AddressLabel
@onready var ipv6_address_edit: LineEdit = $Content/IPv6Panel/IPv6Margin/IPv6VBox/IPv6Grid/IPv6AddressEdit
@onready var prefix_label: Label = $Content/IPv6Panel/IPv6Margin/IPv6VBox/IPv6Grid/PrefixLabel
@onready var prefix_edit: LineEdit = $Content/IPv6Panel/IPv6Margin/IPv6VBox/IPv6Grid/PrefixEdit
@onready var ipv6_gateway_label: Label = $Content/IPv6Panel/IPv6Margin/IPv6VBox/IPv6Grid/IPv6GatewayLabel
@onready var ipv6_gateway_edit: LineEdit = $Content/IPv6Panel/IPv6Margin/IPv6VBox/IPv6Grid/IPv6GatewayEdit
@onready var ipv6_dns_label: Label = $Content/IPv6Panel/IPv6Margin/IPv6VBox/IPv6Grid/IPv6DnsLabel
@onready var ipv6_dns_edit: LineEdit = $Content/IPv6Panel/IPv6Margin/IPv6VBox/IPv6Grid/IPv6DnsEdit
@onready var link_local_label: Label = $Content/IPv6Panel/IPv6Margin/IPv6VBox/IPv6Grid/LinkLocalLabel
@onready var link_local_edit: LineEdit = $Content/IPv6Panel/IPv6Margin/IPv6VBox/IPv6Grid/LinkLocalEdit
@onready var mac_label: Label = $Content/IPv6Panel/IPv6Margin/IPv6VBox/IPv6Grid/MacLabel
@onready var mac_edit: LineEdit = $Content/IPv6Panel/IPv6Margin/IPv6VBox/IPv6Grid/MacEdit
@onready var status_label: Label = $Content/StatusLabel

var device: Device = null
var network_interface: DeviceInterface = null

var _selected_interface_name := ""
var _updating := false
var _ipv4_group := ButtonGroup.new()
var _ipv6_group := ButtonGroup.new()


func _ready() -> void:
	_apply_styles()
	_setup_radio_groups()
	_connect_fields()
	_sync_controls()


func setup(device_value: Device) -> void:
	if device == device_value:
		activate()
		return
	_disconnect_device()
	device = device_value
	_selected_interface_name = ""
	if device != null:
		device.configuration_changed.connect(_on_device_configuration_changed)
		device.interfaces_changed.connect(_on_device_interfaces_changed)
		var primary := device.get_primary_interface()
		if primary != null:
			_selected_interface_name = primary.interface_name
	refresh()


func activate() -> void:
	if device != null:
		refresh()


func refresh() -> void:
	if not is_inside_tree():
		return

	_updating = true
	_populate_interfaces()
	_sync_controls()
	_updating = false


func commit_pending() -> void:
	if device == null or network_interface == null or _updating:
		return
	if network_interface.ipv4_mode == NetworkSettings.IPV4_STATIC:
		_commit_ipv4()
	if network_interface.ipv6_mode == NetworkSettings.IPV6_STATIC:
		_commit_ipv6()


func _apply_styles() -> void:
	interface_panel.add_theme_stylebox_override("panel", ConfigStyles.section_panel())
	ipv4_panel.add_theme_stylebox_override("panel", ConfigStyles.section_panel())
	ipv6_panel.add_theme_stylebox_override("panel", ConfigStyles.section_panel())

	ConfigStyles.apply_label(interface_label)
	ConfigStyles.apply_bold_label(ipv4_title, 14)
	ConfigStyles.apply_bold_label(ipv6_title, 14)
	ConfigStyles.apply_label(ipv4_address_label)
	ConfigStyles.apply_label(subnet_mask_label)
	ConfigStyles.apply_label(gateway_label)
	ConfigStyles.apply_label(dns_label)
	ConfigStyles.apply_label(ipv6_address_label)
	ConfigStyles.apply_label(prefix_label)
	ConfigStyles.apply_label(ipv6_gateway_label)
	ConfigStyles.apply_label(ipv6_dns_label)
	ConfigStyles.apply_label(link_local_label)
	ConfigStyles.apply_label(mac_label)
	ConfigStyles.apply_status_label(status_label)

	ConfigStyles.apply_option_button(interface_option)
	ConfigStyles.apply_checkbox(ipv4_dhcp)
	ConfigStyles.apply_checkbox(ipv4_static)
	ConfigStyles.apply_checkbox(ipv6_automatic)
	ConfigStyles.apply_checkbox(ipv6_static)

	for edit in [
		ipv4_address_edit, subnet_mask_edit, gateway_edit, dns_edit,
		ipv6_address_edit, prefix_edit, ipv6_gateway_edit, ipv6_dns_edit,
		link_local_edit, mac_edit,
	]:
		ConfigStyles.apply_line_edit(edit)


func _setup_radio_groups() -> void:
	ipv4_dhcp.button_group = _ipv4_group
	ipv4_static.button_group = _ipv4_group
	ipv6_automatic.button_group = _ipv6_group
	ipv6_static.button_group = _ipv6_group

	ipv4_dhcp.toggled.connect(_on_ipv4_mode_toggled.bind(NetworkSettings.IPV4_DHCP))
	ipv4_static.toggled.connect(_on_ipv4_mode_toggled.bind(NetworkSettings.IPV4_STATIC))
	ipv6_automatic.toggled.connect(_on_ipv6_mode_toggled.bind(NetworkSettings.IPV6_AUTOMATIC))
	ipv6_static.toggled.connect(_on_ipv6_mode_toggled.bind(NetworkSettings.IPV6_STATIC))


func _connect_fields() -> void:
	interface_option.item_selected.connect(_on_interface_selected)

	for edit in [ipv4_address_edit, subnet_mask_edit, gateway_edit, dns_edit]:
		edit.text_submitted.connect(_on_ipv4_field_submitted)
		edit.focus_exited.connect(_on_ipv4_focus_exited)

	for edit in [ipv6_address_edit, prefix_edit, ipv6_gateway_edit, ipv6_dns_edit]:
		edit.text_submitted.connect(_on_ipv6_field_submitted)
		edit.focus_exited.connect(_on_ipv6_focus_exited)


func _disconnect_device() -> void:
	if device == null or not is_instance_valid(device):
		return
	if device.configuration_changed.is_connected(_on_device_configuration_changed):
		device.configuration_changed.disconnect(_on_device_configuration_changed)
	if device.interfaces_changed.is_connected(_on_device_interfaces_changed):
		device.interfaces_changed.disconnect(_on_device_interfaces_changed)


func _exit_tree() -> void:
	_disconnect_device()


func _on_device_configuration_changed() -> void:
	if not _updating:
		refresh()


func _on_device_interfaces_changed() -> void:
	if not _updating:
		refresh()


func _populate_interfaces() -> void:
	interface_option.clear()
	network_interface = null

	if device == null:
		interface_option.disabled = true
		_selected_interface_name = ""
		return

	var names := device.get_interface_names()
	for interface_name in names:
		interface_option.add_item(interface_name)

	if names.is_empty():
		interface_option.disabled = true
		_selected_interface_name = ""
		return

	interface_option.disabled = false
	if not names.has(_selected_interface_name):
		_selected_interface_name = names[0]

	for index in interface_option.item_count:
		if interface_option.get_item_text(index) == _selected_interface_name:
			interface_option.select(index)
			break

	network_interface = device.get_interface(_selected_interface_name)


func _sync_controls() -> void:
	if network_interface == null:
		_set_all_editable(false)
		ipv4_dhcp.set_pressed_no_signal(false)
		ipv4_static.set_pressed_no_signal(false)
		ipv6_automatic.set_pressed_no_signal(false)
		ipv6_static.set_pressed_no_signal(false)
		ipv4_address_edit.text = ""
		subnet_mask_edit.text = ""
		gateway_edit.text = ""
		dns_edit.text = ""
		ipv6_address_edit.text = ""
		prefix_edit.text = ""
		ipv6_gateway_edit.text = ""
		ipv6_dns_edit.text = ""
		link_local_edit.text = ""
		mac_edit.text = ""
		_set_status("Нет сетевых интерфейсов. Установите модуль в Computer → Config.", true)
		return

	var iface := network_interface
	var ns := device.network_settings
	ipv4_dhcp.set_pressed_no_signal(iface.ipv4_mode == NetworkSettings.IPV4_DHCP)
	ipv4_static.set_pressed_no_signal(iface.ipv4_mode == NetworkSettings.IPV4_STATIC)
	ipv6_automatic.set_pressed_no_signal(iface.ipv6_mode == NetworkSettings.IPV6_AUTOMATIC)
	ipv6_static.set_pressed_no_signal(iface.ipv6_mode == NetworkSettings.IPV6_STATIC)

	ipv4_address_edit.text = iface.ipv4_address
	subnet_mask_edit.text = iface.subnet_mask
	gateway_edit.text = ns.gateway_ipv4
	dns_edit.text = ns.dns_ipv4
	ipv6_address_edit.text = iface.ipv6_address
	prefix_edit.text = str(iface.ipv6_prefix)
	ipv6_gateway_edit.text = ns.gateway_ipv6
	ipv6_dns_edit.text = ns.dns_ipv6
	link_local_edit.text = iface.link_local_ipv6
	mac_edit.text = iface.get_mac_cisco()

	var ipv4_editable := iface.ipv4_mode == NetworkSettings.IPV4_STATIC
	var ipv6_editable := iface.ipv6_mode == NetworkSettings.IPV6_STATIC
	ConfigStyles.set_line_edit_editable(ipv4_address_edit, ipv4_editable)
	ConfigStyles.set_line_edit_editable(subnet_mask_edit, ipv4_editable)
	ConfigStyles.set_line_edit_editable(gateway_edit, ipv4_editable)
	ConfigStyles.set_line_edit_editable(dns_edit, ipv4_editable)
	ConfigStyles.set_line_edit_editable(ipv6_address_edit, ipv6_editable)
	ConfigStyles.set_line_edit_editable(prefix_edit, ipv6_editable)
	ConfigStyles.set_line_edit_editable(ipv6_gateway_edit, ipv6_editable)
	ConfigStyles.set_line_edit_editable(ipv6_dns_edit, ipv6_editable)
	ConfigStyles.set_line_edit_editable(link_local_edit, false)
	ConfigStyles.set_line_edit_editable(mac_edit, false)

	_clear_field_errors()
	_set_status("")


func _set_all_editable(editable: bool) -> void:
	for edit in [
		ipv4_address_edit, subnet_mask_edit, gateway_edit, dns_edit,
		ipv6_address_edit, prefix_edit, ipv6_gateway_edit, ipv6_dns_edit,
	]:
		ConfigStyles.set_line_edit_editable(edit, editable)


func _on_interface_selected(index: int) -> void:
	if index < 0 or index >= interface_option.item_count:
		return
	_selected_interface_name = interface_option.get_item_text(index)
	network_interface = device.get_interface(_selected_interface_name) if device != null else null
	_updating = true
	_sync_controls()
	_updating = false


func _on_ipv4_mode_toggled(pressed: bool, mode: String) -> void:
	if _updating or not pressed or device == null or network_interface == null:
		return
	_updating = true
	device.set_interface_ipv4_mode(network_interface.interface_name, mode)
	device.set_ipv4_mode(mode)
	_sync_controls()
	_updating = false
	if mode == NetworkSettings.IPV4_DHCP:
		_set_status("Режим IPv4: DHCP. Автоматическое получение адреса в симуляторе не выполняется; сохранённые поля не являются арендой.", false, false)
	else:
		_set_status("Режим IPv4: Static.", false, true)


func _on_ipv6_mode_toggled(pressed: bool, mode: String) -> void:
	if _updating or not pressed or device == null or network_interface == null:
		return
	_updating = true
	device.set_interface_ipv6_mode(network_interface.interface_name, mode)
	device.set_ipv6_mode(mode)
	_sync_controls()
	_updating = false
	if mode == NetworkSettings.IPV6_AUTOMATIC:
		_set_status("Режим IPv6: Automatic. SLAAC/автоматическая настройка в симуляторе не выполняются.", false, false)
	else:
		_set_status("Режим IPv6: Static.", false, true)


func _on_ipv4_field_submitted(_text: String) -> void:
	_commit_ipv4()


func _on_ipv4_focus_exited() -> void:
	_commit_ipv4()


func _on_ipv6_field_submitted(_text: String) -> void:
	_commit_ipv6()


func _on_ipv6_focus_exited() -> void:
	_commit_ipv6()


func _commit_ipv4() -> bool:
	if _updating or device == null or network_interface == null:
		return false
	if network_interface.ipv4_mode != NetworkSettings.IPV4_STATIC:
		return true

	var ipv4 := ipv4_address_edit.text.strip_edges()
	var mask := subnet_mask_edit.text.strip_edges()
	var gateway := gateway_edit.text.strip_edges()
	var dns := dns_edit.text.strip_edges()

	_clear_field_errors()
	var has_ipv4 := not ipv4.is_empty()
	var has_mask := not mask.is_empty()
	var ipv4_error := has_ipv4 and not NetworkValidation.is_valid_ipv4(ipv4)
	var mask_error := has_mask and not NetworkValidation.is_valid_subnet_mask(mask)
	var gateway_error := not gateway.is_empty() and not NetworkValidation.is_valid_ipv4(gateway)
	var dns_error := not dns.is_empty() and not NetworkValidation.is_valid_ipv4(dns)
	var missing_pair := has_ipv4 != has_mask

	ConfigStyles.mark_line_edit_error(ipv4_address_edit, ipv4_error or missing_pair)
	ConfigStyles.mark_line_edit_error(subnet_mask_edit, mask_error or missing_pair)
	ConfigStyles.mark_line_edit_error(gateway_edit, gateway_error)
	ConfigStyles.mark_line_edit_error(dns_edit, dns_error)

	if missing_pair:
		_set_status("Для IPv4 нужно заполнить и адрес, и маску подсети.", true)
		return false
	if ipv4_error or mask_error:
		_set_status("Проверьте IPv4-адрес и маску подсети.", true)
		return false
	if gateway_error or dns_error:
		_set_status("Проверьте Gateway/DNS IPv4: нужны четыре октета 0–255.", true)
		return false

	_updating = true
	var saved := device.set_interface_ipv4_config(network_interface.interface_name, ipv4, mask)
	if saved:
		device.set_ipv4_gateway_dns(gateway, dns)
	_updating = false

	if not saved:
		_set_status("Не удалось сохранить IPv4-конфигурацию.", true)
		return false

	ipv4_address_edit.text = ipv4
	subnet_mask_edit.text = mask
	gateway_edit.text = gateway
	dns_edit.text = dns
	_clear_field_errors()
	_set_status("IPv4-конфигурация сохранена.", false, true)
	return true


func _commit_ipv6() -> bool:
	if _updating or device == null or network_interface == null:
		return false
	if network_interface.ipv6_mode != NetworkSettings.IPV6_STATIC:
		return true

	var ipv6 := ipv6_address_edit.text.strip_edges()
	var prefix_text := prefix_edit.text.strip_edges()
	var gateway := ipv6_gateway_edit.text.strip_edges()
	var dns := ipv6_dns_edit.text.strip_edges()

	_clear_field_errors()
	var ipv6_error := not ipv6.is_empty() and not NetworkValidation.is_valid_ipv6(ipv6)
	var prefix_error := not prefix_text.is_empty() and not NetworkValidation.is_valid_ipv6_prefix(prefix_text)
	var gateway_error := not gateway.is_empty() and not NetworkValidation.is_valid_ipv6(gateway)
	var dns_error := not dns.is_empty() and not NetworkValidation.is_valid_ipv6(dns)

	ConfigStyles.mark_line_edit_error(ipv6_address_edit, ipv6_error)
	ConfigStyles.mark_line_edit_error(prefix_edit, prefix_error)
	ConfigStyles.mark_line_edit_error(ipv6_gateway_edit, gateway_error)
	ConfigStyles.mark_line_edit_error(ipv6_dns_edit, dns_error)

	if ipv6_error:
		_set_status("Проверьте IPv6-адрес: поддерживается сокращённая запись через «::».", true)
		return false
	if prefix_error:
		_set_status("Prefix Length должен быть числом от 0 до 128.", true)
		return false
	if gateway_error or dns_error:
		_set_status("Проверьте Gateway/DNS IPv6.", true)
		return false

	var prefix := network_interface.ipv6_prefix
	if not prefix_text.is_empty():
		prefix = int(prefix_text)

	_updating = true
	var saved := device.set_interface_ipv6_config(network_interface.interface_name, ipv6, prefix)
	if saved:
		device.set_ipv6_gateway_dns(gateway, dns)
	_updating = false

	if not saved:
		_set_status("Не удалось сохранить IPv6-конфигурацию.", true)
		return false

	ipv6_address_edit.text = ipv6
	prefix_edit.text = str(prefix)
	ipv6_gateway_edit.text = gateway
	ipv6_dns_edit.text = dns
	link_local_edit.text = network_interface.link_local_ipv6
	_clear_field_errors()
	_set_status("IPv6-конфигурация сохранена.", false, true)
	return true


func _clear_field_errors() -> void:
	for edit in [
		ipv4_address_edit, subnet_mask_edit, gateway_edit, dns_edit,
		ipv6_address_edit, prefix_edit, ipv6_gateway_edit, ipv6_dns_edit,
	]:
		ConfigStyles.mark_line_edit_error(edit, false)
		ConfigStyles.set_line_edit_editable(edit, edit.editable)


func _set_status(text: String, is_error: bool = false, success: bool = false) -> void:
	ConfigStyles.set_status(status_label, text, is_error, success)
