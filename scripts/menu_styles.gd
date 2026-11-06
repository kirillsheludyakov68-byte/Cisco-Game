class_name MenuStyles
extends RefCounted

const BG := Color("#f7fbff")
const BLUE := Color("#3fa9f5")
const BLUE_HOVER := Color("#5bbcff")
const BLUE_PRESSED := Color("#258fd8")
const BLUE_DARK := Color("#1565c0")
const GRAY := Color("#c9d6e5")
const GRAY_HOVER := Color("#dce6f2")
const GRAY_PRESSED := Color("#b0c2d6")
const GRAY_DARK := Color("#6c7f96")
const DANGER := Color("#e85d5d")
const DANGER_HOVER := Color("#f27d7d")
const DANGER_PRESSED := Color("#cf4545")
const DANGER_DARK := Color("#a83232")
const TEXT_DARK := Color("#123a63")
const TEXT_MUTED := Color("#5b7088")


static func panel_style(
	bg: Color,
	border: Color,
	radius: int = 18,
	border_width: int = 3
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.16)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0.0, 3.0)
	return style


static func button_style(
	bg: Color,
	border: Color,
	radius: int = 16,
	padding: int = 24
) -> StyleBoxFlat:
	var style := panel_style(bg, border, radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


static func apply_panel(
	panel: PanelContainer,
	bg: Color,
	border: Color,
	radius: int = 18
) -> void:
	panel.add_theme_stylebox_override("panel", panel_style(bg, border, radius))


static func apply_button(
	button: Button,
	kind: String = "primary",
	font_size: int = 28,
	padding: int = 24,
	radius: int = 16
) -> void:
	var normal_bg := BLUE
	var hover_bg := BLUE_HOVER
	var pressed_bg := BLUE_PRESSED
	var border := BLUE_DARK
	var outline := Color("#0b4f8a")

	if kind == "secondary":
		normal_bg = GRAY
		hover_bg = GRAY_HOVER
		pressed_bg = GRAY_PRESSED
		border = GRAY_DARK
		outline = Color("#42566d")
	elif kind == "danger":
		normal_bg = DANGER
		hover_bg = DANGER_HOVER
		pressed_bg = DANGER_PRESSED
		border = DANGER_DARK
		outline = Color("#7a1f1f")

	button.add_theme_stylebox_override("normal", button_style(normal_bg, border, radius, padding))
	button.add_theme_stylebox_override("hover", button_style(hover_bg, border, radius, padding))
	button.add_theme_stylebox_override("pressed", button_style(pressed_bg, border, radius, padding))
	button.add_theme_stylebox_override(
		"disabled",
		button_style(Color("#dfe7ef"), Color("#aab7c6"), radius, padding)
	)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("#8c9bab"))
	button.add_theme_color_override("font_outline_color", outline)
	button.add_theme_constant_override("outline_size", maxi(2, int(font_size / 7.0)))
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_constant_override("h_separation", 12)
	button.add_theme_constant_override("icon_max_width", maxi(20, font_size + 18))
	button.focus_mode = Control.FOCUS_NONE


static func apply_level_tile(button: Button, unlocked: bool) -> void:
	var bg := BLUE if unlocked else GRAY
	var hover_bg := BLUE_HOVER if unlocked else GRAY
	var pressed_bg := BLUE_PRESSED if unlocked else GRAY_PRESSED
	var border := BLUE_DARK if unlocked else GRAY_DARK

	var normal := panel_style(bg, border, 18, 4)
	normal.content_margin_left = 0
	normal.content_margin_right = 0
	normal.content_margin_top = 0
	normal.content_margin_bottom = 0
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", panel_style(hover_bg, border, 18, 4))
	button.add_theme_stylebox_override("pressed", panel_style(pressed_bg, border, 18, 4))
	button.add_theme_stylebox_override("disabled", panel_style(GRAY, GRAY_DARK, 18, 4))
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_outline_color", Color("#0b4f8a"))
	button.add_theme_constant_override("outline_size", 8)
	button.add_theme_font_size_override("font_size", 56)
	button.focus_mode = Control.FOCUS_NONE


static func apply_line_edit(line_edit: LineEdit) -> void:
	var normal := panel_style(Color.WHITE, Color("#7fb8e8"), 12, 2)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8

	var focus := panel_style(Color.WHITE, BLUE_DARK, 12, 3)
	focus.content_margin_left = 14
	focus.content_margin_right = 14
	focus.content_margin_top = 8
	focus.content_margin_bottom = 8

	line_edit.add_theme_stylebox_override("normal", normal)
	line_edit.add_theme_stylebox_override("focus", focus)
	line_edit.add_theme_font_size_override("font_size", 22)
	line_edit.add_theme_color_override("font_color", TEXT_DARK)
	line_edit.add_theme_color_override("font_placeholder_color", Color("#8a9bb0"))
	line_edit.add_theme_color_override("caret_color", BLUE_DARK)


static func apply_title(
	label: Label,
	font_size: int,
	font_color: Color = BLUE,
	outline_size: int = 10,
	outline_color: Color = Color.WHITE
) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", outline_color)
	label.add_theme_constant_override("outline_size", outline_size)


static func apply_text(label: Label, font_size: int, color: Color = TEXT_DARK) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
