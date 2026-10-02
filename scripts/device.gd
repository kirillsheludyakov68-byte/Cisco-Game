extends Node2D
class_name Device

@onready var name_label: Label = $NameLabel
@onready var sprite: Sprite2D = $Sprite

@export var device_name: String = "PC1":
	set(value):
		device_name = value
		if name_label:
			name_label.text = value

@export var device_type: String = "PC"  # PC, Switch, Router, AccessPoint
@export var ip_address: String = ""
@export var subnet_mask: String = "255.255.255.0"

@export var texture_pc: Texture2D
@export var texture_switch: Texture2D
@export var texture_router: Texture2D
@export var texture_ap: Texture2D   # Access Point

signal device_clicked(device: Device)

var _hovered: bool = false

func _ready() -> void:
	name_label.text = device_name
	_apply_texture_by_type()
	$ClickArea.input_event.connect(_on_click_area_input_event)
	$ClickArea.mouse_entered.connect(_on_mouse_entered)
	$ClickArea.mouse_exited.connect(_on_mouse_exited)

func _apply_texture_by_type() -> void:
	match device_type:
		"PC":
			if texture_pc: sprite.texture = texture_pc
		"Switch":
			if texture_switch: sprite.texture = texture_switch
		"Router":
			if texture_router: sprite.texture = texture_router
		"AccessPoint":
			if texture_ap: sprite.texture = texture_ap

func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Клик по устройству: ", device_name)
		device_clicked.emit(self)

func _on_mouse_entered() -> void:
	_hovered = true
	# Легкая подсветка при наведении — ярче
	sprite.modulate = Color(1.2, 1.2, 1.2)

func _on_mouse_exited() -> void:
	_hovered = false
	sprite.modulate = Color(1, 1, 1)

# Публичный метод — подсветить устройство (для режима соединения)
func highlight(color: Color) -> void:
	sprite.modulate = color

func reset_highlight() -> void:
	sprite.modulate = Color(1, 1, 1)

# Проверить: подходит ли это устройство как цель для соединения
func is_compatible_with(other: Device) -> bool:
	if other == self:
		return false
	# Все устройства совместимы друг с другом
	# (валидацию кабеля сделаем позже)
	return true
