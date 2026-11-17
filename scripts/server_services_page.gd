extends PanelContainer
class_name ServerServicesPage

# Страница Services сервера в стиле Packet Tracer: слева сворачиваемый
# список служб, справа — настройки выбранной службы.

const PAGE_HTTP := "http"
const PAGE_DHCP := "dhcp"
const PAGE_DNS := "dns"
const PAGE_EMAIL := "email"

const PAGE_TITLES := {
	PAGE_HTTP: "HTTP",
	PAGE_DHCP: "DHCP",
	PAGE_DNS: "DNS",
	PAGE_EMAIL: "EMAIL",
}

var device: Device = null

var header_panel: PanelContainer
var header_label: Label
var status_label: Label
var nav_panel: PanelContainer
var nav_header_button: Button
var nav_list: VBoxContainer
var nav_buttons: Dictionary = {}
var content_header: Label
var content_body: VBoxContainer
var pages: Dictionary = {}

# HTTP.
var http_toggle: CheckBox
var https_toggle: CheckBox
var http_file_list: ItemList
var http_file_name_edit: LineEdit
var http_file_content_edit: TextEdit
var http_new_button: Button
var http_save_button: Button
var http_delete_button: Button
var http_import_button: Button
var http_import_dialog: FileDialog

# DHCP.
var dhcp_toggle: CheckBox
var dhcp_interface_option: OptionButton
var dhcp_pool_name_edit: LineEdit
var dhcp_gateway_edit: LineEdit
var dhcp_dns_edit: LineEdit
var dhcp_start_edit: LineEdit
var dhcp_mask_edit: LineEdit
var dhcp_max_users_edit: LineEdit
var dhcp_tftp_edit: LineEdit
var dhcp_wlc_edit: LineEdit
var dhcp_summary_label: Label
var dhcp_add_button: Button
var dhcp_save_button: Button
var dhcp_remove_button: Button

# DNS.
var dns_toggle: CheckBox
var dns_name_edit: LineEdit
var dns_type_option: OptionButton
var dns_address_edit: LineEdit
var dns_records_list: ItemList
var dns_add_button: Button
var dns_save_button: Button
var dns_remove_button: Button
var dns_cache_button: Button
var dns_cache_label: Label

# EMAIL.
var email_smtp_toggle: CheckBox
var email_pop3_toggle: CheckBox
var email_domain_edit: LineEdit
var email_user_edit: LineEdit
var email_password_edit: LineEdit
var email_users_list: ItemList
var email_add_button: Button
var email_change_button: Button
var email_remove_button: Button

var _updating := false
var _current_page := PAGE_HTTP
var _nav_expanded := true
var _selected_http_file := ""
var _selected_dns_record := ""
var _toggle_pairs: Dictionary = {}
var _nav_group: ButtonGroup


func _ready() -> void:
	add_theme_stylebox_override("panel", ConfigStyles.content_panel())
	_build_ui()
	refresh()


func setup(dev: Device) -> void:
	device = dev
	refresh()


func refresh() -> void:
	_updating = true
	if device == null:
		_set_all_toggles_off()
		_clear_service_fields()
		_rebuild_http_files()
		_rebuild_dns_records()
		_rebuild_email_users()
		_update_dhcp_summary()
		_update_status_summary()
		_updating = false
		return

	_set_toggle_pair(PAGE_HTTP, device.http_service_enabled)
	_set_toggle_pair("https", device.https_service_enabled)
	_set_toggle_pair(PAGE_DHCP, device.dhcp_service_enabled)
	_set_toggle_pair(PAGE_DNS, device.dns_service_enabled)
	_set_toggle_pair("email_smtp", device.email_smtp_enabled)
	_set_toggle_pair("email_pop3", device.email_pop3_enabled)

	dhcp_pool_name_edit.text = device.dhcp_pool_name
	dhcp_gateway_edit.text = device.dhcp_gateway
	dhcp_dns_edit.text = device.dhcp_dns
	dhcp_start_edit.text = device.dhcp_start_ip
	dhcp_mask_edit.text = device.dhcp_subnet_mask
	dhcp_max_users_edit.text = str(device.dhcp_max_users) if device.dhcp_max_users > 0 else ""
	dhcp_tftp_edit.text = device.dhcp_tftp
	dhcp_wlc_edit.text = device.dhcp_wlc
	_fill_dhcp_interfaces()

	email_domain_edit.text = device.email_domain
	email_user_edit.clear()
	email_password_edit.clear()

	_rebuild_http_files()
	_rebuild_dns_records()
	_rebuild_email_users()
	_update_dhcp_summary()
	_update_status_summary()
	_updating = false


