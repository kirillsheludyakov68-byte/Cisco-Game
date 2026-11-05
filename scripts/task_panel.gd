extends CanvasLayer
class_name TaskPanel

# Панель задания и отдельная подсказка-лампочка.
# Состояния шагов вычисляет level.gd; панель только отображает их.

@onready var task_card: PanelContainer = $TaskCard
@onready var header: HBoxContainer = $TaskCard/Margin/VBox/Header
@onready var title_label: Label = $TaskCard/Margin/VBox/Header/TitleLabel
@onready var completion_badge: Label = $TaskCard/Margin/VBox/Header/CompletionBadge
@onready var collapse_button: Button = $TaskCard/Margin/VBox/Header/CollapseButton
@onready var content: VBoxContainer = $TaskCard/Margin/VBox/Content
@onready var description_label: Label = $TaskCard/Margin/VBox/Content/DescriptionLabel
@onready var steps_title: Label = $TaskCard/Margin/VBox/Content/StepsTitle
@onready var steps_vbox: VBoxContainer = $TaskCard/Margin/VBox/Content/StepsVBox
@onready var reveal_step_button: Button = $TaskCard/Margin/VBox/Content/RevealStepButton
@onready var completion_label: Label = $TaskCard/Margin/VBox/Content/CompletionLabel

@onready var arrow: HintArrow = $HintArrow
@onready var lamp_button: Button = $HintWidget/VBox/Header/LampButton
@onready var hint_count_label: Label = $HintWidget/VBox/Header/CountLabel
@onready var hint_panel: PanelContainer = $HintWidget/VBox/HintPanel
@onready var hint_label: RichTextLabel = $HintWidget/VBox/HintPanel/Margin/HintLabel

var level: Node = null
var objectives: Array = []
var hints_available: int = 3

var _rows: Array[RichTextLabel] = []
var _last_states: Array[bool] = []
var _revealed_steps := 0
var _completed := false
var _completion_message_visible := false
var _collapsed := false
var _dragging := false
var _drag_offset := Vector2.ZERO
var _user_moved := false


func _ready() -> void:
	header.gui_input.connect(_on_header_gui_input)
	collapse_button.pressed.connect(_toggle_collapsed)
	reveal_step_button.pressed.connect(_reveal_next_step)
	lamp_button.pressed.connect(_on_hint_pressed)

	hint_panel.visible = false
	completion_label.visible = false
	completion_badge.visible = false
	arrow.hide_hint()
	_update_hint_button()

	get_viewport().size_changed.connect(_on_viewport_resized)
	call_deferred("_center_task_card")


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
	_completed = false
	completion_badge.visible = false
	completion_label.visible = false
	hint_panel.visible = false
	_update_hint_button()
	call_deferred("_center_task_card")


func set_states(states: Array) -> void:
	var changed := not _states_equal(states)
	_last_states.clear()
	for state in states:
		_last_states.append(bool(state))

	for index in _rows.size():
		var done := index < _last_states.size() and _last_states[index]
		var text := ""
		if index < objectives.size() and objectives[index] is Dictionary:
			text = str(objectives[index].get("text", ""))
		_rows[index].text = _format_step(text, done)

	_completed = not _last_states.is_empty()
	for state in _last_states:
		if not state:
			_completed = false
			break

	completion_badge.visible = _completed
	completion_label.visible = _completed
	if _completed:
		_show_hint_text("Все шаги выполнены. Задание завершено!")
		_completion_message_visible = true
	elif _completion_message_visible:
		# Задание откатилось (например, выключили коммутатор) —
		# убираем устаревшее сообщение о завершении.
		_completion_message_visible = false
		hint_label.text = ""
		hint_panel.visible = false
	_update_hint_button()

	# Если игрок что-то сделал, старая стрелка уже не актуальна.
	if changed:
		hide_hint_arrow()
		if level != null and level.has_method("hide_device_window_hint"):
			level.hide_device_window_hint()

	call_deferred("_clamp_task_card")


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
	_revealed_steps = 0

	for objective in objectives:
		var row := RichTextLabel.new()
		row.bbcode_enabled = true
		row.fit_content = true
		row.scroll_active = false
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_font_size_override("normal_font_size", 13)
		row.visible = false
		steps_vbox.add_child(row)
		_rows.append(row)

	steps_title.visible = not objectives.is_empty()
	_update_reveal_button()


