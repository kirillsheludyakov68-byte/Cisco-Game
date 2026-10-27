extends RefCounted
class_name ConfigPageRegistry

# Реестр страниц конфигурации. Чтобы добавить новый модуль, достаточно
# создать его сцену и зарегистрировать её здесь. ConfigPanel не меняется.

const MODULE_PAGES := {
	"PT-HOST-NM-1CE": preload("res://scenes/PTHostNM1CEConfigPage.tscn"),
	"WMP300N": preload("res://scenes/WMP300NConfigPage.tscn"),
	"PT-HOST-NM-1W": preload("res://scenes/WMP300NConfigPage.tscn"),
	"PT-HOST-NM-1AM": preload("res://scenes/Modem0ConfigPage.tscn"),
}

const BUILTIN_PAGE := preload("res://scenes/InterfaceSettingsPage.tscn")
const FALLBACK_PAGE := preload("res://scenes/UnsupportedInterfacePage.tscn")


static func get_page_scene(source_module: String) -> PackedScene:
	if source_module.is_empty():
		return BUILTIN_PAGE
	if MODULE_PAGES.has(source_module):
		return MODULE_PAGES[source_module]
	return FALLBACK_PAGE


static func has_module_page(module_name: String) -> bool:
	return MODULE_PAGES.has(module_name)
