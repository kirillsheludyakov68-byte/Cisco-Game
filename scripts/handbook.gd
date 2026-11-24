extends Window

# Глобальное пособие. Содержимое лежит отдельно в data/help, поэтому
# новые статьи и устройства можно добавлять без изменения интерфейса.

const INDEX_PATH := "res://data/help/handbook.json"
const HELP_DIR := "res://data/help/"

var _catalog: Array = []
var _articles_by_id: Dictionary = {}
var _device_articles: Dictionary = {}
var _search_cache: Dictionary = {}

var _ui_root: Control = null
var _categories_box: VBoxContainer = null
var _content_title: Label = null
var _content_summary: Label = null
var _content_body: RichTextLabel = null
var _content_scroll: ScrollContainer = null
var _search_edit: LineEdit = null
var _article_buttons: Dictionary = {}

var _current_article_id := ""
var _last_article_id := ""
var _search_text := ""

var _sidebar_normal := Color(0, 0, 0, 0)
var _sidebar_hover := Color("#eaf5ff")
var _sidebar_active := Color("#dceeff")


func _ready() -> void:
	visible = false
	close_requested.connect(_on_close_requested)
	_load_catalog()
	_build_ui()
	_last_article_id = _first_article_id()
	if not _last_article_id.is_empty():
		_show_article(_last_article_id)
		set_process_unhandled_input(true)


func open() -> void:
	_ensure_ready()
	_search_text = ""
	if _search_edit != null:
		_search_edit.text = ""
	_rebuild_sidebar()
	if _current_article_id.is_empty():
		_current_article_id = _last_article_id if not _last_article_id.is_empty() else _first_article_id()
	_show_article(_current_article_id)
	_show_window()


func open_article(article_id: String) -> void:
	_ensure_ready()
	if not _articles_by_id.has(article_id):
		open()
		return
	_search_text = ""
	if _search_edit != null:
		_search_edit.text = ""
	_rebuild_sidebar()
	_show_article(article_id)
	_show_window()


func open_device(device_type: String) -> void:
	var article_id := str(_device_articles.get(device_type, ""))
	if article_id.is_empty():
		open()
		return
	open_article(article_id)


func close() -> void:
	hide()


func is_open() -> bool:
	return visible


func _ensure_ready() -> void:
	if _catalog.is_empty():
		_load_catalog()
	if _ui_root == null:
		_build_ui()


func _show_window() -> void:
	if not visible:
		popup_centered()
	if _search_edit != null:
		_search_edit.grab_focus()
	_content_scroll.scroll_vertical = 0


func _on_close_requested() -> void:
	close()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.ctrl_pressed and event.keycode == KEY_F:
		_search_edit.grab_focus()
		_search_edit.select_all()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


# --- Загрузка каталога -----------------------------------------------------

func _load_catalog() -> void:
	_catalog.clear()
	_articles_by_id.clear()
	_device_articles.clear()
	_search_cache.clear()

	var index = _read_json(INDEX_PATH)
	if not index is Dictionary:
		push_warning("Пособие: не удалось прочитать " + INDEX_PATH)
		return

	for category_data in index.get("categories", []):
		if not category_data is Dictionary:
			continue
		var category_id := str(category_data.get("id", ""))
		var category_title := str(category_data.get("title", category_id))
		var file_name := str(category_data.get("file", ""))
		if category_id.is_empty() or file_name.is_empty():
			continue
		var articles = _read_json(HELP_DIR + file_name)
		if not articles is Array:
			push_warning("Пособие: не удалось прочитать " + file_name)
			continue

		var category := {
			"id": category_id,
			"title": category_title,
			"articles": [],
		}
		for article_data in articles:
			if not article_data is Dictionary:
				continue
			var article_id := str(article_data.get("id", ""))
			if article_id.is_empty():
				continue
			_articles_by_id[article_id] = article_data
			_search_cache[article_id] = _make_search_blob(article_data)
			(category["articles"] as Array).append(article_data)
			for device_type in article_data.get("device_types", []):
				var type_name := str(device_type)
				if not type_name.is_empty() and not _device_articles.has(type_name):
					_device_articles[type_name] = article_id
		_catalog.append(category)


func _read_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	return JSON.parse_string(text)


func _make_search_blob(article: Dictionary) -> String:
	var parts: Array[String] = [
		str(article.get("title", "")),
		str(article.get("summary", "")),
	]
	for tag in article.get("tags", []):
		parts.append(str(tag))
	for section in article.get("sections", []):
		if section is Dictionary:
			parts.append(str(section.get("heading", "")))
			parts.append(str(section.get("body", "")))
	return "\n".join(parts).to_lower()


func _first_article_id() -> String:
	for category in _catalog:
		var articles: Array = category.get("articles", [])
		if not articles.is_empty():
			return str(articles[0].get("id", ""))
	return ""


