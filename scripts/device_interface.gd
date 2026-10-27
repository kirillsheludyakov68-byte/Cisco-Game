extends RefCounted
class_name DeviceInterface

const BANDWIDTH_10MBPS := "10mbps"
const BANDWIDTH_AUTO := "auto"

const DUPLEX_HALF := "half"
const DUPLEX_FULL := "full"
const DUPLEX_AUTO := "auto"

var interface_name: String = "FastEthernet0"
var interface_kind: String = "ethernet"
var source_module: String = ""
var enabled: bool = true

var bandwidth_mode: String = BANDWIDTH_AUTO
var bandwidth_mbps: int = 10
var bandwidth_kbps: int = 0
var duplex_mode: String = DUPLEX_AUTO

var mac_address: String = ""
var ipv4_mode: String = NetworkSettings.IPV4_STATIC
var ipv4_address: String = ""
var subnet_mask: String = "255.255.255.0"
var ipv6_mode: String = NetworkSettings.IPV6_STATIC
var ipv6_address: String = ""
var ipv6_prefix: int = 64
var link_local_ipv6: String = ""
var wireless: WirelessSettings = WirelessSettings.new()


func _init(name_value: String = "FastEthernet0", mac: String = "") -> void:
	interface_name = name_value
	mac_address = mac
	refresh_link_local()


func get_mac_cisco() -> String:
	var octets := _get_mac_octets()
	if octets.is_empty():
		return ""
	return "%02X%02X.%02X%02X.%02X%02X" % [
		octets[0], octets[1], octets[2], octets[3], octets[4], octets[5]
	]


func set_mac_address(value: String) -> bool:
	var previous := mac_address
	mac_address = value.strip_edges()
	if _get_mac_octets().is_empty():
		mac_address = previous
		refresh_link_local()
		return false
	refresh_link_local()
	return true


func refresh_link_local() -> void:
	link_local_ipv6 = _build_link_local()


func _build_link_local() -> String:
	var octets := _get_mac_octets()
	if octets.is_empty():
		return ""

	# EUI-64: инвертируем U/L-бит и вставляем FF:FE в середину MAC.
	var eui := [
		octets[0] ^ 0x02,
		octets[1],
		octets[2],
		0xFF,
		0xFE,
		octets[3],
		octets[4],
		octets[5],
	]
	var groups: Array[String] = []
	for index in range(0, 8, 2):
		var word := (int(eui[index]) << 8) | int(eui[index + 1])
		groups.append("%X" % word)
	return "FE80::" + ":".join(groups)


func _get_mac_octets() -> Array[int]:
	var cleaned := mac_address.strip_edges().replace(".", "").replace(":", "").replace("-", "")
	if cleaned.length() != 12:
		return []

	var octets: Array[int] = []
	for index in range(0, 12, 2):
		var part := cleaned.substr(index, 2)
		if not part.is_valid_hex_number():
			return []
		octets.append(part.hex_to_int())
	return octets
