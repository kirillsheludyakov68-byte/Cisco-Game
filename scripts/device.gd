extends Node2D
class_name Device

@onready var sprite: Sprite2D = $Sprite
@onready var name_label: Label = $NameLabel
@onready var collision_shape: CollisionShape2D = $ClickArea/CollisionShape2D

@export var device_name: String = "PC1":
	set(value):
		device_name = value
		if name_label:
			name_label.text = value

@export var device_type: String = "PC":
	set(value):
		device_type = value
		if sprite:
			_apply_texture_by_type()
		if collision_shape:
			_fit_sprite_to_collision()

@export var ip_address: String = ""
@export var subnet_mask: String = "255.255.255.0"

@export var texture_pc: Texture2D
@export var texture_switch: Texture2D
@export var texture_router: Texture2D
@export var texture_ap: Texture2D

signal device_clicked(device: Device)

func _ready() -> void:
	if name_label:
		name_label.text = device_name
	_apply_texture_by_type()
	_fit_sprite_to_collision()
	$ClickArea.input_event.connect(_on_click_area_input_event)
	$ClickArea.mouse_entered.connect(_on_mouse_entered)
	$ClickArea.mouse_exited.connect(_on_mouse_exited)

func _apply_texture_by_type() -> void:
	if not sprite:
		return
	match device_type:
		"PC":
			if texture_pc: sprite.texture = texture_pc
		"Switch":
			if texture_switch: sprite.texture = texture_switch
		"Router":
			if texture_router: sprite.texture = texture_router
		"AccessPoint":
			if texture_ap: sprite.texture = texture_ap

func _fit_sprite_to_collision() -> void:
	if not sprite or not sprite.texture:
		return
	if not collision_shape or not collision_shape.shape is RectangleShape2D:
		return
	var target_size: Vector2 = collision_shape.shape.size
	var tex_size: Vector2 = sprite.texture.get_size()
	if tex_size.x <= 0 or tex_size.y <= 0:
		return
	var ratio_x := target_size.x / tex_size.x
	var ratio_y := target_size.y / tex_size.y
	var ratio := minf(ratio_x, ratio_y)
	sprite.scale = Vector2(ratio, ratio)

func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Клик по устройству: ", device_name)
		device_clicked.emit(self)

func _on_mouse_entered() -> void:
	if sprite:
		sprite.modulate = Color(1.2, 1.2, 1.2)

func _on_mouse_exited() -> void:
	if sprite:
		sprite.modulate = Color(1, 1, 1)

func highlight(color: Color) -> void:
	if sprite:
		sprite.modulate = color

func reset_highlight() -> void:
	if sprite:
		sprite.modulate = Color(1, 1, 1)
