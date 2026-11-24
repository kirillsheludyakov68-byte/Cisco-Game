extends PanelContainer
class_name AccessPointWirelessConfigPage

@onready var header_panel: PanelContainer = $Root/VBox/HeaderPanel
@onready var header_label: Label = $Root/VBox/HeaderPanel/HeaderLabel
@onready var status_label: Label = $Root/VBox/StatusLabel

@onready var port_status_check: CheckBox = $Root/VBox/BodyScroll/Body/TopGrid/PortStatusCheck
@onready var ssid_edit: LineEdit = $Root/VBox/BodyScroll/Body/TopGrid/SsidEdit
@onready var channel_option: OptionButton = $Root/VBox/BodyScroll/Body/TopGrid/ChannelOption
@onready var coverage_edit: LineEdit = $Root/VBox/BodyScroll/Body/TopGrid/CoverageEdit

@onready var auth_panel: PanelContainer = $Root/VBox/BodyScroll/Body/AuthPanel
@onready var auth_disabled: CheckBox = $Root/VBox/BodyScroll/Body/AuthPanel/AuthMargin/AuthVBox/AuthContent/AuthLeft/AuthOptions/AuthDisabled
@onready var auth_wep: CheckBox = $Root/VBox/BodyScroll/Body/AuthPanel/AuthMargin/AuthVBox/AuthContent/AuthLeft/AuthOptions/AuthWep
@onready var auth_wpa_psk: CheckBox = $Root/VBox/BodyScroll/Body/AuthPanel/AuthMargin/AuthVBox/AuthContent/AuthLeft/AuthOptions/AuthWpaPsk
@onready var auth_wpa2_psk: CheckBox = $Root/VBox/BodyScroll/Body/AuthPanel/AuthMargin/AuthVBox/AuthContent/AuthLeft/AuthOptions/AuthWpa2Psk

@onready var wep_key_edit: LineEdit = $Root/VBox/BodyScroll/Body/AuthPanel/AuthMargin/AuthVBox/AuthContent/AuthFields/WepKeyEdit
@onready var psk_edit: LineEdit = $Root/VBox/BodyScroll/Body/AuthPanel/AuthMargin/AuthVBox/AuthContent/AuthFields/PskEdit
@onready var user_id_edit: LineEdit = $Root/VBox/BodyScroll/Body/AuthPanel/AuthMargin/AuthVBox/AuthContent/AuthFields/UserIdEdit
@onready var password_edit: LineEdit = $Root/VBox/BodyScroll/Body/AuthPanel/AuthMargin/AuthVBox/AuthContent/AuthFields/PasswordEdit
@onready var encryption_option: OptionButton = $Root/VBox/BodyScroll/Body/AuthPanel/AuthMargin/AuthVBox/EncryptionRow/EncryptionOption

var device: Device = null
var network_interface: DeviceInterface = null
var module_name: String = ""

var _updating := false
var _auth_group: ButtonGroup
var _auth_buttons: Dictionary = {}


func _ready() -> void:
	_setup_auth_group()
	_setup_options()
	_apply_styles()
	_connect_signals()


func setup(dev: Device, iface: DeviceInterface, source_module: String = "") -> void:
	device = dev
	network_interface = iface
	module_name = source_module
	refresh()


func refresh() -> void:
	_updating = true
	ConfigStyles.mark_line_edit_error(ssid_edit, false)
	ConfigStyles.mark_line_edit_error(coverage_edit, false)
	_set_status("")

	if network_interface == null:
		header_label.text = "Port 1"
		port_status_check.disabled = true
		port_status_check.button_pressed = false
		ssid_edit.text = ""
		ConfigStyles.set_line_edit_editable(ssid_edit, false)
		channel_option.disabled = true
		coverage_edit.text = ""
		ConfigStyles.set_line_edit_editable(coverage_edit, false)
		for checkbox in _auth_buttons.values():
			checkbox.disabled = true
			checkbox.button_pressed = false
		for edit in _get_auth_edits():
			edit.text = ""
			ConfigStyles.set_line_edit_editable(edit, false)
		encryption_option.disabled = true
		_updating = false
		return

	header_label.text = network_interface.interface_name
	port_status_check.disabled = false
	port_status_check.button_pressed = network_interface.enabled
	ssid_edit.text = network_interface.wireless.ssid
	ConfigStyles.set_line_edit_editable(ssid_edit, true)

	channel_option.disabled = false
	_select_channel(network_interface.wireless.channel_5ghz)

	coverage_edit.text = "%.2f" % network_interface.wireless.coverage_range_m
	ConfigStyles.set_line_edit_editable(coverage_edit, true)

	for mode in _auth_buttons:
		var checkbox: CheckBox = _auth_buttons[mode]
		checkbox.disabled = false
		checkbox.button_pressed = network_interface.wireless.authentication_mode == mode

	wep_key_edit.text = network_interface.wireless.wep_key
	psk_edit.text = network_interface.wireless.psk_passphrase
	user_id_edit.text = network_interface.wireless.user_id
	password_edit.text = network_interface.wireless.password

	_select_option(
		encryption_option,
		WirelessSettings.ENCRYPTION_TYPES,
		network_interface.wireless.encryption_type
	)
	_update_auth_field_states()
	_updating = false


