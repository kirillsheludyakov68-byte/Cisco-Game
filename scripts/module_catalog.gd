@tool
class_name ModuleCatalog
extends RefCounted

# Единый каталог модулей: используется панелью, слотами и загрузчиком уровня.
const PT_HOST_NM_1AM := "PT-HOST-NM-1AM"
const PT_HOST_NM_1CE := "PT-HOST-NM-1CE"
const PT_HOST_NM_1W := "PT-HOST-NM-1W"
const WMP300N := "WMP300N"

const PT_SWITCH_NM_1CE := "PT-SWITCH-NM-1CE"
const PT_SWITCH_NM_1CFE := "PT-SWITCH-NM-1CFE"
const PT_SWITCH_NM_1FGE := "PT-SWITCH-NM-1FGE"

const SWITCH_SLOT_COUNT := 10

const MODULES: Array[String] = [
	WMP300N,
	PT_HOST_NM_1AM,
	PT_HOST_NM_1CE,
	PT_HOST_NM_1W,
]

const SWITCH_MODULES: Array[String] = [
	PT_SWITCH_NM_1CE,
	PT_SWITCH_NM_1CFE,
	PT_SWITCH_NM_1FGE,
]

# Заводская конфигурация коммутатора: слот 0 — крайний справа, слот 9 — слева.
# Модули можно извлекать и заменять при выключенном устройстве.
const DEFAULT_SWITCH_MODULES := {
	0: PT_SWITCH_NM_1CE,
	1: PT_SWITCH_NM_1CE,
	2: PT_SWITCH_NM_1CE,
	3: PT_SWITCH_NM_1CE,
	4: PT_SWITCH_NM_1FGE,
	5: PT_SWITCH_NM_1FGE,
}

const ICON_PATHS := {
	WMP300N: "res://assets/modules/wmp300n.jpg",
	PT_HOST_NM_1AM: "res://assets/modules/pt-host-nm-1am.jpg",
	PT_HOST_NM_1CE: "res://assets/modules/pt-host-nm-1ce.jpg",
	PT_HOST_NM_1W: "res://assets/modules/pt-host-nm-1w.jpg",
	PT_SWITCH_NM_1CE: "res://assets/Switch/modules/gPTSwitchNM-1CE.png",
	PT_SWITCH_NM_1CFE: "res://assets/Switch/modules/gPTSwitchNM-1CFE.png",
	PT_SWITCH_NM_1FGE: "res://assets/Switch/modules/gPTSwitchNM-1FGE.png",
}

const DESCRIPTIONS := {
	WMP300N: "Модуль WMP300N обеспечивает один беспроводной интерфейс 2,4 ГГц, предназначенный для подключения к беспроводным сетям. Модуль поддерживает протоколы, использующие Ethernet для доступа к локальной сети.",
	PT_HOST_NM_1AM: "Карта PT-HOST-NM-1AM оснащена двумя разъёмами RJ-11, которые используются для базовых телефонных соединений. WIC-1AM использует один порт для подключения к стандартной телефонной линии, а второй порт можно подключить к обычному аналоговому телефону, пока модем не используется.",
	PT_HOST_NM_1CE: "Модуль PT-HOST-NM-1CE оснащён одним портом Ethernet, который может подключаться к магистральной сети LAN, также поддерживающей либо шесть соединений PRI для объединения линий ISDN, либо 24 синхронных/асинхронных порта.",
	PT_HOST_NM_1W: "Модуль PT-HOST-NM-1W обеспечивает один беспроводной интерфейс 2,4 ГГц, предназначенный для подключения к беспроводным сетям. Модуль поддерживает протоколы, использующие Ethernet для доступа к локальной сети.",
	PT_SWITCH_NM_1CE: "Модуль PT-SWITCH-NM-1CE оснащён одним портом Ethernet, который может подключаться к магистральной сети LAN, также поддерживающей либо шесть соединений PRI для объединения линий ISDN, либо 24 синхронных/асинхронных порта.",
	PT_SWITCH_NM_1CFE: "Модуль PT-SWITCH-NM-1CFE предоставляет один интерфейс Fast Ethernet для работы с медным кабелем. Идеально подходит для широкого спектра приложений локальных сетей. Сетевые модули Fast Ethernet поддерживают множество функций и стандартов. Однопортовые модули обеспечивают автоопределение 10/100BaseTX или 100BaseFX. Версия TX (медь) поддерживает развёртывание VLAN.",
	PT_SWITCH_NM_1FGE: "Однопортовый сетевой модуль Cisco Gigabit Ethernet (PT-SWITCH-NM-1FGE) обеспечивает оптическое подключение Gigabit Ethernet для доступа к маршрутизаторам. Модуль поддерживается Cisco 2691, Cisco 3660, Cisco 3725 и Cisco 3745. Модуль имеет один слот GBIC для любого стандартного медного или оптического Cisco GBIC.",
}

