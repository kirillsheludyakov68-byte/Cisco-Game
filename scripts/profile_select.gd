extends Control

const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"
const LEVEL_SELECT_SCENE := "res://scenes/LevelSelect.tscn"
const ICON_TRASH := preload("res://assets/menu/icon_trash.svg")

var profiles_list: VBoxContainer
var delete_overlay: ColorRect
var delete_label: Label
var _pending_delete_id := ""


func _ready() -> void:
	_build_ui()
	_refresh_profiles()


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
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 36)
	add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
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

	var hint := Label.new()
	hint.text = "Выберите профиль, чтобы продолжить"
	MenuStyles.apply_text(hint, 16, MenuStyles.TEXT_MUTED)
	top.add_child(hint)

	var title_center := CenterContainer.new()
	content.add_child(title_center)

	var title_panel := PanelContainer.new()
	title_panel.custom_minimum_size = Vector2(420.0, 86.0)
	MenuStyles.apply_panel(title_panel, MenuStyles.BLUE, MenuStyles.BLUE_DARK, 24)
	title_center.add_child(title_panel)

	var title := Label.new()
	title.text = "Профили"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	MenuStyles.apply_title(title, 46, Color.WHITE, 8, Color("#0b4f8a"))
	title_panel.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)

	var list_center := CenterContainer.new()
	list_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(list_center)

	profiles_list = VBoxContainer.new()
	profiles_list.custom_minimum_size = Vector2(900.0, 0.0)
	profiles_list.add_theme_constant_override("separation", 14)
	list_center.add_child(profiles_list)

	_build_delete_dialog()


func _refresh_profiles() -> void:
	if profiles_list == null:
		return

	for child in profiles_list.get_children():
		profiles_list.remove_child(child)
		child.queue_free()

	var profiles := ProgressManager.get_profiles()
	if profiles.is_empty():
		var empty := Label.new()
		empty.text = "Профилей пока нет.\nСоздайте новый профиль в главном меню."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		MenuStyles.apply_text(empty, 22, MenuStyles.TEXT_MUTED)
		profiles_list.add_child(empty)
		return

	for profile in profiles:
		profiles_list.add_child(_make_profile_card(profile))


func _make_profile_card(profile: Dictionary) -> Control:
	var profile_id := str(profile.get("id", ""))
	var profile_name := str(profile.get("name", "Профиль"))
	var total_score := int(profile.get("total_score", 0))
	var completed_levels := int(profile.get("completed_levels", 0))
	var is_active := profile_id == ProgressManager.get_active_profile_id()

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(900.0, 88.0)
	MenuStyles.apply_panel(panel, Color.WHITE, Color("#9cc8ec"), 16)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)

	var name_label := Label.new()
	name_label.text = profile_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	MenuStyles.apply_text(name_label, 24, MenuStyles.TEXT_DARK)
	row.add_child(name_label)

	if is_active:
		var active_label := Label.new()
		active_label.text = "Активный"
		active_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		active_label.add_theme_font_size_override("font_size", 14)
		active_label.add_theme_color_override("font_color", Color("#1f8a43"))
		row.add_child(active_label)

	var score_label := Label.new()
	score_label.text = "Очки: %d" % total_score
	score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	MenuStyles.apply_text(score_label, 17, MenuStyles.TEXT_MUTED)
	row.add_child(score_label)

	var levels_label := Label.new()
	levels_label.text = "Уровней: %d" % completed_levels
	levels_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	MenuStyles.apply_text(levels_label, 16, MenuStyles.TEXT_MUTED)
	row.add_child(levels_label)

	var select_button := Button.new()
	select_button.text = "Открыть" if is_active else "Выбрать"
	select_button.custom_minimum_size = Vector2(130.0, 44.0)
	MenuStyles.apply_button(select_button, "primary", 17, 14, 12)
	select_button.pressed.connect(_on_select_profile.bind(profile_id))
	row.add_child(select_button)

	var delete_button := Button.new()
	delete_button.icon = ICON_TRASH
	delete_button.tooltip_text = "Удалить профиль"
	delete_button.custom_minimum_size = Vector2(54.0, 44.0)
	MenuStyles.apply_button(delete_button, "danger", 17, 10, 12)
	delete_button.pressed.connect(_on_delete_profile.bind(profile_id, profile_name))
	row.add_child(delete_button)

	return panel


func _on_select_profile(profile_id: String) -> void:
	if ProgressManager.set_active_profile(profile_id):
		get_tree().change_scene_to_file(LEVEL_SELECT_SCENE)


func _on_delete_profile(profile_id: String, profile_name: String) -> void:
	_pending_delete_id = profile_id
	delete_label.text = "Удалить профиль «%s»?\nВесь прогресс и очки будут удалены." % profile_name
	delete_overlay.visible = true


func _on_confirm_delete() -> void:
	if _pending_delete_id.is_empty():
		return
	ProgressManager.delete_profile(_pending_delete_id)
	_pending_delete_id = ""
	delete_overlay.visible = false
	_refresh_profiles()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _build_delete_dialog() -> void:
	delete_overlay = ColorRect.new()
	delete_overlay.color = Color(0.03, 0.12, 0.22, 0.55)
	delete_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	delete_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	delete_overlay.visible = false
	add_child(delete_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	delete_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(540.0, 0.0)
	MenuStyles.apply_panel(panel, Color.WHITE, MenuStyles.DANGER_DARK, 20)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	margin.add_child(content)

	var title := Label.new()
	title.text = "Удаление профиля"
	MenuStyles.apply_title(title, 28, MenuStyles.DANGER_DARK, 0)
	content.add_child(title)

	delete_label = Label.new()
	delete_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	MenuStyles.apply_text(delete_label, 18, MenuStyles.TEXT_DARK)
	content.add_child(delete_label)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 12)
	content.add_child(actions)

	var cancel_button := Button.new()
	cancel_button.text = "Отмена"
	cancel_button.custom_minimum_size = Vector2(140.0, 46.0)
	MenuStyles.apply_button(cancel_button, "secondary", 18, 16, 12)
	cancel_button.pressed.connect(func() -> void: delete_overlay.visible = false)
	actions.add_child(cancel_button)

	var delete_button := Button.new()
	delete_button.text = "Удалить"
	delete_button.custom_minimum_size = Vector2(160.0, 46.0)
	MenuStyles.apply_button(delete_button, "danger", 18, 16, 12)
	delete_button.pressed.connect(_on_confirm_delete)
	actions.add_child(delete_button)
