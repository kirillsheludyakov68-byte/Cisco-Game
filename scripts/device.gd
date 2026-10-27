extends Node2D
class_name Device

@onready var sprite: Sprite2D = $Sprite
@onready var name_label: Label = $NameLabel
@onready var collision_shape: CollisionShape2D = $ClickArea/CollisionShape2D

var is_powered_on: bool = true:
	set(value):
		if is_powered_on == value:
			return
		is_powered_on = value
		_refresh_active_module()
		power_changed.emit(is_powered_on)

# Физически установленный в слот модуль
@export var installed_module: String = ""

# Модуль, который реально работает. Обновляется только при включении ПК.
var active_module: String = ""

@export var device_name: String = "PC1":
	set(value):
		if device_name == value:
			return
		device_name = value
		if name_label:
			name_label.text = value
		device_name_changed.emit(value)

@export var device_type: String = "PC":
	set(value):
		var previous_type := device_type
		device_type = value
		if sprite:
			_apply_texture_by_type()
		if collision_shape:
			_fit_sprite_to_collision()
		if previous_type != value and is_inside_tree():
			_sync_interfaces_from_module()

var interfaces: Array[DeviceInterface] = []
var network_settings: NetworkSettings = NetworkSettings.new()

# Резервные значения для данных старого уровня, пока у устройства нет
# подходящего интерфейса (например, ПК без установленного модуля).
var _pending_ipv4: String = ""
var _pending_mask: String = "255.255.255.0"
var _pending_ipv6: String = ""
var _pending_ipv6_prefix: int = 64

# Совместимость со старыми данными уровня: ip/mask принадлежат первому интерфейсу.
var ip_address: String:
	get:
		var iface := get_primary_interface()
		return iface.ipv4_address if iface != null else _pending_ipv4
	set(value):
		var iface := get_primary_interface()
		if iface != null:
			iface.ipv4_address = value
			_pending_ipv4 = value
			configuration_changed.emit()
		else:
			_pending_ipv4 = value

var subnet_mask: String:
	get:
		var iface := get_primary_interface()
		return iface.subnet_mask if iface != null else _pending_mask
	set(value):
		var iface := get_primary_interface()
		if iface != null:
			iface.subnet_mask = value
			_pending_mask = value
			configuration_changed.emit()
		else:
			_pending_mask = value

@export var texture_pc: Texture2D
@export var texture_switch: Texture2D
@export var texture_router: Texture2D
@export var texture_ap: Texture2D

signal device_clicked(device: Device)
signal power_changed(is_on: bool)
signal modules_applied(device: Device, module_name: String)
signal device_name_changed(new_name: String)
signal configuration_changed
signal interfaces_changed


func _ready() -> void:
	_sync_interfaces_from_module()
	_ensure_mac_addresses()
	if name_label:
		name_label.text = device_name
	_apply_texture_by_type()
	_fit_sprite_to_collision()
	$ClickArea.input_event.connect(_on_click_area_input_event)
	$ClickArea.mouse_entered.connect(_on_mouse_entered)
	$ClickArea.mouse_exited.connect(_on_mouse_exited)

func _apply_texture_by_type() -> void:
	if not sprite:
		return
	match device_type:
		"PC":
			if texture_pc: sprite.texture = texture_pc
		"Switch":
			if texture_switch: sprite.texture = texture_switch
		"Router":
			if texture_router: sprite.texture = texture_router
		"AccessPoint":
			if texture_ap: sprite.texture = texture_ap

func _fit_sprite_to_collision() -> void:
	if not sprite or not sprite.texture:
		return
	if not collision_shape or not collision_shape.shape is RectangleShape2D:
		return
	var target_size: Vector2 = collision_shape.shape.size
	var tex_size: Vector2 = sprite.texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var ratio_x := target_size.x / tex_size.x
	var ratio_y := target_size.y / tex_size.y
	var ratio := minf(ratio_x, ratio_y)
	sprite.scale = Vector2(ratio, ratio)

func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Клик по устройству: ", device_name)
		device_clicked.emit(self)

func _on_mouse_entered() -> void:
	if sprite:
		sprite.modulate = Color(1.2, 1.2, 1.2)

func _on_mouse_exited() -> void:
	if sprite:
		sprite.modulate = Color(1, 1, 1)

