extends RefCounted
class_name NetworkSettings

const IPV4_DHCP := "dhcp"
const IPV4_STATIC := "static"
const IPV6_AUTOMATIC := "automatic"
const IPV6_STATIC := "static"

var ipv4_mode: String = IPV4_STATIC
var gateway_ipv4: String = ""
var dns_ipv4: String = ""

var ipv6_mode: String = IPV6_STATIC
var gateway_ipv6: String = ""
var dns_ipv6: String = ""
