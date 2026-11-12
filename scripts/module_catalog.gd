@tool
class_name ModuleCatalog
extends RefCounted

# Единый каталог модулей: используется панелью, слотами и загрузчиком уровня.
const PT_HOST_NM_1AM := "PT-HOST-NM-1AM"
const PT_HOST_NM_1CE := "PT-HOST-NM-1CE"
const PT_HOST_NM_1CFE := "PT-HOST-NM-1CFE"
const PT_HOST_NM_1FGE := "PT-HOST-NM-1FGE"
const PT_HOST_NM_1W := "PT-HOST-NM-1W"
const WMP300N := "WMP300N"

# Съёмные модули ноутбука.
const WPC300N := "WPC300N"
const PT_LAPTOP_NM_1CFE := "PT-LAPTOP-NM-1CFE"
const PT_LAPTOP_NM_1FGE := "PT-LAPTOP-NM-1FGE"

const PT_SWITCH_NM_1CE := "PT-SWITCH-NM-1CE"
const PT_SWITCH_NM_1CFE := "PT-SWITCH-NM-1CFE"
const PT_SWITCH_NM_1FGE := "PT-SWITCH-NM-1FGE"

const PT_REPEATER_NM_1CE := "PT-REPEATER-NM-1CE"
const PT_REPEATER_NM_1CFE := "PT-REPEATER-NM-1CFE"

const SWITCH_SLOT_COUNT := 10
const HUB_SLOT_COUNT := 10

# Устройства с десятью слотами съёмных модулей.
const SLOT_DEVICE_TYPES: Array[String] = ["Switch", "Hub"]

# Устройства, которые используют съёмные host-модули.
const HOST_MODULE_DEVICE_TYPES: Array[String] = [
	"PC",
	"Laptop",
	"Tablet",
	"Printer",
]

const MODULES: Array[String] = [
	WMP300N,
	PT_HOST_NM_1AM,
	PT_HOST_NM_1CE,
	PT_HOST_NM_1W,
]

# В ноутбук устанавливаются только эти три модуля.
const LAPTOP_MODULES: Array[String] = [
	WPC300N,
	PT_LAPTOP_NM_1CFE,
	PT_LAPTOP_NM_1FGE,
]

# Модули принтера: проводные Ethernet/FastEthernet/GigabitEthernet
# и беспроводной PT-HOST-NM-1W.
const PRINTER_MODULES: Array[String] = [
	PT_HOST_NM_1CE,
	PT_HOST_NM_1CFE,
	PT_HOST_NM_1FGE,
	PT_HOST_NM_1W,
]

const SWITCH_MODULES: Array[String] = [
	PT_SWITCH_NM_1CE,
	PT_SWITCH_NM_1CFE,
	PT_SWITCH_NM_1FGE,
]

