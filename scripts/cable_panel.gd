extends CanvasLayer

const ERROR_DIALOG_SCENE := preload("res://scenes/ErrorDialog.tscn")
const CONNECTOR_DIALOG_SCENE := preload("res://scenes/ConnectorSelectDialog.tscn")

# Какой кабель выбран (или -1, если ничего)
var selected_cable: int = -1

# Первое устройство, с которого начали тянуть кабель
var first_device: Device = null

# Временная "резиновая" линия за курсором
var rubber_line: Line2D = null

# Кнопки кабелей: CableType -> Button
var _cable_buttons: Dictionary = {}

# Текущее открытое окно устройства
var current_device_window: DeviceWindow = null

var _error_dialog: ErrorDialog = null
var _connector_dialog: ConnectorSelectDialog = null
var _connector_dialog_side: String = ""
var _source_interface: String = ""
var _pending_target_device: Device = null

signal cable_selected(cable_type: int)

func _ready() -> void:
	_register_button(NetworkSimulator.CableType.STRAIGHT, $PanelContainer/HBoxContainer/ButtonStraight)
	_register_button(NetworkSimulator.CableType.CROSSOVER, $PanelContainer/HBoxContainer/ButtonCrossover)
	_register_button(NetworkSimulator.CableType.WIRELESS, $PanelContainer/HBoxContainer/ButtonWireless)
	_register_button(NetworkSimulator.CableType.FIBER, $PanelContainer/HBoxContainer/ButtonFiber)
	_clear_cable_cursor()

	# Создаём временную линию, но скрываем её
	rubber_line = Line2D.new()
	rubber_line.width = 3.0
	rubber_line.default_color = Color(0.5, 0.5, 0.5, 0.7)
	rubber_line.visible = false
	add_child(rubber_line)

	# Ошибки кабеля показываем поверх игрового UI, а не только в консоли.
	var error_layer := CanvasLayer.new()
	error_layer.name = "ErrorLayer"
	error_layer.layer = 20
	add_child(error_layer)
	_error_dialog = ERROR_DIALOG_SCENE.instantiate() as ErrorDialog
	if _error_dialog != null:
		error_layer.add_child(_error_dialog)

	_connector_dialog = CONNECTOR_DIALOG_SCENE.instantiate() as ConnectorSelectDialog
	if _connector_dialog != null:
		error_layer.add_child(_connector_dialog)
		_connector_dialog.connector_selected.connect(_on_connector_selected)
		_connector_dialog.cancelled.connect(_on_connector_dialog_cancelled)

func _register_button(cable_type: int, button: Button) -> void:
	_cable_buttons[cable_type] = button
	button.toggle_mode = true
	button.pressed.connect(_on_cable_button_pressed.bind(cable_type))


func get_cable_button(cable_type: int) -> Button:
	return _cable_buttons.get(cable_type) as Button

func _on_cable_button_pressed(cable_type: int) -> void:
	# Повторное нажатие на выбранную иконку выключает режим прокладки кабеля.
	# После этого клик по устройству снова открывает окно настроек.
	var button := _cable_buttons.get(cable_type) as Button
	if button != null and selected_cable == cable_type and not button.button_pressed:
		selected_cable = -1
		_cancel_connection()
		_clear_button_selection()
		_clear_cable_cursor()
		return

	# Визуально оставляем нажатой только одну кнопку.
	for type in _cable_buttons:
		_cable_buttons[type].button_pressed = (type == cable_type)
	_select(cable_type)

func _select(cable_type: int) -> void:
	selected_cable = cable_type
	# Если уже начали соединение — сбросим
	_cancel_connection()
	if rubber_line != null:
		rubber_line.default_color = _cable_color(cable_type)
	_apply_cable_cursor(cable_type)
	cable_selected.emit(cable_type)


# Пока кабель выбран, вместо обычного курсора показываем его иконку.
# Это делает режим прокладки заметным: игрок «держит» кабель в руке.
func _apply_cable_cursor(cable_type: int) -> void:
	var button := _cable_buttons.get(cable_type) as Button
	if button == null or button.icon == null:
		_clear_cable_cursor()
		return
	var icon_size := button.icon.get_size()
	Input.set_custom_mouse_cursor(
		button.icon,
		Input.CURSOR_ARROW,
		icon_size * 0.5
	)


func _clear_cable_cursor() -> void:
	Input.set_custom_mouse_cursor(null)


func _cable_color(cable_type: int) -> Color:
	match cable_type:
		NetworkSimulator.CableType.CROSSOVER:
			return Color(0.9, 0.5, 0.1)
		NetworkSimulator.CableType.FIBER:
			return Color(0.9, 0.08, 0.08)
		NetworkSimulator.CableType.WIRELESS:
			return Color(0.08, 0.08, 0.08)
	return Color(0.1, 0.1, 0.1)

func _cancel_connection() -> void:
	first_device = null
	if rubber_line != null:
		rubber_line.visible = false
	_reset_all_highlights()

func _process(_delta: float) -> void:
	if first_device != null and not is_instance_valid(first_device):
		_cancel_connection()
		return

	if first_device != null and rubber_line != null and rubber_line.visible:
		rubber_line.points = PackedVector2Array([
			first_device.global_position,
			get_viewport().get_mouse_position()   # ← координаты в CanvasLayer
		])