# --- Интерфейс -------------------------------------------------------------

func _build_ui() -> void:
	if _ui_root != null:
		return

	_ui_root = Control.new()
	_ui_root.name = "HandbookRoot"
	_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_ui_root)

	var background := ColorRect.new()
	background.color = MenuStyles.BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	_ui_root.add_child(margin)

	var panel := PanelContainer.new()
	MenuStyles.apply_panel(panel, Color.WHITE, MenuStyles.BLUE_DARK, 18)
	margin.add_child(panel)

	var panel_margin := MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 18)
	panel_margin.add_theme_constant_override("margin_right", 18)
	panel_margin.add_theme_constant_override("margin_top", 14)
	panel_margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(panel_margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	panel_margin.add_child(layout)

	layout.add_child(_build_header())
	layout.add_child(_build_body())
	layout.add_child(_build_footer())

	visible = false


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 0)
	header.add_child(title_box)

	var title := Label.new()
	title.text = "Пособие"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", MenuStyles.BLUE_DARK)
	title_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Устройства, настройки и диагностика сети"
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", MenuStyles.TEXT_MUTED)
	title_box.add_child(subtitle)

	_search_edit = LineEdit.new()
	_search_edit.custom_minimum_size = Vector2(300.0, 38.0)
	_search_edit.placeholder_text = "Поиск по пособию..."
	_search_edit.clear_button_enabled = true
	MenuStyles.apply_line_edit(_search_edit)
	_search_edit.add_theme_font_size_override("font_size", 16)
	_search_edit.text_changed.connect(_on_search_changed)
	header.add_child(_search_edit)

	var close_button := Button.new()
	close_button.text = "✕"
	close_button.tooltip_text = "Закрыть пособие (Esc)"
	close_button.custom_minimum_size = Vector2(44.0, 38.0)
	MenuStyles.apply_button(close_button, "secondary", 18, 10, 9)
	close_button.pressed.connect(close)
	header.add_child(close_button)

	return header


func _build_body() -> Control:
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)

	var sidebar := PanelContainer.new()
	sidebar.custom_minimum_size = Vector2(290.0, 0.0)
	sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	MenuStyles.apply_panel(sidebar, Color("#f4f9ff"), Color("#b9d5ee"), 10)

	var sidebar_margin := MarginContainer.new()
	sidebar_margin.add_theme_constant_override("margin_left", 8)
	sidebar_margin.add_theme_constant_override("margin_right", 6)
	sidebar_margin.add_theme_constant_override("margin_top", 10)
	sidebar_margin.add_theme_constant_override("margin_bottom", 10)
	sidebar.add_child(sidebar_margin)

	var sidebar_scroll := ScrollContainer.new()
	sidebar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sidebar_margin.add_child(sidebar_scroll)

	_categories_box = VBoxContainer.new()
	_categories_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_categories_box.add_theme_constant_override("separation", 2)
	sidebar_scroll.add_child(_categories_box)
	body.add_child(sidebar)

	var content_panel := PanelContainer.new()
	content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	MenuStyles.apply_panel(content_panel, Color.WHITE, Color("#b9d5ee"), 10)
	body.add_child(content_panel)

	var content_margin := MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 24)
	content_margin.add_theme_constant_override("margin_right", 24)
	content_margin.add_theme_constant_override("margin_top", 18)
	content_margin.add_theme_constant_override("margin_bottom", 18)
	content_panel.add_child(content_margin)

	var content_layout := VBoxContainer.new()
	content_layout.add_theme_constant_override("separation", 6)
	content_margin.add_child(content_layout)

	_content_title = Label.new()
	_content_title.add_theme_font_size_override("font_size", 28)
	_content_title.add_theme_color_override("font_color", MenuStyles.TEXT_DARK)
	_content_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_layout.add_child(_content_title)

	_content_summary = Label.new()
	_content_summary.add_theme_font_size_override("font_size", 14)
	_content_summary.add_theme_color_override("font_color", MenuStyles.TEXT_MUTED)
	_content_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_layout.add_child(_content_summary)

	content_layout.add_child(HSeparator.new())

	_content_scroll = ScrollContainer.new()
	_content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_layout.add_child(_content_scroll)

	_content_body = RichTextLabel.new()
	_content_body.bbcode_enabled = true
	_content_body.fit_content = true
	_content_body.scroll_active = false
	_content_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_body.add_theme_font_size_override("normal_font_size", 15)
	_content_body.add_theme_font_size_override("bold_font_size", 15)
	_content_body.add_theme_color_override("default_color", MenuStyles.TEXT_DARK)
	_content_body.meta_clicked.connect(_on_meta_clicked)
	_content_scroll.add_child(_content_body)

	return body


