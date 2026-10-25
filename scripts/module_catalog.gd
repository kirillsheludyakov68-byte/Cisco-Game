class_name ModuleCatalog
extends RefCounted

# Единый каталог модулей: используется панелью, слотом и загрузчиком уровня.
const MODULES: Array[String] = [
	"WMP300N",
	"PT-HOST-NM-1AM",
	"PT-HOST-NM-1CE",
	"PT-HOST-NM-1W",
]

const ICON_PATHS := {
	"WMP300N": "res://assets/modules/wmp300n.jpg",
	"PT-HOST-NM-1AM": "res://assets/modules/pt-host-nm-1am.jpg",
	"PT-HOST-NM-1CE": "res://assets/modules/pt-host-nm-1ce.jpg",
	"PT-HOST-NM-1W": "res://assets/modules/pt-host-nm-1w.jpg",
}


static func has_module(module_name: String) -> bool:
	return MODULES.has(module_name)


static func get_icon(module_name: String) -> Texture2D:
	var path: String = ICON_PATHS.get(module_name, "")
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path)
