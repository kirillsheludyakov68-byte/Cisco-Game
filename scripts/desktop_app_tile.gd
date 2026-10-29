extends VBoxContainer
class_name DesktopAppTile

signal activated(app_id: String)

@onready var icon_frame: PanelContainer = $IconFrame
@onready var icon_margin: MarginContainer = $IconFrame/IconMargin
@onready var icon: TextureRect = $IconFrame/IconMargin/IconCenter/Icon
@onready var missing_icon: Label = $IconFrame/IconMargin/IconCenter/MissingIcon
@onready var caption: Label = $Caption

var app_id: String = ""

var _hovered := false
var _pressed := false
var _tween: Tween = null


func _ready() -> void:
	_apply_styles()
	resized.connect(_on_resized)
	call_deferred("_on_resized")
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func configure(app: Dictionary) -> void:
	app_id = str(app.get("id", ""))
	caption.text = str(app.get("title", app_id))
	tooltip_text = caption.text
	_apply_styles()

	var texture := DesktopAppCatalog.get_icon(app_id)
	if texture != null:
		icon.texture = texture
		icon.visible = true
		missing_icon.visible = false
	else:
		icon.texture = null
		icon.visible = false
		missing_icon.visible = true


func _apply_styles() -> void:
	icon_frame.add_theme_stylebox_override("panel", DesktopStyles.tile_style(0))
	DesktopStyles.apply_desktop_label(caption)


func _on_resized() -> void:
	pivot_offset = size * 0.5


func _on_mouse_entered() -> void:
	if _pressed:
		return
	_hovered = true
	_set_visual_state(1)


func _on_mouse_exited() -> void:
	_hovered = false
	# Если кнопку отпустили за пределами плитки, не оставляем её в нажатом виде.
	_pressed = false
	_set_visual_state(0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			_pressed = true
			_set_visual_state(2)
			accept_event()
		else:
			var was_pressed := _pressed
			_pressed = false
			_set_visual_state(1 if _hovered else 0)
			if was_pressed and _hovered and not app_id.is_empty():
				activated.emit(app_id)
			accept_event()
		return

	if event.is_action_pressed("ui_accept") and not app_id.is_empty():
		activated.emit(app_id)
		accept_event()


func _set_visual_state(state: int) -> void:
	icon_frame.add_theme_stylebox_override("panel", DesktopStyles.tile_style(state))
	icon.modulate = Color(1.04, 1.04, 1.04) if state == 1 else Color(1, 1, 1)
	var target_scale := Vector2(1.0, 1.0)
	if state == 1:
		target_scale = Vector2(1.015, 1.015)
	elif state == 2:
		target_scale = Vector2(0.985, 0.985)

	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", target_scale, 0.07)
