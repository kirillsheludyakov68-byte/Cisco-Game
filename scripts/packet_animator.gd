extends CanvasLayer

signal packet_finished(success: bool, error_msg: String, cancelled: bool)

const PACKET_SCENE := preload("res://scenes/Packet.tscn")
const SEGMENT_DURATION := 0.65
const PULSE_DURATION := 0.35

var _packet: Node2D = null
var _flight_tween: Tween = null
var _pulse_tween: Tween = null
var _route: Dictionary = {}
var _finished := false


func _ready() -> void:
	# Анимация должна быть поверх панели задания и кабелей.
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS


func play(route: Dictionary) -> void:
	_route = route
	var route_path: Array = route.get("path", [])
	var points: Array[Vector2] = []
	for node in route_path:
		if node is Node2D and is_instance_valid(node):
			# CanvasLayer работает в экранных координатах, поэтому учитываем
			# возможную камеру и трансформации канваса.
			points.append((node as Node2D).get_global_transform_with_canvas().origin)

	print("[Ping] Маршрут анимации: %s" % _path_debug_text(route_path))
	if points.is_empty():
		print("[Ping] Нет точек для анимации: %s" % str(route.get("error_msg", "")))
		# Завершаем через deferred, чтобы Command Prompt успел подключиться
		# к сигналу packet_finished и не пропустил его.
		call_deferred("_finish", false, str(route.get("error_msg", "Маршрут не найден.")), false)
		return

	_packet = PACKET_SCENE.instantiate() as Node2D
	if _packet == null:
		call_deferred("_finish", false, "Не удалось создать пакет.", false)
		return

	add_child(_packet)
	_packet.position = points[0]
	_packet.scale = Vector2(0.8, 0.8)
	_start_pulse()

	var success := bool(route.get("success", false))
	if points.size() == 1:
		print("[Ping] Пакет остаётся на месте: %s" % _path_debug_text(route_path))
		_play_finish(success)
		return

	_flight_tween = create_tween()
	_flight_tween.set_trans(Tween.TRANS_SINE)
	_flight_tween.set_ease(Tween.EASE_IN_OUT)
	for index in range(1, points.size()):
		print("[Ping] Пакет летит к точке %d: %s" % [index, str(points[index])])
		_flight_tween.tween_property(_packet, "position", points[index], SEGMENT_DURATION)
	_flight_tween.finished.connect(_on_flight_finished)


func _on_flight_finished() -> void:
	if _finished:
		return
	_play_finish(bool(_route.get("success", false)))


func _play_finish(success: bool) -> void:
	if _finished:
		return
	_stop_pulse()
	if _packet == null or not is_instance_valid(_packet):
		_finish(success, str(_route.get("error_msg", "")), false)
		return

	var tween := create_tween()
	if success:
		print("[Ping] Успех: пакет доставлен.")
		tween.set_parallel(true)
		tween.tween_property(_packet, "modulate", Color(0.35, 1.0, 0.45, 0.0), 0.55)
		tween.tween_property(_packet, "scale", Vector2(1.8, 1.8), 0.55) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		print("[Ping] Ошибка на маршруте: %s" % str(_route.get("error_msg", "")))
		_packet.modulate = Color(1.0, 0.18, 0.18, 1.0)
		tween.set_parallel(true)
		tween.tween_property(_packet, "scale", Vector2(2.0, 2.0), 0.45) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(_packet, "modulate", Color(1.0, 0.0, 0.0, 0.0), 0.55) \
			.set_delay(0.25)

	tween.finished.connect(func() -> void:
		_finish(success, str(_route.get("error_msg", "")), false)
	)


func _start_pulse() -> void:
	if _packet == null or not is_instance_valid(_packet):
		return
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	_pulse_tween.tween_property(_packet, "scale", Vector2(1.2, 1.2), PULSE_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(_packet, "scale", Vector2(0.8, 0.8), PULSE_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null


func _finish(success: bool, error_msg: String, cancelled: bool) -> void:
	if _finished:
		return
	_finished = true
	_stop_pulse()
	if _flight_tween != null and _flight_tween.is_valid():
		_flight_tween.kill()
	_flight_tween = null
	if _packet != null and is_instance_valid(_packet):
		_packet.queue_free()
	_packet = null
	print("[Ping] Анимация завершена: success=%s, cancelled=%s, error=%s" % [
		success, cancelled, error_msg
	])
	packet_finished.emit(success, error_msg, cancelled)
	queue_free()


func _input(event: InputEvent) -> void:
	if _finished:
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and (key.keycode == KEY_ESCAPE or key.physical_keycode == KEY_ESCAPE):
			print("[Ping] ESC: анимация прервана игроком.")
			get_viewport().set_input_as_handled()
			_finish(false, "Проверка прервана пользователем.", true)


func _path_debug_text(path: Array) -> String:
	var names: Array[String] = []
	for node in path:
		if node != null and is_instance_valid(node):
			names.append(str(node.device_name))
	return " -> ".join(PackedStringArray(names))
