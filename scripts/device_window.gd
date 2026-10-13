extends Window
class_name DeviceWindow

@onready var tab_physical: Button = $WindowRoot/TabBar/TabPhysical
@onready var tab_config: Button = $WindowRoot/TabBar/TabConfig
@onready var tab_desktop: Button = $WindowRoot/TabBar/TabDesktop

@onready var page_physical: Control = $MainPanel/ContentPanel/PagePhysical
@onready var page_config: Control = $MainPanel/ContentPanel/PageConfig
@onready var page_desktop: Control = $MainPanel/ContentPanel/PageDesktop

var device: Device = null

func _ready() -> void:
	close_requested.connect(_on_close_requested)
	tab_physical.pressed.connect(_on_tab_physical)
	tab_config.pressed.connect(_on_tab_config)
	tab_desktop.pressed.connect(_on_tab_desktop)
	_show_page("physical")

func open_for(dev: Device) -> void:
	device = dev
	title = "Устройство: " + dev.device_name
	_show_page("physical")

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
