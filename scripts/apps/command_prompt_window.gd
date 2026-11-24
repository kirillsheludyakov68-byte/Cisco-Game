extends VBoxContainer
class_name CommandPromptWindow

@onready var terminal_panel: PanelContainer = $TerminalPanel
@onready var output: RichTextLabel = $TerminalPanel/TerminalMargin/TerminalVBox/OutputScroll/Output
@onready var prompt_label: Label = $TerminalPanel/TerminalMargin/TerminalVBox/PromptRow/PromptLabel
@onready var input: LineEdit = $TerminalPanel/TerminalMargin/TerminalVBox/PromptRow/Input
@onready var status_label: Label = $StatusLabel

var device: Device = null
var _mono_font: SystemFont


func _ready() -> void:
	_mono_font = SystemFont.new()
	_mono_font.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "Courier New"])
	_mono_font.allow_system_fallback = true
	_apply_styles()
	input.text_submitted.connect(_on_command_submitted)
	prompt_label.text = "PC>"


func setup(device_value: Device) -> void:
	device = device_value
	_reset_terminal()
	if device != null:
		input.grab_focus()


func activate() -> void:
	if input != null:
		input.grab_focus()


func commit_pending() -> void:
	# В командной строке нет отложенных настроек: всё выполняется сразу.
	pass


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
	prompt_label.text = _prompt_text()
	_append_line("Command Prompt — локальная модель сети.")
	_append_line("Введите help, чтобы увидеть доступные команды.")
	_append_line("")


func _prompt_text() -> String:
	var name := "PC"
	if device != null:
		name = device.device_name
	return name + ">"


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
	_append_line("")
	if command != "cls" and command != "clear":
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
	if args.is_empty():
		_append_line("Использование: ping <IPv4>")
		return
	if device == null:
		_append_line("Устройство не выбрано.")
		return

	var target := args[0].strip_edges()
	if not NetworkValidation.is_valid_ipv4(target):
		_append_line("Некорректный IPv4-адрес: " + target)
		return

	var simulator = get_node_or_null("/root/NetworkSimulator")
	if simulator == null or not simulator.has_method("ping_ipv4"):
		_append_line("Проверка связи недоступна: NetworkSimulator не инициализирован.")
		return

	var result: Dictionary = simulator.ping_ipv4(device, target)
	if bool(result.get("ok", false)):
		_append_line("Ответ от " + target + ": узел доступен.")
		_append_line("  Проверка выполнена по текущей топологии; ICMP не эмулируется.")
	else:
		_append_line("Не удалось проверить " + target + ": " + str(result.get("reason", "неизвестная ошибка")))


func _append_line(text: String) -> void:
	output.append_text(text + "\n")


func _or_dash(value: String) -> String:
	return value if not value.is_empty() else "—"


func _ipv4_mode_label(mode: String) -> String:
	return "DHCP" if mode == NetworkSettings.IPV4_DHCP else "Static"


func _ipv6_mode_label(mode: String) -> String:
	return "Automatic" if mode == NetworkSettings.IPV6_AUTOMATIC else "Static"
