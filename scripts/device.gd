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
		if device_type == "Switch" and not _suppress_power_boot:
			if value:
				_start_switch_boot()
			else:
				_cancel_switch_boot()
		power_changed.emit(is_powered_on)

# Физически установленный в слот модуль ПК.
@export var installed_module: String = ""

# Физически установленные модули коммутатора: { slot_index: module_name }.
var installed_switch_modules: Dictionary = {}

# Модуль, который реально работает. Обновляется только при включении ПК.
var active_module: String = ""

# Отображаемое имя и отдельное сетевое имя устройства.
@export var hostname: String = "Switch":
	set(value):
		if hostname == value:
			return
		hostname = value
		hostname_changed.emit(hostname)

# Заглушка, пока настоящее серийное число не задано уровнем.
@export var serial_number: String = "Serial Number"

# Журнал коммутатора общий для CLI и Equivalent IOS Commands.
var console: SwitchConsole = SwitchConsole.new()
var is_booting: bool = false

var _switch_defaults_initialized: bool = false
var _boot_generation: int = 0
var _suppress_power_boot: bool = false

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
		if value == "Switch":
			_ensure_switch_defaults()
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
signal hostname_changed(new_hostname: String)
signal boot_started
signal boot_finished
signal boot_state_changed(is_booting: bool)
signal configuration_changed
signal interfaces_changed


func _ready() -> void:
	if device_type == "Switch":
		_ensure_switch_defaults()
	_sync_interfaces_from_module()
	_ensure_mac_addresses()
	if name_label:
		name_label.text = device_name
	_apply_texture_by_type()
	_fit_sprite_to_collision()
	$ClickArea.input_event.connect(_on_click_area_input_event)
	$ClickArea.mouse_entered.connect(_on_mouse_entered)
	$ClickArea.mouse_exited.connect(_on_mouse_exited)


func _ensure_switch_defaults() -> void:
	if _switch_defaults_initialized:
		return
	_switch_defaults_initialized = true
	if installed_switch_modules.is_empty():
		installed_switch_modules = ModuleCatalog.get_default_switch_modules()

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

func get_installed_module(slot_index: int = -1) -> String:
	if device_type == "Switch":
		return str(installed_switch_modules.get(slot_index, ""))
	if slot_index <= 0:
		return installed_module
	return ""


