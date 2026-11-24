extends PanelContainer
class_name PTHostNM1CEConfigPage

@onready var header_panel: PanelContainer = $Root/VBox/HeaderPanel
@onready var header_label: Label = $Root/VBox/HeaderPanel/HeaderLabel
@onready var status_label: Label = $Root/VBox/StatusLabel

@onready var port_status_check: CheckBox = $Root/VBox/BodyScroll/Body/TopGrid/PortStatusCheck
@onready var bandwidth_10: CheckBox = $Root/VBox/BodyScroll/Body/TopGrid/BandwidthRow/Bandwidth10
@onready var bandwidth_auto: CheckBox = $Root/VBox/BodyScroll/Body/TopGrid/BandwidthRow/BandwidthAuto
@onready var duplex_half: CheckBox = $Root/VBox/BodyScroll/Body/TopGrid/DuplexRow/DuplexHalf
@onready var duplex_full: CheckBox = $Root/VBox/BodyScroll/Body/TopGrid/DuplexRow/DuplexFull
@onready var duplex_auto: CheckBox = $Root/VBox/BodyScroll/Body/TopGrid/DuplexRow/DuplexAuto
@onready var mac_edit: LineEdit = $Root/VBox/BodyScroll/Body/TopGrid/MacEdit
@onready var ip_config: InterfaceIpConfigBlock = $Root/VBox/BodyScroll/Body/IpConfig

var device: Device = null
var network_interface: DeviceInterface = null
var module_name: String = ""

var _updating := false
var _bandwidth_group: ButtonGroup
var _duplex_group: ButtonGroup


func _ready() -> void:
	_apply_styles()
	_setup_groups()
	_connect_signals()


func setup(dev: Device, iface: DeviceInterface, source_module: String = "") -> void:
	device = dev
	network_interface = iface
	module_name = source_module
	ip_config.setup(dev, iface)
	refresh()


func refresh() -> void:
	_updating = true
	_set_status("")

	if network_interface == null:
		header_label.text = "Интерфейс"
		port_status_check.button_pressed = false
		port_status_check.disabled = true
		bandwidth_10.disabled = true
		bandwidth_auto.disabled = true
		duplex_half.disabled = true
		duplex_full.disabled = true
		duplex_auto.disabled = true
		mac_edit.text = ""
		_updating = false
		return

	header_label.text = network_interface.interface_name
	port_status_check.disabled = false
	port_status_check.button_pressed = network_interface.enabled

	bandwidth_10.disabled = false
	bandwidth_auto.disabled = false
	bandwidth_10.button_pressed = network_interface.bandwidth_mode == DeviceInterface.BANDWIDTH_10MBPS
	bandwidth_auto.button_pressed = network_interface.bandwidth_mode == DeviceInterface.BANDWIDTH_AUTO

	duplex_half.disabled = false
	duplex_full.disabled = false
	duplex_auto.disabled = false
	duplex_half.button_pressed = network_interface.duplex_mode == DeviceInterface.DUPLEX_HALF
	duplex_full.button_pressed = network_interface.duplex_mode == DeviceInterface.DUPLEX_FULL
	duplex_auto.button_pressed = network_interface.duplex_mode == DeviceInterface.DUPLEX_AUTO

	mac_edit.text = network_interface.get_mac_cisco()
	_updating = false


func commit_pending() -> void:
	ip_config.commit_pending()


func _setup_groups() -> void:
	_bandwidth_group = _make_button_group()
	_duplex_group = _make_button_group()

	bandwidth_10.button_group = _bandwidth_group
	bandwidth_auto.button_group = _bandwidth_group
	duplex_half.button_group = _duplex_group
	duplex_full.button_group = _duplex_group
	duplex_auto.button_group = _duplex_group


func _make_button_group() -> ButtonGroup:
	var group := ButtonGroup.new()
	group.allow_unpress = false
	return group


func _connect_signals() -> void:
	ip_config.status_changed.connect(_on_ip_status_changed)
	port_status_check.toggled.connect(_on_port_status_toggled)

	bandwidth_10.toggled.connect(
		_on_bandwidth_toggled.bind(DeviceInterface.BANDWIDTH_10MBPS)
	)
	bandwidth_auto.toggled.connect(
		_on_bandwidth_toggled.bind(DeviceInterface.BANDWIDTH_AUTO)
	)

	duplex_half.toggled.connect(_on_duplex_toggled.bind(DeviceInterface.DUPLEX_HALF))
	duplex_full.toggled.connect(_on_duplex_toggled.bind(DeviceInterface.DUPLEX_FULL))
	duplex_auto.toggled.connect(_on_duplex_toggled.bind(DeviceInterface.DUPLEX_AUTO))


func _on_ip_status_changed(text: String, is_error: bool, success: bool) -> void:
	_set_status(text, is_error, success)


func _on_port_status_toggled(pressed: bool) -> void:
	if _updating or device == null or network_interface == null:
		return
	device.set_interface_enabled(network_interface.interface_name, pressed)
	_set_status(
		"Интерфейс включён." if pressed else "Интерфейс выключен.",
		false,
		pressed
	)


func _on_bandwidth_toggled(pressed: bool, mode: String) -> void:
	if _updating or not pressed or device == null or network_interface == null:
		return
	device.set_interface_bandwidth(
		network_interface.interface_name,
		mode,
		network_interface.bandwidth_mbps
	)
	_set_status("Режим пропускной способности сохранён. Симуляция скорости не реализована.", false, true)


func _on_duplex_toggled(pressed: bool, mode: String) -> void:
	if _updating or not pressed or device == null or network_interface == null:
		return
	device.set_interface_duplex(network_interface.interface_name, mode)
	_set_status("Режим дуплекса сохранён. Симуляция дуплекса не реализована.", false, true)


func _set_status(text: String, is_error: bool = false, success: bool = false) -> void:
	ConfigStyles.set_status(status_label, text, is_error, success)


func _apply_styles() -> void:
	add_theme_stylebox_override("panel", ConfigStyles.content_panel())
	header_panel.add_theme_stylebox_override("panel", ConfigStyles.header_panel())

	ConfigStyles.apply_bold_label(header_label, 16)
	ConfigStyles.apply_status_label(status_label)

	for label in _get_labels():
		ConfigStyles.apply_label(label)

	ConfigStyles.apply_plain_checkbox(port_status_check)
	ConfigStyles.apply_checkbox(bandwidth_10)
	ConfigStyles.apply_checkbox(bandwidth_auto)
	ConfigStyles.apply_checkbox(duplex_half)
	ConfigStyles.apply_checkbox(duplex_full)
	ConfigStyles.apply_checkbox(duplex_auto)

	ConfigStyles.apply_line_edit(mac_edit)


func _get_labels() -> Array[Label]:
	return [
		$Root/VBox/BodyScroll/Body/TopGrid/PortStatusLabel,
		$Root/VBox/BodyScroll/Body/TopGrid/BandwidthLabel,
		$Root/VBox/BodyScroll/Body/TopGrid/DuplexLabel,
		$Root/VBox/BodyScroll/Body/TopGrid/MacLabel,
	]
