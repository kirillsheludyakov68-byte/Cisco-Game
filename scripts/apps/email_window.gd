extends VBoxContainer
class_name EmailWindow

@onready var compose_grid: GridContainer = $ComposeGrid
@onready var from_label: Label = $ComposeGrid/FromLabel
@onready var from_edit: LineEdit = $ComposeGrid/FromEdit
@onready var to_label: Label = $ComposeGrid/ToLabel
@onready var to_edit: LineEdit = $ComposeGrid/ToEdit
@onready var subject_label: Label = $ComposeGrid/SubjectLabel
@onready var subject_edit: LineEdit = $ComposeGrid/SubjectEdit
@onready var message_label: Label = $MessageLabel
@onready var body_edit: TextEdit = $BodyEdit
@onready var send_button: Button = $SendRow/SendButton
@onready var status_label: Label = $SendRow/StatusLabel
@onready var inbox_title: Label = $InboxTitle
@onready var inbox_panel: PanelContainer = $InboxPanel
@onready var inbox_list: ItemList = $InboxPanel/InboxMargin/InboxRow/InboxList
@onready var preview: RichTextLabel = $InboxPanel/InboxMargin/InboxRow/Preview

var device: Device = null
var _address := ""
var _inbox: Array[Dictionary] = []


func _ready() -> void:
	_apply_styles()
	send_button.pressed.connect(_on_send_pressed)
	inbox_list.item_selected.connect(_on_inbox_selected)


func setup(device_value: Device) -> void:
	device = device_value
	_address = EmailStore.device_address(device)
	from_edit.text = _address
	ConfigStyles.set_line_edit_editable(from_edit, false)
	_refresh_inbox()
	to_edit.grab_focus()


func activate() -> void:
	_refresh_inbox()


func commit_pending() -> void:
	# Письмо отправляется только явной кнопкой Send, поэтому при закрытии
	# окна не отправляем незавершённый черновик автоматически.
	pass


func _apply_styles() -> void:
	for label in [from_label, to_label, subject_label, message_label, inbox_title]:
		ConfigStyles.apply_label(label)
	ConfigStyles.apply_line_edit(from_edit)
	ConfigStyles.apply_line_edit(to_edit)
	ConfigStyles.apply_line_edit(subject_edit)
	ConfigStyles.apply_text_edit(body_edit)
	ConfigStyles.apply_status_label(status_label)
	DesktopStyles.apply_action_button(send_button)

	inbox_panel.add_theme_stylebox_override("panel", ConfigStyles.section_panel())
	inbox_list.add_theme_stylebox_override("panel", ConfigStyles.line_edit_style())
	inbox_list.add_theme_stylebox_override("focus", ConfigStyles.line_edit_focus_style())
	inbox_list.add_theme_color_override("font_color", ConfigStyles.TEXT_COLOR)
	inbox_list.add_theme_color_override("font_selected_color", Color(1, 1, 1))
	inbox_list.add_theme_color_override("guide_color", ConfigStyles.LIGHT_BORDER)
	inbox_list.add_theme_font_size_override("font_size", 12)
	preview.add_theme_stylebox_override("normal", ConfigStyles.line_edit_style())
	preview.add_theme_color_override("default_color", ConfigStyles.TEXT_COLOR)
	preview.add_theme_font_size_override("normal_font_size", 12)
	status_label.visible = false


func _on_send_pressed() -> void:
	var result := EmailStore.send(
		from_edit.text,
		to_edit.text,
		subject_edit.text,
		body_edit.text
	)
	if not bool(result.get("ok", false)):
		ConfigStyles.set_status(status_label, str(result.get("reason", "Не удалось отправить письмо.")), true)
		return

	to_edit.clear()
	subject_edit.clear()
	body_edit.text = ""
	_refresh_inbox()
	ConfigStyles.set_status(
		status_label,
		"Письмо сохранено в локальном ящике. SMTP/POP3 не эмулируются.",
		false,
		true
	)
	to_edit.grab_focus()


func _refresh_inbox() -> void:
	_inbox = EmailStore.get_inbox(_address)
	inbox_list.clear()
	for message in _inbox:
		var subject := str(message.get("subject", ""))
		var sender := str(message.get("from", ""))
		inbox_list.add_item(sender + "  |  " + subject)

	if _inbox.is_empty():
		preview.text = "Входящих писем нет.\n\nЛокальный ящик: " + _address
		return

	inbox_list.select(0)
	_on_inbox_selected(0)


func _on_inbox_selected(index: int) -> void:
	if index < 0 or index >= _inbox.size():
		return
	var message := _inbox[index]
	preview.text = (
		"From: " + str(message.get("from", "")) + "\n"
		+ "To: " + str(message.get("to", "")) + "\n"
		+ "Subject: " + str(message.get("subject", "")) + "\n"
		+ "Date: " + str(message.get("created_at", "")) + "\n\n"
		+ str(message.get("body", ""))
	)
