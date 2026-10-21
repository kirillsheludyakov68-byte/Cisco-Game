extends Window
class_name DeviceWindow

@onready var tab_physical: Button = $WindowRoot/TabBar/TabPhysical
@onready var tab_config: Button = $WindowRoot/TabBar/TabConfig
@onready var tab_desktop: Button = $WindowRoot/TabBar/TabDesktop

@onready var page_physical: Control = $MainPanel/ContentPanel/PagePhysical
@onready var page_config: Control = $MainPanel/ContentPanel/PageConfig
@onready var page_desktop: Control = $MainPanel/ContentPanel/PageDesktop

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
	
	_show_page("physical")

func open_for(dev: Device) -> void:
	device = dev
	title = "Устройство: " + dev.device_name
	_show_page("physical")
	_update_device_image()

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
			print("--- НАЖАТИЕ В ЗОНЕ ---")
			print("Объект device: ", device)
			
			if device == null:
				print("ОШИБКА: device всё еще null!")
				return
			
			device.is_powered_on = not device.is_powered_on
			print("УСПЕХ! ПК переключен. Теперь: ", device.is_powered_on)
			
			_update_device_image()
