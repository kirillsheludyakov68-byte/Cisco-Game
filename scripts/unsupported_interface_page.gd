extends PanelContainer
class_name UnsupportedInterfacePage

@onready var header_panel: PanelContainer = $Root/VBox/HeaderPanel
@onready var header_label: Label = $Root/VBox/HeaderPanel/HeaderLabel
@onready var message_label: Label = $Root/VBox/BodyScroll/Body/MessageLabel
@onready var module_label: Label = $Root/VBox/BodyScroll/Body/ModuleLabel

var device: Device = null
var network_interface: DeviceInterface = null
var source_module: String = ""


func _ready() -> void:
	_apply_styles()


func setup(dev: Device, iface: DeviceInterface, module_name: String = "") -> void:
	device = dev
	network_interface = iface
	source_module = module_name
	refresh()


func refresh() -> void:
	header_label.text = network_interface.interface_name if network_interface != null else "Интерфейс"
	message_label.text = (
		"Настройки этого интерфейса пока не реализованы. "
		+ "Для модуля не зарегистрирована страница конфигурации."
	)
	if not source_module.is_empty():
		module_label.text = "Модуль: " + source_module
	elif device != null:
		module_label.text = "Встроенный интерфейс устройства " + device.device_name
	else:
		module_label.text = ""


func _apply_styles() -> void:
	add_theme_stylebox_override("panel", ConfigStyles.content_panel())
	header_panel.add_theme_stylebox_override("panel", ConfigStyles.header_panel())
	ConfigStyles.apply_bold_label(header_label, 16)
	ConfigStyles.apply_label(message_label)
	ConfigStyles.apply_label(module_label, 13, true)
