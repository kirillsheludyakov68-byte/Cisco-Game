extends Window
class_name DeviceWindow

const ERROR_POWER_ADD := "Невозможно добавить модуль, пока компьютер включён."
const ERROR_POWER_REMOVE := "Невозможно извлечь модуль, пока компьютер включён."
const ERROR_OCCUPIED := "В слоте уже установлен модуль. Сначала извлеките его."
const ERROR_EMPTY := "В слоте нет модуля."
const ERROR_UNKNOWN := "Неизвестный модуль."
const ERROR_DEFAULT := "Не удалось изменить модуль."
const ERROR_POWERED_OFF := "Устройство должно быть включено."

const ZOOM_STEP := 1.2
const ZOOM_MIN := 0.25
const ZOOM_MAX := 3.0
const ZOOM_SCROLL_STEP := 48.0
const ZOOM_SCROLL_BAR_WIDTH := 14.0

@onready var tab_physical: Button = $WindowRoot/TabBar/TabPhysical
@onready var tab_config: Button = $WindowRoot/TabBar/TabConfig
@onready var tab_desktop: Button = $WindowRoot/TabBar/TabDesktop

@onready var page_physical: Control = $MainPanel/ContentPanel/PagePhysical
@onready var page_config: Control = $MainPanel/ContentPanel/PageConfig
@onready var page_desktop: Control = $MainPanel/ContentPanel/PageDesktop

@onready var modules_panel: ModulesPanel = $MainPanel/ContentPanel/PagePhysical/PhysicalLayout/ModulesPanel
@onready var module_slot: ModuleSlot = $MainPanel/ContentPanel/PagePhysical/ViewerPanel/DeviceView/DeviceImage/ModuleSlot
@onready var module_info: ModuleInfoPanel = get_node_or_null("MainPanel/ContentPanel/PagePhysical/ModuleInfoPanel") as ModuleInfoPanel
@onready var config_panel: ConfigPanel = $MainPanel/ContentPanel/PageConfig/ConfigPanel
@onready var error_dialog: ErrorDialog = $ErrorDialog

@onready var device_view: Control = $MainPanel/ContentPanel/PagePhysical/ViewerPanel/DeviceView
@onready var zoom_in_button: Button = $MainPanel/ContentPanel/PagePhysical/ZoomButtons/ZoomIn
@onready var original_size_button: Button = $MainPanel/ContentPanel/PagePhysical/ZoomButtons/OriginalSize
@onready var zoom_out_button: Button = $MainPanel/ContentPanel/PagePhysical/ZoomButtons/ZoomOut

# Ищем картинку по всему дереву
@onready var device_image: TextureRect = find_child("DeviceImage", true, false)

var device: Device = null
var _zoom_scale := 1.0
var _zoom_pan := Vector2.ZERO
var _device_base_rect := Rect2()
var _zoom_scroll_bar: VScrollBar = null
var _updating_zoom_scroll := false


func _ready() -> void:
	close_requested.connect(_on_close_requested)
	tab_physical.pressed.connect(_on_tab_physical)
	tab_config.pressed.connect(_on_tab_config)
	tab_desktop.pressed.connect(_on_tab_desktop)

	zoom_in_button.pressed.connect(_on_zoom_in_pressed)
	original_size_button.pressed.connect(_on_original_size_pressed)
	zoom_out_button.pressed.connect(_on_zoom_out_pressed)

	# Клиппинг не даёт увеличенному изображению выйти за пределы Physical Device View.
	device_view.clip_contents = true
	# PASS нужен, чтобы колесо мыши работало и над пустой частью области просмотра.
	device_view.mouse_filter = Control.MOUSE_FILTER_PASS
	if not device_view.gui_input.is_connected(_on_device_view_gui_input):
		device_view.gui_input.connect(_on_device_view_gui_input)
	call_deferred("_setup_zoom")

	# Подключаем клик по картинке
	if device_image and not device_image.gui_input.is_connected(_on_device_image_gui_input):
		device_image.gui_input.connect(_on_device_image_gui_input)

	# И колесо мыши над слотом модуля — чтобы прокрутка не прерывалась.
	if module_slot and not module_slot.gui_input.is_connected(_on_module_slot_gui_input):
		module_slot.gui_input.connect(_on_module_slot_gui_input)

	if modules_panel.has_signal("module_selected"):
		modules_panel.module_selected.connect(_show_module_info)

	_show_page("physical")