func highlight(color: Color) -> void:
	if sprite:
		sprite.modulate = color

func reset_highlight() -> void:
	if sprite:
		sprite.modulate = Color(1, 1, 1)


# --- Сетевая конфигурация ---

func get_primary_interface() -> DeviceInterface:
	return interfaces[0] if not interfaces.is_empty() else null


func get_interface(interface_name: String) -> DeviceInterface:
	for iface in interfaces:
		if iface.interface_name == interface_name:
			return iface
	return null


func get_interface_names() -> Array[String]:
	var names: Array[String] = []
	for iface in interfaces:
		names.append(iface.interface_name)
	return names


func is_network_ready() -> bool:
	for iface in interfaces:
		if iface.enabled:
			return true
	return false


func set_interface_enabled(interface_name: String, enabled: bool) -> void:
	var iface := get_interface(interface_name)
	if iface == null or iface.enabled == enabled:
		return
	iface.enabled = enabled
	configuration_changed.emit()


func set_interface_addresses(interface_name: String, ipv4: String, mask: String, ipv6: String) -> void:
	var iface := get_interface(interface_name)
	if iface == null:
		return
	iface.ipv4_address = ipv4
	iface.subnet_mask = mask
	iface.ipv6_address = ipv6
	if iface == get_primary_interface():
		_pending_ipv4 = ipv4
		_pending_mask = mask
		_pending_ipv6 = ipv6
	configuration_changed.emit()


func set_interface_ipv4_config(interface_name: String, ipv4: String, mask: String) -> bool:
	if not ipv4.is_empty() and not NetworkValidation.is_valid_ipv4(ipv4):
		return false
	if not mask.is_empty() and not NetworkValidation.is_valid_subnet_mask(mask):
		return false

	var iface := get_interface(interface_name)
	if iface == null:
		return false
	iface.ipv4_address = ipv4
	iface.subnet_mask = mask
	if iface == get_primary_interface():
		_pending_ipv4 = ipv4
		_pending_mask = mask
	configuration_changed.emit()
	return true


func set_interface_ipv6_config(interface_name: String, ipv6: String, prefix: int = -1) -> bool:
	if not ipv6.is_empty() and not NetworkValidation.is_valid_ipv6(ipv6):
		return false
	if prefix < -1 or prefix > 128:
		return false

	var iface := get_interface(interface_name)
	if iface == null:
		return false
	iface.ipv6_address = ipv6
	if prefix >= 0:
		iface.ipv6_prefix = prefix
	if iface == get_primary_interface():
		_pending_ipv6 = ipv6
		if prefix >= 0:
			_pending_ipv6_prefix = prefix
	configuration_changed.emit()
	return true


func set_interface_ipv4_mode(interface_name: String, mode: String) -> void:
	if mode != NetworkSettings.IPV4_DHCP and mode != NetworkSettings.IPV4_STATIC:
		return
	var iface := get_interface(interface_name)
	if iface == null or iface.ipv4_mode == mode:
		return
	iface.ipv4_mode = mode
	configuration_changed.emit()


func set_interface_ipv6_mode(interface_name: String, mode: String) -> void:
	if mode != NetworkSettings.IPV6_AUTOMATIC and mode != NetworkSettings.IPV6_STATIC:
		return
	var iface := get_interface(interface_name)
	if iface == null or iface.ipv6_mode == mode:
		return
	iface.ipv6_mode = mode
	configuration_changed.emit()


func set_interface_bandwidth(interface_name: String, mode: String, mbps: int = 10) -> void:
	if mode != DeviceInterface.BANDWIDTH_10MBPS and mode != DeviceInterface.BANDWIDTH_AUTO:
		return
	var iface := get_interface(interface_name)
	if iface == null:
		return
	if iface.bandwidth_mode == mode and iface.bandwidth_mbps == mbps:
		return
	iface.bandwidth_mode = mode
	iface.bandwidth_mbps = maxi(mbps, 1)
	configuration_changed.emit()


func set_interface_duplex(interface_name: String, mode: String) -> void:
	if mode != DeviceInterface.DUPLEX_HALF \
			and mode != DeviceInterface.DUPLEX_FULL \
			and mode != DeviceInterface.DUPLEX_AUTO:
		return
	var iface := get_interface(interface_name)
	if iface == null or iface.duplex_mode == mode:
		return
	iface.duplex_mode = mode
	configuration_changed.emit()


