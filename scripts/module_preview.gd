@tool
extends PanelContainer
class_name ModulePreview

# Отдельная настраиваемая миниатюра выбранного модуля.
# Размеры окна и картинки задаются в инспекторе,
# внешний вид рамки — в Theme Overrides → Styles → Panel этой сцены.

## Размер окна миниатюры.
@export var preview_size: Vector2 = Vector2(164, 50):
	set(value):
		preview_size = value
		custom_minimum_size = value

## Размер картинки модуля внутри окна.
@export var module_size: Vector2 = Vector2(142, 46):
	set(value):
		module_size = value
		_apply_image_size()

## Модуль, который показывать (можно задать и в редакторе).
@export var module_name: String = "":
	set(value):
		module_name = value
		if is_node_ready():
			_update_texture()


func _ready() -> void:
	custom_minimum_size = preview_size
	_apply_image_size()
	_update_texture()


func show_module(value: String) -> void:
	module_name = value
	_update_texture()


func clear() -> void:
	module_name = ""
	_update_texture()


func _apply_image_size() -> void:
	var image := get_node_or_null("Margin/ModuleImage") as TextureRect
	if image != null:
		image.custom_minimum_size = module_size


func _update_texture() -> void:
	var image := get_node_or_null("Margin/ModuleImage") as TextureRect
	if image == null:
		return

	var icon: Texture2D = ModuleCatalog.get_icon(module_name) if module_name != "" else null
	image.texture = icon
	image.visible = icon != null
