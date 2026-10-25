extends Control
class_name ModuleSlot

const PREVIEW_SIZE := Vector2(128, 128)

var device: Device = null
var device_window = null

@onready var module_image: TextureRect = $ModuleImage


func setup(dev: Device, window) -> void:
	device = dev
	device_window = window
	refresh()


func refresh() -> void:
	var module_name: String = device.installed_module if device != null else ""
	var icon: Texture2D = ModuleCatalog.get_icon(module_name) if module_name != "" else null

	module_image.texture = icon
	module_image.visible = icon != null
	tooltip_text = module_name
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if icon != null else Control.CURSOR_ARROW


# Начинаем тянуть установленный модуль из слота.
func _get_drag_data(_at_position: Vector2) -> Variant:
	if device == null or device.installed_module == "":
		return null

	var icon: Texture2D = ModuleCatalog.get_icon(device.installed_module)
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
		"module": device.installed_module,
		"texture": icon,
	}


# Слот принимает только модули из каталога и только если он пуст.
# Если ПК включён — принимаем дроп, чтобы показать ошибку при отпускании.
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if device == null or not data is Dictionary:
		return false
	if data.get("type", "") != "module" or data.get("source", "") != "catalog":
		return false
	return device.installed_module == ""


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if device_window == null:
		return
	device_window.try_install_module(data.get("module", ""))
