extends Control
class_name SwitchPhysicalOverlay

# Слой поверх iPTRealSwitch.png: 10 отсеков и кнопка питания.
# Координаты заданы в пикселях исходной картинки и масштабируются вместе с ней.

const MODULE_SLOT_SCENE := preload("res://scenes/ModuleSlot.tscn")
const IMAGE_SIZE := Vector2(942, 91)

# Индекс 0 — крайний справа слот, индекс 9 — крайний слева.
const SLOT_RECTS: Array[Rect2] = [
	Rect2(609, 15, 55, 67),
	Rect2(543, 15, 55, 67),
	Rect2(477, 15, 55, 67),
	Rect2(411, 15, 55, 67),
	Rect2(345, 15, 55, 67),
	Rect2(280, 15, 55, 67),
	Rect2(214, 15, 55, 67),
	Rect2(148, 15, 55, 67),
	Rect2(82, 15, 55, 67),
	Rect2(17, 15, 55, 67),
]

const POWER_RECT := Rect2(796, 24, 35, 50)

@onready var slots_layer: Control = $SlotsLayer
@onready var power_area: Control = $PowerArea
@onready var power_overlay: TextureRect = $PowerArea/PowerOnOverlay

var device: Device = null
var device_window = null

var _slots: Array[ModuleSlot] = []


func _ready() -> void:
	_apply_rect(power_area, POWER_RECT)
	power_area.gui_input.connect(_on_power_gui_input)
	visible = false


func setup(dev: Device, window) -> void:
	device = dev
	device_window = window
	_build_slots()
	for slot in _slots:
		slot.setup(device, device_window)
	refresh()


func refresh() -> void:
	for slot in _slots:
		slot.refresh()
	if power_overlay != null:
		power_overlay.visible = device != null and device.is_powered_on


func _build_slots() -> void:
	if not _slots.is_empty():
		return

	for slot_index in range(ModuleCatalog.SWITCH_SLOT_COUNT):
		var slot: ModuleSlot = MODULE_SLOT_SCENE.instantiate()
		slot.name = "Slot%d" % slot_index
		slot.slot_index = slot_index
		slots_layer.add_child(slot)
		_apply_rect(slot, SLOT_RECTS[slot_index])
		slot.slot_clicked.connect(_on_slot_clicked)
		slot.gui_input.connect(_on_slot_gui_input.bind(slot))
		_slots.append(slot)


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


func _on_slot_clicked(slot_index: int) -> void:
	if device_window != null and device_window.has_method("show_slot_module_info"):
		device_window.show_slot_module_info(slot_index)


func _on_slot_gui_input(event: InputEvent, slot: ModuleSlot) -> void:
	if device_window == null or not device_window.has_method("handle_zoom_wheel"):
		return
	if device_window.handle_zoom_wheel(event):
		slot.accept_event()
