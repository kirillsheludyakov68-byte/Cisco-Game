extends VBoxContainer
class_name CommandPromptWindow

const PACKET_ANIMATOR_SCRIPT := preload("res://scripts/packet_animator.gd")
const PING_RESULT_DELAY := 1.5

@onready var terminal_panel: PanelContainer = $TerminalPanel
@onready var output: RichTextLabel = $TerminalPanel/TerminalMargin/TerminalVBox/OutputScroll/Output
@onready var prompt_label: Label = $TerminalPanel/TerminalMargin/TerminalVBox/PromptRow/PromptLabel
@onready var input: LineEdit = $TerminalPanel/TerminalMargin/TerminalVBox/PromptRow/Input
@onready var status_label: Label = $StatusLabel

var device: Device = null
var _mono_font: SystemFont
var _ping_in_progress := false


func _ready() -> void:
	_mono_font = SystemFont.new()
	_mono_font.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "Courier New"])
	_mono_font.allow_system_fallback = true
	_apply_styles()
	input.text_submitted.connect(_on_command_submitted)
	prompt_label.text = "PC>"


func setup(device_value: Device) -> void:
	if device != null and is_instance_valid(device) \
			and device.power_changed.is_connected(_on_device_power_changed):
		device.power_changed.disconnect(_on_device_power_changed)
	device = device_value
	if device != null and is_instance_valid(device) \
			and not device.power_changed.is_connected(_on_device_power_changed):
		device.power_changed.connect(_on_device_power_changed)
	_restore_session()
	if device != null:
		input.grab_focus()


func _exit_tree() -> void:
	_save_session()
	if device != null and is_instance_valid(device) \
			and device.power_changed.is_connected(_on_device_power_changed):
		device.power_changed.disconnect(_on_device_power_changed)


func activate() -> void:
	if input != null:
		input.grab_focus()


func commit_pending() -> void:
	# Сохраняем ввод и вывод, чтобы они пережили закрытие окна ПК.
	_save_session()


func _apply_styles() -> void:
	terminal_panel.add_theme_stylebox_override("panel", DesktopStyles.terminal_style())
	output.add_theme_font_override("normal_font", _mono_font)
	output.add_theme_font_override("bold_font", _mono_font)
	output.add_theme_font_override("italics_font", _mono_font)
	output.add_theme_color_override("default_color", DesktopStyles.TERMINAL_TEXT)
	output.add_theme_color_override("font_color", DesktopStyles.TERMINAL_TEXT)
	output.add_theme_font_size_override("normal_font_size", 13)
	prompt_label.add_theme_font_override("font", _mono_font)
	prompt_label.add_theme_color_override("font_color", DesktopStyles.TERMINAL_TEXT)
	prompt_label.add_theme_font_size_override("font_size", 13)
	DesktopStyles.apply_terminal_input(input)
	input.add_theme_font_override("font", _mono_font)
	ConfigStyles.apply_status_label(status_label)
	status_label.visible = false


func _reset_terminal() -> void:
	output.text = ""
	input.clear()
	prompt_label.text = _prompt_text()
	_append_line("Command Prompt — локальная модель сети.")
	_append_line("Введите help, чтобы увидеть доступные команды.")
	_append_line("")
	if device != null and is_instance_valid(device):
		device.command_prompt_initialized = true
	_save_session()


func _restore_session() -> void:
	if device == null or not is_instance_valid(device):
		_reset_terminal()
		return
	if not device.is_powered_on:
		_clear_terminal_view()
		return
	if not device.command_prompt_initialized:
		_reset_terminal()
		return
	prompt_label.text = _prompt_text()
	output.text = device.command_prompt_output
	input.text = device.command_prompt_input
	input.caret_column = input.text.length()


func _clear_terminal_view() -> void:
	output.text = ""
	input.clear()
	prompt_label.text = _prompt_text()


func _save_session() -> void:
	if device == null or not is_instance_valid(device):
		return
	if not device.is_powered_on or not device.command_prompt_initialized:
		return
	if not is_instance_valid(output) or not is_instance_valid(input):
		return
	device.command_prompt_output = output.get_parsed_text()
	device.command_prompt_input = input.text


