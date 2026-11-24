extends PanelContainer
class_name WMP300NConfigPage

@onready var header_panel: PanelContainer = $Root/VBox/HeaderPanel
@onready var header_label: Label = $Root/VBox/HeaderPanel/HeaderLabel
@onready var status_label: Label = $Root/VBox/StatusLabel

@onready var port_status_check: CheckBox = $Root/VBox/BodyScroll/Body/TopGrid/PortStatusCheck
@onready var bandwidth_value: Label = $Root/VBox/BodyScroll/Body/TopGrid/BandwidthValue
@onready var mac_edit: LineEdit = $Root/VBox/BodyScroll/Body/TopGrid/MacEdit
@onready var ssid_edit: LineEdit = $Root/VBox/BodyScroll/Body/TopGrid/SsidEdit

@onready var auth_panel: PanelContainer = $Root/VBox/BodyScroll/Body/AuthPanel
@onready var auth_disabled: CheckBox = $Root/VBox/BodyScroll/Body/AuthPanel/AuthMargin/AuthVBox/AuthContent/AuthLeft/AuthOptions/AuthDisabled
@onready var auth_wep: CheckBox = $Root/VBox/BodyScroll/Body/AuthPanel/AuthMargin/AuthVBox/AuthContent/AuthLeft/AuthOptions/AuthWep
@onready var auth_wpa_psk: CheckBox = $Root/VBox/BodyScroll/Body/AuthPanel/AuthMargin/AuthVBox/AuthContent/AuthLeft/AuthOptions/AuthWpaPsk
@onready var auth_wpa2_psk: CheckBox = $Root/VBox/BodyScroll/Body/AuthPanel/AuthMargin/AuthVBox/AuthContent/AuthLeft/AuthOptions/AuthWpa2Psk
@onready var auth_wpa: CheckBox = $Root/VBox/BodyScroll/Body/AuthPanel/AuthMargin/AuthVBox/AuthContent/AuthLeft/AuthOptions/AuthWpa
@onready var auth_wpa2: CheckBox = $Root/VBox/BodyScroll/Body/AuthPanel/AuthMargin/AuthVBox/AuthContent/AuthLeft/AuthOptions/AuthWpa2
@onready var auth_8021x: CheckBox = $Root/VBox/BodyScroll/Body/AuthPanel/AuthMargin/AuthVBox/AuthContent/AuthLeft/AuthOptions/Auth8021x
@onready var method_option: OptionButton = $Root/VBox/BodyScroll/Body/AuthPanel/AuthMargin/AuthVBox/AuthContent/AuthLeft/MethodRow/MethodOption

@onready var wep_key_edit: LineEdit = $Root/VBox/BodyScroll/Body/AuthPanel/AuthMargin/AuthVBox/AuthContent/AuthFields/WepKeyEdit
@onready var psk_edit: LineEdit = $Root/VBox/BodyScroll/Body/AuthPanel/AuthMargin/AuthVBox/AuthContent/AuthFields/PskEdit
@onready var user_id_edit: LineEdit = $Root/VBox/BodyScroll/Body/AuthPanel/AuthMargin/AuthVBox/AuthContent/AuthFields/UserIdEdit
@onready var password_edit: LineEdit = $Root/VBox/BodyScroll/Body/AuthPanel/AuthMargin/AuthVBox/AuthContent/AuthFields/PasswordEdit
@onready var eap_user_edit: LineEdit = $Root/VBox/BodyScroll/Body/AuthPanel/AuthMargin/AuthVBox/AuthContent/AuthFields/EapUserEdit
@onready var eap_password_edit: LineEdit = $Root/VBox/BodyScroll/Body/AuthPanel/AuthMargin/AuthVBox/AuthContent/AuthFields/EapPasswordEdit
@onready var encryption_option: OptionButton = $Root/VBox/BodyScroll/Body/AuthPanel/AuthMargin/AuthVBox/EncryptionRow/EncryptionOption

@onready var ip_config: InterfaceIpConfigBlock = $Root/VBox/BodyScroll/Body/IpConfig

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
	ip_config.setup(dev, iface)
	refresh()