const HUB_MODULES: Array[String] = [
	PT_REPEATER_NM_1CE,
	PT_REPEATER_NM_1CFE,
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

# Хаб собирается из модулей так же, как коммутатор. По умолчанию слоты
# пусты: порты появляются только после установки модуля.
const DEFAULT_HUB_MODULES := {}

const ICON_PATHS := {
	WMP300N: "res://assets/modules/wmp300n.jpg",
	PT_HOST_NM_1AM: "res://assets/modules/pt-host-nm-1am.jpg",
	PT_HOST_NM_1CE: "res://assets/Printer/gPTHostNM-1CE.png",
	PT_HOST_NM_1CFE: "res://assets/Printer/gPTHostNM-1CFE.png",
	PT_HOST_NM_1FGE: "res://assets/Printer/gPTHostNM-1FGE.png",
	PT_HOST_NM_1W: "res://assets/Printer/gPTHostNM-1W.png",
	WPC300N: "res://assets/modules/gPTLaptopNM-1W.png",
	PT_LAPTOP_NM_1CFE: "res://assets/modules/gPTLaptopNM-1CFE.png",
	PT_LAPTOP_NM_1FGE: "res://assets/modules/gPTLaptopNM-1FGE.png",
	PT_SWITCH_NM_1CE: "res://assets/Switch/modules/gPTSwitchNM-1CE.png",
	PT_SWITCH_NM_1CFE: "res://assets/Switch/modules/gPTSwitchNM-1CFE.png",
	PT_SWITCH_NM_1FGE: "res://assets/Switch/modules/gPTSwitchNM-1FGE.png",
	PT_REPEATER_NM_1CE: "res://assets/devices/gPTRepeaterNM-1CE.png",
	PT_REPEATER_NM_1CFE: "res://assets/devices/gPTRepeaterNM-1CFE.png",
}

const DESCRIPTIONS := {
	WMP300N: "Модуль WMP300N обеспечивает один беспроводной интерфейс 2,4 ГГц, предназначенный для подключения к беспроводным сетям. Модуль поддерживает протоколы, использующие Ethernet для доступа к локальной сети.",
	PT_HOST_NM_1AM: "Карта PT-HOST-NM-1AM оснащена двумя разъёмами RJ-11, которые используются для базовых телефонных соединений. WIC-1AM использует один порт для подключения к стандартной телефонной линии, а второй порт можно подключить к обычному аналоговому телефону, пока модем не используется.",
	PT_HOST_NM_1CE: "Модуль PT-HOST-NM-1CE оснащён одним портом Ethernet, который может подключаться к магистральной сети LAN, также поддерживающей либо шесть соединений PRI для объединения линий ISDN, либо 24 синхронных/асинхронных порта.",
	PT_HOST_NM_1CFE: "Модуль PT-HOST-NM-1CFE предоставляет один интерфейс Fast Ethernet для работы с медным кабелем. Идеально подходит для широкого спектра приложений локальных сетей. Сетевые модули Fast Ethernet поддерживают множество функций и стандартов. Однопортовые модули обеспечивают автоопределение 10/100BaseTX или 100BaseFX. Версия TX (медь) поддерживает развёртывание VLAN.",
	PT_HOST_NM_1FGE: "Однопортовый сетевой модуль Cisco Gigabit Ethernet (PT-HOST-NM-1FGE) обеспечивает оптическое подключение Gigabit Ethernet для доступа к маршрутизаторам. Модуль поддерживается Cisco 2691, Cisco 3660, Cisco 3725 и Cisco 3745. Модуль имеет один слот GBIC для любого стандартного медного или оптического Cisco GBIC.",
	PT_HOST_NM_1W: "Модуль PT-HOST-NM-1W обеспечивает один беспроводной интерфейс 2,4 ГГц, предназначенный для подключения к беспроводным сетям. Модуль поддерживает протоколы, использующие Ethernet для доступа к локальной сети.",
	WPC300N: "Модуль WPC300N обеспечивает один беспроводной интерфейс 2,4 ГГц, предназначенный для подключения к беспроводным сетям. Модуль поддерживает протоколы, использующие Ethernet для доступа к локальной сети.",
	PT_LAPTOP_NM_1CFE: "Модуль PT-LAPTOP-NM-1CFE предоставляет один интерфейс Fast Ethernet для работы с медным кабелем. Идеально подходит для широкого спектра приложений локальных сетей. Сетевые модули Fast Ethernet поддерживают множество функций и стандартов. Однопортовые модули обеспечивают автоопределение 10/100BaseTX или 100BaseFX. Версия TX (медь) поддерживает развёртывание VLAN.",
	PT_LAPTOP_NM_1FGE: "Однопортовый сетевой модуль Cisco Gigabit Ethernet (PT-LAPTOP-NM-1FGE) обеспечивает оптическое подключение Gigabit Ethernet для доступа к маршрутизаторам. Модуль поддерживается Cisco 2691, Cisco 3660, Cisco 3725 и Cisco 3745. Модуль имеет один слот GBIC для любого стандартного медного или оптического Cisco GBIC.",
	PT_SWITCH_NM_1CE: "Модуль PT-SWITCH-NM-1CE оснащён одним портом Ethernet, который может подключаться к магистральной сети LAN, также поддерживающей либо шесть соединений PRI для объединения линий ISDN, либо 24 синхронных/асинхронных порта.",
	PT_SWITCH_NM_1CFE: "Модуль PT-SWITCH-NM-1CFE предоставляет один интерфейс Fast Ethernet для работы с медным кабелем. Идеально подходит для широкого спектра приложений локальных сетей. Сетевые модули Fast Ethernet поддерживают множество функций и стандартов. Однопортовые модули обеспечивают автоопределение 10/100BaseTX или 100BaseFX. Версия TX (медь) поддерживает развёртывание VLAN.",
	PT_SWITCH_NM_1FGE: "Однопортовый сетевой модуль Cisco Gigabit Ethernet (PT-SWITCH-NM-1FGE) обеспечивает оптическое подключение Gigabit Ethernet для доступа к маршрутизаторам. Модуль поддерживается Cisco 2691, Cisco 3660, Cisco 3725 и Cisco 3745. Модуль имеет один слот GBIC для любого стандартного медного или оптического Cisco GBIC.",
	PT_REPEATER_NM_1CE: "Модуль повторителя PT-REPEATER-NM-1CE добавляет хабу один порт Ethernet 10 Мбит/с для подключения оконечных устройств или другого концентратора.",
	PT_REPEATER_NM_1CFE: "Модуль повторителя PT-REPEATER-NM-1CFE добавляет хабу один порт Fast Ethernet 100 Мбит/с для подключения оконечных устройств или другого концентратора.",
}

# Интерфейсы, которые физически предоставляют модули host-устройств.
# Это единственный источник названий и типов интерфейсов для Config.
const NETWORK_INTERFACES := {
	PT_HOST_NM_1CE: [
		{
			"name": "Ethernet0",
			"kind": "ethernet",
			"bandwidth_mbps": 10,
		},
	],
	PT_HOST_NM_1CFE: [
		{
			"name": "FastEthernet0",
			"kind": "ethernet",
			"bandwidth_mbps": 100,
			"bandwidth_mode": "100mbps",
		},
	],
	PT_HOST_NM_1FGE: [
		{
			"name": "GigabitEthernet0",
			"kind": "fiber",
			"bandwidth_mbps": 1000,
			"bandwidth_mode": "1000mbps",
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
	WPC300N: [
		{
			"name": "Wireless0",
			"kind": "wireless",
			"bandwidth_mbps": 54,
			"ipv4_mode": "dhcp",
			"ipv6_mode": "automatic",
		},
	],
	PT_LAPTOP_NM_1CFE: [
		{
			"name": "FastEthernet0",
			"kind": "ethernet",
			"bandwidth_mbps": 100,
		},
	],
	PT_LAPTOP_NM_1FGE: [
		{
			"name": "GigabitEthernet0",
			"kind": "fiber",
			"bandwidth_mbps": 1000,
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
		# Оптический порт нужен, чтобы правило Switch ↔ Router по Fiber
		# можно было проверить на реальных интерфейсах, а не только в таблице.
		{
			"name": "Fiber0",
			"kind": "fiber",
		},
	],
	"AccessPoint": [
		{
			"name": "FastEthernet0",
			"kind": "ethernet",
		},
		{
			"name": "Wireless0",
			"kind": "wireless",
			"bandwidth_mbps": 11,
			"ipv4_mode": "static",
			"ipv6_mode": "static",
		},
	],
	"Server": [
		{
			"name": "Ethernet0",
			"kind": "ethernet",
			"bandwidth_mbps": 1000,
		},
	],
}


static func has_module(module_name: String) -> bool:
	return MODULES.has(module_name) \
		or LAPTOP_MODULES.has(module_name) \
		or PRINTER_MODULES.has(module_name)


static func has_switch_module(module_name: String) -> bool:
	return SWITCH_MODULES.has(module_name)


static func is_slot_device(device_type: String) -> bool:
	return SLOT_DEVICE_TYPES.has(device_type)


static func get_slot_count(device_type: String) -> int:
	if device_type == "Hub":
		return HUB_SLOT_COUNT
	if device_type == "Switch":
		return SWITCH_SLOT_COUNT
	return 0


static func get_slot_modules(device_type: String) -> Array[String]:
	var result: Array[String] = []
	if device_type == "Switch":
		for module_name in SWITCH_MODULES:
			result.append(module_name)
	elif device_type == "Hub":
		for module_name in HUB_MODULES:
			result.append(module_name)
	return result


static func has_slot_module(device_type: String, module_name: String) -> bool:
	return get_slot_modules(device_type).has(module_name)


static func uses_host_modules(device_type: String) -> bool:
	return HOST_MODULE_DEVICE_TYPES.has(device_type)


static func get_modules_for_device(device_type: String) -> Array[String]:
	var result: Array[String] = []
	if device_type == "Laptop":
		for module_name in LAPTOP_MODULES:
			result.append(module_name)
	elif device_type == "Printer":
		for module_name in PRINTER_MODULES:
			result.append(module_name)
	elif uses_host_modules(device_type):
		for module_name in MODULES:
			result.append(module_name)
	else:
		result = get_slot_modules(device_type)
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


# Имя интерфейса слота: тип модуля + номер слота + /1.
# Второй номер всегда 1, потому что каждый модуль имеет один порт.
static func get_slot_interface_name(module_name: String, slot_index: int) -> String:
	var prefix := ""
	match module_name:
		PT_SWITCH_NM_1CE, PT_REPEATER_NM_1CE:
			prefix = "Ethernet"
		PT_SWITCH_NM_1CFE, PT_REPEATER_NM_1CFE:
			prefix = "FastEthernet"
		PT_SWITCH_NM_1FGE:
			prefix = "GigabitEthernet"
		_:
			return ""
	return "%s%d/1" % [prefix, slot_index]


static func get_switch_interface_name(module_name: String, slot_index: int) -> String:
	return get_slot_interface_name(module_name, slot_index)


static func get_slot_interface_spec(
	device_type: String,
	module_name: String,
	slot_index: int
) -> Dictionary:
	if not has_slot_module(device_type, module_name):
		return {}
	var interface_name := get_slot_interface_name(module_name, slot_index)
	if interface_name.is_empty():
		return {}

	var bandwidth_mbps := 10
	var interface_kind := "ethernet"
	match module_name:
		PT_SWITCH_NM_1CFE, PT_REPEATER_NM_1CFE:
			bandwidth_mbps = 100
		PT_SWITCH_NM_1FGE:
			bandwidth_mbps = 1000
			# PT-SWITCH-NM-1FGE — оптический Gigabit Ethernet.
			interface_kind = "fiber"

	return {
		"name": interface_name,
		"kind": interface_kind,
		"source_module": module_name,
		"slot_index": slot_index,
		"bandwidth_mbps": bandwidth_mbps,
		"bandwidth_mode": "auto",
		"duplex_mode": "auto",
		"ipv4_mode": "static",
		"ipv6_mode": "static",
	}


static func get_switch_interface_spec(module_name: String, slot_index: int) -> Dictionary:
	return get_slot_interface_spec("Switch", module_name, slot_index)


static func get_slot_bandwidth_options(module_name: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	match module_name:
		PT_SWITCH_NM_1CE, PT_REPEATER_NM_1CE:
			result = [
				{"label": "10 Mbps", "value": "10mbps"},
				{"label": "Auto", "value": "auto"},
			]
		PT_SWITCH_NM_1CFE, PT_REPEATER_NM_1CFE:
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


static func get_switch_bandwidth_options(module_name: String) -> Array[Dictionary]:
	return get_slot_bandwidth_options(module_name)


static func get_default_slot_modules(device_type: String) -> Dictionary:
	if device_type == "Hub":
		return DEFAULT_HUB_MODULES.duplicate(true)
	if device_type == "Switch":
		return DEFAULT_SWITCH_MODULES.duplicate(true)
	return {}


static func get_default_switch_modules() -> Dictionary:
	return DEFAULT_SWITCH_MODULES.duplicate(true)
