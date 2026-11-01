extends PanelContainer
class_name SwitchCLIPage

@onready var header_panel: PanelContainer = $Root/VBox/HeaderPanel
@onready var header_label: Label = $Root/VBox/HeaderPanel/HeaderLabel
@onready var output: TextEdit = $Root/VBox/Output

var device: Device = null


func _ready() -> void:
	_apply_styles()


func setup(dev: Device) -> void:
	_disconnect_device()
	device = dev
	if device != null:
		device.console.line_added.connect(_on_console_changed)
		device.console.cleared.connect(_on_console_changed)
		device.boot_finished.connect(_on_console_changed)
		device.boot_state_changed.connect(_on_console_changed)
		device.hostname_changed.connect(_on_hostname_changed)
	refresh()


func on_activated() -> void:
	refresh()


func refresh() -> void:
	if output == null:
		return
	output.text = device.get_console_text() if device != null else ""
	_scroll_to_end()


func _disconnect_device() -> void:
	if device == null:
		return
	if device.console.line_added.is_connected(_on_console_changed):
		device.console.line_added.disconnect(_on_console_changed)
	if device.console.cleared.is_connected(_on_console_changed):
		device.console.cleared.disconnect(_on_console_changed)
	if device.boot_finished.is_connected(_on_console_changed):
		device.boot_finished.disconnect(_on_console_changed)
	if device.boot_state_changed.is_connected(_on_console_changed):
		device.boot_state_changed.disconnect(_on_console_changed)
	if device.hostname_changed.is_connected(_on_hostname_changed):
		device.hostname_changed.disconnect(_on_hostname_changed)


func _on_console_changed(_arg = null) -> void:
	refresh()


func _on_hostname_changed(_new_hostname: String) -> void:
	refresh()


func _scroll_to_end() -> void:
	if output == null or not is_inside_tree():
		return
	output.scroll_vertical = output.get_line_count()
	# После первого кадра TextEdit пересчитывает высоту и полосу прокрутки,
	# поэтому прокручиваем ещё раз, чтобы последняя строка лога была видна.
	await get_tree().process_frame
	if is_instance_valid(output):
		output.scroll_vertical = output.get_line_count()


func _apply_styles() -> void:
	add_theme_stylebox_override("panel", ConfigStyles.content_panel())
	header_panel.add_theme_stylebox_override("panel", ConfigStyles.header_panel())
	ConfigStyles.apply_bold_label(header_label, 16)
	ConfigStyles.apply_text_edit(output)
	output.editable = false
	output.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	output.scroll_fit_content_height = false
