extends PanelContainer
class_name ModulesPanel

const MODULES: Array[String] = [
	"WMP300N",
	"PT-HOST-NM-1AM",
	"PT-HOST-NM-1CE",
	"PT-HOST-NM-1W",
]

const BUTTON_HEIGHT: int = 20

@onready var header_button: Button = $RootVBox/HeaderButton
@onready var modules_list: VBoxContainer = $RootVBox/ScrollList/ModulesList

func _ready() -> void:
	_populate_modules()

func _populate_modules() -> void:
	if modules_list == null:
		push_error("ModulesList не найден. Проверь путь в сцене.")
		return
	
	for module_name in MODULES:
		var btn := Button.new()
		btn.text = module_name
		btn.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# --- Стили (фон, рамка, скругление) ---
		var sb_normal := _make_stylebox(Color(1, 1, 1, 1))
		var sb_hover := _make_stylebox(Color(0.92, 0.92, 0.92, 1))
		var sb_pressed := _make_stylebox(Color(0.85, 0.85, 0.85, 1))
		var sb_focus := _make_stylebox(Color(1, 1, 1, 1))
		
		btn.add_theme_stylebox_override("normal", sb_normal)
		btn.add_theme_stylebox_override("hover", sb_hover)
		btn.add_theme_stylebox_override("pressed", sb_pressed)
		btn.add_theme_stylebox_override("focus", sb_focus)
		
		# --- Цвета шрифта ---
		btn.add_theme_color_override("font_color", Color(0, 0, 0, 1))
		btn.add_theme_color_override("font_hover_color", Color(0, 0, 0, 1))
		btn.add_theme_color_override("font_pressed_color", Color(0, 0, 0, 1))
		btn.add_theme_color_override("font_focus_color", Color(0, 0, 0, 1))
		
		# --- Копируем ШРИФТ и РАЗМЕР из HeaderButton (Способ 2) ---
		var font := header_button.get_theme_font("font")
		if font:
			btn.add_theme_font_override("font", font)
		
		var font_size := header_button.get_theme_font_size("font_size")
		if font_size > 0:
			btn.add_theme_font_size_override("font_size", font_size)
		
		# ПКМ — начало drag & drop
		btn.gui_input.connect(_on_module_input.bind(btn, module_name))
		
		modules_list.add_child(btn)

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

func _on_module_input(event: InputEvent, _btn: Button, module_name: String) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			print("ПКМ на модуле: ", module_name)
			# TODO: drag & drop
