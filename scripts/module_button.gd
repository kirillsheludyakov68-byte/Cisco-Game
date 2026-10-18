extends Button

var module_name: String = ""
var module_texture: Texture2D = null

@export var press_offset: Vector2i = Vector2i(-2, 2)

var _default_left: float = 0.0
var _default_top: float = 0.0
var _default_right: float = 0.0
var _default_bottom: float = 0.0

func _ready() -> void:
	_save_defaults()
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)

func _save_defaults() -> void:
	var sb := get_theme_stylebox("normal")
	if sb is StyleBoxFlat:
		_default_left = sb.content_margin_left
		_default_top = sb.content_margin_top
		_default_right = sb.content_margin_right
		_default_bottom = sb.content_margin_bottom

func _on_button_down() -> void:
	_apply_offset(press_offset)

func _on_button_up() -> void:
	_apply_offset(Vector2i.ZERO)

func _apply_offset(offset: Vector2i) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb = get_theme_stylebox(state)
		if not sb is StyleBoxFlat:
			continue
		
		sb.content_margin_left = _default_left
		sb.content_margin_top = _default_top
		sb.content_margin_right = _default_right
		sb.content_margin_bottom = _default_bottom
		
		if offset.x < 0:
			sb.content_margin_right = _default_right + float(abs(offset.x))
		elif offset.x > 0:
			sb.content_margin_left = _default_left + float(offset.x)
		
		if offset.y > 0:
			sb.content_margin_top = _default_top + float(offset.y)
		elif offset.y < 0:
			sb.content_margin_bottom = _default_bottom + float(abs(offset.y))

# === Drag & Drop ===
func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := TextureRect.new()
	preview.texture = module_texture if module_texture else _create_placeholder()
	preview.custom_minimum_size = Vector2(128, 128)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.modulate = Color(1, 1, 1, 0.8)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_drag_preview(preview)
	
	return {
		"type": "module",
		"name": module_name,
		"texture": module_texture,
	}

func _create_placeholder() -> Texture2D:
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.8, 0.8, 0.9, 0.8))
	return ImageTexture.create_from_image(img)
