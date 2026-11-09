extends PanelContainer
class_name ServerServicesPage

@onready var header_panel: PanelContainer = $Root/VBox/HeaderPanel
@onready var header_label: Label = $Root/VBox/HeaderPanel/HeaderLabel
@onready var status_label: Label = $Root/VBox/StatusLabel
@onready var dns_panel: PanelContainer = $Root/VBox/BodyScroll/Body/DnsPanel
@onready var dns_toggle: CheckBox = $Root/VBox/BodyScroll/Body/DnsPanel/DnsMargin/DnsVBox/DnsToggle
@onready var dns_name_edit: LineEdit = $Root/VBox/BodyScroll/Body/DnsPanel/DnsMargin/DnsVBox/DnsFields/DnsNameEdit
@onready var dns_address_edit: LineEdit = $Root/VBox/BodyScroll/Body/DnsPanel/DnsMargin/DnsVBox/DnsFields/DnsAddressEdit
@onready var dns_add_button: Button = $Root/VBox/BodyScroll/Body/DnsPanel/DnsMargin/DnsVBox/DnsAddButton
@onready var dns_records_list: VBoxContainer = $Root/VBox/BodyScroll/Body/DnsPanel/DnsMargin/DnsVBox/DnsRecords
@onready var dhcp_panel: PanelContainer = $Root/VBox/BodyScroll/Body/DhcpPanel
@onready var dhcp_toggle: CheckBox = $Root/VBox/BodyScroll/Body/DhcpPanel/DhcpMargin/DhcpVBox/DhcpToggle
@onready var dhcp_start_edit: LineEdit = $Root/VBox/BodyScroll/Body/DhcpPanel/DhcpMargin/DhcpVBox/DhcpFields/DhcpStartEdit
@onready var dhcp_mask_edit: LineEdit = $Root/VBox/BodyScroll/Body/DhcpPanel/DhcpMargin/DhcpVBox/DhcpFields/DhcpMaskEdit
@onready var dhcp_gateway_edit: LineEdit = $Root/VBox/BodyScroll/Body/DhcpPanel/DhcpMargin/DhcpVBox/DhcpFields/DhcpGatewayEdit
@onready var dhcp_dns_edit: LineEdit = $Root/VBox/BodyScroll/Body/DhcpPanel/DhcpMargin/DhcpVBox/DhcpFields/DhcpDnsEdit
@onready var dhcp_max_users_edit: LineEdit = $Root/VBox/BodyScroll/Body/DhcpPanel/DhcpMargin/DhcpVBox/DhcpFields/DhcpMaxUsersEdit
@onready var dhcp_save_button: Button = $Root/VBox/BodyScroll/Body/DhcpPanel/DhcpMargin/DhcpVBox/DhcpSaveButton
@onready var hint_label: Label = $Root/VBox/HintLabel

var device: Device = null
var _updating := false


func _ready() -> void:
	_apply_styles()
	dns_toggle.toggled.connect(_on_dns_toggled)
	dns_add_button.pressed.connect(_on_add_dns_record)
	dns_name_edit.text_submitted.connect(_on_dns_name_submitted)
	dns_address_edit.text_submitted.connect(_on_dns_address_submitted)
	dhcp_toggle.toggled.connect(_on_dhcp_toggled)
	dhcp_save_button.pressed.connect(_on_save_dhcp)
	for edit in [dhcp_start_edit, dhcp_mask_edit, dhcp_gateway_edit, dhcp_dns_edit, dhcp_max_users_edit]:
		edit.text_submitted.connect(_on_dhcp_field_submitted)
	refresh()


func setup(dev: Device) -> void:
	device = dev
	refresh()


func refresh() -> void:
	_updating = true
	if device == null:
		dns_toggle.button_pressed = false
		dhcp_toggle.button_pressed = false
		dns_start_values_clear()
		_rebuild_dns_records()
		_set_status("Устройство не выбрано.", false, false)
		_updating = false
		return

	dns_toggle.button_pressed = device.dns_service_enabled
	dhcp_toggle.button_pressed = device.dhcp_service_enabled
	dhcp_start_edit.text = device.dhcp_start_ip
	dhcp_mask_edit.text = device.dhcp_subnet_mask
	dhcp_gateway_edit.text = device.dhcp_gateway
	dhcp_dns_edit.text = device.dhcp_dns
	dhcp_max_users_edit.text = str(device.dhcp_max_users) if device.dhcp_max_users > 0 else ""
	_rebuild_dns_records()
	_update_service_summary()
	_updating = false


func commit_pending() -> void:
	if device == null or _updating:
		return
	_save_dhcp(false)


func _on_dns_toggled(pressed: bool) -> void:
	if _updating or device == null:
		return
	device.set_dns_service(pressed)
	_set_status(
		"Служба DNS включена." if pressed else "Служба DNS выключена.",
		false,
		pressed
	)


func _on_add_dns_record() -> void:
	if device == null:
		return
	var record_name := dns_name_edit.text.strip_edges()
	var address := dns_address_edit.text.strip_edges()
	if not device.add_dns_record(record_name, address):
		_set_status("Введите имя записи и корректный IPv4-адрес.", true, false)
		return
	dns_name_edit.clear()
	dns_address_edit.clear()
	_rebuild_dns_records()
	_set_status("DNS-запись %s добавлена." % record_name.to_lower(), false, true)