func refresh() -> void:
	_updating = true
	ConfigStyles.mark_line_edit_error(ssid_edit, false)
	_set_status("")

	if network_interface == null:
		header_label.text = "Интерфейс"
		port_status_check.disabled = true
		port_status_check.button_pressed = false
		bandwidth_value.text = ""
		mac_edit.text = ""
		ssid_edit.text = ""
		ConfigStyles.set_line_edit_editable(ssid_edit, false)
		for checkbox in _auth_buttons.values():
			checkbox.disabled = true
			checkbox.button_pressed = false
		for edit in _get_auth_edits():
			edit.text = ""
			ConfigStyles.set_line_edit_editable(edit, false)
		method_option.disabled = true
		encryption_option.disabled = true
		_updating = false
		return

	header_label.text = network_interface.interface_name
	port_status_check.disabled = false
	port_status_check.button_pressed = network_interface.enabled
	bandwidth_value.text = "%d Mbps" % network_interface.bandwidth_mbps
	mac_edit.text = network_interface.get_mac_cisco()
	ssid_edit.editable = true
	ssid_edit.text = network_interface.wireless.ssid
	ConfigStyles.set_line_edit_editable(ssid_edit, true)

	for mode in _auth_buttons:
		var checkbox: CheckBox = _auth_buttons[mode]
		checkbox.disabled = false
		checkbox.button_pressed = network_interface.wireless.authentication_mode == mode

	wep_key_edit.text = network_interface.wireless.wep_key
	psk_edit.text = network_interface.wireless.psk_passphrase
	user_id_edit.text = network_interface.wireless.user_id
	password_edit.text = network_interface.wireless.password
	eap_user_edit.text = network_interface.wireless.eap_user_name
	eap_password_edit.text = network_interface.wireless.eap_password

	_select_option(method_option, WirelessSettings.EAP_METHODS, network_interface.wireless.eap_method)
	_select_option(encryption_option, WirelessSettings.ENCRYPTION_TYPES, network_interface.wireless.encryption_type)
	_update_auth_field_states()
	_updating = false


func commit_pending() -> void:
	if device == null or network_interface == null:
		return
	_commit_ssid()
	_commit_credentials()
	ip_config.commit_pending()


func _setup_auth_group() -> void:
	_auth_group = ButtonGroup.new()
	_auth_group.allow_unpress = false
	_auth_buttons = {
		WirelessSettings.AUTH_DISABLED: auth_disabled,
		WirelessSettings.AUTH_WEP: auth_wep,
		WirelessSettings.AUTH_WPA_PSK: auth_wpa_psk,
		WirelessSettings.AUTH_WPA2_PSK: auth_wpa2_psk,
		WirelessSettings.AUTH_WPA: auth_wpa,
		WirelessSettings.AUTH_WPA2: auth_wpa2,
		WirelessSettings.AUTH_8021X: auth_8021x,
	}
	for checkbox in _auth_buttons.values():
		checkbox.button_group = _auth_group


func _setup_options() -> void:
	method_option.clear()
	for value in WirelessSettings.EAP_METHODS:
		method_option.add_item(_eap_label(value))

	encryption_option.clear()
	for value in WirelessSettings.ENCRYPTION_TYPES:
		encryption_option.add_item(_encryption_label(value))


func _connect_signals() -> void:
	ip_config.status_changed.connect(_on_ip_status_changed)
	port_status_check.toggled.connect(_on_port_status_toggled)

	ssid_edit.text_submitted.connect(_on_ssid_submitted)
	ssid_edit.focus_exited.connect(_on_ssid_focus_exited)

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
	eap_user_edit.text_submitted.connect(_on_credential_submitted)
	eap_user_edit.focus_exited.connect(_on_credential_focus_exited)
	eap_password_edit.text_submitted.connect(_on_credential_submitted)
	eap_password_edit.focus_exited.connect(_on_credential_focus_exited)

	method_option.item_selected.connect(_on_method_selected)
	encryption_option.item_selected.connect(_on_encryption_selected)


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


func _on_ssid_submitted(_text: String) -> void:
	_commit_ssid()


func _on_ssid_focus_exited() -> void:
	_commit_ssid()


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


