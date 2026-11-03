extends Window
class_name DeviceWindow

const ERROR_POWER_ADD := "Невозможно добавить модуль, пока компьютер включён."
const ERROR_POWER_REMOVE := "Невозможно извлечь модуль, пока компьютер включён."
const ERROR_POWER_ADD_SWITCH := "Невозможно добавить модуль, пока коммутатор включён."
const ERROR_POWER_REMOVE_SWITCH := "Невозможно извлечь модуль, пока коммутатор включён."
const ERROR_OCCUPIED := "В слоте уже установлен модуль. Сначала извлеките его."
const ERROR_EMPTY := "В слоте нет модуля."
const ERROR_UNKNOWN := "Неизвестный модуль."
const ERROR_DEFAULT := "Не удалось изменить модуль."
const ERROR_INVALID_SLOT := "Некорректный слот модуля."
const ERROR_POWERED_OFF := "Устройство должно быть включено."
const ERROR_BOOTING := "Коммутатор загружается. Пожалуйста, подождите."

const ZOOM_STEP := 1.2
const ZOOM_MIN := 0.25
const ZOOM_MAX := 3.0
const ZOOM_SCROLL_STEP := 48.0
const ZOOM_SCROLL_BAR_WIDTH := 14.0

@onready var tab_physical: Button = $WindowRoot/TabBar/TabPhysical
@onready var tab_config: Button = $WindowRoot/TabBar/TabConfig
@onready var tab_cli: Button = $WindowRoot/TabBar/TabCLI
@onready var tab_desktop: Button = $WindowRoot/TabBar/TabDesktop

@onready var page_physical: Control = $MainPanel/ContentPanel/PagePhysical
@onready var page_config: Control = $MainPanel/ContentPanel/PageConfig
@onready var page_cli: Control = $MainPanel/ContentPanel/PageCLI
@onready var page_desktop: Control = $MainPanel/ContentPanel/PageDesktop

@onready var modules_panel: ModulesPanel = $MainPanel/ContentPanel/PagePhysical/PhysicalLayout/ModulesPanel
@onready var module_slot: ModuleSlot = $MainPanel/ContentPanel/PagePhysical/ViewerPanel/DeviceView/DeviceImage/ModuleSlot
@onready var switch_overlay: SwitchPhysicalOverlay = $MainPanel/ContentPanel/PagePhysical/ViewerPanel/DeviceView/DeviceImage/SwitchPhysicalOverlay
@onready var module_info: ModuleInfoPanel = get_node_or_null("MainPanel/ContentPanel/PagePhysical/ModuleInfoPanel") as ModuleInfoPanel
@onready var config_panel: ConfigPanel = $MainPanel/ContentPanel/PageConfig/ConfigPanel
@onready var cli_page: SwitchCLIPage = $MainPanel/ContentPanel/PageCLI/SwitchCLIPage
@onready var desktop_page: DesktopPage = $MainPanel/ContentPanel/PageDesktop/DesktopPage
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
var _pc_base_rect := Rect2()
var _zoom_scroll_bar: VScrollBar = null
var _zoom_h_scroll_bar: HScrollBar = null
var _updating_zoom_scroll := false
var _boot_warning_active := false
var _config_focus_modes: Dictionary = {}


func _ready() -> void:
	# Запоминаем исходный размер ПК-картинки до открытия коммутатора.
	_pc_base_rect = Rect2(device_image.position, device_image.size)
	_device_base_rect = _pc_base_rect

	close_requested.connect(_on_close_requested)
	if error_dialog:
		error_dialog.closed.connect(_on_error_dialog_closed)
	tab_physical.pressed.connect(_on_tab_physical)
	tab_config.pressed.connect(_on_tab_config)
	tab_cli.pressed.connect(_on_tab_cli)
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
	if not device_view.resized.is_connected(_on_device_view_resized):
		device_view.resized.connect(_on_device_view_resized)
	call_deferred("_setup_zoom")

	# Подключаем клик по картинке
	if device_image and not device_image.gui_input.is_connected(_on_device_image_gui_input):
		device_image.gui_input.connect(_on_device_image_gui_input)

	# И колесо мыши над слотом модуля — чтобы прокрутка не прерывалась.
	if module_slot and not module_slot.gui_input.is_connected(_on_module_slot_gui_input):
		module_slot.gui_input.connect(_on_module_slot_gui_input)

	if modules_panel.has_signal("module_selected"):
		modules_panel.module_selected.connect(_show_module_info)

	tab_cli.visible = false
	tab_desktop.visible = true
	page_cli.visible = false
	_show_page("physical")


