extends RefCounted
class_name ConfigStyles

const TEXT_COLOR := Color(0.05, 0.05, 0.05)
const MUTED_COLOR := Color(0.35, 0.35, 0.35)
const PANEL_BG := Color(1, 1, 1)
const HEADER_BG := Color(0.93, 0.93, 0.93)
const SECTION_BG := Color(0.97, 0.97, 0.97)
const FIELD_BG := Color(1, 1, 1)
const FIELD_READONLY_BG := Color(0.94, 0.94, 0.94)
const BORDER_COLOR := Color(0.42, 0.43, 0.45)
const LIGHT_BORDER := Color(0.62, 0.63, 0.65)
const ACTIVE_BORDER := Color(0.18, 0.42, 0.68)
const ERROR_BORDER := Color(0.72, 0.12, 0.10)
const ERROR_TEXT := Color(0.68, 0.08, 0.06)
const SUCCESS_TEXT := Color(0.10, 0.38, 0.12)

static var _radio_checked: Texture2D
static var _radio_unchecked: Texture2D
static var _checkbox_checked: Texture2D
static var _checkbox_unchecked: Texture2D


static func content_panel() -> StyleBoxFlat:
	return _flat(PANEL_BG, BORDER_COLOR)


static func section_panel() -> StyleBoxFlat:
	return _flat(SECTION_BG, LIGHT_BORDER)


static func header_panel() -> StyleBoxFlat:
	return _flat(HEADER_BG, LIGHT_BORDER)


static func line_edit_style(error: bool = false, read_only: bool = false) -> StyleBoxFlat:
	var border := ERROR_BORDER if error else LIGHT_BORDER
	var style := _flat(FIELD_READONLY_BG if read_only else FIELD_BG, border)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style


static func line_edit_focus_style(error: bool = false) -> StyleBoxFlat:
	var border := ERROR_BORDER if error else ACTIVE_BORDER
	var style := _flat(FIELD_BG, border)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style


static func apply_line_edit(edit: LineEdit) -> void:
	edit.add_theme_stylebox_override("normal", line_edit_style())
	edit.add_theme_stylebox_override("focus", line_edit_focus_style())
	edit.add_theme_stylebox_override("read_only", line_edit_style(false, true))
	edit.add_theme_color_override("font_color", TEXT_COLOR)
	edit.add_theme_color_override("font_uneditable_color", MUTED_COLOR)
	edit.add_theme_color_override("font_placeholder_color", Color(0.50, 0.50, 0.50))
	edit.add_theme_font_size_override("font_size", 13)


static func set_line_edit_editable(edit: LineEdit, editable: bool) -> void:
	edit.editable = editable
	var style := line_edit_style(false, not editable)
	edit.add_theme_stylebox_override("normal", style)
	edit.add_theme_stylebox_override("focus", line_edit_focus_style() if editable else style)
	edit.add_theme_stylebox_override("read_only", style)


static func mark_line_edit_error(edit: LineEdit, has_error: bool) -> void:
	edit.add_theme_stylebox_override("normal", line_edit_style(has_error))
	edit.add_theme_stylebox_override("focus", line_edit_focus_style(has_error))


static func apply_text_edit(edit: TextEdit) -> void:
	edit.add_theme_stylebox_override("normal", line_edit_style())
	edit.add_theme_stylebox_override("focus", line_edit_focus_style())
	edit.add_theme_stylebox_override("read_only", line_edit_style(false, true))
	edit.add_theme_color_override("font_color", TEXT_COLOR)
	edit.add_theme_color_override("font_readonly_color", MUTED_COLOR)
	edit.add_theme_color_override("font_placeholder_color", Color(0.50, 0.50, 0.50))
	edit.add_theme_font_size_override("font_size", 13)


static func apply_option_button(option: OptionButton) -> void:
	option.add_theme_stylebox_override("normal", line_edit_style())
	option.add_theme_stylebox_override("hover", line_edit_focus_style())
	option.add_theme_stylebox_override("pressed", line_edit_focus_style())
	option.add_theme_stylebox_override("focus", line_edit_focus_style())
	option.add_theme_stylebox_override("disabled", line_edit_style(false, true))
	option.add_theme_color_override("font_color", TEXT_COLOR)
	option.add_theme_color_override("font_hover_color", TEXT_COLOR)
	option.add_theme_color_override("font_pressed_color", TEXT_COLOR)
	option.add_theme_color_override("font_focus_color", TEXT_COLOR)
	option.add_theme_color_override("font_disabled_color", MUTED_COLOR)
	option.add_theme_font_size_override("font_size", 13)


static func apply_checkbox(check: CheckBox) -> void:
	if _radio_checked == null:
		_radio_checked = load("res://assets/ui/radio_checked.svg")
	if _radio_unchecked == null:
		_radio_unchecked = load("res://assets/ui/radio_unchecked.svg")

	for icon_name in ["checked", "radio_checked"]:
		check.add_theme_icon_override(icon_name, _radio_checked)
	for icon_name in ["unchecked", "radio_unchecked"]:
		check.add_theme_icon_override(icon_name, _radio_unchecked)

	check.add_theme_color_override("font_color", TEXT_COLOR)
	check.add_theme_color_override("font_hover_color", TEXT_COLOR)
	check.add_theme_color_override("font_pressed_color", TEXT_COLOR)
	check.add_theme_color_override("font_focus_color", TEXT_COLOR)
	check.add_theme_color_override("font_disabled_color", MUTED_COLOR)
	check.add_theme_font_size_override("font_size", 13)
	check.add_theme_constant_override("h_separation", 5)


static func apply_plain_checkbox(check: CheckBox) -> void:
	if _checkbox_checked == null:
		_checkbox_checked = load("res://assets/ui/checkbox_checked.svg")
	if _checkbox_unchecked == null:
		_checkbox_unchecked = load("res://assets/ui/checkbox_unchecked.svg")

	# Для CheckBox внутри ButtonGroup Godot может использовать radio-иконки,
	# поэтому квадратные иконки назначаются на все четыре состояния.
	check.add_theme_icon_override("checked", _checkbox_checked)
	check.add_theme_icon_override("unchecked", _checkbox_unchecked)
	check.add_theme_icon_override("radio_checked", _checkbox_checked)
	check.add_theme_icon_override("radio_unchecked", _checkbox_unchecked)
	check.add_theme_color_override("font_color", TEXT_COLOR)
	check.add_theme_color_override("font_hover_color", TEXT_COLOR)
	check.add_theme_color_override("font_pressed_color", TEXT_COLOR)
	check.add_theme_color_override("font_focus_color", TEXT_COLOR)
	check.add_theme_color_override("font_disabled_color", MUTED_COLOR)
	check.add_theme_font_size_override("font_size", 13)
	check.add_theme_constant_override("h_separation", 5)


static func apply_label(label: Label, font_size: int = 13, muted: bool = false) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", MUTED_COLOR if muted else TEXT_COLOR)


static func apply_bold_label(label: Label, font_size: int = 13) -> void:
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.variation_embolden = 0.55
	label.add_theme_font_override("font", font)
	apply_label(label, font_size)


static func apply_status_label(label: Label) -> void:
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", MUTED_COLOR)


static func set_status(label: Label, text: String, is_error: bool = false, success: bool = false) -> void:
	label.text = text
	label.visible = not text.is_empty()
	var color := MUTED_COLOR
	if is_error:
		color = ERROR_TEXT
	elif success:
		color = SUCCESS_TEXT
	label.add_theme_color_override("font_color", color)


static func _flat(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.anti_aliasing = false
	return style