func _on_device_power_changed(is_on: bool) -> void:
	if is_on:
		_reset_terminal()
	else:
		_clear_terminal_view()


func _prompt_text() -> String:
	var prompt_name := "PC"
	if device != null:
		prompt_name = device.device_name
	return prompt_name + ">"


func _on_command_submitted(text: String) -> void:
	var raw := text.strip_edges()
	var prompt := _prompt_text()
	_append_line(prompt + " " + raw)
	input.clear()

	if raw.is_empty():
		return

	var parts := raw.split(" ", false)
	if parts.is_empty():
		return
	var command := parts[0].to_lower()
	var args := parts.slice(1)
	var is_ping := command == "ping"

	match command:
		"help", "?":
			_print_help()
		"ipconfig":
			_print_ipconfig()
		"ping":
			_run_ping(args)
		"cls", "clear":
			output.text = ""
		_:
			_append_line("Команда не найдена: " + parts[0] + ". Введите help для списка команд.")

	# У ping собственный вывод и пауза с анимацией, поэтому пустую строку
	# и фокус добавляет сам _run_ping() после возврата интерфейса.
	if command != "cls" and command != "clear" and not is_ping:
		_append_line("")
		input.grab_focus()


func _print_help() -> void:
	_append_line("Доступные команды:")
	_append_line("  help                 — список команд")
	_append_line("  ipconfig             — параметры сетевых интерфейсов")
	_append_line("  ping <IPv4>          — проверка доступности по топологии")
	_append_line("  cls | clear          — очистить экран")
	_append_line("")
	_append_line("Ping не эмулирует ICMP, ARP и маршрутизацию.")


func _print_ipconfig() -> void:
	if device == null:
		_append_line("Устройство не выбрано.")
		return

	var names := device.get_interface_names()
	_append_line("Настройка IP для " + device.device_name + ":")
	if names.is_empty():
		_append_line("  Сетевые интерфейсы отсутствуют. Установите модуль в Config.")
		return

	for interface_name in names:
		var iface := device.get_interface(interface_name)
		if iface == null:
			continue
		_append_line("")
		_append_line("  " + iface.interface_name + ":")
		_append_line("    IPv4 Mode . . . . . " + _ipv4_mode_label(iface.ipv4_mode))
		_append_line("    IPv4 Address . . . . " + _or_dash(iface.ipv4_address))
		_append_line("    Subnet Mask . . . . . " + _or_dash(iface.subnet_mask))
		_append_line("    Default Gateway . . . " + _or_dash(device.network_settings.gateway_ipv4))
		_append_line("    DNS Server . . . . . " + _or_dash(device.network_settings.dns_ipv4))
		_append_line("    MAC Address . . . . . " + _or_dash(iface.get_mac_cisco()))
		_append_line("    IPv6 Mode . . . . . " + _ipv6_mode_label(iface.ipv6_mode))
		_append_line("    IPv6 Address . . . . " + _or_dash(iface.ipv6_address))
		_append_line("    Link-local IPv6 . . . " + _or_dash(iface.link_local_ipv6))


