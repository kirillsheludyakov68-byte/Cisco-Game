extends Control
class_name ServerPhysicalOverlay

# Слой поверх iRealServer.png: два слота съёмных модулей (верхний и нижний)
# и кнопка питания. Координаты заданы в пикселях исходной картинки
# и масштабируются вместе с ней.

const MODULE_SLOT_SCENE := preload("res://scenes/ModuleSlot.tscn")
const IMAGE_SIZE := Vector2(1010, 443)

# Верхний и нижний тёмные отсеки на правой панели корпуса.
const UPPER_MODULE_RECT := Rect2(733, 159, 172, 50)
const LOWER_MODULE_RECT := Rect2(733, 234, 172, 50)

# Кнопка питания с индикатором (PowerOnServer.png / PowerOffServer.png).
const POWER_RECT := Rect2(760, 292, 57, 63)

@onready var slots_layer: Control = $SlotsLayer
@onready var power_area: Control = $PowerArea
@onready var power_overlay: TextureRect = $PowerArea/PowerOnOverlay
@onready var power_off_overlay: TextureRect = $PowerArea/PowerOffOverlay

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


func get_slot(slot_index: int = 0) -> ModuleSlot:
	if slot_index < 0 or slot_index >= _slots.size():
		return null
	return _slots[slot_index]


func refresh() -> void:
	for slot in _slots:
		slot.refresh()
	var is_on := device != null and device.is_powered_on
	if power_overlay != null:
		power_overlay.visible = is_on
	if power_off_overlay != null:
		power_off_overlay.visible = device != null and not is_on


func _build_slots() -> void:
	if not _slots.is_empty():
		return

	var rects := [UPPER_MODULE_RECT, LOWER_MODULE_RECT]
	for slot_index in range(rects.size()):
		var slot := MODULE_SLOT_SCENE.instantiate() as ModuleSlot
		slot.name = "ModuleSlot%d" % slot_index
		slot.slot_index = slot_index
		slots_layer.add_child(slot)
		# Иконки модулей сервера должны заполнять отсек целиком.
		slot.module_image.stretch_mode = TextureRect.STRETCH_SCALE
		_apply_rect(slot, rects[slot_index])
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