func commit_pending() -> void:
	if device == null or _updating:
		return
	_save_dhcp(false)
	_save_dns(false, false)
	_apply_email_config(false)


func dns_start_values_clear() -> void:
	dhcp_pool_name_edit.text = "serverPool"
	dhcp_start_edit.text = ""
	dhcp_mask_edit.text = "255.255.255.0"
	dhcp_gateway_edit.text = ""
	dhcp_dns_edit.text = ""
	dhcp_max_users_edit.text = ""
	dhcp_tftp_edit.text = ""
	dhcp_wlc_edit.text = ""


# --- Построение интерфейса -------------------------------------------------

func _build_ui() -> void:
	var root_margin := MarginContainer.new()
	root_margin.add_theme_constant_override("margin_left", 9)
	root_margin.add_theme_constant_override("margin_top", 8)
	root_margin.add_theme_constant_override("margin_right", 9)
	root_margin.add_theme_constant_override("margin_bottom", 9)
	add_child(root_margin)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 7)
	root_margin.add_child(root_box)

	header_panel = PanelContainer.new()
	header_panel.custom_minimum_size = Vector2(0, 28)
	header_panel.add_theme_stylebox_override("panel", ConfigStyles.header_panel())
	root_box.add_child(header_panel)
	header_label = Label.new()
	header_label.text = "Services"
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ConfigStyles.apply_bold_label(header_label, 14)
	header_panel.add_child(header_label)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	root_box.add_child(body)

	_build_nav(body)
	_build_content(body)

	status_label = Label.new()
	status_label.custom_minimum_size = Vector2(0, 20)
	ConfigStyles.apply_status_label(status_label)
	root_box.add_child(status_label)


func _build_nav(parent: Control) -> void:
	nav_panel = PanelContainer.new()
	nav_panel.custom_minimum_size = Vector2(188, 0)
	nav_panel.add_theme_stylebox_override("panel", PanelNavStyles.make_panel_style())
	parent.add_child(nav_panel)

	var nav_margin := MarginContainer.new()
	nav_margin.add_theme_constant_override("margin_left", 4)
	nav_margin.add_theme_constant_override("margin_top", 4)
	nav_margin.add_theme_constant_override("margin_right", 4)
	nav_margin.add_theme_constant_override("margin_bottom", 4)
	nav_panel.add_child(nav_margin)

	var nav_box := VBoxContainer.new()
	nav_box.add_theme_constant_override("separation", 2)
	nav_margin.add_child(nav_box)

	nav_header_button = Button.new()
	nav_header_button.text = "▼  SERVICES"
	nav_header_button.focus_mode = Control.FOCUS_NONE
	PanelNavStyles.apply_header_button(nav_header_button)
	nav_header_button.pressed.connect(_toggle_nav)
	nav_box.add_child(nav_header_button)

	nav_list = VBoxContainer.new()
	nav_list.add_theme_constant_override("separation", 2)
	nav_box.add_child(nav_list)

	if _nav_group == null:
		_nav_group = ButtonGroup.new()
		_nav_group.allow_unpress = false

	for page_id in [PAGE_HTTP, PAGE_DHCP, PAGE_DNS, PAGE_EMAIL]:
		var button := Button.new()
		button.text = "   " + str(PAGE_TITLES[page_id])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.toggle_mode = true
		button.button_group = _nav_group
		PanelNavStyles.apply_item_button(button)
		button.pressed.connect(_on_nav_pressed.bind(page_id))
		nav_list.add_child(button)
		nav_buttons[page_id] = button