func get_installed_switch_modules() -> Dictionary:
	return installed_switch_modules.duplicate(true)


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
	_log_console("%s is %s" % [interface_name, "up" if enabled else "down"])
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
	if mode != DeviceInterface.BANDWIDTH_10MBPS \
			and mode != DeviceInterface.BANDWIDTH_100MBPS \
			and mode != DeviceInterface.BANDWIDTH_1000MBPS \
			and mode != DeviceInterface.BANDWIDTH_AUTO:
		return
	var iface := get_interface(interface_name)
	if iface == null:
		return
	if iface.bandwidth_mode == mode and iface.bandwidth_mbps == mbps:
		return
	iface.bandwidth_mode = mode
	if mode != DeviceInterface.BANDWIDTH_AUTO:
		iface.bandwidth_mbps = maxi(mbps, 1)
	_log_console("%s bandwidth set to %s" % [interface_name, mode])
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
	_log_console("%s duplex set to %s" % [interface_name, mode])
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
		for spec in specs:
			spec["source_module"] = installed_module
			spec["slot_index"] = -1
	elif device_type == "Switch":
		var slots: Array = installed_switch_modules.keys()
		slots.sort()
		for slot_value in slots:
			var slot_index := int(slot_value)
			var module_name := str(installed_switch_modules[slot_value])
			var spec := ModuleCatalog.get_switch_interface_spec(module_name, slot_index)
			if not spec.is_empty():
				specs.append(spec)
	else:
		specs = ModuleCatalog.get_builtin_interfaces(device_type)
		for spec in specs:
			spec["source_module"] = ""
			spec["slot_index"] = -1

	var new_signature: Array[String] = []
	for spec in specs:
		new_signature.append("%s|%s|%s|%d" % [
			str(spec.get("name", "")),
			str(spec.get("kind", "ethernet")),
			str(spec.get("source_module", "")),
			int(spec.get("slot_index", -1)),
		])

	var current_signature: Array[String] = []
	for iface in interfaces:
		current_signature.append("%s|%s|%s|%d" % [
			iface.interface_name,
			iface.interface_kind,
			iface.source_module,
			iface.slot_index,
		])

	if new_signature == current_signature:
		return

	var old_by_name: Dictionary = {}
	var old_primary: DeviceInterface = null
	for iface in interfaces:
		old_by_name[iface.interface_name] = iface
		if old_primary == null:
			old_primary = iface

	# Совместимость со старым поведением ПК: настройки первого интерфейса
	# переносятся на новый первый интерфейс при смене модуля.
	if old_primary != null:
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
		var source_module := str(spec.get("source_module", ""))
		var slot_index := int(spec.get("slot_index", -1))
		var old_interface = old_by_name.get(interface_name)
		var mac_address := ""
		if old_interface != null:
			mac_address = old_interface.mac_address
		if mac_address.is_empty():
			mac_address = _generate_mac(slot_index if slot_index >= 0 else index)

		var network_interface := DeviceInterface.new(interface_name, mac_address)
		network_interface.interface_kind = interface_kind
		network_interface.source_module = source_module
		network_interface.slot_index = slot_index
		network_interface.bandwidth_mbps = int(spec.get("bandwidth_mbps", 10))
		network_interface.bandwidth_kbps = int(spec.get("bandwidth_kbps", 0))
		var bandwidth_mode := str(spec.get("bandwidth_mode", DeviceInterface.BANDWIDTH_AUTO))
		if bandwidth_mode == DeviceInterface.BANDWIDTH_10MBPS \
				or bandwidth_mode == DeviceInterface.BANDWIDTH_100MBPS \
				or bandwidth_mode == DeviceInterface.BANDWIDTH_1000MBPS \
				or bandwidth_mode == DeviceInterface.BANDWIDTH_AUTO:
			network_interface.bandwidth_mode = bandwidth_mode
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

		if old_interface != null:
			_copy_interface_state(old_interface, network_interface)
		elif index == 0 and device_type == "PC":
			# ПК сохраняет IP первого интерфейса при смене/переустановке модуля.
			network_interface.ipv4_address = _pending_ipv4
			network_interface.subnet_mask = _pending_mask
			network_interface.ipv6_address = _pending_ipv6
			network_interface.ipv6_prefix = _pending_ipv6_prefix

		interfaces.append(network_interface)
		index += 1

	_ensure_mac_addresses()
	interfaces_changed.emit()


func _copy_interface_state(source: DeviceInterface, target: DeviceInterface) -> void:
	target.enabled = source.enabled
	target.bandwidth_mode = source.bandwidth_mode
	target.bandwidth_mbps = source.bandwidth_mbps
	target.bandwidth_kbps = source.bandwidth_kbps
	target.duplex_mode = source.duplex_mode
	target.ipv4_mode = source.ipv4_mode
	target.ipv4_address = source.ipv4_address
	target.subnet_mask = source.subnet_mask
	target.ipv6_mode = source.ipv6_mode
	target.ipv6_address = source.ipv6_address
	target.ipv6_prefix = source.ipv6_prefix
	target.wireless.ssid = source.wireless.ssid
	target.wireless.authentication_mode = source.wireless.authentication_mode
	target.wireless.wep_key = source.wireless.wep_key
	target.wireless.psk_passphrase = source.wireless.psk_passphrase
	target.wireless.user_id = source.wireless.user_id
	target.wireless.password = source.wireless.password
	target.wireless.eap_method = source.wireless.eap_method
	target.wireless.eap_user_name = source.wireless.eap_user_name
	target.wireless.eap_password = source.wireless.eap_password
	target.wireless.encryption_type = source.wireless.encryption_type


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


# Начальное состояние из уровня: без запуска загрузки и без записи
# «Power off.» в консоль. Так коммутатор может стартовать выключенным.
func set_initial_power(on: bool) -> void:
	if is_powered_on == on:
		return
	_suppress_power_boot = true
	is_powered_on = on
	_suppress_power_boot = false


func can_modify_modules() -> bool:
	return not is_powered_on


# Поставить модуль в единственный слот ПК.
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


# Извлечь модуль из единственного слота ПК.
func remove_module() -> Dictionary:
	if is_powered_on:
		return {"ok": false, "reason": "power_on_remove"}
	if installed_module == "":
		return {"ok": false, "reason": "empty"}

	installed_module = ""
	_sync_interfaces_from_module()
	_refresh_active_module()
	return {"ok": true, "reason": ""}