# Устройство кликнуто — вызывается из level.gd
func handle_device_click(device: Device) -> void:
	if device == null or not is_instance_valid(device):
		return

	if selected_cable == -1:
		# Кабель не выбран — открываем окно настроек устройства.
		_open_device_window(device)
		return

	if first_device != null and not is_instance_valid(first_device):
		_cancel_connection()

	if first_device == null:
		# Первый клик — начинаем тянуть: сначала выбираем источник кабеля.
		first_device = device
		rubber_line.visible = true
		_open_source_connector_picker(device)
		return

	# Второй клик — выбираем порт на принимающем устройстве.
	if first_device == device:
		# Кликнули на то же устройство — отмена
		_cancel_connection()
		return

	_pending_target_device = device
	_open_target_connector_picker(device)


func _open_source_connector_picker(device: Device) -> void:
	if device == null or not is_instance_valid(device):
		_cancel_connection()
		return

	var candidates: Array = _connector_dialog.get_connector_candidates(device, int(selected_cable))
	if candidates.is_empty():
		_error_dialog.show_error(_missing_connector_message(device, int(selected_cable)))
		_cancel_connection()
		return

	_connector_dialog_side = "source"
	_connector_dialog.setup(
		device,
		device,
		null,
		int(selected_cable),
		"Выберите разъём",
		"Куда вставить кабель от %s?" % device.device_name
	)


func _open_target_connector_picker(device: Device) -> void:
	if first_device == null or not is_instance_valid(first_device):
		_cancel_connection()
		return

	var candidates: Array = _connector_dialog.get_connector_candidates(device, int(selected_cable))
	if candidates.is_empty():
		_error_dialog.show_error(_missing_connector_message(device, int(selected_cable)))
		_cancel_connection()
		return

	_pending_target_device = device
	_connector_dialog_side = "target"
	_connector_dialog.setup(
		device,
		first_device,
		device,
		int(selected_cable),
		"Выберите разъём",
		"Куда вставить кабель к %s?" % device.device_name
	)


func _on_connector_selected(interface_name: String) -> void:
	var side := _connector_dialog_side
	_connector_dialog_side = ""
	if _connector_dialog != null:
		_connector_dialog.visible = false

	if side == "source":
		if device_is_valid(first_device):
			_source_interface = interface_name
		return

	if side == "target":
		var source := first_device
		var target := _pending_target_device
		if source == null or target == null or not is_instance_valid(source) or not is_instance_valid(target):
			_cancel_connection()
			return
		_finish_connection(source, target, int(selected_cable), _source_interface, interface_name)


func _on_connector_dialog_cancelled() -> void:
	_connector_dialog_side = ""
	if _connector_dialog != null:
		_connector_dialog.visible = false
	_cancel_connection()


func _finish_connection(
	source: Device,
	target: Device,
	cable_type: int,
	source_interface: String,
	target_interface: String
) -> void:
	var check := NetworkSimulator.can_connect(source, target, cable_type)
	if not check.ok:
		if _error_dialog != null:
			_error_dialog.show_error(str(check.reason))
		_cancel_connection()
		return

	_create_connection(source, target, cable_type, source_interface, target_interface)


func device_is_valid(device: Device) -> bool:
	return device != null and is_instance_valid(device)


func _missing_connector_message(device: Device, cable_type: int) -> String:
	var kind := _cable_interface_kind(cable_type)
	var port_name := "Fiber"
	if kind == "ethernet":
		port_name = "Ethernet"
	if kind == "wireless":
		port_name = "wireless"
	return "У %s нет доступного %s-разъёма для выбранного кабеля." % [device.device_name, port_name]


func _cable_interface_kind(cable_type: int) -> String:
	match cable_type:
		NetworkSimulator.CableType.STRAIGHT, NetworkSimulator.CableType.CROSSOVER:
			return "ethernet"
		NetworkSimulator.CableType.FIBER:
			return "fiber"
		NetworkSimulator.CableType.WIRELESS:
			return "wireless"
	return ""


func _create_connection(
	a: Device,
	b: Device,
	cable_type: int,
	source_interface: String = "",
	target_interface: String = ""
) -> void:
	var scene := load("res://scenes/Connection.tscn")
	var conn = scene.instantiate()
	# Добавляем в тот же родитель, где лежат устройства (в уровень).
	var parent := get_parent()
	if parent == null:
		parent = get_tree().current_scene
	parent.add_child(conn)
	conn.setup(a, b, cable_type, -1.0, source_interface, target_interface)
	NetworkSimulator.add_connection(conn)
	print("Соединено: ", a.device_name, " ↔ ", b.device_name)
	# После соединения выключаем режим (Вариант A)
	selected_cable = -1
	_clear_button_selection()
	_clear_cable_cursor()

func _clear_button_selection() -> void:
	for button in _cable_buttons.values():
		button.button_pressed = false

func _open_device_window(device: Device) -> void:
	if current_device_window and is_instance_valid(current_device_window):
		current_device_window.queue_free()

	var scene := load("res://scenes/DeviceWindow.tscn")
	if scene == null:
		push_error("Не удалось загрузить DeviceWindow.tscn")
		return

	current_device_window = scene.instantiate()

	# ВАЖНО: Сначала добавляем в дерево
	var root := get_tree().current_scene
	if root == null:
		root = get_parent()
	root.add_child(current_device_window)

	# Только потом передаем устройство и открываем
	current_device_window.open_for(device)
	current_device_window.popup_centered(Vector2i(850, 670))

func _reset_all_highlights() -> void:
	for d in NetworkSimulator.devices:
		if is_instance_valid(d):
			d.reset_highlight()


func _exit_tree() -> void:
	_clear_cable_cursor()