func _build_content(parent: Control) -> void:
	var content_panel := PanelContainer.new()
	content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_panel.add_theme_stylebox_override("panel", ConfigStyles.section_panel())
	parent.add_child(content_panel)

	var content_margin := MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 8)
	content_margin.add_theme_constant_override("margin_top", 6)
	content_margin.add_theme_constant_override("margin_right", 8)
	content_margin.add_theme_constant_override("margin_bottom", 6)
	content_panel.add_child(content_margin)

	var content_box := VBoxContainer.new()
	content_box.add_theme_constant_override("separation", 5)
	content_margin.add_child(content_box)

	content_header = Label.new()
	content_header.text = "HTTP"
	ConfigStyles.apply_bold_label(content_header, 14)
	content_box.add_child(content_header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_box.add_child(scroll)

	content_body = VBoxContainer.new()
	content_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_body.add_theme_constant_override("separation", 8)
	scroll.add_child(content_body)

	_build_http_page()
	_build_dhcp_page()
	_build_dns_page()
	_build_email_page()
	_show_page(_current_page)


func _build_http_page() -> void:
	var page := _make_page(PAGE_HTTP)
	var section := _make_section(page, "HTTP")

	var toggles := HBoxContainer.new()
	toggles.add_theme_constant_override("separation", 18)
	section.add_child(toggles)
	var http_pair := _make_on_off(toggles, "HTTP", _on_http_toggled.bind(false))
	_toggle_pairs[PAGE_HTTP] = http_pair
	http_toggle = http_pair["on"]
	var https_pair := _make_on_off(toggles, "HTTPS", _on_http_toggled.bind(true))
	_toggle_pairs["https"] = https_pair
	https_toggle = https_pair["on"]

	var separator := HSeparator.new()
	section.add_child(separator)

	var file_title := Label.new()
	file_title.text = "File Manager"
	ConfigStyles.apply_bold_label(file_title, 13)
	section.add_child(file_title)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 8)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section.add_child(columns)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(220, 0)
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 4)
	columns.add_child(left)

	http_file_list = ItemList.new()
	http_file_list.custom_minimum_size = Vector2(220, 175)
	http_file_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	http_file_list.item_selected.connect(_on_http_file_selected)
	_apply_list_style(http_file_list)
	left.add_child(http_file_list)

	var left_buttons := HBoxContainer.new()
	left_buttons.add_theme_constant_override("separation", 4)
	left.add_child(left_buttons)
	http_new_button = _make_button("New File", "secondary")
	http_new_button.pressed.connect(_on_http_new_file)
	left_buttons.add_child(http_new_button)
	http_import_button = _make_button("Import", "secondary")
	http_import_button.pressed.connect(_on_http_import_pressed)
	left_buttons.add_child(http_import_button)
	http_delete_button = _make_button("Delete", "danger")
	http_delete_button.pressed.connect(_on_http_delete_file)
	left_buttons.add_child(http_delete_button)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 4)
	columns.add_child(right)

	var name_label := Label.new()
	name_label.text = "File Name"
	ConfigStyles.apply_label(name_label, 12, false)
	right.add_child(name_label)
	http_file_name_edit = _make_edit("index.html")
	right.add_child(http_file_name_edit)

	var content_label := Label.new()
	content_label.text = "File Content"
	ConfigStyles.apply_label(content_label, 12, false)
	right.add_child(content_label)
	http_file_content_edit = TextEdit.new()
	http_file_content_edit.custom_minimum_size = Vector2(0, 175)
	http_file_content_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	http_file_content_edit.placeholder_text = "<html>...</html>"
	ConfigStyles.apply_text_edit(http_file_content_edit)
	right.add_child(http_file_content_edit)

	http_save_button = _make_button("Save", "primary")
	http_save_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	http_save_button.custom_minimum_size = Vector2(0, 28)
	http_save_button.pressed.connect(_on_http_save_file)
	right.add_child(http_save_button)

	http_import_dialog = FileDialog.new()
	http_import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	http_import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	http_import_dialog.filters = PackedStringArray([
		"*.html ; HTML",
		"*.htm ; HTML",
		"*.txt ; Text",
	])
	http_import_dialog.file_selected.connect(_on_http_import_file)
	add_child(http_import_dialog)


func _build_dhcp_page() -> void:
	var page := _make_page(PAGE_DHCP)
	var section := _make_section(page, "DHCP")

	var pair := _make_on_off(section, "Service", _on_dhcp_toggled)
	_toggle_pairs[PAGE_DHCP] = pair
	dhcp_toggle = pair["on"]

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 5)
	section.add_child(grid)

	dhcp_interface_option = OptionButton.new()
	dhcp_interface_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ConfigStyles.apply_option_button(dhcp_interface_option)
	_add_grid_field(grid, "Interface", dhcp_interface_option)

	dhcp_pool_name_edit = _make_edit("serverPool")
	_add_grid_field(grid, "Pool Name", dhcp_pool_name_edit)
	dhcp_gateway_edit = _make_edit("0.0.0.0")
	_add_grid_field(grid, "Default Gateway", dhcp_gateway_edit)
	dhcp_dns_edit = _make_edit("0.0.0.0")
	_add_grid_field(grid, "DNS Server", dhcp_dns_edit)
	dhcp_start_edit = _make_edit("0.0.0.0")
	_add_grid_field(grid, "Start IP Address", dhcp_start_edit)
	dhcp_mask_edit = _make_edit("255.255.255.0")
	_add_grid_field(grid, "Subnet Mask", dhcp_mask_edit)
	dhcp_max_users_edit = _make_edit("10")
	_add_grid_field(grid, "Maximum Users", dhcp_max_users_edit)
	dhcp_tftp_edit = _make_edit("0.0.0.0 (optional)")
	_add_grid_field(grid, "TFTP Server", dhcp_tftp_edit)
	dhcp_wlc_edit = _make_edit("0.0.0.0 (optional)")
	_add_grid_field(grid, "WLC Address", dhcp_wlc_edit)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	section.add_child(buttons)
	dhcp_add_button = _make_button("Add", "primary")
	dhcp_add_button.pressed.connect(_on_add_dhcp)
	buttons.add_child(dhcp_add_button)
	dhcp_save_button = _make_button("Save", "primary")
	dhcp_save_button.pressed.connect(_on_save_dhcp)
	buttons.add_child(dhcp_save_button)
	dhcp_remove_button = _make_button("Remove", "danger")
	dhcp_remove_button.pressed.connect(_on_remove_dhcp)
	buttons.add_child(dhcp_remove_button)

	dhcp_summary_label = Label.new()
	dhcp_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ConfigStyles.apply_label(dhcp_summary_label, 12, true)
	section.add_child(dhcp_summary_label)

	for edit in [
		dhcp_pool_name_edit,
		dhcp_gateway_edit,
		dhcp_dns_edit,
		dhcp_start_edit,
		dhcp_mask_edit,
		dhcp_max_users_edit,
		dhcp_tftp_edit,
		dhcp_wlc_edit,
	]:
		edit.text_submitted.connect(_on_dhcp_field_submitted)


