extends PanelContainer
class_name CellularConfigPage

# Страница встроенного интерфейса 3G/4G Cell1.
# В отличие от Ethernet-страниц здесь нет переключателей Static/DHCP:
# сотовый интерфейс получает адрес от провайдера, а кнопки Refresh
# перечитывают результат математической модели DHCP.

@onready var header_panel: PanelContainer = $Root/VBox/HeaderPanel
@onready var header_label: Label = $Root/VBox/HeaderPanel/HeaderLabel
@onready var status_label: Label = $Root/VBox/StatusLabel

@onready var port_status_check: CheckBox = $Root/VBox/BodyScroll/Body/TopGrid/PortStatusCheck
@onready var provider_edit: LineEdit = $Root/VBox/BodyScroll/Body/TopGrid/ProviderEdit

@onready var ipv4_panel: PanelContainer = $Root/VBox/BodyScroll/Body/IPv4Panel
@onready var ipv4_edit: LineEdit = $Root/VBox/BodyScroll/Body/IPv4Panel/IPv4Margin/IPv4VBox/IPv4Grid/IPv4AddressEdit
@onready var mask_edit: LineEdit = $Root/VBox/BodyScroll/Body/IPv4Panel/IPv4Margin/IPv4VBox/IPv4Grid/SubnetMaskEdit
@onready var ipv4_refresh_button: Button = $Root/VBox/BodyScroll/Body/IPv4Panel/IPv4Margin/IPv4VBox/IPv4RefreshRow/IPv4RefreshButton

@onready var ipv6_panel: PanelContainer = $Root/VBox/BodyScroll/Body/IPv6Panel
@onready var ipv6_edit: LineEdit = $Root/VBox/BodyScroll/Body/IPv6Panel/IPv6Margin/IPv6VBox/IPv6Grid/IPv6AddressRow/IPv6AddressEdit
@onready var prefix_edit: LineEdit = $Root/VBox/BodyScroll/Body/IPv6Panel/IPv6Margin/IPv6VBox/IPv6Grid/IPv6AddressRow/PrefixEdit
@onready var link_local_edit: LineEdit = $Root/VBox/BodyScroll/Body/IPv6Panel/IPv6Margin/IPv6VBox/IPv6Grid/LinkLocalEdit
@onready var ipv6_refresh_button: Button = $Root/VBox/BodyScroll/Body/IPv6Panel/IPv6Margin/IPv6VBox/IPv6RefreshRow/IPv6RefreshButton

var device: Device = null
var network_interface: DeviceInterface = null
var module_name: String = ""

var _updating := false


func _ready() -> void:
	_apply_styles()
	_connect_signals()


func setup(dev: Device, iface: DeviceInterface, source_module: String = "") -> void:
	device = dev
	network_interface = iface
	module_name = source_module
	refresh()


func refresh() -> void:
	_updating = true
	ConfigStyles.mark_line_edit_error(provider_edit, false)
	_set_status("")

	if network_interface == null:
		header_label.text = "3G/4G Cell1"
		port_status_check.disabled = true
		port_status_check.button_pressed = false
		provider_edit.text = ""
		ConfigStyles.set_line_edit_editable(provider_edit, false)
		ipv4_edit.text = ""
		mask_edit.text = ""
		ipv6_edit.text = ""
		prefix_edit.text = ""
		link_local_edit.text = ""
		ipv4_refresh_button.disabled = true
		ipv6_refresh_button.disabled = true
		_updating = false
		return

	header_label.text = network_interface.interface_name
	port_status_check.disabled = false
	port_status_check.button_pressed = network_interface.enabled
	provider_edit.text = network_interface.provider_name
	ConfigStyles.set_line_edit_editable(provider_edit, true)

	ipv4_edit.text = network_interface.ipv4_address
	mask_edit.text = network_interface.subnet_mask
	ConfigStyles.set_line_edit_editable(ipv4_edit, false)
	ConfigStyles.set_line_edit_editable(mask_edit, false)

	ipv6_edit.text = network_interface.ipv6_address
	prefix_edit.text = str(network_interface.ipv6_prefix)
	link_local_edit.text = network_interface.link_local_ipv6
	ConfigStyles.set_line_edit_editable(ipv6_edit, false)
	ConfigStyles.set_line_edit_editable(prefix_edit, false)
	ConfigStyles.set_line_edit_editable(link_local_edit, false)

	ipv4_refresh_button.disabled = false
	ipv6_refresh_button.disabled = false
	_updating = false