func open_for(dev: Device) -> void:
	_disconnect_device()
	_dismiss_boot_warning()

	device = dev
	title = "Устройство: " + dev.device_name
	if not device.device_name_changed.is_connected(_on_device_name_changed):
		device.device_name_changed.connect(_on_device_name_changed)
	if not device.power_changed.is_connected(_on_device_power_changed):
		device.power_changed.connect(_on_device_power_changed)
	if not device.boot_finished.is_connected(_on_device_boot_finished):
		device.boot_finished.connect(_on_device_boot_finished)

	var is_switch := dev.device_type == "Switch"
	tab_desktop.visible = not is_switch
	tab_cli.visible = is_switch
	page_desktop.visible = false
	page_cli.visible = false

	# Слот модулей есть только у ПК, у коммутатора — десять отдельных слотов.
	module_slot.visible = not is_switch
	switch_overlay.visible = is_switch
	module_slot.setup(dev, self)
	if is_switch:
		switch_overlay.setup(dev, self)
	modules_panel.setup(dev, self)
	_update_device_image()
	_update_device_base_rect()
	_reset_zoom()
	_update_module_info()
	config_panel.setup(dev)
	if is_switch:
		cli_page.setup(dev)
	else:
		desktop_page.setup(dev)
	_show_page("physical")


func _disconnect_device() -> void:
	if device == null:
		return
	if device.device_name_changed.is_connected(_on_device_name_changed):
		device.device_name_changed.disconnect(_on_device_name_changed)
	if device.power_changed.is_connected(_on_device_power_changed):
		device.power_changed.disconnect(_on_device_power_changed)
	if device.boot_finished.is_connected(_on_device_boot_finished):
		device.boot_finished.disconnect(_on_device_boot_finished)


func _on_device_name_changed(new_name: String) -> void:
	title = "Устройство: " + new_name


func _on_device_view_resized() -> void:
	if device == null or device.device_type != "Switch":
		return
	# После первого расчёта раскладки область просмотра может измениться.
	# Пересчитываем размер картинки, чтобы она точно вписалась в окно.
	_update_device_base_rect()
	_clamp_zoom_pan()
	_apply_zoom()


func _on_device_power_changed(is_on: bool) -> void:
	if not is_on:
		_dismiss_boot_warning()
		if page_config.visible or page_cli.visible:
			_show_page("physical")
	_update_device_image()
	_update_device_base_rect()
	_apply_zoom()
	module_slot.refresh()
	if switch_overlay.visible:
		switch_overlay.refresh()
	cli_page.refresh()
	if is_on and page_config.visible:
		config_panel.refresh()


func _show_boot_warning() -> void:
	_boot_warning_active = true
	_lock_config_keyboard(true)
	if error_dialog:
		error_dialog.show_warning(ERROR_BOOTING)


func _dismiss_boot_warning() -> void:
	if not _boot_warning_active:
		return
	_boot_warning_active = false
	_lock_config_keyboard(false)
	if error_dialog:
		error_dialog.dismiss()


func _on_error_dialog_closed() -> void:
	if not _boot_warning_active:
		return
	_dismiss_boot_warning()
	_show_page("physical")