func set_interface_wireless_settings(interface_name: String, values: Dictionary) -> bool:
	# Wireless security is configuration state only; no encryption handshake is simulated.
	var iface := get_interface(interface_name)
	if iface == null:
		return false

	var ssid := str(values.get("ssid", iface.wireless.ssid)).strip_edges()
	if ssid.is_empty() or ssid.length() > 32:
		return false

	var auth_mode := str(values.get("authentication_mode", iface.wireless.authentication_mode))
	if not WirelessSettings.is_valid_auth_mode(auth_mode):
		return false

	var encryption_type := str(values.get("encryption_type", iface.wireless.encryption_type))
	if not WirelessSettings.is_valid_encryption_type(encryption_type):
		return false

	var eap_method := str(values.get("eap_method", iface.wireless.eap_method))
	if not WirelessSettings.is_valid_eap_method(eap_method):
		return false

	iface.wireless.ssid = ssid
	iface.wireless.authentication_mode = auth_mode
	iface.wireless.encryption_type = encryption_type
	iface.wireless.eap_method = eap_method
	if values.has("wep_key"):
		iface.wireless.wep_key = str(values["wep_key"])
	if values.has("psk_passphrase"):
		iface.wireless.psk_passphrase = str(values["psk_passphrase"])
	if values.has("user_id"):
		iface.wireless.user_id = str(values["user_id"])
	if values.has("password"):
		iface.wireless.password = str(values["password"])
	if values.has("eap_user_name"):
		iface.wireless.eap_user_name = str(values["eap_user_name"])
	if values.has("eap_password"):
		iface.wireless.eap_password = str(values["eap_password"])

	configuration_changed.emit()
	return true


func set_ipv4_mode(mode: String) -> void:
	if mode != NetworkSettings.IPV4_DHCP and mode != NetworkSettings.IPV4_STATIC:
		return
	if network_settings.ipv4_mode == mode:
		return
	network_settings.ipv4_mode = mode
	configuration_changed.emit()


func set_ipv4_gateway_dns(gateway: String, dns: String) -> void:
	network_settings.gateway_ipv4 = gateway
	network_settings.dns_ipv4 = dns
	configuration_changed.emit()


func set_ipv6_mode(mode: String) -> void:
	if mode != NetworkSettings.IPV6_AUTOMATIC and mode != NetworkSettings.IPV6_STATIC:
		return
	if network_settings.ipv6_mode == mode:
		return
	network_settings.ipv6_mode = mode
	configuration_changed.emit()


func set_ipv6_gateway_dns(gateway: String, dns: String) -> void:
	network_settings.gateway_ipv6 = gateway
	network_settings.dns_ipv6 = dns
	configuration_changed.emit()


