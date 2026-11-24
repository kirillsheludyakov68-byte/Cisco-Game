extends PanelContainer
class_name AccessPointGlobalSettingsPage

@onready var header_panel: PanelContainer = $Root/VBox/HeaderPanel
@onready var header_label: Label = $Root/VBox/HeaderPanel/HeaderLabel
@onready var status_label: Label = $Root/VBox/StatusLabel
@onready var display_name_edit: LineEdit = $Root/VBox/Body/Fields/DisplayNameEdit

var device: Device = null


func _ready() -> void:
	_apply_styles()
	display_name_edit.text_submitted.connect(_on_display_name_submitted)
	display_name_edit.focus_exited.connect(_on_display_name_focus_exited)


func setup(dev: Device, _interface_name: String = "") -> void:
	device = dev
	refresh()


func set_selected_interface(_interface_name: String) -> void:
	# У точки доступа Global Settings содержит только Display Name.
	pass


func refresh() -> void:
	if device == null:
		return
	display_name_edit.text = device.device_name
	ConfigStyles.mark_line_edit_error(display_name_edit, false)
	_set_status("")


func commit_pending() -> void:
	_commit_display_name()


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
		_set_status("Имя точки доступа не может быть пустым.", true)
		return

	ConfigStyles.mark_line_edit_error(display_name_edit, false)
	display_name_edit.text = value
	if value != device.device_name:
		device.device_name = value
		_set_status("Имя точки доступа изменено.", false, true)


func _set_status(text: String, is_error: bool = false, success: bool = false) -> void:
	ConfigStyles.set_status(status_label, text, is_error, success)


func _apply_styles() -> void:
	add_theme_stylebox_override("panel", ConfigStyles.content_panel())
	header_panel.add_theme_stylebox_override("panel", ConfigStyles.header_panel())
	ConfigStyles.apply_bold_label(header_label, 16)
	ConfigStyles.apply_label($Root/VBox/Body/Fields/DisplayNameLabel)
	ConfigStyles.apply_status_label(status_label)
	ConfigStyles.apply_line_edit(display_name_edit)