# Интерфейсы, которые физически предоставляют модули ПК.
# Это единственный источник названий и типов интерфейсов для Config.
const NETWORK_INTERFACES := {
	PT_HOST_NM_1CE: [
		{
			"name": "Ethernet0",
			"kind": "ethernet",
			"bandwidth_mbps": 10,
		},
	],
	WMP300N: [
		{
			"name": "Wireless0",
			"kind": "wireless",
			"bandwidth_mbps": 11,
			"ipv4_mode": "dhcp",
			"ipv6_mode": "automatic",
		},
	],
	PT_HOST_NM_1W: [
		{
			"name": "Wireless0",
			"kind": "wireless",
			"bandwidth_mbps": 11,
			"ipv4_mode": "dhcp",
			"ipv6_mode": "automatic",
		},
	],
	# У 1AM два телефонных порта RJ-11; для Config используется интерфейс модема.
	PT_HOST_NM_1AM: [
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


static func has_switch_module(module_name: String) -> bool:
	return SWITCH_MODULES.has(module_name)


static func get_modules_for_device(device_type: String) -> Array[String]:
	var result: Array[String] = []
	match device_type:
		"PC":
			for module_name in MODULES:
				result.append(module_name)
		"Switch":
			for module_name in SWITCH_MODULES:
				result.append(module_name)
	return result


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


# Имя интерфейса коммутатора: тип модуля + номер слота + /1.
# Второй номер всегда 1, потому что каждый модуль имеет один порт.
static func get_switch_interface_name(module_name: String, slot_index: int) -> String:
	var prefix := ""
	match module_name:
		PT_SWITCH_NM_1CE:
			prefix = "Ethernet"
		PT_SWITCH_NM_1CFE:
			prefix = "FastEthernet"
		PT_SWITCH_NM_1FGE:
			prefix = "GigabitEthernet"
		_:
			return ""
	return "%s%d/1" % [prefix, slot_index]


static func get_switch_interface_spec(module_name: String, slot_index: int) -> Dictionary:
	var interface_name := get_switch_interface_name(module_name, slot_index)
	if interface_name.is_empty():
		return {}

	var bandwidth_mbps := 10
	match module_name:
		PT_SWITCH_NM_1CFE:
			bandwidth_mbps = 100
		PT_SWITCH_NM_1FGE:
			bandwidth_mbps = 1000

	return {
		"name": interface_name,
		"kind": "ethernet",
		"source_module": module_name,
		"slot_index": slot_index,
		"bandwidth_mbps": bandwidth_mbps,
		"bandwidth_mode": "auto",
		"duplex_mode": "auto",
		"ipv4_mode": "static",
		"ipv6_mode": "static",
	}


static func get_switch_bandwidth_options(module_name: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	match module_name:
		PT_SWITCH_NM_1CE:
			result = [
				{"label": "10 Mbps", "value": "10mbps"},
				{"label": "Auto", "value": "auto"},
			]
		PT_SWITCH_NM_1CFE:
			result = [
				{"label": "100 Mbps", "value": "100mbps"},
				{"label": "Auto", "value": "auto"},
			]
		PT_SWITCH_NM_1FGE:
			result = [
				{"label": "1000 Mbps", "value": "1000mbps"},
				{"label": "Auto", "value": "auto"},
			]
	return result


static func get_default_switch_modules() -> Dictionary:
	return DEFAULT_SWITCH_MODULES.duplicate(true)