func _sync_interfaces_from_module() -> void:
	var specs: Array[Dictionary] = []
	if device_type == "PC":
		specs = ModuleCatalog.get_network_interfaces(installed_module)
	else:
		specs = ModuleCatalog.get_builtin_interfaces(device_type)

	var source_module := installed_module if device_type == "PC" else ""
	var new_signature: Array[String] = []
	for spec in specs:
		new_signature.append("%s|%s|%s" % [
			str(spec.get("name", "")),
			str(spec.get("kind", "ethernet")),
			source_module,
		])

	var current_signature: Array[String] = []
	for iface in interfaces:
		current_signature.append("%s|%s|%s" % [
			iface.interface_name,
			iface.interface_kind,
			iface.source_module,
		])

	if new_signature == current_signature:
		return

	# Через Config можно менять IP, поэтому при смене модуля сохраняем
	# настройки первого интерфейса и переносим их на новый первый интерфейс.
	if not interfaces.is_empty():
		var old_primary := interfaces[0]
		if not old_primary.ipv4_address.is_empty():
			_pending_ipv4 = old_primary.ipv4_address
		_pending_mask = old_primary.subnet_mask
		if not old_primary.ipv6_address.is_empty():
			_pending_ipv6 = old_primary.ipv6_address
		_pending_ipv6_prefix = old_primary.ipv6_prefix

	interfaces.clear()
	var index := 0
	for spec in specs:
		var interface_name := str(spec.get("name", "Interface%d" % index))
		var interface_kind := str(spec.get("kind", "ethernet"))
		var network_interface := DeviceInterface.new(interface_name, _generate_mac(index))
		network_interface.interface_kind = interface_kind
		network_interface.source_module = source_module
		network_interface.bandwidth_mbps = int(spec.get("bandwidth_mbps", 10))
		network_interface.bandwidth_kbps = int(spec.get("bandwidth_kbps", 0))
		var duplex_mode := str(spec.get("duplex_mode", DeviceInterface.DUPLEX_AUTO))
		if duplex_mode == DeviceInterface.DUPLEX_HALF \
				or duplex_mode == DeviceInterface.DUPLEX_FULL \
				or duplex_mode == DeviceInterface.DUPLEX_AUTO:
			network_interface.duplex_mode = duplex_mode
		var ipv6_prefix := int(spec.get("ipv6_prefix", 64))
		network_interface.ipv6_prefix = clampi(ipv6_prefix, 0, 128)
		var ipv4_mode := str(spec.get("ipv4_mode", NetworkSettings.IPV4_STATIC))
		if ipv4_mode == NetworkSettings.IPV4_DHCP or ipv4_mode == NetworkSettings.IPV4_STATIC:
			network_interface.ipv4_mode = ipv4_mode
		var ipv6_mode := str(spec.get("ipv6_mode", NetworkSettings.IPV6_STATIC))
		if ipv6_mode == NetworkSettings.IPV6_AUTOMATIC or ipv6_mode == NetworkSettings.IPV6_STATIC:
			network_interface.ipv6_mode = ipv6_mode
		interfaces.append(network_interface)
		index += 1

	if not interfaces.is_empty():
		var primary := interfaces[0]
		primary.ipv4_address = _pending_ipv4
		primary.subnet_mask = _pending_mask
		primary.ipv6_address = _pending_ipv6
		primary.ipv6_prefix = _pending_ipv6_prefix

	_ensure_mac_addresses()
	interfaces_changed.emit()


func _ensure_mac_addresses() -> void:
	for index in interfaces.size():
		var iface := interfaces[index]
		if iface.mac_address.is_empty():
			iface.mac_address = _generate_mac(index)
		iface.refresh_link_local()


func _generate_mac(index: int) -> String:
	# Локально администрируемый MAC, уникальный в пределах текущей сессии.
	var value: int = get_instance_id() + index * 7919
	return "02:1A:%02X:%02X:%02X:%02X" % [
		(value >> 24) & 0xFF,
		(value >> 16) & 0xFF,
		(value >> 8) & 0xFF,
		value & 0xFF,
	]


# --- Модули ---

func set_power(on: bool) -> void:
	is_powered_on = on


func can_modify_modules() -> bool:
	return not is_powered_on


# Поставить модуль. Работает только при выключенном ПК и пустом слоте.
# Возвращает {ok: bool, reason: String}.
func install_module(module_name: String) -> Dictionary:
	if is_powered_on:
		return {"ok": false, "reason": "power_on_add"}
	if installed_module != "":
		return {"ok": false, "reason": "occupied"}
	if not ModuleCatalog.has_module(module_name):
		return {"ok": false, "reason": "unknown"}

	installed_module = module_name
	_sync_interfaces_from_module()
	_refresh_active_module()
	return {"ok": true, "reason": ""}


# Извлечь модуль. Работает только при выключенном ПК.
func remove_module() -> Dictionary:
	if is_powered_on:
		return {"ok": false, "reason": "power_on_remove"}
	if installed_module == "":
		return {"ok": false, "reason": "empty"}

	installed_module = ""
	_sync_interfaces_from_module()
	_refresh_active_module()
	return {"ok": true, "reason": ""}


# Установка предустановленного модуля из JSON уровня (без проверок питания).
func set_initial_module(module_name: String) -> void:
	if not ModuleCatalog.has_module(module_name):
		push_warning("Неизвестный модуль в уровне: " + module_name)
		return
	installed_module = module_name
	_sync_interfaces_from_module()
	_refresh_active_module()


func _refresh_active_module() -> void:
	active_module = installed_module if is_powered_on else ""
	if is_powered_on and active_module != "":
		modules_applied.emit(self, active_module)