# Пока висит предупреждение о загрузке, убираем фокус со всех
# элементов Config. Мышь и так блокируется затемнением диалога,
# а это не даёт перейти к настройкам клавишей Tab.
func _lock_config_keyboard(locked: bool) -> void:
	if locked:
		if not _config_focus_modes.is_empty():
			return
		_apply_focus_lock(config_panel, true)
	else:
		if _config_focus_modes.is_empty():
			return
		_apply_focus_lock(config_panel, false)
		_config_focus_modes.clear()


func _apply_focus_lock(node: Node, locked: bool) -> void:
	for child in node.get_children():
		if child is Control:
			if locked:
				_config_focus_modes[child] = child.focus_mode
				child.focus_mode = Control.FOCUS_NONE
			elif _config_focus_modes.has(child):
				child.focus_mode = _config_focus_modes[child]
		_apply_focus_lock(child, locked)


func _on_device_boot_finished() -> void:
	_dismiss_boot_warning()


# Показываем описание установленного модуля,
# а если слот пуст — первого модуля из каталога.
func _update_module_info() -> void:
	if device == null:
		return
	if device.device_type == "Switch":
		var module_name := _get_first_installed_switch_module()
		if module_name.is_empty() and not ModuleCatalog.SWITCH_MODULES.is_empty():
			module_name = ModuleCatalog.SWITCH_MODULES[0]
		_show_module_info(module_name)
		return

	if device.installed_module != "":
		_show_module_info(device.installed_module)
	elif not ModuleCatalog.MODULES.is_empty():
		_show_module_info(ModuleCatalog.MODULES[0])


func _get_first_installed_switch_module() -> String:
	if device == null:
		return ""
	for slot_index in range(ModuleCatalog.SWITCH_SLOT_COUNT):
		var module_name := device.get_installed_module(slot_index)
		if not module_name.is_empty():
			return module_name
	return ""


func _show_module_info(module_name: String) -> void:
	if module_info == null or module_name == "":
		return
	module_info.show_module(module_name)


func show_slot_module_info(slot_index: int) -> void:
	if device == null or device.device_type != "Switch":
		return
	_show_module_info(device.get_installed_module(slot_index))


func _on_tab_physical() -> void:
	_show_page("physical")


func _on_tab_config() -> void:
	_show_page("config")


func _on_tab_cli() -> void:
	_show_page("cli")


func _on_tab_desktop() -> void:
	_show_page("desktop")


func _show_page(page: String) -> void:
	if device != null:
		if device.device_type == "Switch" and page == "desktop":
			page = "physical"
		elif device.device_type != "Switch" and page == "cli":
			page = "physical"

	if page != "physical" and device != null and not device.is_powered_on:
		if error_dialog:
			error_dialog.show_error(ERROR_POWERED_OFF)
		return

	var was_config_visible := page_config.visible
	var was_cli_visible := page_cli.visible
	var was_desktop_visible := page_desktop.visible
	if was_config_visible and page != "config":
		config_panel.commit_pending()
	if was_desktop_visible and page != "desktop" and desktop_page != null:
		desktop_page.commit_pending_windows()

	page_physical.visible = (page == "physical")
	page_config.visible = (page == "config")
	page_cli.visible = (page == "cli")
	page_desktop.visible = (page == "desktop")

	if page == "config" and not was_config_visible and config_panel != null:
		# IP Configuration на Desktop пишет в ту же модель DeviceInterface,
		# поэтому при входе в Config перечитываем актуальные значения.
		config_panel.refresh()
	if page == "cli" and not was_cli_visible and cli_page != null:
		cli_page.on_activated()
	if page == "desktop" and not was_desktop_visible and desktop_page != null:
		desktop_page.on_activated()

	# Во время загрузки коммутатора вкладку Config/CLI открыть можно,
	# чтобы увидеть процесс загрузки, но модальное предупреждение
	# блокирует изменение настроек. По ОК возвращаемся на Physical.
	if page != "physical" and device != null \
			and device.device_type == "Switch" and device.is_booting:
		_show_boot_warning()