func commit_pending() -> void:
	_commit_provider()


func _connect_signals() -> void:
	port_status_check.toggled.connect(_on_port_status_toggled)
	provider_edit.text_submitted.connect(_on_provider_submitted)
	provider_edit.focus_exited.connect(_on_provider_focus_exited)
	ipv4_refresh_button.pressed.connect(_on_ipv4_refresh_pressed)
	ipv6_refresh_button.pressed.connect(_on_ipv6_refresh_pressed)


func _on_port_status_toggled(pressed: bool) -> void:
	if _updating or device == null or network_interface == null:
		return
	device.set_interface_enabled(network_interface.interface_name, pressed)
	_set_status(
		"Интерфейс включён." if pressed else "Интерфейс выключен.",
		false,
		pressed
	)


func _on_provider_submitted(_text: String) -> void:
	_commit_provider()


func _on_provider_focus_exited() -> void:
	_commit_provider()


func _commit_provider() -> bool:
	if _updating or device == null or network_interface == null:
		return false

	var value := provider_edit.text.strip_edges()
	if value.is_empty() or value.length() > 64:
		ConfigStyles.mark_line_edit_error(provider_edit, true)
		_set_status("Имя провайдера должно содержать от 1 до 64 символов.", true)
		return false

	if not device.set_interface_provider_name(network_interface.interface_name, value):
		ConfigStyles.mark_line_edit_error(provider_edit, true)
		_set_status("Не удалось сохранить имя провайдера.", true)
		return false

	ConfigStyles.mark_line_edit_error(provider_edit, false)
	provider_edit.text = value
	network_interface = device.get_interface(network_interface.interface_name)
	_set_status("Имя провайдера сохранено.", false, true)
	return true


func _on_ipv4_refresh_pressed() -> void:
	if device == null or network_interface == null:
		return
	_refresh_dhcp_leases()
	refresh()
	if NetworkValidation.is_valid_ipv4(network_interface.ipv4_address):
		_set_status(
			"DHCP-аренда обновлена: %s." % network_interface.ipv4_address,
			false,
			true
		)
	else:
		_set_status("Ожидание DHCP-аренды от сотового провайдера.", false, false)


func _on_ipv6_refresh_pressed() -> void:
	if device == null or network_interface == null:
		return
	_refresh_dhcp_leases()
	refresh()
	if not network_interface.ipv6_address.is_empty():
		_set_status(
			"IPv6-адрес обновлён: %s." % network_interface.ipv6_address,
			false,
			true
		)
	else:
		_set_status("IPv6-адрес пока не назначен.", false, false)


func _refresh_dhcp_leases() -> void:
	var simulator = get_node_or_null("/root/NetworkSimulator")
	if simulator != null and simulator.has_method("refresh_dhcp_leases"):
		simulator.refresh_dhcp_leases()


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

	ConfigStyles.apply_plain_checkbox(port_status_check)
	for edit in [provider_edit, ipv4_edit, mask_edit, ipv6_edit, prefix_edit, link_local_edit]:
		ConfigStyles.apply_line_edit(edit)
	DesktopStyles.apply_action_button(ipv4_refresh_button)
	DesktopStyles.apply_action_button(ipv6_refresh_button)


func _get_labels() -> Array[Label]:
	return [
		$Root/VBox/BodyScroll/Body/TopGrid/PortStatusLabel,
		$Root/VBox/BodyScroll/Body/TopGrid/ProviderLabel,
		$Root/VBox/BodyScroll/Body/IPv4Panel/IPv4Margin/IPv4VBox/IPv4Grid/IPv4AddressLabel,
		$Root/VBox/BodyScroll/Body/IPv4Panel/IPv4Margin/IPv4VBox/IPv4Grid/SubnetMaskLabel,
		$Root/VBox/BodyScroll/Body/IPv6Panel/IPv6Margin/IPv6VBox/IPv6Grid/IPv6AddressLabel,
		$Root/VBox/BodyScroll/Body/IPv6Panel/IPv6Margin/IPv6VBox/IPv6Grid/LinkLocalLabel,
	]
