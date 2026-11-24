extends Control

const PROFILE_SELECT_SCENE := "res://scenes/ProfileSelect.tscn"
const LEVEL_SELECT_SCENE := "res://scenes/LevelSelect.tscn"
const ICON_PLAY := preload("res://assets/menu/icon_play.svg")
const ICON_PROFILE := preload("res://assets/menu/icon_profile.svg")
const ICON_EXIT := preload("res://assets/menu/icon_exit.svg")
const PC_TEXTURE := preload("res://assets/PC.svg")
const GLOBE_TEXTURE := preload("res://assets/menu/globe.svg")

var continue_button: Button
var new_game_button: Button
var exit_button: Button
var overlay: ColorRect
var name_input: LineEdit
var error_label: Label


func _ready() -> void:
	_build_ui()
	if not ProgressManager.profiles_changed.is_connected(_refresh_continue_state):
		ProgressManager.profiles_changed.connect(_refresh_continue_state)
	_refresh_continue_state()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = MenuStyles.BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 18)
	center.add_child(content)

	content.add_child(_build_logo())

	var buttons := VBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 18)
	content.add_child(buttons)

	new_game_button = _make_menu_button("Новая игра", ICON_PLAY, "primary")
	new_game_button.pressed.connect(_on_new_game_pressed)
	buttons.add_child(new_game_button)

	continue_button = _make_menu_button("Продолжить", ICON_PROFILE, "secondary")
	continue_button.pressed.connect(_on_continue_pressed)
	buttons.add_child(continue_button)

	exit_button = _make_menu_button("Выход", ICON_EXIT, "primary")
	exit_button.pressed.connect(_on_exit_pressed)
	buttons.add_child(exit_button)

	_build_profile_dialog()


func _build_logo() -> Control:
	var logo := VBoxContainer.new()
	logo.alignment = BoxContainer.ALIGNMENT_CENTER
	logo.add_theme_constant_override("separation", -6)

	var art := Control.new()
	art.custom_minimum_size = Vector2(720, 170)
	logo.add_child(art)

	var left_arc := Line2D.new()
	left_arc.points = PackedVector2Array([
		Vector2(250.0, 82.0),
		Vector2(278.0, 56.0),
		Vector2(312.0, 43.0),
		Vector2(340.0, 40.0),
	])
	left_arc.width = 6.0
	left_arc.default_color = Color("#2a9ee0")
	left_arc.antialiased = true
	art.add_child(left_arc)

	var right_arc := Line2D.new()
	right_arc.points = PackedVector2Array([
		Vector2(390.0, 40.0),
		Vector2(418.0, 43.0),
		Vector2(452.0, 56.0),
		Vector2(480.0, 82.0),
	])
	right_arc.width = 6.0
	right_arc.default_color = Color("#2a9ee0")
	right_arc.antialiased = true
	art.add_child(right_arc)

	var globe := TextureRect.new()
	globe.texture = GLOBE_TEXTURE
	globe.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	globe.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	globe.position = Vector2(296.0, 8.0)
	globe.size = Vector2(128.0, 128.0)
	globe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(globe)

	var pc_left := TextureRect.new()
	pc_left.texture = PC_TEXTURE
	pc_left.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pc_left.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pc_left.position = Vector2(150.0, 44.0)
	pc_left.size = Vector2(110.0, 96.0)
	pc_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(pc_left)

	var pc_right := TextureRect.new()
	pc_right.texture = PC_TEXTURE
	pc_right.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pc_right.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pc_right.position = Vector2(470.0, 44.0)
	pc_right.size = Vector2(110.0, 96.0)
	pc_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(pc_right)

	var title := Label.new()
	title.text = "Cisco Game"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	MenuStyles.apply_title(title, 72, Color("#1e88e5"), 14, Color.WHITE)
	logo.add_child(title)
	return logo


func _make_menu_button(text: String, icon: Texture2D, kind: String) -> Button:
	var button := Button.new()
	button.text = text
	button.icon = icon
	button.custom_minimum_size = Vector2(460.0, 78.0)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	MenuStyles.apply_button(button, kind, 30, 28, 18)
	return button


func _build_profile_dialog() -> void:
	overlay = ColorRect.new()
	overlay.color = Color(0.03, 0.12, 0.22, 0.55)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520.0, 0.0)
	MenuStyles.apply_panel(panel, Color.WHITE, MenuStyles.BLUE_DARK, 20)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)

	var title := Label.new()
	title.text = "Новая игра"
	MenuStyles.apply_title(title, 30, MenuStyles.TEXT_DARK, 0)
	content.add_child(title)

	var hint := Label.new()
	hint.text = "Введите имя профиля:"
	MenuStyles.apply_text(hint, 18, MenuStyles.TEXT_MUTED)
	content.add_child(hint)

	name_input = LineEdit.new()
	name_input.placeholder_text = "Например, Алексей"
	name_input.custom_minimum_size = Vector2(0.0, 52.0)
	name_input.max_length = 24
	MenuStyles.apply_line_edit(name_input)
	name_input.text_submitted.connect(_on_name_submitted)
	content.add_child(name_input)

	error_label = Label.new()
	error_label.add_theme_color_override("font_color", Color("#d33b3b"))
	error_label.add_theme_font_size_override("font_size", 15)
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_label.visible = false
	content.add_child(error_label)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 12)
	content.add_child(actions)

	var cancel_button := Button.new()
	cancel_button.text = "Отмена"
	cancel_button.custom_minimum_size = Vector2(140.0, 46.0)
	MenuStyles.apply_button(cancel_button, "secondary", 18, 16, 12)
	cancel_button.pressed.connect(_close_profile_dialog)
	actions.add_child(cancel_button)

	var create_button := Button.new()
	create_button.text = "Создать"
	create_button.custom_minimum_size = Vector2(160.0, 46.0)
	MenuStyles.apply_button(create_button, "primary", 18, 16, 12)
	create_button.pressed.connect(_on_create_profile_pressed)
	actions.add_child(create_button)


func _refresh_continue_state() -> void:
	if continue_button == null:
		return
	var has_profiles := ProgressManager.has_profiles()
	continue_button.disabled = not has_profiles
	MenuStyles.apply_button(
		continue_button,
		"primary" if has_profiles else "secondary",
		30,
		28,
		18
	)


func _on_new_game_pressed() -> void:
	error_label.visible = false
	name_input.clear()
	overlay.visible = true
	name_input.grab_focus()


func _on_continue_pressed() -> void:
	if not ProgressManager.has_profiles():
		return
	get_tree().change_scene_to_file(PROFILE_SELECT_SCENE)


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_name_submitted(_text: String) -> void:
	_on_create_profile_pressed()


func _on_create_profile_pressed() -> void:
	var result := ProgressManager.create_profile(name_input.text)
	if bool(result.get("ok", false)):
		_close_profile_dialog()
		get_tree().change_scene_to_file(LEVEL_SELECT_SCENE)
		return

	error_label.text = str(result.get("reason", "Не удалось создать профиль."))
	error_label.visible = true


func _close_profile_dialog() -> void:
	overlay.visible = false
	error_label.visible = false
