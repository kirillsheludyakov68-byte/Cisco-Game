extends Control

const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"
const ICON_LOCK := preload("res://assets/menu/icon_lock.svg")

const LEVEL_COUNT := 15
const LEVEL_SCENES := {
	1: "res://scenes/level_1.tscn",
}

const TILE_SIZE := Vector2(132.0, 132.0)
const TILE_SEPARATION := 18


func _ready() -> void:
	if not ProgressManager.has_active_profile():
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
		return
	_build_ui()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = MenuStyles.BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 56)
	margin.add_theme_constant_override("margin_right", 56)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	content.add_child(top)

	var back_button := Button.new()
	back_button.text = "← В меню"
	back_button.custom_minimum_size = Vector2(170.0, 48.0)
	MenuStyles.apply_button(back_button, "secondary", 18, 16, 12)
	back_button.pressed.connect(_on_back_pressed)
	top.add_child(back_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)

	var profile_label := Label.new()
	profile_label.text = "Профиль: %s    Очки: %d" % [
		ProgressManager.get_active_profile_name(),
		ProgressManager.get_total_score(),
	]
	profile_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	MenuStyles.apply_text(profile_label, 17, MenuStyles.TEXT_DARK)
	top.add_child(profile_label)

	var title_center := CenterContainer.new()
	content.add_child(title_center)

	var title_panel := PanelContainer.new()
	title_panel.custom_minimum_size = Vector2(420.0, 86.0)
	MenuStyles.apply_panel(title_panel, MenuStyles.BLUE, MenuStyles.BLUE_DARK, 24)
	title_center.add_child(title_panel)

	var title := Label.new()
	title.text = "Levels"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	MenuStyles.apply_title(title, 48, Color.WHITE, 8, Color("#0b4f8a"))
	title_panel.add_child(title)

	var grid_center := CenterContainer.new()
	grid_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(grid_center)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", TILE_SEPARATION)
	grid.add_theme_constant_override("v_separation", TILE_SEPARATION)
	grid_center.add_child(grid)

	for level_number in range(1, LEVEL_COUNT + 1):
		grid.add_child(_make_level_tile(level_number))


func _make_level_tile(level_number: int) -> Button:
	var scene_path := str(LEVEL_SCENES.get(level_number, ""))
	var unlocked := not scene_path.is_empty()

	var button := Button.new()
	button.custom_minimum_size = TILE_SIZE
	MenuStyles.apply_level_tile(button, unlocked)

	if not unlocked:
		button.icon = ICON_LOCK
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.disabled = true
		button.tooltip_text = "Уровень %d — скоро" % level_number
		return button

	button.text = str(level_number)
	button.pressed.connect(_on_level_pressed.bind(level_number))

	var result := ProgressManager.get_level_result(str(level_number))
	if bool(result.get("completed", false)):
		_add_completed_mark(button)
		_add_best_score(button, int(result.get("best_score", 0)))

	return button


func _add_completed_mark(button: Button) -> void:
	var check := Label.new()
	check.text = "✓"
	check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	check.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	check.offset_left = -38.0
	check.offset_top = 8.0
	check.offset_right = -8.0
	check.offset_bottom = 42.0
	check.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	check.add_theme_font_size_override("font_size", 26)
	check.add_theme_color_override("font_color", Color("#7bf29a"))
	check.add_theme_color_override("font_outline_color", Color("#0b4f8a"))
	check.add_theme_constant_override("outline_size", 4)
	button.add_child(check)


func _add_best_score(button: Button, best_score: int) -> void:
	var score_label := Label.new()
	score_label.text = "★ %d" % best_score
	score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	score_label.offset_top = -38.0
	score_label.offset_bottom = -8.0
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 16)
	score_label.add_theme_color_override("font_color", Color("#fff2a8"))
	score_label.add_theme_color_override("font_outline_color", Color("#0b4f8a"))
	score_label.add_theme_constant_override("outline_size", 3)
	button.add_child(score_label)


func _on_level_pressed(level_number: int) -> void:
	var scene_path := str(LEVEL_SCENES.get(level_number, ""))
	if scene_path.is_empty():
		return
	get_tree().change_scene_to_file(scene_path)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