func _on_close_requested() -> void:
	if page_config.visible:
		config_panel.commit_pending()
	if desktop_page != null:
		desktop_page.commit_pending_windows()
	queue_free()


func _update_device_image() -> void:
	if device == null or device_image == null:
		return

	switch_overlay.visible = device.device_type == "Switch"
	if device.device_type == "PC":
		if device.is_powered_on:
			device_image.texture = load("res://assets/devices/PC_on.png")
		else:
			device_image.texture = load("res://assets/devices/PC_off.png")
	elif device.device_type == "Switch":
		# Базовая текстура коммутатора; поверх неё показывается
		# кнопка питания в состоянии PowerOn.png или PowerOff.png.
		device_image.texture = load("res://assets/Switch/iPTRealSwitch.png")
		switch_overlay.setup(device, self)
		switch_overlay.refresh()
	elif device.device_type == "Router":
		device_image.texture = load("res://assets/devices/Router.png")


func _update_device_base_rect() -> void:
	if device_image == null or device_image.texture == null:
		return

	if device != null and device.device_type == "Switch":
		var texture_size := device_image.texture.get_size()
		var view_size := device_view.size
		if view_size.x <= 1.0 or view_size.y <= 1.0:
			view_size = Vector2(606, 396)
		var margin := 10.0
		var fit_scale := minf(
			(view_size.x - margin * 2.0) / maxf(texture_size.x, 1.0),
			(view_size.y - margin * 2.0) / maxf(texture_size.y, 1.0)
		)
		var fitted_size := texture_size * maxf(fit_scale, 0.01)
		# Коммутатор прижат к левому верхнему углу области просмотра,
		# чтобы кнопка питания и слоты всегда были на одном месте.
		_device_base_rect = Rect2(Vector2(margin, margin), fitted_size)
	else:
		if _pc_base_rect.size == Vector2.ZERO:
			_pc_base_rect = Rect2(Vector2.ZERO, Vector2(166, 396))
		_device_base_rect = _pc_base_rect


# --- Масштаб Physical Device View ---

func _setup_zoom() -> void:
	if device_image == null:
		return
	if _pc_base_rect.size == Vector2.ZERO:
		_pc_base_rect = Rect2(device_image.position, device_image.size)
	if _device_base_rect.size == Vector2.ZERO:
		_update_device_base_rect()
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

	# Коммутатор — широкая картинка, поэтому при увеличении нужна
	# ещё и горизонтальная прокрутка, иначе кнопка питания уходит за край.
	_zoom_h_scroll_bar = HScrollBar.new()
	_zoom_h_scroll_bar.name = "ZoomHScrollBar"
	_zoom_h_scroll_bar.visible = false
	_zoom_h_scroll_bar.step = 1.0
	_zoom_h_scroll_bar.focus_mode = Control.FOCUS_NONE
	_zoom_h_scroll_bar.z_index = 20
	device_view.add_child(_zoom_h_scroll_bar)

	_zoom_h_scroll_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_zoom_h_scroll_bar.offset_left = 2.0
	_zoom_h_scroll_bar.offset_right = -2.0
	_zoom_h_scroll_bar.offset_top = -ZOOM_SCROLL_BAR_WIDTH
	_zoom_h_scroll_bar.offset_bottom = 0.0
	_zoom_h_scroll_bar.value_changed.connect(_on_zoom_h_scroll_bar_changed)


