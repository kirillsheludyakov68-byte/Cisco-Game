extends PanelContainer
class_name DesktopWindowFrame

signal close_requested
signal focus_requested(window: Control)

@onready var title_bar: PanelContainer = $FrameVBox/TitleBar
@onready var title_row: HBoxContainer = $FrameVBox/TitleBar/TitleRow
@onready var title_label: Label = $FrameVBox/TitleBar/TitleRow/TitleLabel
@onready var close_button: Button = $FrameVBox/TitleBar/TitleRow/CloseButton
@onready var content_host: PanelContainer = $FrameVBox/ContentHost
@onready var content_margin: MarginContainer = $FrameVBox/ContentHost/ContentMargin

var _dragging := false
var _drag_offset := Vector2.ZERO


func _ready() -> void:
	_apply_styles()
	close_button.pressed.connect(_on_close_pressed)
	title_bar.gui_input.connect(_on_title_bar_gui_input)
	gui_input.connect(_on_window_gui_input)
	set_process(false)


func setup(title: String) -> void:
	title_label.text = title


func set_content(content: Control) -> void:
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_child(content)

	# Содержимое задаёт базовый размер окна. Если оно не указало минимум,
	# используем его расчётный минимальный размер после добавления в дерево.
	var content_size := content.custom_minimum_size
	if content_size.x <= 0.0 or content_size.y <= 0.0:
		content_size = content.get_combined_minimum_size()
	content_size.x = maxf(content_size.x, 320.0)
	content_size.y = maxf(content_size.y, 180.0)

	var frame_size := Vector2(content_size.x + 22.0, content_size.y + 52.0)
	custom_minimum_size = frame_size
	size = frame_size


func _apply_styles() -> void:
	add_theme_stylebox_override("panel", DesktopStyles.window_style())
	title_bar.add_theme_stylebox_override("panel", DesktopStyles.window_title_style())
	content_host.add_theme_stylebox_override("panel", DesktopStyles.window_content_style())

	title_label.add_theme_color_override("font_color", DesktopStyles.WINDOW_TITLE_TEXT)
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.25))
	title_label.add_theme_constant_override("shadow_offset_x", 1)
	title_label.add_theme_constant_override("shadow_offset_y", 1)

	close_button.add_theme_stylebox_override("normal", DesktopStyles.close_button_style(0))
	close_button.add_theme_stylebox_override("hover", DesktopStyles.close_button_style(1))
	close_button.add_theme_stylebox_override("pressed", DesktopStyles.close_button_style(2))
	close_button.add_theme_stylebox_override("focus", DesktopStyles.close_button_style(1))
	close_button.add_theme_color_override("font_color", Color(0.15, 0.18, 0.20))
	close_button.add_theme_color_override("font_hover_color", Color(0.10, 0.10, 0.10))
	close_button.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	close_button.add_theme_font_size_override("font_size", 17)


func _on_close_pressed() -> void:
	close_requested.emit()


func _on_window_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			focus_requested.emit(self)


func _on_title_bar_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			focus_requested.emit(self)
			_dragging = true
			var parent_control := get_parent() as Control
			var mouse_local := get_global_mouse_position()
			if parent_control != null:
				mouse_local = parent_control.get_global_transform().affine_inverse() * get_global_mouse_position()
			_drag_offset = mouse_local - position
			set_process(true)
		else:
			_dragging = false
			set_process(false)
		accept_event()
		return

	if event is InputEventMouseMotion and _dragging:
		_update_drag_position()
		accept_event()


func _input(event: InputEvent) -> void:
	# Страховка на случай, если отпускание кнопки произошло вне title bar.
	if _dragging and event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			_dragging = false
			set_process(false)


func _process(_delta: float) -> void:
	if _dragging:
		_update_drag_position()


func _update_drag_position() -> void:
	var parent_control := get_parent() as Control
	if parent_control == null:
		return
	var mouse_local := parent_control.get_global_transform().affine_inverse() * get_global_mouse_position()
	var target := mouse_local - _drag_offset
	var max_x := maxf(0.0, parent_control.size.x - size.x)
	var max_y := maxf(0.0, parent_control.size.y - size.y)
	position = Vector2(clampf(target.x, 0.0, max_x), clampf(target.y, 0.0, max_y))
