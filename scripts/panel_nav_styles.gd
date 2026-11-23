extends RefCounted
class_name PanelNavStyles

# Общие стили для левых панелей ModulesPanel и Config.
# Значения взяты из ModulesPanel.tscn и modules_panel.gd, чтобы обе панели
# использовали одинаковые рамки, отступы и состояния кнопок.

const PANEL_BG := Color("#f2f2f2")
const PANEL_HIGHLIGHT_BG := Color("#fff7c2")
const PANEL_BORDER := Color("#6f6f6f")

const HEADER_NORMAL_BG := Color(1, 1, 1)
const HEADER_HOVER_BG := Color("#eef4fa")
const HEADER_PRESSED_BG := Color("#dfeaf5")
const HEADER_BORDER := Color("#a9a9a9")

const ITEM_NORMAL_BG := Color(1, 1, 1)
const ITEM_HOVER_BG := Color("#eef4fa")
const ITEM_PRESSED_BG := Color("#dce9f6")
const ITEM_BORDER := Color("#c4c4c4")

const HEADER_HEIGHT := 24
const ITEM_HEIGHT := 27
const FONT_SIZE := 15


static func make_panel_style(highlight: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_HIGHLIGHT_BG if highlight else PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(1)
	style.corner_detail = 1
	style.expand_margin_left = 1.0
	style.expand_margin_top = 1.0
	style.expand_margin_right = 1.0
	style.expand_margin_bottom = 1.0
	return style


static func apply_header_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _header_style(HEADER_NORMAL_BG))
	button.add_theme_stylebox_override("hover", _header_style(HEADER_HOVER_BG))
	button.add_theme_stylebox_override("pressed", _header_style(HEADER_PRESSED_BG, true))
	button.add_theme_stylebox_override("hover_pressed", _header_style(HEADER_PRESSED_BG, true))
	button.add_theme_stylebox_override("focus", _header_style(HEADER_NORMAL_BG))
	button.add_theme_stylebox_override("disabled", _header_style(HEADER_NORMAL_BG))

	button.add_theme_color_override("font_color", Color(0, 0, 0.015686275, 1))
	button.add_theme_color_override("font_hover_color", Color(0, 0, 0, 1))
	button.add_theme_color_override("font_pressed_color", Color(0, 0, 0, 1))
	button.add_theme_color_override("font_focus_color", Color(0, 0, 0, 1))
	button.add_theme_color_override("font_hover_pressed_color", Color(0, 0, 0, 1))
	button.add_theme_font_size_override("font_size", FONT_SIZE)

	button.custom_minimum_size = Vector2(0, HEADER_HEIGHT)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER


static func apply_item_button(button: Button, font: Font = null, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	button.add_theme_stylebox_override("normal", _item_style(ITEM_NORMAL_BG))
	button.add_theme_stylebox_override("hover", _item_style(ITEM_HOVER_BG))
	button.add_theme_stylebox_override("pressed", _item_style(ITEM_PRESSED_BG))
	button.add_theme_stylebox_override("hover_pressed", _item_style(ITEM_PRESSED_BG))
	button.add_theme_stylebox_override("focus", _item_style(ITEM_NORMAL_BG))
	button.add_theme_stylebox_override("disabled", _item_style(ITEM_NORMAL_BG))

	if font != null:
		button.add_theme_font_override("font", font)
	button.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	button.add_theme_color_override("font_hover_color", Color(0, 0, 0, 1))
	button.add_theme_color_override("font_pressed_color", Color(0, 0, 0, 1))
	button.add_theme_color_override("font_focus_color", Color(0, 0, 0, 1))
	button.add_theme_color_override("font_hover_pressed_color", Color(0, 0, 0, 1))
	button.add_theme_font_size_override("font_size", FONT_SIZE)

	button.custom_minimum_size = Vector2(0, ITEM_HEIGHT)
	button.alignment = alignment
	button.add_theme_constant_override("h_separation", 0)


static func _header_style(bg: Color, pressed: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = HEADER_BORDER
	style.set_border_width_all(1)
	var radius := 2 if pressed else 3
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.anti_aliasing = true
	return style


static func _item_style(bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = ITEM_BORDER
	style.set_border_width_all(1)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_right = 3
	style.corner_radius_bottom_left = 3
	style.anti_aliasing = true
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style