func _build_dns_page() -> void:
	var page := _make_page(PAGE_DNS)
	var section := _make_section(page, "DNS")

	var pair := _make_on_off(section, "Service", _on_dns_toggled)
	_toggle_pairs[PAGE_DNS] = pair
	dns_toggle = pair["on"]

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 5)
	section.add_child(grid)

	dns_name_edit = _make_edit("server.local")
	_add_grid_field(grid, "Name", dns_name_edit)
	dns_type_option = OptionButton.new()
	dns_type_option.add_item("A Record")
	dns_type_option.select(0)
	dns_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ConfigStyles.apply_option_button(dns_type_option)
	_add_grid_field(grid, "Type", dns_type_option)
	dns_address_edit = _make_edit("0.0.0.0")
	_add_grid_field(grid, "Address", dns_address_edit)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	section.add_child(buttons)
	dns_add_button = _make_button("Add", "primary")
	dns_add_button.pressed.connect(_on_add_dns_record)
	buttons.add_child(dns_add_button)
	dns_save_button = _make_button("Save", "primary")
	dns_save_button.pressed.connect(_on_save_dns_record)
	buttons.add_child(dns_save_button)
	dns_remove_button = _make_button("Remove", "danger")
	dns_remove_button.pressed.connect(_on_remove_selected_dns_record)
	buttons.add_child(dns_remove_button)

	var records_title := Label.new()
	records_title.text = "DNS Records"
	ConfigStyles.apply_bold_label(records_title, 13)
	section.add_child(records_title)

	dns_records_list = ItemList.new()
	dns_records_list.custom_minimum_size = Vector2(0, 130)
	dns_records_list.item_selected.connect(_on_dns_record_selected)
	_apply_list_style(dns_records_list)
	section.add_child(dns_records_list)

	var cache_section := _make_section(page, "DNS Cache")
	var cache_buttons := HBoxContainer.new()
	cache_section.add_child(cache_buttons)
	dns_cache_button = _make_button("Show Cache", "secondary")
	dns_cache_button.pressed.connect(_on_show_dns_cache)
	cache_buttons.add_child(dns_cache_button)
	dns_cache_label = Label.new()
	dns_cache_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ConfigStyles.apply_label(dns_cache_label, 12, true)
	dns_cache_label.text = "Кэш пуст."
	cache_section.add_child(dns_cache_label)

	dns_name_edit.text_submitted.connect(func(_text: String) -> void: dns_address_edit.grab_focus())
	dns_address_edit.text_submitted.connect(func(_text: String) -> void: _on_add_dns_record())