# Поставить модуль в конкретный слот коммутатора.
func install_module_in_slot(module_name: String, slot_index: int) -> Dictionary:
	if device_type != "Switch":
		return install_module(module_name)
	if is_powered_on:
		return {"ok": false, "reason": "power_on_add"}
	if slot_index < 0 or slot_index >= ModuleCatalog.SWITCH_SLOT_COUNT:
		return {"ok": false, "reason": "invalid_slot"}
	if str(installed_switch_modules.get(slot_index, "")) != "":
		return {"ok": false, "reason": "occupied"}
	if not ModuleCatalog.has_switch_module(module_name):
		return {"ok": false, "reason": "unknown"}

	installed_switch_modules[slot_index] = module_name
	_sync_interfaces_from_module()
	return {"ok": true, "reason": ""}


# Извлечь модуль из конкретного слота коммутатора.
func remove_module_from_slot(slot_index: int) -> Dictionary:
	if device_type != "Switch":
		return remove_module()
	if is_powered_on:
		return {"ok": false, "reason": "power_on_remove"}
	if slot_index < 0 or slot_index >= ModuleCatalog.SWITCH_SLOT_COUNT:
		return {"ok": false, "reason": "invalid_slot"}
	if str(installed_switch_modules.get(slot_index, "")) == "":
		return {"ok": false, "reason": "empty"}

	installed_switch_modules.erase(slot_index)
	_sync_interfaces_from_module()
	return {"ok": true, "reason": ""}


# Установка предустановленного модуля из JSON уровня (без проверок питания).
func set_initial_module(module_name: String) -> void:
	if not ModuleCatalog.has_module(module_name):
		push_warning("Неизвестный модуль в уровне: " + module_name)
		return
	installed_module = module_name
	_sync_interfaces_from_module()
	_refresh_active_module()


func set_initial_switch_module(module_name: String, slot_index: int) -> void:
	if not ModuleCatalog.has_switch_module(module_name):
		push_warning("Неизвестный модуль коммутатора в уровне: " + module_name)
		return
	if slot_index < 0 or slot_index >= ModuleCatalog.SWITCH_SLOT_COUNT:
		push_warning("Некорректный слот модуля коммутатора: " + str(slot_index))
		return
	installed_switch_modules[slot_index] = module_name
	_sync_interfaces_from_module()


func set_hostname(value: String) -> bool:
	var trimmed := value.strip_edges()
	if trimmed.is_empty() or trimmed.length() > 32:
		return false
	if hostname == trimmed:
		return true
	hostname = trimmed
	_log_console("Hostname set to %s" % hostname)
	return true


func get_console_text() -> String:
	var text := console.get_text()
	if device_type == "Switch" and is_powered_on and not is_booting:
		var prompt := "%s>" % hostname
		if text.is_empty():
			return prompt
		return text + "\n" + prompt
	return text


func _log_console(line: String) -> void:
	if device_type == "Switch" and is_powered_on and not is_booting:
		console.append_line(line)


func _start_switch_boot() -> void:
	if device_type != "Switch" or not is_inside_tree():
		return

	_boot_generation += 1
	var generation := _boot_generation
	is_booting = true
	console.clear()
	boot_state_changed.emit(true)
	boot_started.emit()
	_run_switch_boot(generation)


