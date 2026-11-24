extends PanelContainer
class_name SwitchGlobalSettingsPage

@onready var header_panel: PanelContainer = $Root/VBox/HeaderPanel
@onready var header_label: Label = $Root/VBox/HeaderPanel/HeaderLabel
@onready var status_label: Label = $Root/VBox/StatusLabel
@onready var display_name_edit: LineEdit = $Root/VBox/Body/Fields/DisplayNameEdit
@onready var hostname_edit: LineEdit = $Root/VBox/Body/Fields/HostnameEdit
@onready var serial_number_edit: LineEdit = $Root/VBox/Body/Fields/SerialNumberEdit
@onready var equivalent_panel: PanelContainer = $Root/VBox/EquivalentPanel
@onready var equivalent_header: Label = $Root/VBox/EquivalentPanel/EquivalentVBox/EquivalentHeader
@onready var ios_output: TextEdit = $Root/VBox/EquivalentPanel/EquivalentVBox/IOSOutput

var device: Device = null
var _updating := false


func _ready() -> void:
	_apply_styles()
	display_name_edit.text_submitted.connect(_on_field_submitted)
	display_name_edit.focus_exited.connect(_on_field_focus_exited)
	hostname_edit.text_submitted.connect(_on_field_submitted)
	hostname_edit.focus_exited.connect(_on_field_focus_exited)


func setup(dev: Device, _interface_name: String = "") -> void:
	_disconnect_device()
	device = dev
	if device != null:
		device.console.line_added.connect(_on_console_line_added)
		device.console.cleared.connect(_on_console_cleared)
		device.hostname_changed.connect(_on_hostname_changed)
		device.boot_finished.connect(_on_console_cleared)
		device.boot_state_changed.connect(_on_boot_state_changed)
	refresh()


func set_selected_interface(_interface_name: String) -> void:
	# У страницы настроек коммутатора нет выбора интерфейса.
	pass


func refresh() -> void:
	if device == null:
		return
	_updating = true
	display_name_edit.text = device.device_name
	hostname_edit.text = device.hostname
	serial_number_edit.text = device.serial_number
	ConfigStyles.mark_line_edit_error(display_name_edit, false)
	ConfigStyles.mark_line_edit_error(hostname_edit, false)
	_update_console()
	_set_status("")
	_updating = false


func commit_pending() -> void:
	_commit_display_name()
	_commit_hostname()


func _disconnect_device() -> void:
	if device == null:
		return
	if device.console.line_added.is_connected(_on_console_line_added):
		device.console.line_added.disconnect(_on_console_line_added)
	if device.console.cleared.is_connected(_on_console_cleared):
		device.console.cleared.disconnect(_on_console_cleared)
	if device.hostname_changed.is_connected(_on_hostname_changed):
		device.hostname_changed.disconnect(_on_hostname_changed)
	if device.boot_finished.is_connected(_on_console_cleared):
		device.boot_finished.disconnect(_on_console_cleared)
	if device.boot_state_changed.is_connected(_on_boot_state_changed):
		device.boot_state_changed.disconnect(_on_boot_state_changed)


func _on_field_submitted(_text: String) -> void:
	commit_pending()


func _on_field_focus_exited() -> void:
	commit_pending()


func _commit_display_name() -> void:
	if device == null:
		return
	var value := display_name_edit.text.strip_edges()
	if value.is_empty():
		ConfigStyles.mark_line_edit_error(display_name_edit, true)
		_set_status("Display Name не может быть пустым.", true)
		return

	ConfigStyles.mark_line_edit_error(display_name_edit, false)
	display_name_edit.text = value
	if value != device.device_name:
		device.device_name = value
		_set_status("Display Name изменён.", false, true)


func _commit_hostname() -> void:
	if device == null:
		return
	var value := hostname_edit.text.strip_edges()
	if value.is_empty() or value.length() > 32:
		ConfigStyles.mark_line_edit_error(hostname_edit, true)
		_set_status("Hostname должен содержать от 1 до 32 символов.", true)
		return

	ConfigStyles.mark_line_edit_error(hostname_edit, false)
	if not device.set_hostname(value):
		ConfigStyles.mark_line_edit_error(hostname_edit, true)
		_set_status("Не удалось изменить Hostname.", true)
		return
	hostname_edit.text = value
	_set_status("Hostname изменён.", false, true)


func _on_console_line_added(_line: String) -> void:
	_update_console()


func _on_console_cleared() -> void:
	_update_console()


func _on_boot_state_changed(_is_booting: bool) -> void:
	_update_console()


func _on_hostname_changed(_new_hostname: String) -> void:
	if _updating:
		return
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
	ConfigStyles.apply_label($Root/VBox/Body/Fields/DisplayNameLabel)
	ConfigStyles.apply_label($Root/VBox/Body/Fields/HostnameLabel)
	ConfigStyles.apply_label($Root/VBox/Body/Fields/SerialNumberLabel)
	ConfigStyles.apply_status_label(status_label)
	ConfigStyles.apply_line_edit(display_name_edit)
	ConfigStyles.apply_line_edit(hostname_edit)
	ConfigStyles.apply_line_edit(serial_number_edit)
	ConfigStyles.set_line_edit_editable(serial_number_edit, false)
	ConfigStyles.apply_text_edit(ios_output)
	ios_output.editable = false
	ios_output.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	ios_output.scroll_fit_content_height = false