func _update_zoom_scroll_bar() -> void:
	if _zoom_scroll_bar == null or _zoom_h_scroll_bar == null:
		return
	if _device_base_rect.size == Vector2.ZERO:
		return

	var content_size := _device_base_rect.size * _zoom_scale
	var view_size := device_view.size
	var max_scroll_x := maxf(content_size.x - view_size.x, 0.0)
	var max_scroll_y := maxf(content_size.y - view_size.y, 0.0)

	_updating_zoom_scroll = true
	_zoom_scroll_bar.min_value = 0.0
	_zoom_scroll_bar.max_value = maxf(content_size.y, view_size.y)
	_zoom_scroll_bar.page = view_size.y
	_zoom_scroll_bar.value = clampf(-_zoom_pan.y, 0.0, max_scroll_y)
	_zoom_scroll_bar.visible = max_scroll_y > 0.5

	_zoom_h_scroll_bar.min_value = 0.0
	_zoom_h_scroll_bar.max_value = maxf(content_size.x, view_size.x)
	_zoom_h_scroll_bar.page = view_size.x
	_zoom_h_scroll_bar.value = clampf(-_zoom_pan.x, 0.0, max_scroll_x)
	_zoom_h_scroll_bar.visible = max_scroll_x > 0.5
	_updating_zoom_scroll = false

	# Не даём вертикальной полосе перекрывать угол горизонтальной.
	_zoom_scroll_bar.offset_bottom = (
		-ZOOM_SCROLL_BAR_WIDTH if _zoom_h_scroll_bar.visible else -2.0
	)


func _on_zoom_scroll_bar_changed(value: float) -> void:
	if _updating_zoom_scroll:
		return

	_zoom_pan.y = -value
	_clamp_zoom_pan()
	_update_device_image_position()


func _on_zoom_h_scroll_bar_changed(value: float) -> void:
	if _updating_zoom_scroll:
		return

	_zoom_pan.x = -value
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


# Публичный вход для слотов коммутатора: они тоже должны пропускать
# колесо мыши к механизму прокрутки Physical Device View.
func handle_zoom_wheel(event: InputEvent) -> bool:
	return _handle_zoom_wheel(event)


func _on_module_slot_gui_input(event: InputEvent) -> void:
	if _handle_zoom_wheel(event):
		module_slot.accept_event()


func _on_device_image_gui_input(event: InputEvent) -> void:
	if _handle_zoom_wheel(event):
		device_image.accept_event()
		return

	# У коммутатора кнопку питания обрабатывает SwitchPhysicalOverlay,
	# чтобы её зона точно совпадала с PowerOn.png.
	if device == null or device.device_type != "PC":
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Огромная зона для теста, чтобы точно попасть
		# (X, Y, Ширина, Высота) - потом подгонишь под кнопку
		var button_rect = Rect2(132, 118, 14, 21)

		# Координаты события локальные для уже масштабированной картинки.
		var base_position: Vector2 = event.position / _zoom_scale
		if button_rect.has_point(base_position):
			device.set_power(not device.is_powered_on)


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


func try_install_module_to_slot(module_name: String, slot_index: int) -> void:
	if device == null:
		return
	if device.device_type != "Switch":
		try_install_module(module_name)
		return

	var result: Dictionary = device.install_module_in_slot(module_name, slot_index)
	if result.get("ok", false):
		switch_overlay.refresh()
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


func try_remove_module_from_slot(slot_index: int) -> void:
	if device == null:
		return
	if device.device_type != "Switch" or slot_index < 0:
		try_remove_module()
		return

	var result: Dictionary = device.remove_module_from_slot(slot_index)
	if result.get("ok", false):
		switch_overlay.refresh()
		module_slot.refresh()
		_update_module_info()
	else:
		_show_module_error(result.get("reason", ""))


func toggle_power() -> void:
	if device == null:
		return
	device.set_power(not device.is_powered_on)


func _show_module_error(reason: String) -> void:
	var text := ERROR_DEFAULT
	match reason:
		"power_on_add":
			text = ERROR_POWER_ADD_SWITCH if _is_switch() else ERROR_POWER_ADD
		"power_on_remove":
			text = ERROR_POWER_REMOVE_SWITCH if _is_switch() else ERROR_POWER_REMOVE
		"occupied":
			text = ERROR_OCCUPIED
		"empty":
			text = ERROR_EMPTY
		"unknown":
			text = ERROR_UNKNOWN
		"invalid_slot":
			text = ERROR_INVALID_SLOT

	if error_dialog:
		error_dialog.show_error(text)


func _is_switch() -> bool:
	return device != null and device.device_type == "Switch"
