extends CanvasLayer
class_name TaskPanel

# Панель задания: цель, шаги, подсказки и стрелка-указатель.
# Состояния шагов вычисляет level.gd; панель только отображает их.

@onready var title_label: Label = $PanelContainer/Margin/VBox/TitleLabel
@onready var description_label: Label = $PanelContainer/Margin/VBox/DescriptionLabel
@onready var steps_vbox: VBoxContainer = $PanelContainer/Margin/VBox/StepsVBox
@onready var hint_button: Button = $PanelContainer/Margin/VBox/HintButton
@onready var hint_label: RichTextLabel = $PanelContainer/Margin/VBox/HintLabel
@onready var completion_label: Label = $PanelContainer/Margin/VBox/CompletionLabel
@onready var arrow: HintArrow = $HintArrow

var level: Node = null
var objectives: Array = []
var hints_available: int = 3

var _rows: Array[RichTextLabel] = []
var _last_states: Array[bool] = []
var _completed := false


func _ready() -> void:
	hint_button.pressed.connect(_on_hint_pressed)
	hint_label.visible = false
	completion_label.visible = false
	arrow.hide_hint()
	_update_hint_button()


func setup(
	level_value: Node,
	title: String,
	description: String,
	objectives_value: Array,
	hints_value: int
) -> void:
	level = level_value
	title_label.text = title
	description_label.text = description
	objectives = objectives_value.duplicate(true)
	hints_available = hints_value
	_build_rows()
	_last_states.clear()
	_update_hint_button()


func set_states(states: Array) -> void:
	var changed := not _states_equal(states)
	_last_states.clear()
	for state in states:
		_last_states.append(bool(state))

	for index in _rows.size():
		var done := index < states.size() and bool(states[index])
		_rows[index].text = _format_step(str(objectives[index].get("text", "")), done)

	_completed = not states.is_empty()
	for state in states:
		if not bool(state):
			_completed = false
			break

	completion_label.visible = _completed
	if _completed:
		hint_label.text = "Все шаги выполнены. Задание завершено!"
		hint_label.visible = true
	_update_hint_button()

	# Если игрок что-то сделал, старая стрелка уже не актуальна.
	if changed:
		hide_hint_arrow()
		if level != null and level.has_method("hide_device_window_hint"):
			level.hide_device_window_hint()


func _states_equal(states: Array) -> bool:
	if states.size() != _last_states.size():
		return false
	for index in states.size():
		if bool(states[index]) != _last_states[index]:
			return false
	return true


func _build_rows() -> void:
	for child in steps_vbox.get_children():
		child.queue_free()
	_rows.clear()

	for objective in objectives:
		var row := RichTextLabel.new()
		row.bbcode_enabled = true
		row.fit_content = true
		row.scroll_active = false
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_font_size_override("normal_font_size", 13)
		steps_vbox.add_child(row)
		_rows.append(row)


func _format_step(text: String, done: bool) -> String:
	if done:
		return "[color=#2e7d32]✓[/color] [s][color=#6b6b6b]%s[/color][/s]" % text
	return "[color=#555555]○[/color] %s" % text


func _on_hint_pressed() -> void:
	if _completed:
		hint_label.text = "Все шаги выполнены. Задание завершено!"
		hint_label.visible = true
		return
	if hints_available == 0:
		hint_label.text = "Подсказки закончились."
		hint_label.visible = true
		return

	if hints_available > 0:
		hints_available -= 1
	_update_hint_button()

	if level == null or not level.has_method("request_hint"):
		hint_label.text = "Подсказки недоступны."
		hint_label.visible = true
		return

	var hint: Dictionary = level.request_hint()
	hint_label.text = str(hint.get("text", ""))
	hint_label.visible = not hint_label.text.is_empty()
	var target: Dictionary = hint.get("target", {})
	if level.has_method("show_hint_target"):
		level.show_hint_target(target)


func _update_hint_button() -> void:
	if _completed:
		hint_button.text = "Задание выполнено"
		hint_button.disabled = true
	elif hints_available < 0:
		hint_button.text = "Подсказка (∞)"
		hint_button.disabled = false
	elif hints_available == 0:
		hint_button.text = "Подсказка (0)"
		hint_button.disabled = true
	else:
		hint_button.text = "Подсказка (%d)" % hints_available
		hint_button.disabled = false


func show_world_hint(device: Node2D) -> void:
	arrow.show_world_device(device)


func show_control_hint(control: Control) -> void:
	arrow.show_control(control)


func show_world_point(point: Vector2) -> void:
	arrow.show_world_point(point)


func hide_hint_arrow() -> void:
	arrow.hide_hint()
