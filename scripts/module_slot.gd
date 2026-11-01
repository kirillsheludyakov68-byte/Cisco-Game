extends Control
class_name ModuleSlot

const PREVIEW_SIZE := Vector2(128, 128)

signal slot_clicked(slot_index: int)

var device: Device = null
var device_window = null
# Для коммутатора — номер слота 0..9. Для ПК остаётся -1.
var slot_index: int = -1

@onready var module_image: TextureRect = $ModuleImage


func setup(dev: Device, window, _module_info = null, _extra = null) -> void:
	device = dev
	device_window = window
	refresh()


func get_installed_module() -> String:
	if device == null:
		return ""
	if device.device_type == "Switch":
		return device.get_installed_module(slot_index)
	return device.installed_module


func refresh() -> void:
	var module_name := get_installed_module()
	var icon: Texture2D = ModuleCatalog.get_icon(module_name) if module_name != "" else null

	module_image.texture = icon
	module_image.visible = icon != null
	tooltip_text = module_name
	mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if icon != null else Control.CURSOR_ARROW
	)


# Начинаем тянуть установленный модуль из слота.
func _get_drag_data(_at_position: Vector2) -> Variant:
	var module_name := get_installed_module()
	if device == null or module_name == "":
		return null

	var icon: Texture2D = ModuleCatalog.get_icon(module_name)
	var preview := TextureRect.new()
	preview.texture = icon
	preview.custom_minimum_size = PREVIEW_SIZE
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.modulate = Color(1, 1, 1, 0.9)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_drag_preview(preview)

	return {
		"type": "module",
		"source": "slot",
		"module": module_name,
		"texture": icon,
		"slot_index": slot_index,
	}


# Слот принимает только модули из каталога и только если он пуст.
# Если устройство включено — принимаем дроп, чтобы показать ошибку при отпускании.
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if device == null or not data is Dictionary:
		return false
	if data.get("type", "") != "module" or data.get("source", "") != "catalog":
		return false
	return get_installed_module() == ""


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if device_window == null:
		return
	var module_name := str(data.get("module", ""))
	if device != null and device.device_type == "Switch":
		if device_window.has_method("try_install_module_to_slot"):
			device_window.try_install_module_to_slot(module_name, slot_index)
		return
	if device_window.has_method("try_install_module"):
		device_window.try_install_module(module_name)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if get_installed_module() != "":
		slot_clicked.emit(slot_index)