func _run_ping(args: PackedStringArray) -> void:
	if _ping_in_progress:
		_append_line("Проверка уже выполняется.")
		_finish_ping_output()
		return
	if args.is_empty():
		_append_line("Использование: ping <IPv4>")
		_finish_ping_output()
		return
	if device == null:
		_append_line("Устройство не выбрано.")
		_finish_ping_output()
		return

	var target := args[0].strip_edges()
	if not NetworkValidation.is_valid_ipv4(target):
		_append_line("Некорректный IPv4-адрес: " + target)
		_finish_ping_output()
		return

	var simulator = get_node_or_null("/root/NetworkSimulator")
	if simulator == null or not simulator.has_method("calculate_ping_route"):
		_append_line("Проверка связи недоступна: NetworkSimulator не инициализирован.")
		_finish_ping_output()
		return

	_ping_in_progress = true
	input.editable = false
	_append_line("Pinging %s with 32 bytes of data:" % target)

	var route: Dictionary = simulator.calculate_ping_route(device, target)
	print("[Ping] Маршрут: %s" % _route_debug_text(route))

	# Прячем все открытые окна устройств, но не главное окно игры.
	var hidden_windows := _hide_open_device_windows()
	var animator := _spawn_packet_animator(route)

	var success := bool(route.get("success", false))
	var error_msg := str(route.get("error_msg", ""))
	var cancelled := false
	if animator != null:
		var signal_args = await animator.packet_finished
		if signal_args is Array:
			if signal_args.size() > 0:
				success = bool(signal_args[0])
			if signal_args.size() > 1:
				error_msg = str(signal_args[1])
			if signal_args.size() > 2:
				cancelled = bool(signal_args[2])

	if cancelled:
		_append_line("[Прервано] Проверка ping остановлена.")
	elif success:
		_append_line("Reply from %s: bytes=32 time=1ms TTL=128" % target)
	else:
		_append_line(_ping_failure_line(error_msg))
		if not error_msg.is_empty():
			_append_line("[Ошибка] " + error_msg)
	_append_line("")

	# Даём игроку увидеть результат анимации. При отмене по ESC
	# возвращаем интерфейс сразу, без лишней задержки.
	if not cancelled:
		await get_tree().create_timer(PING_RESULT_DELAY).timeout

	_restore_device_windows(hidden_windows)
	_ping_in_progress = false
	input.editable = true
	input.grab_focus()

	# Уровень слушает этот сигнал, чтобы отметить шаг задания.
	# При отмене не меняем результат предыдущей проверки.
	if not cancelled:
		if simulator.has_method("notify_ping_checked"):
			simulator.notify_ping_checked(device, target, success)
		else:
			simulator.ping_checked.emit(device, target, success)


func _finish_ping_output() -> void:
	_append_line("")
	input.grab_focus()


func _hide_open_device_windows() -> Array[Window]:
	var hidden: Array[Window] = []
	var root := get_tree().root
	if root == null:
		return hidden
	for node in root.find_children("*", "Window", true, false):
		if node is DeviceWindow:
			var window := node as DeviceWindow
			if window.visible:
				window.hide()
				hidden.append(window)
				print("[Ping] Скрыто окно: %s" % window.title)
	if not hidden.is_empty():
		# После скрытия дочернего окна фокус может остаться у невидимого
		# окна. Возвращаем его главному окну, чтобы ESC работал.
		root.grab_focus()
	return hidden


func _restore_device_windows(windows: Array[Window]) -> void:
	for window in windows:
		if is_instance_valid(window):
			window.show()
			print("[Ping] Показано окно: %s" % window.title)
	var prompt_window := get_window()
	if prompt_window != null and is_instance_valid(prompt_window):
		prompt_window.grab_focus()


func _spawn_packet_animator(route: Dictionary) -> Node:
	var host := get_tree().current_scene
	if host == null:
		host = get_tree().root
	if host == null:
		return null
	var animator := PACKET_ANIMATOR_SCRIPT.new() as Node
	host.add_child(animator)
	animator.play(route)
	return animator


func _route_debug_text(route: Dictionary) -> String:
	var path: Array = route.get("path", [])
	var names: Array[String] = []
	for node in path:
		if node != null and is_instance_valid(node):
			names.append(str(node.device_name))
	var result := " -> ".join(PackedStringArray(names))
	if bool(route.get("success", false)):
		return result
	return "%s (ошибка: %s)" % [result, str(route.get("error_msg", ""))]


func _ping_failure_line(error_msg: String) -> String:
	var lower := error_msg.to_lower()
	if lower.contains("выключен") or lower.contains("загружается") \
			or lower.contains("прервана") or lower.contains("нет пути"):
		return "Request timed out"
	return "Destination host unreachable"


func _append_line(text: String) -> void:
	output.append_text(text + "\n")


func _or_dash(value: String) -> String:
	return value if not value.is_empty() else "—"


func _ipv4_mode_label(mode: String) -> String:
	return "DHCP" if mode == NetworkSettings.IPV4_DHCP else "Static"


func _ipv6_mode_label(mode: String) -> String:
	return "Automatic" if mode == NetworkSettings.IPV6_AUTOMATIC else "Static"