func commit_pending() -> void:
	if device == null or network_interface == null:
		return
	_commit_ssid()
	_commit_coverage()
	_commit_credentials()


func _setup_auth_group() -> void:
	_auth_group = ButtonGroup.new()
	_auth_group.allow_unpress = false
	_auth_buttons = {
		WirelessSettings.AUTH_DISABLED: auth_disabled,
		WirelessSettings.AUTH_WEP: auth_wep,
		WirelessSettings.AUTH_WPA_PSK: auth_wpa_psk,
		WirelessSettings.AUTH_WPA2_PSK: auth_wpa2_psk,
	}
	for checkbox in _auth_buttons.values():
		checkbox.button_group = _auth_group


func _setup_options() -> void:
	channel_option.clear()
	for channel in WirelessSettings.FIVE_GHZ_CHANNELS:
		channel_option.add_item(str(channel))

	encryption_option.clear()
	for value in WirelessSettings.ENCRYPTION_TYPES:
		encryption_option.add_item(_encryption_label(value))


func _connect_signals() -> void:
	port_status_check.toggled.connect(_on_port_status_toggled)
	ssid_edit.text_submitted.connect(_on_ssid_submitted)
	ssid_edit.focus_exited.connect(_on_ssid_focus_exited)
	channel_option.item_selected.connect(_on_channel_selected)
	coverage_edit.text_submitted.connect(_on_coverage_submitted)
	coverage_edit.focus_exited.connect(_on_coverage_focus_exited)

	for mode in _auth_buttons:
		var checkbox: CheckBox = _auth_buttons[mode]
		checkbox.toggled.connect(_on_auth_mode_toggled.bind(mode))

	wep_key_edit.text_submitted.connect(_on_credential_submitted)
	wep_key_edit.focus_exited.connect(_on_credential_focus_exited)
	psk_edit.text_submitted.connect(_on_credential_submitted)
	psk_edit.focus_exited.connect(_on_credential_focus_exited)
	user_id_edit.text_submitted.connect(_on_credential_submitted)
	user_id_edit.focus_exited.connect(_on_credential_focus_exited)
	password_edit.text_submitted.connect(_on_credential_submitted)
	password_edit.focus_exited.connect(_on_credential_focus_exited)

	encryption_option.item_selected.connect(_on_encryption_selected)


func _on_port_status_toggled(pressed: bool) -> void:
	if _updating or device == null or network_interface == null:
		return
	device.set_interface_enabled(network_interface.interface_name, pressed)
	_set_status(
		"Порт включён." if pressed else "Порт выключен.",
		false,
		pressed
	)


func _on_ssid_submitted(_text: String) -> void:
	_commit_ssid()


func _on_ssid_focus_exited() -> void:
	_commit_ssid()


func _on_channel_selected(index: int) -> void:
	if _updating or device == null or network_interface == null:
		return
	if index < 0 or index >= WirelessSettings.FIVE_GHZ_CHANNELS.size():
		return
	var channel := WirelessSettings.FIVE_GHZ_CHANNELS[index]
	if not device.set_interface_wireless_settings(
		network_interface.interface_name,
		{"channel_5ghz": channel}
	):
		_set_status("Не удалось сохранить канал 5 ГГц.", true)
		return
	_set_status("Канал 5 ГГц сохранён.", false, true)


func _on_coverage_submitted(_text: String) -> void:
	_commit_coverage()


func _on_coverage_focus_exited() -> void:
	_commit_coverage()


func _on_credential_submitted(_text: String) -> void:
	_commit_credentials()


