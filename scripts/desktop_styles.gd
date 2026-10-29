extends RefCounted
class_name DesktopStyles

# Визуальные константы рабочего стола. Держим их отдельно от ConfigStyles,
# потому что Desktop использует собственную тёмную палитру.
const DESKTOP_BG := Color(0.043, 0.165, 0.314)          # #0B2A50
const TILE_BG := Color(0.302, 0.741, 0.816)             # #4DBDD0
const TILE_HOVER_BG := Color(0.380, 0.816, 0.878)
const TILE_PRESSED_BG := Color(0.235, 0.635, 0.710)
const TILE_BORDER := Color(0.075, 0.235, 0.390)
const TILE_TEXT := Color(1, 1, 1)
const TILE_MUTED_TEXT := Color(0.82, 0.91, 0.95)
const WINDOW_BG := Color(0.955, 0.965, 0.973)
const WINDOW_CONTENT_BG := Color(1, 1, 1)
const WINDOW_BORDER := Color(0.310, 0.360, 0.410)
const WINDOW_TITLE_BG := Color(0.075, 0.270, 0.450)
const WINDOW_TITLE_TEXT := Color(1, 1, 1)
const CLOSE_NORMAL_BG := Color(0.930, 0.945, 0.955)
const CLOSE_HOVER_BG := Color(1.0, 0.780, 0.760)
const CLOSE_PRESSED_BG := Color(0.820, 0.370, 0.340)
const STATUS_TEXT := Color(0.880, 0.930, 0.970)

const TERMINAL_BG := Color(0.025, 0.035, 0.045)
const TERMINAL_TEXT := Color(0.830, 0.930, 0.830)
const TERMINAL_INPUT_BG := Color(0.045, 0.060, 0.070)
const TERMINAL_BORDER := Color(0.240, 0.320, 0.360)


static func tile_style(state: int = 0) -> StyleBoxFlat:
	var colors := [TILE_BG, TILE_HOVER_BG, TILE_PRESSED_BG]
	var style := _flat(colors[clampi(state, 0, colors.size() - 1)], TILE_BORDER)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	return style


static func desktop_background_style() -> StyleBoxFlat:
	return _flat(DESKTOP_BG, DESKTOP_BG)


static func window_style() -> StyleBoxFlat:
	var style := _flat(WINDOW_BG, WINDOW_BORDER)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	return style


static func window_content_style() -> StyleBoxFlat:
	var style := _flat(WINDOW_CONTENT_BG, WINDOW_BORDER)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	return style


static func window_title_style() -> StyleBoxFlat:
	var style := _flat(WINDOW_TITLE_BG, WINDOW_TITLE_BG)
	style.content_margin_left = 7
	style.content_margin_right = 4
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style


static func close_button_style(state: int = 0) -> StyleBoxFlat:
	var colors := [CLOSE_NORMAL_BG, CLOSE_HOVER_BG, CLOSE_PRESSED_BG]
	var style := _flat(colors[clampi(state, 0, colors.size() - 1)], WINDOW_BORDER)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style


static func action_button_style(state: int = 0) -> StyleBoxFlat:
	var colors := [
		Color(0.965, 0.975, 0.980),
		Color(0.820, 0.900, 0.950),
		Color(0.690, 0.820, 0.900),
	]
	var style := _flat(colors[clampi(state, 0, colors.size() - 1)], ConfigStyles.LIGHT_BORDER)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style


static func terminal_style() -> StyleBoxFlat:
	var style := _flat(TERMINAL_BG, TERMINAL_BORDER)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style


static func terminal_input_style() -> StyleBoxFlat:
	var style := _flat(TERMINAL_INPUT_BG, TERMINAL_BORDER)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style


static func apply_terminal_input(edit: LineEdit) -> void:
	edit.add_theme_stylebox_override("normal", terminal_input_style())
	edit.add_theme_stylebox_override("focus", terminal_input_style())
	edit.add_theme_stylebox_override("read_only", terminal_input_style())
	edit.add_theme_color_override("font_color", TERMINAL_TEXT)
	edit.add_theme_color_override("font_placeholder_color", Color(0.55, 0.65, 0.60))
	edit.add_theme_color_override("caret_color", TERMINAL_TEXT)
	edit.add_theme_font_size_override("font_size", 13)


static func apply_action_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", action_button_style(0))
	button.add_theme_stylebox_override("hover", action_button_style(1))
	button.add_theme_stylebox_override("pressed", action_button_style(2))
	button.add_theme_stylebox_override("focus", action_button_style(1))
	button.add_theme_stylebox_override("disabled", ConfigStyles.line_edit_style(false, true))
	button.add_theme_color_override("font_color", ConfigStyles.TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", ConfigStyles.TEXT_COLOR)
	button.add_theme_color_override("font_pressed_color", ConfigStyles.TEXT_COLOR)
	button.add_theme_color_override("font_disabled_color", ConfigStyles.MUTED_COLOR)
	button.add_theme_font_size_override("font_size", 13)


static func apply_desktop_label(label: Label, muted: bool = false) -> void:
	label.add_theme_color_override("font_color", TILE_MUTED_TEXT if muted else TILE_TEXT)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)


static func apply_terminal_text(control: Control) -> void:
	control.add_theme_color_override("font_color", TERMINAL_TEXT)
	control.add_theme_color_override("default_color", TERMINAL_TEXT)
	control.add_theme_color_override("font_readonly_color", TERMINAL_TEXT)
	control.add_theme_font_size_override("normal_font_size", 13)
	control.add_theme_font_size_override("font_size", 13)


static func _flat(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.anti_aliasing = false
	return style
