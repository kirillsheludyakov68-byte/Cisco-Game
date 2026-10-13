extends HBoxContainer

const NORMAL_BG := Color(1, 1, 1, 1)
const HOVER_LINE_COLOR := Color("0d274d")
const TEXT_COLOR := Color(0, 0, 0, 1)
const HOVER_LINE_HEIGHT: int = 4

func _ready() -> void:
	add_theme_constant_override("separation", 0)
	
	for child in get_children():
		if child is Button:
			_style_button(child)

func _style_button(btn: Button) -> void:
	# Normal
	var normal := StyleBoxFlat.new()
	normal.bg_color = NORMAL_BG
	normal.border_width_bottom = 0
	normal.set_corner_radius_all(0)
	btn.add_theme_stylebox_override("normal", normal)
	
	# Hover — с полосой снизу
	var hover := StyleBoxFlat.new()
	hover.bg_color = NORMAL_BG
	hover.border_width_bottom = HOVER_LINE_HEIGHT
	hover.border_color = HOVER_LINE_COLOR
	hover.set_corner_radius_all(0)
	btn.add_theme_stylebox_override("hover", hover)
	
	# Pressed
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = NORMAL_BG
	pressed.border_width_bottom = HOVER_LINE_HEIGHT
	pressed.border_color = HOVER_LINE_COLOR
	pressed.set_corner_radius_all(0)
	btn.add_theme_stylebox_override("pressed", pressed)
	
	# Focus
	var focus := StyleBoxFlat.new()
	focus.bg_color = NORMAL_BG
	focus.border_width_bottom = 0
	focus.set_corner_radius_all(0)
	btn.add_theme_stylebox_override("focus", focus)
	
	# Цвет текста
	btn.add_theme_color_override("font_color", TEXT_COLOR)
	btn.add_theme_color_override("font_hover_color", TEXT_COLOR)
	btn.add_theme_color_override("font_pressed_color", TEXT_COLOR)
	btn.add_theme_color_override("font_focus_color", TEXT_COLOR)
	
	btn.add_theme_constant_override("h_separation", 0)
	btn.custom_minimum_size = Vector2(120, 40)