func _on_credential_focus_exited() -> void:
	_commit_credentials()


func _on_auth_mode_toggled(pressed: bool, mode: String) -> void:
	if _updating or not pressed or device == null or network_interface == null:
		return

	var encryption := _default_encryption_for(mode)
	var result := device.set_interface_wireless_settings(
		network_interface.interface_name,
		{
			"authentication_mode": mode,
			"encryption_type": encryption,
		}
	)
	if not result:
		_set_status("Не удалось сохранить режим аутентификации.", true)
		return

	_select_option(encryption_option, WirelessSettings.ENCRYPTION_TYPES, encryption)
	_update_auth_field_states()
	_set_status(
		"Режим аутентификации сохранён. Шифрование беспроводной сети не моделируется.",
		false,
		true
	)


func _on_encryption_selected(_index: int) -> void:
	if _updating or device == null or network_interface == null:
		return
	var value := _option_value(encryption_option, WirelessSettings.ENCRYPTION_TYPES)
	if not device.set_interface_wireless_settings(
		network_interface.interface_name,
		{"encryption_type": value}
	):
		_set_status("Не удалось сохранить тип шифрования.", true)
		return
	_set_status("Тип шифрования сохранён. Шифрование не моделируется.", false, true)


func _commit_ssid() -> bool:
	if device == null or network_interface == null:
		return false

	var value := ssid_edit.text.strip_edges()
	if value.is_empty() or value.length() > 32:
		ConfigStyles.mark_line_edit_error(ssid_edit, true)
		_set_status("SSID должен содержать от 1 до 32 символов.", true)
		return false

	if not device.set_interface_wireless_settings(
		network_interface.interface_name,
		{"ssid": value}
	):
		ConfigStyles.mark_line_edit_error(ssid_edit, true)
		_set_status("Не удалось сохранить SSID.", true)
		return false

	ConfigStyles.mark_line_edit_error(ssid_edit, false)
	ssid_edit.text = value
	network_interface = device.get_interface(network_interface.interface_name)
	_set_status("Параметры беспроводной сети сохранены. Шифрование не моделируется.", false, true)
	return true


func _commit_coverage() -> bool:
	if device == null or network_interface == null:
		return false

	var text := coverage_edit.text.strip_edges().replace(",", ".")
	if not text.is_valid_float():
		ConfigStyles.mark_line_edit_error(coverage_edit, true)
		_set_status("Зона покрытия должна быть числом от 0 до 10000 метров.", true)
		return false

	var value := text.to_float()
	if value < 0.0 or value > 10000.0:
		ConfigStyles.mark_line_edit_error(coverage_edit, true)
		_set_status("Зона покрытия должна быть числом от 0 до 10000 метров.", true)
		return false

	if not device.set_interface_wireless_settings(
		network_interface.interface_name,
		{"coverage_range_m": value}
	):
		ConfigStyles.mark_line_edit_error(coverage_edit, true)
		_set_status("Не удалось сохранить зону покрытия.", true)
		return false

	ConfigStyles.mark_line_edit_error(coverage_edit, false)
	coverage_edit.text = "%.2f" % value
	network_interface = device.get_interface(network_interface.interface_name)
	_set_status("Зона покрытия сохранена.", false, true)
	return true


func _commit_credentials() -> bool:
	if device == null or network_interface == null:
		return false

	var result := device.set_interface_wireless_settings(
		network_interface.interface_name,
		{
			"wep_key": wep_key_edit.text,
			"psk_passphrase": psk_edit.text,
			"user_id": user_id_edit.text,
			"password": password_edit.text,
		}
	)
	if not result:
		_set_status("Не удалось сохранить параметры беспроводной сети.", true)
		return false

	network_interface = device.get_interface(network_interface.interface_name)
	_set_status("Параметры беспроводной сети сохранены. Шифрование не моделируется.", false, true)
	return true


func _update_auth_field_states() -> void:
	if network_interface == null:
		return

	var mode := network_interface.wireless.authentication_mode
	ConfigStyles.set_line_edit_editable(wep_key_edit, mode == WirelessSettings.AUTH_WEP)
	ConfigStyles.set_line_edit_editable(
		psk_edit,
		mode == WirelessSettings.AUTH_WPA_PSK
			or mode == WirelessSettings.AUTH_WPA2_PSK
	)
	# У точки доступа нет режимов WPA/WPA2 Enterprise и 802.1X,
	# поэтому поля User ID и Password всегда недоступны.
	ConfigStyles.set_line_edit_editable(user_id_edit, false)
	ConfigStyles.set_line_edit_editable(password_edit, false)
	encryption_option.disabled = mode == WirelessSettings.AUTH_DISABLED


