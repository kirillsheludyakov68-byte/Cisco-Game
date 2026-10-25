extends Window
class_name DeviceWindow

const ERROR_POWER_ADD := "Невозможно добавить модуль, пока компьютер включён."
const ERROR_POWER_REMOVE := "Невозможно извлечь модуль, пока компьютер включён."
const ERROR_OCCUPIED := "В слоте уже установлен модуль. Сначала извлеките его."
const ERROR_EMPTY := "В слоте нет модуля."
const ERROR_UNKNOWN := "Неизвестный модуль."
const ERROR_DEFAULT := "Не удалось изменить модуль."

@onready var tab_physical: Button = $WindowRoot/TabBar/TabPhysical
@onready var tab_config: Button = $WindowRoot/TabBar/TabConfig
@onready var tab_desktop: Button = $WindowRoot/TabBar/TabDesktop

@onready var page_physical: Control = $MainPanel/ContentPanel/PagePhysical
@onready var page_config: Control = $MainPanel/ContentPanel/PageConfig
@onready var page_desktop: Control = $MainPanel/ContentPanel/PageDesktop

@onready var modules_panel: ModulesPanel = $MainPanel/ContentPanel/PagePhysical/PhysicalLayout/ModulesPanel
@onready var module_slot: ModuleSlot = $MainPanel/ContentPanel/PagePhysical/ViewerPanel/DeviceView/DeviceImage/ModuleSlot
@onready var module_info: ModuleInfoPanel = get_node_or_null("MainPanel/ContentPanel/PagePhysical/ModuleInfoPanel") as ModuleInfoPanel
@onready var error_dialog: ErrorDialog = $ErrorDialog

# Ищем картинку по всему дереву
@onready var device_image: TextureRect = find_child("DeviceImage", true, false)

var device: Device = null


func _ready() -> void:
	close_requested.connect(_on_close_requested)
	tab_physical.pressed.connect(_on_tab_physical)
	tab_config.pressed.connect(_on_tab_config)
	tab_desktop.pressed.connect(_on_tab_desktop)

	# Подключаем клик по картинке
	if device_image and not device_image.gui_input.is_connected(_on_device_image_gui_input):
		device_image.gui_input.connect(_on_device_image_gui_input)

	if modules_panel.has_signal("module_selected"):
		modules_panel.module_selected.connect(_show_module_info)

	_show_page("physical")


func open_for(dev: Device) -> void:
	device = dev
	title = "Устройство: " + dev.device_name
	_show_page("physical")
	_update_device_image()

	# Слот модулей есть только у ПК
	module_slot.visible = dev.device_type == "PC"
	module_slot.setup(dev, self)
	modules_panel.setup(dev, self)
	_update_module_info()


# Показываем описание установленного модуля,
# а если слот пуст — первого модуля из каталога.
func _update_module_info() -> void:
	if device != null and device.installed_module != "":
		_show_module_info(device.installed_module)
	else:
		_show_module_info(ModuleCatalog.MODULES[0])


func _show_module_info(module_name: String) -> void:
	if module_info == null or module_name == "":
		return
	module_info.show_module(module_name)


func _on_tab_physical() -> void:
	_show_page("physical")


func _on_tab_config() -> void:
	_show_page("config")


func _on_tab_desktop() -> void:
	_show_page("desktop")


func _show_page(page: String) -> void:
	page_physical.visible = (page == "physical")
	page_config.visible = (page == "config")
	page_desktop.visible = (page == "desktop")


func _on_close_requested() -> void:
	queue_free()


func _update_device_image() -> void:
	if device == null or device_image == null:
		return

	if device.device_type == "PC":
		if device.is_powered_on:
			device_image.texture = load("res://assets/devices/PC_on.png")
		else:
			device_image.texture = load("res://assets/devices/PC_off.png")
	elif device.device_type == "Switch":
		device_image.texture = load("res://assets/devices/Switch.png")
	elif device.device_type == "Router":
		device_image.texture = load("res://assets/devices/Router.png")


func _on_device_image_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Огромная зона для теста, чтобы точно попасть
		# (X, Y, Ширина, Высота) - потом подгонишь под кнопку
		var button_rect = Rect2(132, 118, 14, 21)

		if button_rect.has_point(event.position):
			if device == null:
				return

			device.set_power(not device.is_powered_on)
			_update_device_image()
			module_slot.refresh()


# --- Модули: вызываются из ModuleSlot и ModulesPanel ---

func try_install_module(module_name: String) -> void:
	if device == null:
		return

	var result: Dictionary = device.install_module(module_name)
	if result.get("ok", false):
		module_slot.refresh()
		_show_module_info(module_name)
	else:
		_show_module_error(result.get("reason", ""))


func try_remove_module() -> void:
	if device == null:
		return

	var result: Dictionary = device.remove_module()
	if result.get("ok", false):
		module_slot.refresh()
		_update_module_info()
	else:
		_show_module_error(result.get("reason", ""))


func _show_module_error(reason: String) -> void:
	var text := ERROR_DEFAULT
	match reason:
		"power_on_add":
			text = ERROR_POWER_ADD
		"power_on_remove":
			text = ERROR_POWER_REMOVE
		"occupied":
			text = ERROR_OCCUPIED
		"empty":
			text = ERROR_EMPTY
		"unknown":
			text = ERROR_UNKNOWN

	if error_dialog:
		error_dialog.show_error(text)
