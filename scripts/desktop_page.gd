extends Control
class_name DesktopPage

const TILE_SCENE := preload("res://scenes/DesktopAppTile.tscn")
const FRAME_SCENE := preload("res://scenes/DesktopWindowFrame.tscn")
const MIN_TILE_WIDTH := 132.0
const GRID_GAP := 14.0
const MAX_COLUMNS := 4

@onready var background: ColorRect = $Background
@onready var desktop_scroll: ScrollContainer = $DesktopMargin/DesktopScroll
@onready var desktop_grid: GridContainer = $DesktopMargin/DesktopScroll/DesktopGrid
@onready var application_layer: Control = $ApplicationLayer
@onready var status_label: Label = $StatusLabel

var device: Device = null

var _tiles: Array[DesktopAppTile] = []
var _windows: Dictionary = {}
var _window_contents: Dictionary = {}
var _window_sequence := 0


func _ready() -> void:
	background.color = DesktopStyles.DESKTOP_BG
	DesktopStyles.apply_desktop_label(status_label, true)
	desktop_scroll.resized.connect(_on_scroll_resized)
	_build_tiles()
	_update_columns.call_deferred()


func setup(device_value: Device) -> void:
	if device == device_value:
		return
	_close_all_windows()
	device = device_value
	if device != null:
		_hide_status()


func on_activated() -> void:
	if device == null:
		return
	for app_id in _window_contents.keys():
		var content = _window_contents.get(app_id)
		if is_instance_valid(content) and content.has_method("activate"):
			content.activate()


func commit_pending_windows() -> void:
	for app_id in _window_contents.keys():
		var content = _window_contents.get(app_id)
		if is_instance_valid(content) and content.has_method("commit_pending"):
			content.commit_pending()


func _build_tiles() -> void:
	for child in desktop_grid.get_children():
		child.queue_free()
	_tiles.clear()

	for app in DesktopAppCatalog.get_apps():
		var tile := TILE_SCENE.instantiate() as DesktopAppTile
		if tile == null:
			push_error("DesktopAppTile scene is invalid.")
			continue
		desktop_grid.add_child(tile)
		tile.configure(app)
		tile.activated.connect(_on_tile_activated)
		_tiles.append(tile)


func _on_tile_activated(app_id: String) -> void:
	_open_app(app_id)


func _open_app(app_id: String) -> void:
	if device == null:
		_show_status("Сначала выберите устройство.", true)
		return

	var existing = _windows.get(app_id)
	if existing != null and is_instance_valid(existing):
		_focus_window(existing)
		var existing_content = _window_contents.get(app_id)
		if is_instance_valid(existing_content) and existing_content.has_method("activate"):
			existing_content.activate()
		return

	var app := DesktopAppCatalog.get_app(app_id)
	if app.is_empty():
		_show_status("Приложение не зарегистрировано: " + app_id, true)
		return

	var app_scene := DesktopAppCatalog.get_scene(app_id)
	if app_scene == null:
		_show_status("Не найдена сцена приложения: " + str(app.get("scene_path", "")), true)
		return

	var content := app_scene.instantiate() as Control
	if content == null:
		push_error("Desktop app scene must have a Control root: " + str(app.get("scene_path", "")))
		return

	var frame := FRAME_SCENE.instantiate() as DesktopWindowFrame
	if frame == null:
		push_error("DesktopWindowFrame scene is invalid.")
		content.queue_free()
		return

	application_layer.add_child(frame)
	frame.setup(str(app.get("title", app_id)))
	frame.set_content(content)
	frame.close_requested.connect(_close_app.bind(app_id))
	frame.focus_requested.connect(_on_frame_focus_requested.bind(app_id))
	frame.tree_exited.connect(_on_window_tree_exited.bind(app_id, frame))

	if content.has_method("setup"):
		content.setup(device)
	_windows[app_id] = frame
	_window_contents[app_id] = content
	_window_sequence += 1
	_place_new_window(frame)
	_focus_window(frame)
	_hide_status()


func _on_frame_focus_requested(window: Control, _app_id: String) -> void:
	_focus_window(window)


func _focus_window(window: Control) -> void:
	if not is_instance_valid(window):
		return
	if application_layer.get_children().has(window):
		application_layer.move_child(window, application_layer.get_child_count() - 1)
	window.z_index = 1


func _close_app(app_id: String) -> void:
	var frame = _windows.get(app_id)
	var content = _window_contents.get(app_id)
	if is_instance_valid(content) and content.has_method("commit_pending"):
		content.commit_pending()
	_windows.erase(app_id)
	_window_contents.erase(app_id)
	if is_instance_valid(frame):
		frame.queue_free()


func _on_window_tree_exited(app_id: String, frame: Control) -> void:
	# Старое окно может завершить удаление уже после открытия нового окна
	# с тем же id. Удаляем запись только если она всё ещё указывает на него.
	if _windows.get(app_id) != frame:
		return
	_windows.erase(app_id)
	_window_contents.erase(app_id)


func _close_all_windows() -> void:
	for app_id in _windows.keys():
		var content = _window_contents.get(app_id)
		if is_instance_valid(content) and content.has_method("commit_pending"):
			content.commit_pending()
		var frame = _windows[app_id]
		if is_instance_valid(frame):
			frame.queue_free()
	_windows.clear()
	_window_contents.clear()
	_window_sequence = 0


func _place_new_window(frame: DesktopWindowFrame) -> void:
	if not is_instance_valid(frame):
		return
	var area := application_layer.size
	var max_x := maxf(0.0, area.x - frame.size.x)
	var max_y := maxf(0.0, area.y - frame.size.y)
	var offset := float((_window_sequence - 1) % 5) * 20.0
	frame.position = Vector2(
		clampf(42.0 + offset, 0.0, max_x),
		clampf(34.0 + offset, 0.0, max_y)
	)


func _on_scroll_resized() -> void:
	_update_columns.call_deferred()


func _update_columns() -> void:
	var width := desktop_scroll.size.x
	if width <= 1.0:
		return
	var columns := int(floor((width + GRID_GAP) / (MIN_TILE_WIDTH + GRID_GAP)))
	columns = clampi(columns, 1, MAX_COLUMNS)
	if desktop_grid.columns != columns:
		desktop_grid.columns = columns


func _show_status(message: String, is_error: bool = false) -> void:
	status_label.text = message
	status_label.visible = true
	status_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.78, 0.72) if is_error else DesktopStyles.STATUS_TEXT
	)


func _hide_status() -> void:
	status_label.visible = false


func has_open_app(app_id: String) -> bool:
	return _windows.has(app_id) and is_instance_valid(_windows[app_id])


func get_open_app_count() -> int:
	return _windows.size()