func _format_step(text: String, done: bool) -> String:
	if done:
		return "[color=#2e7d32]✓[/color] [s][color=#5c5c5c]%s[/color][/s]" % text
	return "[color=#333333]○[/color] [color=#111111]%s[/color]" % text


func _reveal_next_step() -> void:
	if _revealed_steps >= _rows.size():
		return

	var index := _revealed_steps
	var done := index < _last_states.size() and _last_states[index]
	var text := ""
	if index < objectives.size() and objectives[index] is Dictionary:
		text = str(objectives[index].get("text", ""))

	_rows[index].text = _format_step(text, done)
	_rows[index].visible = true
	_revealed_steps += 1
	_update_reveal_button()
	call_deferred("_clamp_task_card")


func _update_reveal_button() -> void:
	if _rows.is_empty() or _revealed_steps >= _rows.size():
		reveal_step_button.visible = false
		return
	reveal_step_button.visible = true
	reveal_step_button.text = "Подсказать следующий шаг"


func _on_header_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_user_moved = true
			_drag_offset = get_viewport().get_mouse_position() - task_card.position
			header.accept_event()
		else:
			_dragging = false
			header.accept_event()
	elif event is InputEventMouseMotion and _dragging:
		task_card.position = get_viewport().get_mouse_position() - _drag_offset
		_clamp_task_card()
		header.accept_event()


func _toggle_collapsed() -> void:
	_collapsed = not _collapsed
	content.visible = not _collapsed
	collapse_button.text = "▸" if _collapsed else "▾"
	call_deferred("_clamp_task_card")


func _center_task_card() -> void:
	if task_card == null:
		return
	await get_tree().process_frame
	_fit_task_card()
	var viewport_size := get_viewport().get_visible_rect().size
	task_card.position = ((viewport_size - task_card.size) * 0.5).round()
	_user_moved = false


func _fit_task_card() -> void:
	if task_card == null:
		return
	var card_size := task_card.get_combined_minimum_size()
	card_size.x = maxf(card_size.x, 480.0)
	task_card.size = card_size


func _clamp_task_card() -> void:
	if task_card == null:
		return
	_fit_task_card()
	var viewport_size := get_viewport().get_visible_rect().size
	var position := task_card.position
	position.x = clampf(position.x, 0.0, maxf(0.0, viewport_size.x - task_card.size.x))
	position.y = clampf(position.y, 0.0, maxf(0.0, viewport_size.y - task_card.size.y))
	task_card.position = position


func _on_viewport_resized() -> void:
	if _user_moved:
		_clamp_task_card()
	else:
		_center_task_card()


func _on_hint_pressed() -> void:
	if _completed:
		_show_hint_text("Все шаги выполнены. Задание завершено!")
		return
	if hints_available == 0:
		_show_hint_text("Подсказки закончились.")
		return

	if hints_available > 0:
		hints_available -= 1
	_update_hint_button()

	if level == null or not level.has_method("request_hint"):
		_show_hint_text("Подсказки недоступны.")
		return

	var hint: Dictionary = level.request_hint()
	_show_hint_text(str(hint.get("text", "")))
	var target: Dictionary = hint.get("target", {})
	if level.has_method("show_hint_target"):
		level.show_hint_target(target)


func _show_hint_text(text: String) -> void:
	_completion_message_visible = false
	hint_label.text = text
	hint_panel.visible = not text.is_empty()


func _update_hint_button() -> void:
	if _completed:
		hint_count_label.text = "✓"
		hint_count_label.add_theme_color_override("font_color", Color(0.12, 0.48, 0.2, 1))
		lamp_button.disabled = true
		lamp_button.modulate = Color(1, 1, 1, 0.55)
		return

	if hints_available < 0:
		hint_count_label.text = "∞"
		hint_count_label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
		lamp_button.disabled = false
		lamp_button.modulate = Color(1, 1, 1, 1)
	elif hints_available == 0:
		hint_count_label.text = "0"
		hint_count_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35, 1))
		lamp_button.disabled = false
		lamp_button.modulate = Color(0.6, 0.6, 0.6, 1)
	else:
		hint_count_label.text = str(hints_available)
		hint_count_label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
		lamp_button.disabled = false
		lamp_button.modulate = Color(1, 1, 1, 1)


func show_world_hint(device: Node2D) -> void:
	arrow.show_world_device(device)


func show_control_hint(control: Control) -> void:
	arrow.show_control(control)


func show_world_point(point: Vector2) -> void:
	arrow.show_world_point(point)


func hide_hint_arrow() -> void:
	arrow.hide_hint()
