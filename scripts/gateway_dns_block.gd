extends PanelContainer
class_name GatewayDnsBlock

signal mode_selected(mode: String)
signal field_committed(field_name: String)

@export var title_text: String = "Gateway/DNS IPv4"
@export var automatic_label: String = "DHCP"
@export var automatic_mode: String = NetworkSettings.IPV4_DHCP
@export var static_mode: String = NetworkSettings.IPV4_STATIC

@onready var title_label: Label = $Root/VBox/TitleLabel
@onready var automatic_radio: CheckBox = $Root/VBox/ModeRow/AutomaticRadio
@onready var static_radio: CheckBox = $Root/VBox/ModeRow/StaticRadio
@onready var gateway_label: Label = $Root/VBox/Fields/GatewayLabel
@onready var gateway_edit: LineEdit = $Root/VBox/Fields/GatewayEdit
@onready var dns_label: Label = $Root/VBox/Fields/DnsLabel
@onready var dns_edit: LineEdit = $Root/VBox/Fields/DnsEdit

var _updating := false


func _ready() -> void:
	_apply_styles()
	_setup_radios()
	_connect_fields()
	set_mode(static_mode)


func set_values(mode: String, gateway: String, dns: String) -> void:
	_updating = true
	title_label.text = title_text
	automatic_radio.text = automatic_label
	gateway_edit.text = gateway
	dns_edit.text = dns

	var is_automatic := mode == automatic_mode
	automatic_radio.button_pressed = is_automatic
	static_radio.button_pressed = not is_automatic
	_apply_enabled()
	clear_field_errors()
	_updating = false


func set_mode(mode: String) -> void:
	_updating = true
	var is_automatic := mode == automatic_mode
	automatic_radio.button_pressed = is_automatic
	static_radio.button_pressed = not is_automatic
	_apply_enabled()
	_updating = false


func get_mode() -> String:
	return automatic_mode if automatic_radio.button_pressed else static_mode


func get_gateway_text() -> String:
	return gateway_edit.text.strip_edges()


func get_dns_text() -> String:
	return dns_edit.text.strip_edges()


func set_field_errors(gateway_error: bool, dns_error: bool) -> void:
	ConfigStyles.mark_line_edit_error(gateway_edit, gateway_error)
	ConfigStyles.mark_line_edit_error(dns_edit, dns_error)


func clear_field_errors() -> void:
	set_field_errors(false, false)


func _apply_styles() -> void:
	add_theme_stylebox_override("panel", ConfigStyles.section_panel())
	ConfigStyles.apply_bold_label(title_label, 13)
	ConfigStyles.apply_label(gateway_label)
	ConfigStyles.apply_label(dns_label)
	ConfigStyles.apply_checkbox(automatic_radio)
	ConfigStyles.apply_checkbox(static_radio)
	ConfigStyles.apply_line_edit(gateway_edit)
	ConfigStyles.apply_line_edit(dns_edit)


func _setup_radios() -> void:
	var group := ButtonGroup.new()
	group.allow_unpress = false
	automatic_radio.button_group = group
	static_radio.button_group = group
	automatic_radio.toggled.connect(_on_automatic_toggled)
	static_radio.toggled.connect(_on_static_toggled)


func _connect_fields() -> void:
	gateway_edit.text_submitted.connect(_on_gateway_submitted)
	gateway_edit.focus_exited.connect(_on_gateway_focus_exited)
	dns_edit.text_submitted.connect(_on_dns_submitted)
	dns_edit.focus_exited.connect(_on_dns_focus_exited)


func _apply_enabled() -> void:
	var enabled := static_radio.button_pressed
	gateway_edit.editable = enabled
	dns_edit.editable = enabled


func _on_automatic_toggled(pressed: bool) -> void:
	if _updating or not pressed:
		return
	_apply_enabled()
	clear_field_errors()
	mode_selected.emit(automatic_mode)


func _on_static_toggled(pressed: bool) -> void:
	if _updating or not pressed:
		return
	_apply_enabled()
	clear_field_errors()
	mode_selected.emit(static_mode)


func _on_gateway_submitted(_text: String) -> void:
	field_committed.emit("gateway")


func _on_gateway_focus_exited() -> void:
	field_committed.emit("gateway")


func _on_dns_submitted(_text: String) -> void:
	field_committed.emit("dns")


func _on_dns_focus_exited() -> void:
	field_committed.emit("dns")