func _build_footer() -> Control:
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)

	var hint := Label.new()
	hint.text = "Esc — закрыть · Ctrl+F — поиск"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", MenuStyles.TEXT_MUTED)
	footer.add_child(hint)

	return footer


func _rebuild_sidebar() -> void:
	if _categories_box == null:
		return
	for child in _categories_box.get_children():
		child.queue_free()
	_article_buttons.clear()

	if _search_text.is_empty():
		for category in _catalog:
			_add_category_header(str(category.get("title", "")))
			for article in category.get("articles", []):
				_add_article_button(article)
		return

	var found := 0
	for category in _catalog:
		var matches: Array = []
		for article in category.get("articles", []):
			if _article_matches(article):
				matches.append(article)
		if matches.is_empty():
			continue
		_add_category_header(str(category.get("title", "")))
		for article in matches:
			_add_article_button(article)
			found += 1

	if found == 0:
		var empty := Label.new()
		empty.text = "Ничего не найдено"
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", MenuStyles.TEXT_MUTED)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_categories_box.add_child(empty)


func _add_category_header(title: String) -> void:
	if title.is_empty():
		return
	var label := Label.new()
	label.text = title.to_upper()
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", MenuStyles.TEXT_MUTED)
	label.add_theme_constant_override("outline_size", 0)
	label.custom_minimum_size = Vector2(0.0, 26.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_categories_box.add_child(label)


func _add_article_button(article: Dictionary) -> void:
	var article_id := str(article.get("id", ""))
	if article_id.is_empty():
		return
	var button := Button.new()
	button.text = str(article.get("title", article_id))
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0.0, 32.0)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(_on_article_pressed.bind(article_id))
	_categories_box.add_child(button)
	_article_buttons[article_id] = button
	_apply_article_button_style(button, article_id == _current_article_id)


func _apply_article_button_style(button: Button, active: bool) -> void:
	button.add_theme_stylebox_override(
		"normal", _sidebar_style(_sidebar_active if active else _sidebar_normal, active)
	)
	button.add_theme_stylebox_override(
		"hover", _sidebar_style(_sidebar_hover, active)
	)
	button.add_theme_stylebox_override(
		"pressed", _sidebar_style(_sidebar_active, active)
	)
	button.add_theme_color_override("font_color", MenuStyles.TEXT_DARK)
	button.add_theme_color_override("font_hover_color", MenuStyles.TEXT_DARK)
	button.add_theme_color_override("font_pressed_color", MenuStyles.TEXT_DARK)
	button.add_theme_color_override("font_focus_color", MenuStyles.TEXT_DARK)


func _sidebar_style(bg: Color, active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	if active:
		style.border_width_left = 3
		style.border_color = MenuStyles.BLUE_DARK
	return style


func _on_article_pressed(article_id: String) -> void:
	_show_article(article_id)
	_content_scroll.scroll_vertical = 0


func _on_search_changed(new_text: String) -> void:
	_search_text = new_text.strip_edges().to_lower()
	_rebuild_sidebar()


func _article_matches(article: Dictionary) -> bool:
	if _search_text.is_empty():
		return true
	var article_id := str(article.get("id", ""))
	var haystack := str(_search_cache.get(article_id, ""))
	if haystack.is_empty():
		haystack = _make_search_blob(article)
	return haystack.find(_search_text) >= 0


func _show_article(article_id: String) -> void:
	if not _articles_by_id.has(article_id):
		return
	_current_article_id = article_id
	_last_article_id = article_id
	var article: Dictionary = _articles_by_id[article_id]
	_content_title.text = str(article.get("title", article_id))
	_content_summary.text = str(article.get("summary", ""))

	var lines: Array[String] = []
	for section in article.get("sections", []):
		if not section is Dictionary:
			continue
		var heading := str(section.get("heading", ""))
		if not heading.is_empty():
			lines.append("[font_size=19][b]%s[/b][/font_size]" % heading)
		lines.append(str(section.get("body", "")))
		lines.append("")

	var related: Array = article.get("related", [])
	if not related.is_empty():
		lines.append("[font_size=17][b]См. также[/b][/font_size]")
		for related_id in related:
			var related_article = _articles_by_id.get(str(related_id), null)
			if related_article is Dictionary:
				lines.append(
					"• [url=article:%s]%s[/url]" % [
						str(related_id),
						str(related_article.get("title", related_id)),
					]
				)
		lines.append("")

	_content_body.text = "\n".join(lines)
	for id in _article_buttons:
		_apply_article_button_style(_article_buttons[id], str(id) == _current_article_id)


func _on_meta_clicked(meta: Variant) -> void:
	var value := str(meta)
	if value.begins_with("article:"):
		open_article(value.substr("article:".length()))
