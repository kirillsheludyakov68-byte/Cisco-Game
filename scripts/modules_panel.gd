extends PanelContainer
class_name ModulesPanel

const BUTTON_HEIGHT: int = 27
const PRESS_OFFSET_SCRIPT := preload("res://scripts/button_press_offset.gd")
const MODULE_BUTTON_SCRIPT := preload("res://scripts/module_button.gd")

const HIGHLIGHT_BG := Color(1.0, 1.0, 0.78, 1.0)

@onready var header_button: Button = $RootVBox/HeaderButton
@onready var scroll_list: ScrollContainer = $RootVBox/ScrollList
@onready var modules_list: VBoxContainer = $RootVBox/ScrollList/ModulesList
@onready var drop_zone: ModuleDropZone = $DropZone

var device: Device = null
var device_window = null

var _panel_normal_style: StyleBoxFlat
var _panel_highlight_style: StyleBoxFlat


func _ready() -> void:
	_build_styles()
	_populate_modules()
	_apply_press_offset_to_header()

	header_button.pressed.connect(_on_header_pressed)
	drop_zone.module_dropped.connect(_on_module_dropped)
	drop_zone.highlight_changed.connect(_on_highlight_changed)


func setup(dev: Device, window) -> void:
	device = dev
	device_window = window


func _build_styles() -> void:
	var base_style := get_theme_stylebox("panel")
	if base_style is StyleBoxFlat:
		_panel_normal_style = base_style.duplicate() as StyleBoxFlat
	else:
		_panel_normal_style = StyleBoxFlat.new()

	_panel_highlight_style = _panel_normal_style.duplicate() as StyleBoxFlat
	_panel_highlight_style.bg_color = HIGHLIGHT_BG

	add_theme_stylebox_override("panel", _panel_normal_style)


func _on_header_pressed() -> void:
	scroll_list.visible = not scroll_list.visible
	drop_zone.enabled = scroll_list.visible


func _on_highlight_changed(active: bool) -> void:
	add_theme_stylebox_override(
		"panel", _panel_highlight_style if active else _panel_normal_style
	)


func _on_module_dropped(_module_name: String) -> void:
	if device_window != null:
		device_window.try_remove_module()


func _populate_modules() -> void:
	if modules_list == null:
		push_error("ModulesList не найден")
		return

	for module_name in ModuleCatalog.MODULES:
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
		btn.module_texture = ModuleCatalog.get_icon(module_name)
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
