extends RefCounted
class_name WirelessSettings

const AUTH_DISABLED := "disabled"
const AUTH_WEP := "wep"
const AUTH_WPA_PSK := "wpa_psk"
const AUTH_WPA2_PSK := "wpa2_psk"
const AUTH_WPA := "wpa"
const AUTH_WPA2 := "wpa2"
const AUTH_8021X := "8021x"

const ENCRYPTION_DISABLED := "disabled"
const ENCRYPTION_WEP := "wep"
const ENCRYPTION_TKIP := "tkip"
const ENCRYPTION_AES := "aes"

const EAP_MD5 := "md5"
const EAP_PEAP := "peap"
const EAP_TLS := "tls"

const AUTH_MODES: Array[String] = [
	AUTH_DISABLED,
	AUTH_WEP,
	AUTH_WPA_PSK,
	AUTH_WPA2_PSK,
	AUTH_WPA,
	AUTH_WPA2,
	AUTH_8021X,
]

const ENCRYPTION_TYPES: Array[String] = [
	ENCRYPTION_DISABLED,
	ENCRYPTION_WEP,
	ENCRYPTION_TKIP,
	ENCRYPTION_AES,
]

const EAP_METHODS: Array[String] = [
	EAP_MD5,
	EAP_PEAP,
	EAP_TLS,
]

var ssid: String = "Default"
var authentication_mode: String = AUTH_DISABLED
var wep_key: String = ""
var psk_passphrase: String = ""
var user_id: String = ""
var password: String = ""
var eap_method: String = EAP_MD5
var eap_user_name: String = ""
var eap_password: String = ""
var encryption_type: String = ENCRYPTION_DISABLED


static func is_valid_auth_mode(mode: String) -> bool:
	return AUTH_MODES.has(mode)


static func is_valid_encryption_type(value: String) -> bool:
	return ENCRYPTION_TYPES.has(value)


static func is_valid_eap_method(value: String) -> bool:
	return EAP_METHODS.has(value)
