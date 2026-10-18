extends PanelContainer
class_name ModulesPanel

const MODULES: Array[String] = [
	"WMP300N",
	"PT-HOST-NM-1AM",
	"PT-HOST-NM-1CE",
	"PT-HOST-NM-1W",
]

const MODULE_ICONS := {
	"WMP300N": "res://assets/modules/wmp300n.jpg",
	"PT-HOST-NM-1AM": "res://assets/modules/pt-host-nm-1am.jpg",
	"PT-HOST-NM-1CE": "res://assets/modules/pt-host-nm-1ce.jpg",
	"PT-HOST-NM-1W": "res://assets/modules/pt-host-nm-1w.jpg",
}

const BUTTON_HEIGHT: int = 20
const PRESS_OFFSET_SCRIPT := preload("res://scripts/button_press_offset.gd")
const MODULE_BUTTON_SCRIPT := preload("res://scripts/module_button.gd")

@onready var header_button: Button = $RootVBox/HeaderButton
@onready var scroll_list: ScrollContainer = $RootVBox/ScrollList
@onready var modules_list: VBoxContainer = $RootVBox/ScrollList/ModulesList

func _ready() -> void:
	_populate_modules()
	_apply_press_offset_to_header()
	header_button.pressed.connect(_on_header_pressed)

func _on_header_pressed() -> void:
	scroll_list.visible = not scroll_list.visible

func _populate_modules() -> void:
	if modules_list == null:
		push_error("ModulesList не найден")
		return
	
	for module_name in MODULES:
		var btn := Button.new()
		btn.text = module_name
		btn.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Стили
		btn.add_theme_stylebox_override("normal", _make_stylebox(Color(1, 1, 1, 1)))
		btn.add_theme_stylebox_override("hover", _make_stylebox(Color(0.85, 0.85, 0.85, 1)))
		btn.add_theme_stylebox_override("pressed", _make_stylebox(Color(0.7, 0.7, 0.7, 1)))
		btn.add_theme_stylebox_override("focus", _make_stylebox(Color(1, 1, 1, 1)))
		
		# Цвета текста
		btn.add_theme_color_override("font_color", Color(0, 0, 0, 1))
		btn.add_theme_color_override("font_hover_color", Color(0, 0, 0, 1))
		btn.add_theme_color_override("font_pressed_color", Color(0, 0, 0, 1))
		btn.add_theme_color_override("font_focus_color", Color(0, 0, 0, 1))
		btn.add_theme_color_override("font_hover_pressed_color", Color(0, 0, 0, 1))
		
		# Шрифт из HeaderButton
		var font := header_button.get_theme_font("font")
		if font:
			btn.add_theme_font_override("font", font)
		var font_size := header_button.get_theme_font_size("font_size")
		if font_size > 0:
			btn.add_theme_font_size_override("font_size", font_size)
		
		# В дерево
		modules_list.add_child(btn)
		
		# Скрипт — ОДИН раз (module_button уже содержит всё)
		btn.set_script(MODULE_BUTTON_SCRIPT)
		
		# Иконка и имя
		var icon_path: String = MODULE_ICONS.get(module_name, "")
		if icon_path != "" and ResourceLoader.exists(icon_path):
			btn.module_texture = load(icon_path)
		btn.module_name = module_name

func _apply_press_offset_to_header() -> void:
	if header_button.get_script() == null:
		header_button.set_script(PRESS_OFFSET_SCRIPT)

func _make_stylebox(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.7, 0.7, 0.7, 1)
	sb.set_corner_radius_all(4)
	sb.anti_aliasing = true
	return sb
