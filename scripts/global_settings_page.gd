extends PanelContainer
class_name GlobalSettingsPage

signal interface_selected(interface_name: String)

@onready var header_panel: PanelContainer = $Root/VBox/HeaderPanel
@onready var header_label: Label = $Root/VBox/HeaderPanel/HeaderLabel
@onready var status_label: Label = $Root/VBox/StatusLabel
@onready var display_name_edit: LineEdit = $Root/VBox/BodyScroll/Body/Fields/DisplayNameEdit
@onready var interfaces_option: OptionButton = $Root/VBox/BodyScroll/Body/Fields/InterfacesOption
@onready var ipv4_block: GatewayDnsBlock = $Root/VBox/BodyScroll/Body/IPv4Block
@onready var ipv6_block: GatewayDnsBlock = $Root/VBox/BodyScroll/Body/IPv6Block
@onready var hint_label: Label = $Root/VBox/BodyScroll/Body/HintLabel

var device: Device = null
var selected_interface_name: String = ""


func _ready() -> void:
	_apply_styles()
	display_name_edit.text_submitted.connect(_on_display_name_submitted)
	display_name_edit.focus_exited.connect(_on_display_name_focus_exited)
	interfaces_option.item_selected.connect(_on_interface_selected)
	ipv4_block.mode_selected.connect(_on_ipv4_mode_selected)
	ipv4_block.field_committed.connect(_on_ipv4_field_committed)
	ipv6_block.mode_selected.connect(_on_ipv6_mode_selected)
	ipv6_block.field_committed.connect(_on_ipv6_field_committed)


func setup(dev: Device, interface_name: String = "") -> void:
	device = dev
	selected_interface_name = interface_name
	if selected_interface_name.is_empty() and device != null:
		var primary := device.get_primary_interface()
		if primary != null:
			selected_interface_name = primary.interface_name
	refresh()


func refresh() -> void:
	if device == null:
		return

	display_name_edit.text = device.device_name
	ConfigStyles.mark_line_edit_error(display_name_edit, false)
	_populate_interfaces()
	ipv4_block.set_values(
		device.network_settings.ipv4_mode,
		device.network_settings.gateway_ipv4,
		device.network_settings.dns_ipv4
	)
	ipv6_block.set_values(
		device.network_settings.ipv6_mode,
		device.network_settings.gateway_ipv6,
		device.network_settings.dns_ipv6
	)
	_set_status("")


func set_selected_interface(interface_name: String) -> void:
	selected_interface_name = interface_name
	_select_option_by_text(interface_name)


func commit_pending() -> void:
	if device == null:
		return
	_commit_display_name()
	if ipv4_block.get_mode() == NetworkSettings.IPV4_STATIC:
		_on_ipv4_field_committed("")
	if ipv6_block.get_mode() == NetworkSettings.IPV6_STATIC:
		_on_ipv6_field_committed("")


func _populate_interfaces() -> void:
	interfaces_option.clear()
	for interface_name in device.get_interface_names():
		interfaces_option.add_item(interface_name)

	if interfaces_option.item_count == 0:
		interfaces_option.disabled = true
		selected_interface_name = ""
		return

	interfaces_option.disabled = false
	_select_option_by_text(selected_interface_name)


func _select_option_by_text(interface_name: String) -> void:
	if interfaces_option.item_count == 0:
		return
	for index in interfaces_option.item_count:
		if interfaces_option.get_item_text(index) == interface_name:
			interfaces_option.select(index)
			return
	interfaces_option.select(0)
	selected_interface_name = interfaces_option.get_item_text(0)


func _on_display_name_submitted(_text: String) -> void:
	_commit_display_name()


func _on_display_name_focus_exited() -> void:
	_commit_display_name()


func _commit_display_name() -> void:
	if device == null:
		return

	var value := display_name_edit.text.strip_edges()
	if value.is_empty():
		ConfigStyles.mark_line_edit_error(display_name_edit, true)
		_set_status("Имя устройства не может быть пустым.", true)
		return

	ConfigStyles.mark_line_edit_error(display_name_edit, false)
	display_name_edit.text = value
	if value != device.device_name:
		device.device_name = value
		_set_status("Имя устройства изменено.", false, true)


func _on_interface_selected(index: int) -> void:
	if index < 0 or index >= interfaces_option.item_count:
		return
	selected_interface_name = interfaces_option.get_item_text(index)
	interface_selected.emit(selected_interface_name)


func _on_ipv4_mode_selected(mode: String) -> void:
	if device == null:
		return
	device.set_ipv4_mode(mode)
	_set_status("Режим IPv4: " + ("DHCP" if mode == NetworkSettings.IPV4_DHCP else "Static"), false, true)


func _on_ipv4_field_committed(_field_name: String) -> void:
	if device == null:
		return

	var gateway := ipv4_block.get_gateway_text()
	var dns := ipv4_block.get_dns_text()
	var gateway_error := not gateway.is_empty() and not NetworkValidation.is_valid_ipv4(gateway)
	var dns_error := not dns.is_empty() and not NetworkValidation.is_valid_ipv4(dns)
	ipv4_block.set_field_errors(gateway_error, dns_error)

	if gateway_error or dns_error:
		_set_status("Проверьте IPv4-адреса: нужны четыре октета 0–255, разделённые точками.", true)
		return

	device.set_ipv4_gateway_dns(gateway, dns)
	_set_status("Настройки Gateway/DNS IPv4 сохранены.", false, true)


func _on_ipv6_mode_selected(mode: String) -> void:
	if device == null:
		return
	device.set_ipv6_mode(mode)
	_set_status("Режим IPv6: " + ("Automatic" if mode == NetworkSettings.IPV6_AUTOMATIC else "Static"), false, true)


func _on_ipv6_field_committed(_field_name: String) -> void:
	if device == null:
		return

	var gateway := ipv6_block.get_gateway_text()
	var dns := ipv6_block.get_dns_text()
	var gateway_error := not gateway.is_empty() and not NetworkValidation.is_valid_ipv6(gateway)
	var dns_error := not dns.is_empty() and not NetworkValidation.is_valid_ipv6(dns)
	ipv6_block.set_field_errors(gateway_error, dns_error)

	if gateway_error or dns_error:
		_set_status("Проверьте IPv6-адреса: поддерживается сокращённая запись через «::».", true)
		return

	device.set_ipv6_gateway_dns(gateway, dns)
	_set_status("Настройки Gateway/DNS IPv6 сохранены.", false, true)


func _set_status(text: String, is_error: bool = false, success: bool = false) -> void:
	ConfigStyles.set_status(status_label, text, is_error, success)


func _apply_styles() -> void:
	add_theme_stylebox_override("panel", ConfigStyles.content_panel())
	header_panel.add_theme_stylebox_override("panel", ConfigStyles.header_panel())
	ConfigStyles.apply_bold_label(header_label, 16)
	ConfigStyles.apply_label($Root/VBox/BodyScroll/Body/Fields/DisplayNameLabel)
	ConfigStyles.apply_label($Root/VBox/BodyScroll/Body/Fields/InterfacesLabel)
	ConfigStyles.apply_label(hint_label, 11, true)
	ConfigStyles.apply_status_label(status_label)
	ConfigStyles.apply_line_edit(display_name_edit)
	ConfigStyles.apply_option_button(interfaces_option)
