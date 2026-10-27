extends PanelContainer
class_name ModulesPanel

signal module_selected(module_name: String)

const BUTTON_HEIGHT: int = 27
const PRESS_OFFSET_SCRIPT := preload("res://scripts/button_press_offset.gd")
const MODULE_BUTTON_SCRIPT := preload("res://scripts/module_button.gd")

@onready var header_button: Button = $RootVBox/HeaderButton
@onready var scroll_list: ScrollContainer = $RootVBox/ScrollList
@onready var modules_list: VBoxContainer = $RootVBox/ScrollList/ModulesList
@onready var drop_zone: ModuleDropZone = $DropZone

var device: Device = null
var device_window = null
var module_info_panel = null

var _panel_normal_style: StyleBoxFlat
var _panel_highlight_style: StyleBoxFlat


func _ready() -> void:
	_build_styles()
	_populate_modules()
	_apply_press_offset_to_header()

	header_button.pressed.connect(_on_header_pressed)
	drop_zone.module_dropped.connect(_on_module_dropped)
	drop_zone.highlight_changed.connect(_on_highlight_changed)


# Дополнительные аргументы оставлены для совместимости:
# панель можно использовать и без них.
func setup(dev: Device, window, module_info = null, _extra = null) -> void:
	device = dev
	device_window = window
	module_info_panel = module_info


func _build_styles() -> void:
	_panel_normal_style = PanelNavStyles.make_panel_style()
	_panel_highlight_style = PanelNavStyles.make_panel_style(true)
	add_theme_stylebox_override("panel", _panel_normal_style)
	PanelNavStyles.apply_header_button(header_button)


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
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		PanelNavStyles.apply_item_button(
			btn,
			header_button.get_theme_font("font"),
			HORIZONTAL_ALIGNMENT_CENTER
		)

		# В дерево
		modules_list.add_child(btn)

		# Скрипт — ОДИН раз (module_button уже содержит всё)
		btn.set_script(MODULE_BUTTON_SCRIPT)

		# Иконка и имя
		btn.module_texture = ModuleCatalog.get_icon(module_name)
		btn.module_name = module_name

		# Описание выбранного модуля — по клику левой кнопкой мыши
		btn.pressed.connect(_on_module_pressed.bind(module_name))


func _on_module_pressed(module_name: String) -> void:
	if module_info_panel != null and module_info_panel.has_method("show_module"):
		module_info_panel.show_module(module_name)
	module_selected.emit(module_name)


func _apply_press_offset_to_header() -> void:
	if header_button.get_script() == null:
		header_button.set_script(PRESS_OFFSET_SCRIPT)