func _run_switch_boot(generation: int) -> void:
	var started_at := Time.get_ticks_msec()
	console.append_line("Boot Sector Filesystem (bs:) installed, fsid: 3")
	console.append_line("Parameter Block Filesystem (pb:) installed, fsid: 4")
	console.append_line("")

	if not await _boot_wait(0.6, generation):
		return

	console.append_line('Loading "flash:/pt3000-i6q4l2-mz.121-22.EA4.bin"...')
	console.append_line("")

	# Полоса загрузки: символы # дописываются в одну строку.
	for _index in range(74):
		if not await _boot_wait(0.04, generation):
			return
		console.append_text("#")
	console.append_text(" [OK]")

	if not await _boot_wait(0.3, generation):
		return

	var rights_lines: Array[String] = [
		"              Restricted Rights Legend",
		"",
		"Use, duplication, or disclosure by the Government is",
		"subject to restrictions as set forth in subparagraph",
		"(c) of the Commercial Computer Software - Restricted",
		"Rights clause at FAR sec. 52.227-19 and subparagraph",
		"(c) (1) (ii) of the Rights in Technical Data and Computer",
		"Software clause at DFARS sec. 252.227-7013.",
		"",
		"           cisco Systems, Inc.",
		"           170 West Tasman Drive",
		"           San Jose, California 95134-1706",
		"",
		"",
	]
	for line in rights_lines:
		if not await _boot_wait(0.05, generation):
			return
		console.append_line(line)

	if not await _boot_wait(0.3, generation):
		return

	var ios_lines: Array[String] = [
		"Cisco Internetwork Operating System Software",
		"IOS (tm) PT3000 Software (PT3000-I6Q4L2-M), Version 12.1(22)EA4, RELEASE SOFTWARE (fc1)",
		"Copyright (c) 1986-2006 by cisco Systems, Inc.",
		"Compiled Fri 12-May-06 17:19 by pt_team",
		"",
	]
	for line in ios_lines:
		if not await _boot_wait(0.08, generation):
			return
		console.append_line(line)

	if not await _boot_wait(0.3, generation):
		return

	var base_mac := "00D0.58DD.11D7"
	var primary := get_primary_interface()
	if primary != null and not primary.get_mac_cisco().is_empty():
		base_mac = primary.get_mac_cisco()

	var hardware_lines: Array[String] = [
		"Cisco WS-CSwitch-PT (RC32300) processor (revision C0) with 21039K bytes of memory.",
		"Processor board ID FHK0610Z0WC",
		"Running Standard Image",
		"%d Ethernet/IEEE 802.3 interface(s)" % interfaces.size(),
		"",
		"63488K bytes of flash-simulated non-volatile configuration memory.",
		"Base ethernet MAC Address: %s" % base_mac,
		"Motherboard assembly number: 73-5781-09",
		"Power supply part number: 34-0965-01",
		"Motherboard serial number: FOC061004SZ",
		"Power supply serial number: DAB0609127D",
		"Model revision number: C0",
		"Motherboard revision number: A0",
		"Model number: WS-CSwitch-PT",
		"System serial number: %s" % serial_number,
		"",
	]
	for line in hardware_lines:
		if not await _boot_wait(0.05, generation):
			return
		console.append_line(line)

	if not await _boot_wait(0.3, generation):
		return

	console.append_line("Initializing switch modules...")
	var slots: Array = installed_switch_modules.keys()
	slots.sort()
	for slot_value in slots:
		if not await _boot_wait(0.1, generation):
			return
		var slot_index := int(slot_value)
		var module_name := str(installed_switch_modules[slot_value])
		console.append_line("Slot %d: %s ... OK" % [slot_index, module_name])
	if slots.is_empty():
		console.append_line("No switch modules installed.")

	if not await _boot_wait(0.3, generation):
		return

	console.append_line("Bringing up interfaces...")
	for iface in interfaces:
		if not await _boot_wait(0.1, generation):
			return
		if iface.enabled:
			console.append_line("%s ... up" % iface.interface_name)

	# Загрузка всегда занимает 10 секунд от момента включения.
	var elapsed := float(Time.get_ticks_msec() - started_at) / 1000.0
	var remaining := maxf(10.0 - elapsed, 0.0)
	if remaining > 0.0:
		if not await _boot_wait(remaining, generation):
			return

	console.append_line("")
	console.append_line("Press RETURN to get started!")
	is_booting = false
	boot_state_changed.emit(false)
	boot_finished.emit()


func _boot_wait(seconds: float, generation: int) -> bool:
	if not _boot_is_current(generation):
		return false
	await get_tree().create_timer(seconds).timeout
	return _boot_is_current(generation)


func _boot_is_current(generation: int) -> bool:
	return is_inside_tree() and is_powered_on and is_booting and generation == _boot_generation


func _cancel_switch_boot() -> void:
	_boot_generation += 1
	if is_booting:
		is_booting = false
		boot_state_changed.emit(false)
	console.append_line("Power off.")


func _refresh_active_module() -> void:
	if device_type == "Switch":
		active_module = ""
		return
	active_module = installed_module if is_powered_on else ""
	if is_powered_on and active_module != "":
		modules_applied.emit(self, active_module)
