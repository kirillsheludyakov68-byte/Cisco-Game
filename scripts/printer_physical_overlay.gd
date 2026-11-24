extends Control
class_name PrinterPhysicalOverlay

# Слой поверх iRealPrinter.png: отсек для съёмного модуля и кнопка питания.
# Координаты заданы в пикселях исходной картинки и масштабируются вместе с ней.

const MODULE_SLOT_SCENE := preload("res://scenes/ModuleSlot.tscn")
const IMAGE_SIZE := Vector2(400, 427)

# Чёрный отсек для модуля на передней панели принтера.
const MODULE_RECT := Rect2(306, 159, 87, 27)

# Круглая кнопка питания с индикатором под ней.
const POWER_RECT := Rect2(331, 67, 29, 32)

@onready var slots_layer: Control = $SlotsLayer
@onready var power_area: Control = $PowerArea
@onready var power_overlay: TextureRect = $PowerArea/PowerOnOverlay
@onready var power_off_overlay: TextureRect = $PowerArea/PowerOffOverlay

var device: Device = null
var device_window = null

var _slot: ModuleSlot = null


func _ready() -> void:
	_apply_rect(power_area, POWER_RECT)
	power_area.gui_input.connect(_on_power_gui_input)
	visible = false


func setup(dev: Device, window) -> void:
	device = dev
	device_window = window
	_build_slot()
	if _slot != null:
		_slot.setup(device, device_window)
	refresh()


func get_slot() -> ModuleSlot:
	return _slot


func refresh() -> void:
	if _slot != null:
		_slot.refresh()
	var is_on := device != null and device.is_powered_on
	if power_overlay != null:
		power_overlay.visible = is_on
	if power_off_overlay != null:
		power_off_overlay.visible = device != null and not is_on


func _build_slot() -> void:
	if _slot != null:
		return

	_slot = MODULE_SLOT_SCENE.instantiate()
	_slot.name = "ModuleSlot"
	_slot.slot_index = -1
	slots_layer.add_child(_slot)
	_apply_rect(_slot, MODULE_RECT)
	_slot.slot_clicked.connect(_on_slot_clicked)
	_slot.gui_input.connect(_on_slot_gui_input)


func _apply_rect(control: Control, rect: Rect2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.anchor_left = rect.position.x / IMAGE_SIZE.x
	control.anchor_top = rect.position.y / IMAGE_SIZE.y
	control.anchor_right = (rect.position.x + rect.size.x) / IMAGE_SIZE.x
	control.anchor_bottom = (rect.position.y + rect.size.y) / IMAGE_SIZE.y
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0


func _on_power_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if device_window != null and device_window.has_method("toggle_power"):
		device_window.toggle_power()
	elif device != null:
		device.set_power(not device.is_powered_on)


func _on_slot_clicked(_slot_index: int) -> void:
	if device_window != null and device_window.has_method("show_slot_module_info"):
		device_window.show_slot_module_info(-1)


func _on_slot_gui_input(event: InputEvent) -> void:
	if device_window == null or not device_window.has_method("handle_zoom_wheel"):
		return
	if device_window.handle_zoom_wheel(event):
		_slot.accept_event()