func _on_dns_name_submitted(_text: String) -> void:
	dns_address_edit.grab_focus()


func _on_dns_address_submitted(_text: String) -> void:
	_on_add_dns_record()


func _on_remove_dns_record(record_name: String) -> void:
	if device == null:
		return
	if device.remove_dns_record(record_name):
		_rebuild_dns_records()
		_set_status("DNS-запись %s удалена." % record_name, false, true)


func _on_dhcp_toggled(pressed: bool) -> void:
	if _updating or device == null:
		return
	if pressed:
		# Удобство: включение DHCP сразу сохраняет заполненные поля пула.
		_save_dhcp(false)
	device.set_dhcp_service(pressed)
	_set_status(
		"Служба DHCP включена." if pressed else "Служба DHCP выключена.",
		false,
		pressed
	)


func _on_save_dhcp() -> void:
	_save_dhcp(true)


func _on_dhcp_field_submitted(_text: String) -> void:
	_save_dhcp(true)


func _save_dhcp(show_status: bool) -> bool:
	if device == null:
		return false
	var values := {
		"start_ip": dhcp_start_edit.text.strip_edges(),
		"subnet_mask": dhcp_mask_edit.text.strip_edges(),
		"gateway": dhcp_gateway_edit.text.strip_edges(),
		"dns": dhcp_dns_edit.text.strip_edges(),
		"max_users": int(dhcp_max_users_edit.text.strip_edges()),
	}
	if not device.set_dhcp_config(values):
		if show_status:
			_set_status(
				"Проверьте начальный IP, маску, шлюз, DNS и число пользователей (1–254).",
				true,
				false
			)
		return false
	if show_status:
		_set_status("Настройки DHCP сохранены.", false, true)
	return true


func _rebuild_dns_records() -> void:
	for child in dns_records_list.get_children():
		dns_records_list.remove_child(child)
		child.queue_free()

	if device == null or device.dns_records.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Нет DNS-записей"
		ConfigStyles.apply_label(empty_label, 12, true)
		dns_records_list.add_child(empty_label)
		return

	var names: Array = device.dns_records.keys()
	names.sort()
	for record_name in names:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var label := Label.new()
		label.text = "%s → %s" % [str(record_name), str(device.dns_records[record_name])]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ConfigStyles.apply_label(label, 12, false)
		row.add_child(label)

		var remove_button := Button.new()
		remove_button.text = "Удалить"
		remove_button.focus_mode = Control.FOCUS_NONE
		MenuStyles.apply_button(remove_button, "secondary", 11, 8, 6)
		remove_button.pressed.connect(_on_remove_dns_record.bind(str(record_name)))
		row.add_child(remove_button)
		dns_records_list.add_child(row)


func dns_start_values_clear() -> void:
	dhcp_start_edit.text = ""
	dhcp_mask_edit.text = "255.255.255.0"
	dhcp_gateway_edit.text = ""
	dhcp_dns_edit.text = ""
	dhcp_max_users_edit.text = ""


func _update_service_summary() -> void:
	if device == null:
		return
	var dns_state := "включена" if device.dns_service_enabled else "выключена"
	var dhcp_state := "включена" if device.dhcp_service_enabled else "выключена"
	_set_status("DNS: %s. DHCP: %s." % [dns_state, dhcp_state], false, false)


func _set_status(text: String, is_error: bool, success: bool) -> void:
	ConfigStyles.set_status(status_label, text, is_error, success)


func _apply_styles() -> void:
	add_theme_stylebox_override("panel", ConfigStyles.content_panel())
	header_panel.add_theme_stylebox_override("panel", ConfigStyles.header_panel())
	dns_panel.add_theme_stylebox_override("panel", ConfigStyles.section_panel())
	dhcp_panel.add_theme_stylebox_override("panel", ConfigStyles.section_panel())
	ConfigStyles.apply_bold_label(header_label, 14)
	ConfigStyles.apply_status_label(status_label)
	ConfigStyles.apply_checkbox(dns_toggle)
	ConfigStyles.apply_checkbox(dhcp_toggle)
	ConfigStyles.apply_line_edit(dns_name_edit)
	ConfigStyles.apply_line_edit(dns_address_edit)
	ConfigStyles.apply_line_edit(dhcp_start_edit)
	ConfigStyles.apply_line_edit(dhcp_mask_edit)
	ConfigStyles.apply_line_edit(dhcp_gateway_edit)
	ConfigStyles.apply_line_edit(dhcp_dns_edit)
	ConfigStyles.apply_line_edit(dhcp_max_users_edit)
	MenuStyles.apply_button(dns_add_button, "primary", 13, 10, 8)
	MenuStyles.apply_button(dhcp_save_button, "primary", 13, 10, 8)
	ConfigStyles.apply_label(hint_label, 12, true)
	hint_label.text = "DNS сопоставляет имена IPv4-адресам. DHCP выдаёт адреса клиентам автоматически."
