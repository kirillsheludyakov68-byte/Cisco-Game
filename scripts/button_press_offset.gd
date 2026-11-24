extends Button
class_name ButtonPressOffset

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
		
		# Сброс к дефолтным
		sb.content_margin_left = _default_left
		sb.content_margin_top = _default_top
		sb.content_margin_right = _default_right
		sb.content_margin_bottom = _default_bottom
		
		# Сдвиг по X (влево = увеличить правый margin)
		if offset.x < 0:
			sb.content_margin_right = _default_right + float(abs(offset.x))
		elif offset.x > 0:
			sb.content_margin_left = _default_left + float(offset.x)
		
		# Сдвиг по Y (вниз = увеличить верхний margin)
		if offset.y > 0:
			sb.content_margin_top = _default_top + float(offset.y)
		elif offset.y < 0:
			sb.content_margin_bottom = _default_bottom + float(abs(offset.y))
