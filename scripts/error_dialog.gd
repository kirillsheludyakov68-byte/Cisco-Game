extends Control
class_name ErrorDialog

signal closed

@onready var message_label: Label = $Center/Panel/Margin/VBox/Message
@onready var ok_button: Button = $Center/Panel/Margin/VBox/Buttons/OkButton


func _ready() -> void:
	visible = false
	ok_button.pressed.connect(_on_ok)


func show_error(text: String) -> void:
	message_label.text = text
	visible = true
	ok_button.grab_focus()


func _on_ok() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_ok()
		get_viewport().set_input_as_handled()
