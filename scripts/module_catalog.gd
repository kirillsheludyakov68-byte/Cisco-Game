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

# Интерфейсы, которые физически предоставляют модули.
# Это единственный источник названий и типов интерфейсов для Config.
const NETWORK_INTERFACES := {
	"PT-HOST-NM-1CE": [
		{
			"name": "Ethernet0",
			"kind": "ethernet",
			"bandwidth_mbps": 10,
		},
	],
	"WMP300N": [
		{
			"name": "Wireless0",
			"kind": "wireless",
			"bandwidth_mbps": 11,
			"ipv4_mode": "dhcp",
			"ipv6_mode": "automatic",
		},
	],
	"PT-HOST-NM-1W": [
		{
			"name": "Wireless0",
			"kind": "wireless",
			"bandwidth_mbps": 11,
			"ipv4_mode": "dhcp",
			"ipv6_mode": "automatic",
		},
	],
	# У 1AM два телефонных порта RJ-11; для Config используется интерфейс модема.
	"PT-HOST-NM-1AM": [
		{
			"name": "Modem0",
			"kind": "modem",
			"bandwidth_mbps": 0,
			"bandwidth_kbps": 56,
			"duplex_mode": "full",
			"ipv4_mode": "static",
			"ipv6_mode": "static",
			"ipv6_prefix": 64,
		},
	],
}

# Устройства без слотов модулей сохраняют один встроенный интерфейс,
# который использовался в проекте до появления модульной конфигурации.
const BUILTIN_INTERFACES := {
	"Switch": [
		{
			"name": "FastEthernet0",
			"kind": "ethernet",
		},
	],
	"Router": [
		{
			"name": "FastEthernet0",
			"kind": "ethernet",
		},
	],
	"AccessPoint": [
		{
			"name": "FastEthernet0",
			"kind": "ethernet",
		},
	],
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


static func get_network_interfaces(module_name: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for spec in NETWORK_INTERFACES.get(module_name, []):
		result.append((spec as Dictionary).duplicate(true))
	return result


static func get_builtin_interfaces(device_type: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for spec in BUILTIN_INTERFACES.get(device_type, []):
		result.append((spec as Dictionary).duplicate(true))
	return result