func open_for(dev: Device) -> void:
	if device != null and device.device_name_changed.is_connected(_on_device_name_changed):
		device.device_name_changed.disconnect(_on_device_name_changed)

	device = dev
	title = "Устройство: " + dev.device_name
	if not device.device_name_changed.is_connected(_on_device_name_changed):
		device.device_name_changed.connect(_on_device_name_changed)

	_show_page("physical")
	_update_device_image()
	_reset_zoom()

	# Слот модулей есть только у ПК
	module_slot.visible = dev.device_type == "PC"
	module_slot.setup(dev, self)
	modules_panel.setup(dev, self)
	_update_module_info()
	config_panel.setup(dev)


func _on_device_name_changed(new_name: String) -> void:
	title = "Устройство: " + new_name


# Показываем описание установленного модуля,
# а если слот пуст — первого модуля из каталога.
func _update_module_info() -> void:
	if device != null and device.installed_module != "":
		_show_module_info(device.installed_module)
	else:
		_show_module_info(ModuleCatalog.MODULES[0])


func _show_module_info(module_name: String) -> void:
	if module_info == null or module_name == "":
		return
	module_info.show_module(module_name)


func _on_tab_physical() -> void:
	_show_page("physical")


func _on_tab_config() -> void:
	_show_page("config")


func _on_tab_desktop() -> void:
	_show_page("desktop")


func _show_page(page: String) -> void:
	if page == "config" and device != null and not device.is_powered_on:
		if error_dialog:
			error_dialog.show_error(ERROR_POWERED_OFF)
		return

	if page_config.visible and page != "config":
		config_panel.commit_pending()

	page_physical.visible = (page == "physical")
	page_config.visible = (page == "config")
	page_desktop.visible = (page == "desktop")


func _on_close_requested() -> void:
	if page_config.visible:
		config_panel.commit_pending()
	queue_free()


func _update_device_image() -> void:
	if device == null or device_image == null:
		return

	if device.device_type == "PC":
		if device.is_powered_on:
			device_image.texture = load("res://assets/devices/PC_on.png")
		else:
			device_image.texture = load("res://assets/devices/PC_off.png")
	elif device.device_type == "Switch":
		device_image.texture = load("res://assets/devices/Switch.png")
	elif device.device_type == "Router":
		device_image.texture = load("res://assets/devices/Router.png")


# --- Масштаб Physical Device View ---

func _setup_zoom() -> void:
	if device_image == null:
		return
	_device_base_rect = Rect2(device_image.position, device_image.size)
	_create_zoom_scroll_bar()
	_apply_zoom()


func _reset_zoom() -> void:
	_zoom_scale = 1.0
	_zoom_pan = Vector2.ZERO
	_apply_zoom()


func _on_zoom_in_pressed() -> void:
	_set_zoom(_zoom_scale * ZOOM_STEP)


func _on_zoom_out_pressed() -> void:
	_set_zoom(_zoom_scale / ZOOM_STEP)


func _on_original_size_pressed() -> void:
	_reset_zoom()


func _set_zoom(value: float) -> void:
	_zoom_scale = clampf(value, ZOOM_MIN, ZOOM_MAX)
	_apply_zoom()


func _apply_zoom() -> void:
	if device_image == null or _device_base_rect.size == Vector2.ZERO:
		return

	device_image.size = _device_base_rect.size * _zoom_scale
	_clamp_zoom_pan()
	_update_device_image_position()
	_update_zoom_scroll_bar()


# Картинка всегда масштабируется от левого верхнего угла.
# _zoom_pan позволяет вручную прокрутить её вниз, когда она выше области.
func _update_device_image_position() -> void:
	if device_image == null:
		return
	device_image.position = _device_base_rect.position + _zoom_pan


func _get_max_zoom_scroll() -> Vector2:
	if _device_base_rect.size == Vector2.ZERO:
		return Vector2.ZERO

	var content_size := _device_base_rect.size * _zoom_scale
	return Vector2(
		maxf(content_size.x - device_view.size.x, 0.0),
		maxf(content_size.y - device_view.size.y, 0.0)
	)


func _clamp_zoom_pan() -> void:
	var max_scroll := _get_max_zoom_scroll()
	_zoom_pan.x = clampf(_zoom_pan.x, -max_scroll.x, 0.0)
	_zoom_pan.y = clampf(_zoom_pan.y, -max_scroll.y, 0.0)