func _build_email_page() -> void:
	var page := _make_page(PAGE_EMAIL)
	var section := _make_section(page, "EMAIL")

	var toggles := HBoxContainer.new()
	toggles.add_theme_constant_override("separation", 18)
	section.add_child(toggles)
	var smtp_pair := _make_on_off(toggles, "SMTP", _on_email_protocol_toggled)
	_toggle_pairs["email_smtp"] = smtp_pair
	email_smtp_toggle = smtp_pair["on"]
	var pop3_pair := _make_on_off(toggles, "POP3", _on_email_protocol_toggled)
	_toggle_pairs["email_pop3"] = pop3_pair
	email_pop3_toggle = pop3_pair["on"]

	var domain_row := HBoxContainer.new()
	domain_row.add_theme_constant_override("separation", 8)
	section.add_child(domain_row)
	var domain_label := Label.new()
	domain_label.text = "Domain Name"
	domain_label.custom_minimum_size = Vector2(150, 0)
	ConfigStyles.apply_label(domain_label, 12, false)
	domain_row.add_child(domain_label)
	email_domain_edit = _make_edit("local")
	email_domain_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	domain_row.add_child(email_domain_edit)
	email_domain_edit.text_submitted.connect(_on_email_domain_submitted)
	email_domain_edit.focus_exited.connect(_on_email_domain_focus_exited)

	var users_title := Label.new()
	users_title.text = "User Accounts"
	ConfigStyles.apply_bold_label(users_title, 13)
	section.add_child(users_title)

	email_users_list = ItemList.new()
	email_users_list.custom_minimum_size = Vector2(0, 105)
	email_users_list.item_selected.connect(_on_email_user_selected)
	_apply_list_style(email_users_list)
	section.add_child(email_users_list)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 5)
	section.add_child(grid)
	email_user_edit = _make_edit("user")
	_add_grid_field(grid, "User Name", email_user_edit)
	email_password_edit = _make_edit("password")
	email_password_edit.secret = true
	_add_grid_field(grid, "Password", email_password_edit)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	section.add_child(buttons)
	email_add_button = _make_button("Add", "primary")
	email_add_button.pressed.connect(_on_add_email_user)
	buttons.add_child(email_add_button)
	email_change_button = _make_button("Change", "secondary")
	email_change_button.pressed.connect(_on_change_email_user)
	buttons.add_child(email_change_button)
	email_remove_button = _make_button("Remove", "danger")
	email_remove_button.pressed.connect(_on_remove_email_user)
	buttons.add_child(email_remove_button)


func _make_page(page_id: String) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 8)
	pages[page_id] = page
	content_body.add_child(page)
	return page