func _on_method_selected(_index: int) -> void:
	if _updating or device == null or network_interface == null:
		return
	var value := _option_value(method_option, WirelessSettings.EAP_METHODS)
	if not device.set_interface_wireless_settings(
		network_interface.interface_name,
		{"eap_method": value}
	):
		_set_status("Не удалось сохранить метод 802.1X.", true)
		return
	_set_status("Метод 802.1X сохранён.", false, true)


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
			"eap_user_name": eap_user_edit.text,
			"eap_password": eap_password_edit.text,
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
	var enterprise_auth := (
		mode == WirelessSettings.AUTH_WPA
		or mode == WirelessSettings.AUTH_WPA2
	)
	ConfigStyles.set_line_edit_editable(user_id_edit, enterprise_auth)
	ConfigStyles.set_line_edit_editable(password_edit, enterprise_auth)
	ConfigStyles.set_line_edit_editable(eap_user_edit, mode == WirelessSettings.AUTH_8021X)
	ConfigStyles.set_line_edit_editable(eap_password_edit, mode == WirelessSettings.AUTH_8021X)
	method_option.disabled = mode != WirelessSettings.AUTH_8021X
	encryption_option.disabled = mode == WirelessSettings.AUTH_DISABLED


func _default_encryption_for(mode: String) -> String:
	match mode:
		WirelessSettings.AUTH_DISABLED:
			return WirelessSettings.ENCRYPTION_DISABLED
		WirelessSettings.AUTH_WEP:
			return WirelessSettings.ENCRYPTION_WEP
		WirelessSettings.AUTH_WPA, WirelessSettings.AUTH_WPA_PSK:
			return WirelessSettings.ENCRYPTION_TKIP
		_:
			return WirelessSettings.ENCRYPTION_AES


func _select_option(option: OptionButton, values: Array[String], value: String) -> void:
	var index := values.find(value)
	option.select(index if index >= 0 else 0)


func _option_value(option: OptionButton, values: Array[String]) -> String:
	var index := option.selected
	if index < 0 or index >= values.size():
		return values[0] if not values.is_empty() else ""
	return values[index]


func _eap_label(value: String) -> String:
	match value:
		WirelessSettings.EAP_MD5:
			return "MD5"
		WirelessSettings.EAP_PEAP:
			return "PEAP"
		WirelessSettings.EAP_TLS:
			return "TLS"
	return value


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
		eap_user_edit,
		eap_password_edit,
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
	ConfigStyles.apply_label(bandwidth_value, 13, true)

	ConfigStyles.apply_plain_checkbox(port_status_check)
	for checkbox in _auth_buttons.values():
		ConfigStyles.apply_checkbox(checkbox)

	for edit in [mac_edit, ssid_edit] + _get_auth_edits():
		ConfigStyles.apply_line_edit(edit)

	ConfigStyles.apply_option_button(method_option)
	ConfigStyles.apply_option_button(encryption_option)


func _get_labels() -> Array[Label]:
	return [
		$Root/VBox/BodyScroll/Body/TopGrid/PortStatusLabel,
		$Root/VBox/BodyScroll/Body/TopGrid/BandwidthLabel,
		$Root/VBox/BodyScroll/Body/TopGrid/MacLabel,
		$Root/VBox/BodyScroll/Body/TopGrid/SsidLabel,
		$Root/VBox/BodyScroll/Body/AuthPanel/AuthMargin/AuthVBox/AuthContent/AuthLeft/MethodRow/MethodLabel,
		$Root/VBox/BodyScroll/Body/AuthPanel/AuthMargin/AuthVBox/AuthContent/AuthFields/WepKeyLabel,
		$Root/VBox/BodyScroll/Body/AuthPanel/AuthMargin/AuthVBox/AuthContent/AuthFields/PskLabel,
		$Root/VBox/BodyScroll/Body/AuthPanel/AuthMargin/AuthVBox/AuthContent/AuthFields/UserIdLabel,
		$Root/VBox/BodyScroll/Body/AuthPanel/AuthMargin/AuthVBox/AuthContent/AuthFields/PasswordLabel,
		$Root/VBox/BodyScroll/Body/AuthPanel/AuthMargin/AuthVBox/AuthContent/AuthFields/EapUserLabel,
		$Root/VBox/BodyScroll/Body/AuthPanel/AuthMargin/AuthVBox/AuthContent/AuthFields/EapPasswordLabel,
		$Root/VBox/BodyScroll/Body/AuthPanel/AuthMargin/AuthVBox/EncryptionRow/EncryptionLabel,
	]