func _create_zoom_scroll_bar() -> void:
	if _zoom_scroll_bar != null:
		return

	_zoom_scroll_bar = VScrollBar.new()
	_zoom_scroll_bar.name = "ZoomScrollBar"
	_zoom_scroll_bar.visible = false
	_zoom_scroll_bar.step = 1.0
	_zoom_scroll_bar.focus_mode = Control.FOCUS_NONE
	_zoom_scroll_bar.z_index = 20
	device_view.add_child(_zoom_scroll_bar)

	_zoom_scroll_bar.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_zoom_scroll_bar.offset_left = -ZOOM_SCROLL_BAR_WIDTH
	_zoom_scroll_bar.offset_right = 0.0
	_zoom_scroll_bar.offset_top = 2.0
	_zoom_scroll_bar.offset_bottom = -2.0
	_zoom_scroll_bar.value_changed.connect(_on_zoom_scroll_bar_changed)


func _update_zoom_scroll_bar() -> void:
	if _zoom_scroll_bar == null or _device_base_rect.size == Vector2.ZERO:
		return

	var content_size := _device_base_rect.size * _zoom_scale
	var view_size := device_view.size
	var max_scroll_y := maxf(content_size.y - view_size.y, 0.0)

	_updating_zoom_scroll = true
	_zoom_scroll_bar.min_value = 0.0
	_zoom_scroll_bar.max_value = maxf(content_size.y, view_size.y)
	_zoom_scroll_bar.page = view_size.y
	_zoom_scroll_bar.value = clampf(-_zoom_pan.y, 0.0, max_scroll_y)
	_zoom_scroll_bar.visible = max_scroll_y > 0.5
	_updating_zoom_scroll = false


func _on_zoom_scroll_bar_changed(value: float) -> void:
	if _updating_zoom_scroll:
		return

	_zoom_pan.y = -value
	_clamp_zoom_pan()
	_update_device_image_position()


func _scroll_zoom(amount: float) -> void:
	var max_scroll := _get_max_zoom_scroll()
	if max_scroll.y <= 0.5:
		return

	# amount > 0 — прокрутка вниз, к нижней части корпуса.
	_zoom_pan.y = clampf(_zoom_pan.y - amount, -max_scroll.y, 0.0)
	_update_device_image_position()
	_update_zoom_scroll_bar()


func _handle_zoom_wheel(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton):
		return false

	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return false

	if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_scroll_zoom(-ZOOM_SCROLL_STEP)
		return true
	if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_scroll_zoom(ZOOM_SCROLL_STEP)
		return true
	return false


func _on_device_view_gui_input(event: InputEvent) -> void:
	if _handle_zoom_wheel(event):
		device_view.accept_event()


func _on_module_slot_gui_input(event: InputEvent) -> void:
	if _handle_zoom_wheel(event):
		module_slot.accept_event()


func _on_device_image_gui_input(event: InputEvent) -> void:
	if _handle_zoom_wheel(event):
		device_image.accept_event()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Огромная зона для теста, чтобы точно попасть
		# (X, Y, Ширина, Высота) - потом подгонишь под кнопку
		var button_rect = Rect2(132, 118, 14, 21)

		# Координаты события локальные для уже масштабированной картинки.
		var base_position: Vector2 = event.position / _zoom_scale
		if button_rect.has_point(base_position):
			if device == null:
				return

			device.set_power(not device.is_powered_on)
			_update_device_image()
			module_slot.refresh()


# --- Модули: вызываются из ModuleSlot и ModulesPanel ---

func try_install_module(module_name: String) -> void:
	if device == null:
		return

	var result: Dictionary = device.install_module(module_name)
	if result.get("ok", false):
		module_slot.refresh()
		_show_module_info(module_name)
	else:
		_show_module_error(result.get("reason", ""))


func try_remove_module() -> void:
	if device == null:
		return

	var result: Dictionary = device.remove_module()
	if result.get("ok", false):
		module_slot.refresh()
		_update_module_info()
	else:
		_show_module_error(result.get("reason", ""))


func _show_module_error(reason: String) -> void:
	var text := ERROR_DEFAULT
	match reason:
		"power_on_add":
			text = ERROR_POWER_ADD
		"power_on_remove":
			text = ERROR_POWER_REMOVE
		"occupied":
			text = ERROR_OCCUPIED
		"empty":
			text = ERROR_EMPTY
		"unknown":
			text = ERROR_UNKNOWN

	if error_dialog:
		error_dialog.show_error(text)
