@tool
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

const DESCRIPTIONS := {
	"WMP300N": "Модуль WMP300N обеспечивает один беспроводной интерфейс 2,4 ГГц, предназначенный для подключения к беспроводным сетям. Модуль поддерживает протоколы, использующие Ethernet для доступа к локальной сети.",
	"PT-HOST-NM-1AM": "Карта PT-HOST-NM-1AM оснащена двумя разъёмами RJ-11, которые используются для базовых телефонных соединений. WIC-1AM использует один порт для подключения к стандартной телефонной линии, а второй порт можно подключить к обычному аналоговому телефону, пока модем не используется.",
	"PT-HOST-NM-1CE": "Модуль PT-HOST-NM-1CE оснащён одним портом Ethernet, который может подключаться к магистральной сети LAN, также поддерживающей либо шесть соединений PRI для объединения линий ISDN, либо 24 синхронных/асинхронных порта.",
	"PT-HOST-NM-1W": "Модуль PT-HOST-NM-1W обеспечивает один беспроводной интерфейс 2,4 ГГц, предназначенный для подключения к беспроводным сетям. Модуль поддерживает протоколы, использующие Ethernet для доступа к локальной сети.",
}


static func has_module(module_name: String) -> bool:
	return MODULES.has(module_name)


static func get_icon(module_name: String) -> Texture2D:
	var path: String = ICON_PATHS.get(module_name, "")
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path)


static func get_description(module_name: String) -> String:
	return DESCRIPTIONS.get(module_name, "")
