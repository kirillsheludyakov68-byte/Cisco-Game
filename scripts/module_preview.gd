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

## Размер окна для вертикальных модулей коммутатора (55×67).
@export var portrait_preview_size: Vector2 = Vector2(68, 76)

## Размер картинки для вертикальных модулей коммутатора.
@export var portrait_module_size: Vector2 = Vector2(55, 67)

## Модуль, который показывать (можно задать и в редакторе).
@export var module_name: String = "":
	set(value):
		module_name = value
		if is_node_ready():
			_update_texture()


func _ready() -> void:
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


func _apply_sizes(panel_size: Vector2, image_size: Vector2) -> void:
	custom_minimum_size = panel_size
	var image := get_node_or_null("Margin/ModuleImage") as TextureRect
	if image != null:
		image.custom_minimum_size = image_size


func _update_texture() -> void:
	var image := get_node_or_null("Margin/ModuleImage") as TextureRect
	if image == null:
		return

	var icon: Texture2D = ModuleCatalog.get_icon(module_name) if module_name != "" else null
	var is_portrait := icon != null and icon.get_height() > icon.get_width()
	if is_portrait:
		_apply_sizes(portrait_preview_size, portrait_module_size)
	else:
		_apply_sizes(preview_size, module_size)

	image.texture = icon
	image.visible = icon != null
