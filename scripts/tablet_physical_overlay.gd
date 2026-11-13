extends Control
class_name TabletPhysicalOverlay

# Слой поверх iRealTabletPC.png: только кнопка питания.
# У планшета нет съёмных модулей, поэтому отсек для них не создаётся.

const IMAGE_SIZE := Vector2(500, 397)

# Круглая кнопка питания с индикатором под ней.
const POWER_RECT := Rect2(30, 335, 38, 43)

@onready var power_area: Control = $PowerArea
@onready var power_overlay: TextureRect = $PowerArea/PowerOnOverlay
@onready var power_off_overlay: TextureRect = $PowerArea/PowerOffOverlay

var device: Device = null
var device_window = null


func _ready() -> void:
	_apply_rect(power_area, POWER_RECT)
	power_area.gui_input.connect(_on_power_gui_input)
	visible = false


func setup(dev: Device, window) -> void:
	device = dev
	device_window = window
	refresh()


func refresh() -> void:
	var is_on := device != null and device.is_powered_on
	if power_overlay != null:
		power_overlay.visible = is_on
	if power_off_overlay != null:
		power_off_overlay.visible = device != null and not is_on


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