func _make_section(parent: Control, title: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", ConfigStyles.section_panel())
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	if not title.is_empty():
		var title_label := Label.new()
		title_label.text = title
		ConfigStyles.apply_bold_label(title_label, 13)
		box.add_child(title_label)
	return box


func _make_on_off(parent: Control, title: String, callback: Callable) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(60, 0)
	ConfigStyles.apply_label(label, 12, false)
	row.add_child(label)

	var group := ButtonGroup.new()
	group.allow_unpress = false
	var on_check := CheckBox.new()
	on_check.text = "On"
	on_check.button_group = group
	on_check.focus_mode = Control.FOCUS_NONE
	ConfigStyles.apply_checkbox(on_check)
	row.add_child(on_check)
	var off_check := CheckBox.new()
	off_check.text = "Off"
	off_check.button_group = group
	off_check.focus_mode = Control.FOCUS_NONE
	ConfigStyles.apply_checkbox(off_check)
	row.add_child(off_check)

	on_check.toggled.connect(func(pressed: bool) -> void:
		if pressed and not _updating:
			callback.call(true)
	)
	off_check.toggled.connect(func(pressed: bool) -> void:
		if pressed and not _updating:
			callback.call(false)
	)
	return {"on": on_check, "off": off_check}


func _make_edit(placeholder: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ConfigStyles.apply_line_edit(edit)
	return edit


func _make_button(text: String, kind: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	MenuStyles.apply_button(button, kind, 12, 12, 8)
	return button


func _apply_list_style(list: ItemList) -> void:
	list.add_theme_stylebox_override("panel", ConfigStyles.line_edit_style())
	list.add_theme_stylebox_override("focus", ConfigStyles.line_edit_focus_style())
	list.add_theme_stylebox_override("cursor", ConfigStyles.line_edit_focus_style())
	list.add_theme_stylebox_override("cursor_unfocused", ConfigStyles.line_edit_style())
	var selected := StyleBoxFlat.new()
	selected.bg_color = Color(0.24, 0.51, 0.80)
	selected.border_color = Color(0.12, 0.32, 0.55)
	selected.set_border_width_all(1)
	selected.set_corner_radius_all(2)
	list.add_theme_stylebox_override("selected", selected)
	list.add_theme_stylebox_override("selected_focus", selected)
	list.add_theme_color_override("font_color", ConfigStyles.TEXT_COLOR)
	list.add_theme_color_override("font_selected_color", Color.WHITE)
	list.add_theme_color_override("guide_color", ConfigStyles.LIGHT_BORDER)
	list.add_theme_font_size_override("font_size", 12)
	list.add_theme_constant_override("v_separation", 2)


func _add_grid_field(grid: GridContainer, label_text: String, control: Control) -> void:
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(150, 0)
	ConfigStyles.apply_label(label, 12, false)
	grid.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(control)


func _set_toggle_pair(key: String, value: bool) -> void:
	var pair: Dictionary = _toggle_pairs.get(key, {})
	if pair.is_empty():
		return
	var on_check: CheckBox = pair.get("on")
	var off_check: CheckBox = pair.get("off")
	if on_check == null or off_check == null:
		return
	if value:
		on_check.button_pressed = true
	else:
		off_check.button_pressed = true


func _set_all_toggles_off() -> void:
	for key in _toggle_pairs:
		_set_toggle_pair(str(key), false)


# --- Навигация и статус ----------------------------------------------------

func _toggle_nav() -> void:
	_nav_expanded = not _nav_expanded
	nav_list.visible = _nav_expanded
	nav_header_button.text = "▼  SERVICES" if _nav_expanded else "▶  SERVICES"


func _on_nav_pressed(page_id: String) -> void:
	_show_page(page_id)


func show_service_page(page_id: String) -> void:
	_show_page(page_id)


func _show_page(page_id: String) -> void:
	if not pages.has(page_id):
		return
	_current_page = page_id
	for key in pages:
		var page: Control = pages[key]
		page.visible = str(key) == page_id
	for key in nav_buttons:
		var nav_button: Button = nav_buttons[key]
		nav_button.button_pressed = str(key) == page_id
	content_header.text = str(PAGE_TITLES.get(page_id, "Services"))


func _set_status(text: String, is_error: bool = false, success: bool = false) -> void:
	ConfigStyles.set_status(status_label, text, is_error, success)


func _update_status_summary() -> void:
	if device == null:
		_set_status("Сервер не выбран.", false, false)
		return
	var http_state := "включён" if device.http_service_enabled else "выключен"
	var dhcp_state := "включён" if device.dhcp_service_enabled else "выключен"
	var dns_state := "включён" if device.dns_service_enabled else "выключен"
	var email_state := "включён" if device.email_smtp_enabled else "выключен"
	_set_status(
		"HTTP: %s. DHCP: %s. DNS: %s. EMAIL(SMTP): %s."
		% [http_state, dhcp_state, dns_state, email_state],
		false,
		false
	)


# --- HTTP ------------------------------------------------------------------

func _on_http_toggled(use_https: bool, enabled: bool) -> void:
	if _updating or device == null:
		return
	device.set_http_service(enabled, use_https)
	var label := "HTTPS" if use_https else "HTTP"
	_set_status(
		"Служба %s включена." % label if enabled else "Служба %s выключена." % label,
		false,
		enabled
	)


func _on_http_file_selected(index: int) -> void:
	if device == null or index < 0 or index >= http_file_list.item_count:
		return
	_selected_http_file = http_file_list.get_item_text(index)
	http_file_name_edit.text = _selected_http_file
	http_file_content_edit.text = device.get_http_file(_selected_http_file)


func _on_http_new_file() -> void:
	_selected_http_file = ""
	http_file_list.deselect_all()
	http_file_name_edit.text = ""
	http_file_content_edit.text = ""
	http_file_name_edit.grab_focus()
	_set_status("Введите имя нового файла.", false, false)


func _on_http_save_file() -> void:
	if device == null:
		return
	var old_name := _selected_http_file
	var name := http_file_name_edit.text.strip_edges()
	if not device.set_http_file(name, http_file_content_edit.text):
		_set_status(
			"Некорректное имя файла. Используйте имя без слэшей, до 128 символов.",
			true,
			false
		)
		return
	if not old_name.is_empty() and old_name != name:
		device.remove_http_file(old_name)
	_selected_http_file = name
	_rebuild_http_files()
	_set_status("Файл /%s сохранён." % name, false, true)


func _on_http_delete_file() -> void:
	if device == null or _selected_http_file.is_empty():
		_set_status("Выберите файл для удаления.", true, false)
		return
	var name := _selected_http_file
	if device.remove_http_file(name):
		_selected_http_file = ""
		http_file_name_edit.clear()
		http_file_content_edit.text = ""
		_rebuild_http_files()
		_set_status("Файл /%s удалён." % name, false, true)


func _on_http_import_pressed() -> void:
	http_import_dialog.popup_centered_ratio(0.7)


func _on_http_import_file(path: String) -> void:
	var content := FileAccess.get_file_as_string(path)
	if content.is_empty() and not FileAccess.file_exists(path):
		_set_status("Не удалось прочитать выбранный файл.", true, false)
		return
	_selected_http_file = ""
	http_file_name_edit.text = path.get_file()
	http_file_content_edit.text = content
	_set_status("Файл загружен. Нажмите Save, чтобы добавить его на сервер.", false, false)


func _rebuild_http_files() -> void:
	if http_file_list == null:
		return
	http_file_list.clear()
	if device == null:
		return
	var names: Array = device.http_files.keys()
	names.sort()
	for name in names:
		http_file_list.add_item(str(name))
	if not _selected_http_file.is_empty():
		for index in range(http_file_list.item_count):
			if http_file_list.get_item_text(index) == _selected_http_file:
				http_file_list.select(index)
				break


# --- DHCP ------------------------------------------------------------------

func _fill_dhcp_interfaces() -> void:
	dhcp_interface_option.clear()
	if device == null:
		return
	var names := device.get_interface_names()
	var selected_index := 0
	for index in range(names.size()):
		var interface_name := str(names[index])
		dhcp_interface_option.add_item(interface_name)
		if interface_name == device.dhcp_interface:
			selected_index = index
	if dhcp_interface_option.item_count > 0:
		dhcp_interface_option.select(selected_index)


func _on_dhcp_toggled(enabled: bool) -> void:
	if _updating or device == null:
		return
	if enabled and not _save_dhcp(false):
		_set_toggle_pair(PAGE_DHCP, false)
		_set_status(
			"Перед включением DHCP заполните Start IP, маску, шлюз, DNS и Maximum Users (1–254).",
			true,
			false
		)
		return
	device.set_dhcp_service(enabled)
	_update_dhcp_summary()
	_set_status("Служба DHCP включена." if enabled else "Служба DHCP выключена.", false, enabled)


func _on_add_dhcp() -> void:
	_save_dhcp(true)


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
		"pool_name": dhcp_pool_name_edit.text.strip_edges(),
		"interface": _get_selected_dhcp_interface(),
		"tftp": dhcp_tftp_edit.text.strip_edges(),
		"wlc": dhcp_wlc_edit.text.strip_edges(),
	}
	if not device.set_dhcp_config(values):
		if show_status:
			_set_status(
				"Проверьте Start IP, маску, шлюз, DNS, TFTP/WLC и Maximum Users (1–254).",
				true,
				false
			)
		return false
	_update_dhcp_summary()
	if show_status:
		_set_status("Пул DHCP сохранён.", false, true)
	return true


func _get_selected_dhcp_interface() -> String:
	if dhcp_interface_option.item_count == 0:
		return ""
	var index := dhcp_interface_option.selected
	if index < 0:
		index = 0
	return dhcp_interface_option.get_item_text(index)


func _on_remove_dhcp() -> void:
	if device == null:
		return
	device.clear_dhcp_config()
	dns_start_values_clear()
	_set_toggle_pair(PAGE_DHCP, false)
	_update_dhcp_summary()
	_set_status("Пул DHCP удалён, служба выключена.", false, true)


func _update_dhcp_summary() -> void:
	if dhcp_summary_label == null:
		return
	if device == null or device.dhcp_start_ip.is_empty():
		dhcp_summary_label.text = "Пул не настроен."
		return
	dhcp_summary_label.text = (
		"Pool: %s    Start IP: %s    Mask: %s    Max Users: %d"
		% [
			device.dhcp_pool_name,
			device.dhcp_start_ip,
			device.dhcp_subnet_mask,
			device.dhcp_max_users,
		]
	)


# --- DNS -------------------------------------------------------------------

func _on_dns_toggled(enabled: bool) -> void:
	if _updating or device == null:
		return
	device.set_dns_service(enabled)
	_set_status("Служба DNS включена." if enabled else "Служба DNS выключена.", false, enabled)


func _on_add_dns_record() -> void:
	_save_dns(true, true)


func _on_save_dns_record() -> void:
	_save_dns(true, false)


func _save_dns(show_status: bool, clear_fields: bool) -> bool:
	if device == null:
		return false
	var record_name := dns_name_edit.text.strip_edges()
	var address := dns_address_edit.text.strip_edges()
	if record_name.is_empty() and address.is_empty():
		if show_status:
			_set_status("Введите DNS-имя и IPv4-адрес.", true, false)
		return false
	if not device.add_dns_record(record_name, address):
		if show_status:
			_set_status("Проверьте DNS-имя и IPv4-адрес.", true, false)
		return false
	if not _selected_dns_record.is_empty() and _selected_dns_record != record_name.to_lower():
		device.remove_dns_record(_selected_dns_record)
	_selected_dns_record = record_name.to_lower()
	_rebuild_dns_records()
	if clear_fields:
		dns_name_edit.clear()
		dns_address_edit.clear()
		_selected_dns_record = ""
		dns_records_list.deselect_all()
	if show_status:
		_set_status("DNS-запись %s сохранена." % record_name.to_lower(), false, true)
	return true


func _on_dns_record_selected(index: int) -> void:
	if device == null or index < 0 or index >= dns_records_list.item_count:
		return
	var key := dns_records_list.get_item_text(index).get_slice("  ", 0)
	dns_name_edit.text = key
	dns_address_edit.text = str(device.dns_records.get(key, ""))
	_selected_dns_record = key


func _on_remove_selected_dns_record() -> void:
	if device == null:
		return
	var key := _selected_dns_record
	if key.is_empty():
		key = dns_name_edit.text.strip_edges().to_lower()
	if key.is_empty() or not device.remove_dns_record(key):
		_set_status("Выберите DNS-запись для удаления.", true, false)
		return
	_selected_dns_record = ""
	dns_name_edit.clear()
	dns_address_edit.clear()
	_rebuild_dns_records()
	_set_status("DNS-запись %s удалена." % key, false, true)


func _rebuild_dns_records() -> void:
	if dns_records_list == null:
		return
	dns_records_list.clear()
	if device == null:
		return
	var names: Array = device.dns_records.keys()
	names.sort()
	for name in names:
		dns_records_list.add_item(
			"%s    A Record    %s" % [str(name), str(device.dns_records[name])]
		)
	if not _selected_dns_record.is_empty():
		for index in range(dns_records_list.item_count):
			if dns_records_list.get_item_text(index).begins_with(_selected_dns_record + "  "):
				dns_records_list.select(index)
				break


func _on_show_dns_cache() -> void:
	if device == null:
		return
	if device.dns_cache.is_empty():
		dns_cache_label.text = "Кэш пуст."
		return
	var lines: Array[String] = []
	var names: Array = device.dns_cache.keys()
	names.sort()
	for name in names:
		lines.append("%s → %s" % [str(name), str(device.dns_cache[name])])
	dns_cache_label.text = "\n".join(lines)


# --- EMAIL -----------------------------------------------------------------

func _on_email_protocol_toggled(_enabled: bool) -> void:
	_apply_email_config(true)


func _apply_email_config(show_status: bool) -> bool:
	if device == null:
		return false
	var smtp_enabled: bool = _toggle_pairs["email_smtp"]["on"].button_pressed
	var pop3_enabled: bool = _toggle_pairs["email_pop3"]["on"].button_pressed
	if not device.set_email_config(email_domain_edit.text, smtp_enabled, pop3_enabled):
		if show_status:
			_set_status("Некорректное имя домена EMAIL.", true, false)
			refresh()
		return false
	if show_status:
		_set_status("Настройки EMAIL сохранены.", false, true)
	return true


func _on_email_domain_submitted(_text: String) -> void:
	_apply_email_config(true)


func _on_email_domain_focus_exited() -> void:
	_apply_email_config(false)


func _on_email_user_selected(index: int) -> void:
	if device == null or index < 0 or index >= email_users_list.item_count:
		return
	var user := email_users_list.get_item_text(index)
	email_user_edit.text = user
	email_password_edit.text = str(device.email_users.get(user, ""))


func _on_add_email_user() -> void:
	_save_email_user(true)


func _on_change_email_user() -> void:
	_save_email_user(true)


func _save_email_user(show_status: bool) -> bool:
	if device == null:
		return false
	var user := email_user_edit.text.strip_edges()
	if not device.set_email_user(user, email_password_edit.text):
		if show_status:
			_set_status("Проверьте имя пользователя: без @ и пробелов, до 64 символов.", true, false)
		return false
	_rebuild_email_users()
	if show_status:
		_set_status("Пользователь %s сохранён." % user.to_lower(), false, true)
	return true


func _on_remove_email_user() -> void:
	if device == null:
		return
	var user := email_user_edit.text.strip_edges()
	if user.is_empty() or not device.remove_email_user(user):
		_set_status("Выберите пользователя для удаления.", true, false)
		return
	email_user_edit.clear()
	email_password_edit.clear()
	_rebuild_email_users()
	_set_status("Пользователь %s удалён." % user.to_lower(), false, true)


func _rebuild_email_users() -> void:
	if email_users_list == null:
		return
	email_users_list.clear()
	if device == null:
		return
	var names: Array = device.email_users.keys()
	names.sort()
	for name in names:
		email_users_list.add_item(str(name))


func _clear_service_fields() -> void:
	if dhcp_pool_name_edit == null:
		return
	dns_start_values_clear()
	http_file_name_edit.clear()
	http_file_content_edit.text = ""
	email_domain_edit.text = ""
	email_user_edit.clear()
	email_password_edit.clear()
	dns_name_edit.clear()
	dns_address_edit.clear()
	dns_cache_label.text = "Кэш пуст."
