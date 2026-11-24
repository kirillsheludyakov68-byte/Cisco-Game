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
	_style_scrollbar()
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
	_populate_modules()


func _build_styles() -> void:
	_panel_normal_style = PanelNavStyles.make_panel_style()
	_panel_highlight_style = PanelNavStyles.make_panel_style(true)
	add_theme_stylebox_override("panel", _panel_normal_style)
	PanelNavStyles.apply_header_button(header_button)


# Тонкий скроллбар в стиле эталонного окна Packet Tracer.
func _style_scrollbar() -> void:
	if scroll_list == null:
		return
	var scroll_bar := scroll_list.get_v_scroll_bar()
	scroll_bar.custom_minimum_size = Vector2(10, 0)

	var scroll_style := StyleBoxFlat.new()
	scroll_style.bg_color = Color("#edf1f5")
	scroll_style.set_corner_radius_all(4)

	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color("#9aa8b5")
	grabber.set_corner_radius_all(4)
	grabber.content_margin_left = 2
	grabber.content_margin_right = 2
	grabber.content_margin_top = 2
	grabber.content_margin_bottom = 2

	var grabber_hover := grabber.duplicate() as StyleBoxFlat
	grabber_hover.bg_color = Color("#7f8f9e")
	var grabber_pressed := grabber.duplicate() as StyleBoxFlat
	grabber_pressed.bg_color = Color("#66798a")

	scroll_bar.add_theme_stylebox_override("scroll", scroll_style)
	scroll_bar.add_theme_stylebox_override("grabber", grabber)
	scroll_bar.add_theme_stylebox_override("grabber_highlight", grabber_hover)
	scroll_bar.add_theme_stylebox_override("grabber_pressed", grabber_pressed)


func _on_header_pressed() -> void:
	scroll_list.visible = not scroll_list.visible
	drop_zone.enabled = scroll_list.visible


func is_list_visible() -> bool:
	return scroll_list.visible


func get_module_button(module_name: String) -> Button:
	for child in modules_list.get_children():
		if child is Button and str(child.get("module_name")) == module_name:
			return child
	return null


func _on_highlight_changed(active: bool) -> void:
	add_theme_stylebox_override(
		"panel", _panel_highlight_style if active else _panel_normal_style
	)


func _on_module_dropped(_module_name: String, slot_index: int) -> void:
	if device_window == null:
		return
	if device_window.has_method("try_remove_module_from_slot"):
		device_window.try_remove_module_from_slot(slot_index)
	elif device_window.has_method("try_remove_module"):
		device_window.try_remove_module()


func _populate_modules() -> void:
	if modules_list == null:
		push_error("ModulesList не найден")
		return

	for child in modules_list.get_children():
		modules_list.remove_child(child)
		child.queue_free()

	var modules: Array[String] = []
	if device != null:
		modules = ModuleCatalog.get_modules_for_device(device.device_type)
	else:
		for module_name in ModuleCatalog.MODULES:
			modules.append(module_name)

	for module_name in modules:
		var btn := Button.new()
		btn.text = module_name
		# Длинные имена модулей не должны растягивать панель.
		btn.clip_text = true
		btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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