func _default_encryption_for(mode: String) -> String:
	match mode:
		WirelessSettings.AUTH_DISABLED:
			return WirelessSettings.ENCRYPTION_DISABLED
		WirelessSettings.AUTH_WEP:
			return WirelessSettings.ENCRYPTION_WEP
		WirelessSettings.AUTH_WPA_PSK:
			return WirelessSettings.ENCRYPTION_TKIP
		_:
			return WirelessSettings.ENCRYPTION_AES


func _select_channel(channel: int) -> void:
	var index := WirelessSettings.FIVE_GHZ_CHANNELS.find(channel)
	if index < 0:
		index = WirelessSettings.FIVE_GHZ_CHANNELS.find(112)
	channel_option.select(maxi(index, 0))


func _select_option(option: OptionButton, values: Array[String], value: String) -> void:
	var index := values.find(value)
	option.select(index if index >= 0 else 0)


func _option_value(option: OptionButton, values: Array[String]) -> String:
	var index := option.selected
	if index < 0 or index >= values.size():
		return values[0] if not values.is_empty() else ""
	return values[index]


func _encryption_label(value: String) -> String:
	match value:
		WirelessSettings.ENCRYPTION_DISABLED:
			return "Disabled"
		WirelessSettings.ENCRYPTION_WEP:
			return "WEP"
		WirelessSettings.ENCRYPTION_TKIP:
			return "TKIP"
		WirelessSettings.ENCRYPTION_AES:
			return "AES"
	return value


func _get_auth_edits() -> Array[LineEdit]:
	return [
		wep_key_edit,
		psk_edit,
		user_id_edit,
		password_edit,
	]


func _set_status(text: String, is_error: bool = false, success: bool = false) -> void:
	ConfigStyles.set_status(status_label, text, is_error, success)


func _apply_styles() -> void:
	add_theme_stylebox_override("panel", ConfigStyles.content_panel())
	header_panel.add_theme_stylebox_override("panel", ConfigStyles.header_panel())
	auth_panel.add_theme_stylebox_override("panel", ConfigStyles.section_panel())

	ConfigStyles.apply_bold_label(header_label, 16)
	ConfigStyles.apply_status_label(status_label)
	ConfigStyles.apply_bold_label(
		$Root/VBox/BodyScroll/Body/AuthPanel/AuthMargin/AuthVBox/AuthTitle,
		13
	)

	for label in _get_labels():
		ConfigStyles.apply_label(label)

	ConfigStyles.apply_plain_checkbox(port_status_check)
	for checkbox in _auth_buttons.values():
		ConfigStyles.apply_checkbox(checkbox)

	for edit in [ssid_edit, coverage_edit]:
		ConfigStyles.apply_line_edit(edit)
	for edit in _get_auth_edits():
		ConfigStyles.apply_line_edit(edit)

	ConfigStyles.apply_option_button(channel_option)
	ConfigStyles.apply_option_button(encryption_option)


func _get_labels() -> Array[Label]:
	return [
		$Root/VBox/BodyScroll/Body/TopGrid/PortStatusLabel,
		$Root/VBox/BodyScroll/Body/TopGrid/SsidLabel,
		$Root/VBox/BodyScroll/Body/TopGrid/ChannelLabel,
		$Root/VBox/BodyScroll/Body/TopGrid/CoverageLabel,
		$Root/VBox/BodyScroll/Body/AuthPanel/AuthMargin/AuthVBox/AuthContent/AuthFields/WepKeyLabel,
		$Root/VBox/BodyScroll/Body/AuthPanel/AuthMargin/AuthVBox/AuthContent/AuthFields/PskLabel,
		$Root/VBox/BodyScroll/Body/AuthPanel/AuthMargin/AuthVBox/AuthContent/AuthFields/UserIdLabel,
		$Root/VBox/BodyScroll/Body/AuthPanel/AuthMargin/AuthVBox/AuthContent/AuthFields/PasswordLabel,
		$Root/VBox/BodyScroll/Body/AuthPanel/AuthMargin/AuthVBox/EncryptionRow/EncryptionLabel,
	]
