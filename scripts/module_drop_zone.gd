extends Control
class_name ModuleDropZone

signal module_dropped(module_name: String)
signal highlight_changed(active: bool)

# Панель свёрнута — принимать дроп нельзя
var enabled: bool = true

var _highlighted: bool = false


func _ready() -> void:
	# Зона всегда существует в раскладке, но не мешает мыши,
	# пока над ней не проносят модуль из слота ПК.
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# Подсветка и приём дропа включаются только когда курсор
# с модулем из слота реально находится над панелью.
func _process(_delta: float) -> void:
	if not enabled:
		_set_active(false, false)
		return

	var slot_drag := false
	if get_viewport().gui_is_dragging():
		var data: Variant = get_viewport().gui_get_drag_data()
		slot_drag = data is Dictionary \
			and data.get("type", "") == "module" \
			and data.get("source", "") == "slot"

	# Дроп принимаем на время всего перетаскивания из слота,
	# а жёлтая подсветка — только когда курсор реально над панелью.
	var local_mouse := get_local_mouse_position()
	var over_panel: bool = Rect2(Vector2.ZERO, size).has_point(local_mouse)
	_set_active(slot_drag, slot_drag and over_panel)


func _set_active(accept: bool, highlight: bool) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if accept else Control.MOUSE_FILTER_IGNORE
	_set_highlight(highlight)


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not enabled:
		return false
	if not Rect2(Vector2.ZERO, size).has_point(at_position):
		return false
	return data is Dictionary \
		and data.get("type", "") == "module" \
		and data.get("source", "") == "slot"


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_set_highlight(false)
	if data is Dictionary:
		module_dropped.emit(data.get("module", ""))


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_set_active(false, false)


func _set_highlight(value: bool) -> void:
	if value == _highlighted:
		return
	_highlighted = value
	highlight_changed.emit(value)
