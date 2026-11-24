extends WebBrowserRequestHandler
class_name SimWebRequestHandler

# HTTP/HTTPS-клиент внутри симулятора. Он не выходит в интернет:
# находит сервер по IP или DNS-имени и отдаёт файл из его File Manager.

var device: Device = null


func fetch(url: String) -> Dictionary:
	if device == null:
		return _error(0, url, "Устройство браузера не задано.")
	if not device.is_operational():
		return _error(0, url, "Устройство выключено.")

	var parsed := _parse_url(url)
	if parsed.is_empty():
		return _error(0, url, "Некорректный адрес. Используйте http://host/file.")

	var scheme := str(parsed.get("scheme", "http"))
	if scheme != "http" and scheme != "https":
		return _error(0, url, "Поддерживаются только http:// и https://.")

	var host := str(parsed.get("host", ""))
	var path := str(parsed.get("path", ""))
	if path.is_empty() or path == "/":
		path = "index.html"
	path = path.trim_prefix("/")

	var resolved := _resolve_host(host)
	if not bool(resolved.get("ok", false)):
		return _error(0, url, str(resolved.get("error", "Не удалось разрешить имя.")))

	var address := str(resolved.get("address", ""))
	var target := _find_server_by_address(address)
	if target == null:
		return _error(404, url, "Сервер %s не найден." % address)

	if target != device:
		var simulator = _get_simulator()
		if simulator != null:
			var ping: Dictionary = simulator.ping_ipv4(device, address)
			if not bool(ping.get("ok", false)):
				return _error(
					0,
					url,
					"Сервер недоступен: " + str(ping.get("reason", "нет маршрута."))
				)

	var enabled := (
		target.https_service_enabled if scheme == "https"
		else target.http_service_enabled
	)
	if not enabled:
		return _error(
			503,
			url,
			"Служба %s на сервере %s выключена." % [scheme.to_upper(), target.device_name]
		)

	var content := target.get_http_file(path)
	if content.is_empty():
		return _error(404, url, "Файл /%s не найден на сервере %s." % [path, target.device_name])

	var title := _extract_title(content)
	if title.is_empty():
		title = path
	return {
		"ok": true,
		"status": 200,
		"url": url,
		"title": title,
		"text": _html_to_text(content),
	}


func _parse_url(url: String) -> Dictionary:
	var value := url.strip_edges()
	var scheme_end := value.find("://")
	if scheme_end <= 0:
		return {}
	var scheme := value.substr(0, scheme_end).to_lower()
	var rest := value.substr(scheme_end + 3)
	var path_start := rest.find("/")
	var authority := rest if path_start < 0 else rest.substr(0, path_start)
	var path := "/" if path_start < 0 else rest.substr(path_start)
	if authority.is_empty():
		return {}
	# Порт в этой модели не используется, но не мешает разбору адреса.
	var port_start := authority.find(":")
	if port_start >= 0:
		authority = authority.substr(0, port_start)
	return {"scheme": scheme, "host": authority, "path": path}


func _resolve_host(host: String) -> Dictionary:
	if NetworkValidation.is_valid_ipv4(host):
		return {"ok": true, "address": host}
	var simulator = _get_simulator()
	if simulator == null:
		return {"ok": false, "error": "Симулятор сети недоступен."}
	var result: Dictionary = simulator.resolve_hostname(device, host)
	if bool(result.get("ok", false)):
		return result
	# Для адресов вида server.local пробуем короткое DNS-имя.
	if host.contains("."):
		var short_name := host.get_slice(".", 0)
		if short_name != host:
			var fallback: Dictionary = simulator.resolve_hostname(device, short_name)
			if bool(fallback.get("ok", false)):
				return fallback
	return result


func _find_server_by_address(address: String) -> Device:
	var simulator = _get_simulator()
	if simulator == null:
		return null
	for candidate in simulator.devices:
		if candidate == null or not is_instance_valid(candidate):
			continue
		if str(candidate.device_type) != "Server" or not candidate.is_operational():
			continue
		for interface_name in candidate.get_interface_names():
			var iface: DeviceInterface = candidate.get_interface(interface_name)
			if iface != null and iface.enabled and iface.ipv4_address == address:
				return candidate
	return null


func _extract_title(content: String) -> String:
	var regex := RegEx.new()
	regex.compile("(?is)<title[^>]*>(.*?)</title>")
	var found := regex.search(content)
	if found == null:
		return ""
	return _decode_entities(_strip_tags(found.get_string(1))).strip_edges()


func _html_to_text(content: String) -> String:
	var text := content
	text = text.replace("\r\n", "\n")
	text = text.replace("\r", "\n")
	var head_regex := RegEx.new()
	head_regex.compile("(?is)<head[^>]*>.*?</head>")
	text = head_regex.sub(text, "", true)
	var script_regex := RegEx.new()
	script_regex.compile("(?is)<(script|style)[^>]*>.*?</(script|style)>")
	text = script_regex.sub(text, "", true)
	var block_regex := RegEx.new()
	block_regex.compile("(?i)</(p|div|h[1-6]|li|tr|br)\\s*>")
	text = block_regex.sub(text, "\n", true)
	var br_regex := RegEx.new()
	br_regex.compile("(?i)<br\\s*/?>")
	text = br_regex.sub(text, "\n", true)
	text = _strip_tags(text)
	text = _decode_entities(text)
	while text.contains("\n\n\n"):
		text = text.replace("\n\n\n", "\n\n")
	return text.strip_edges()


func _strip_tags(value: String) -> String:
	var regex := RegEx.new()
	regex.compile("(?s)<[^>]+>")
	return regex.sub(value, "", true)


func _decode_entities(value: String) -> String:
	var text := value
	text = text.replace("&nbsp;", " ")
	text = text.replace("&amp;", "&")
	text = text.replace("&lt;", "<")
	text = text.replace("&gt;", ">")
	text = text.replace("&quot;", "\"")
	text = text.replace("&#39;", "'")
	return text


func _error(status: int, url: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"status": status,
		"url": url,
		"title": "HTTP ошибка" if status > 0 else "HTTP недоступен",
		"text": message,
	}


func _get_simulator():
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("NetworkSimulator")
	return null
