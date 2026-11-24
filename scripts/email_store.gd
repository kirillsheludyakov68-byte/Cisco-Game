extends RefCounted
class_name EmailStore

# Модель почты для симулятора. Если в сети есть включённый EMAIL-сервер
# с подходящим доменом, письмо сохраняется в его ящике и подчиняется
# настройкам SMTP/POP3. Без сервера используется локальный ящик.

static var _messages: Array[Dictionary] = []
static var _next_id := 1
static var _default_domain := "local"


static func reset() -> void:
	_messages.clear()
	_next_id = 1


static func send(sender: String, recipient: String, subject: String, body: String) -> Dictionary:
	return _send(sender, recipient, subject, body, null)


static func send_from_device(
	source: Device,
	sender: String,
	recipient: String,
	subject: String,
	body: String
) -> Dictionary:
	return _send(sender, recipient, subject, body, source)


static func _send(
	sender: String,
	recipient: String,
	subject: String,
	body: String,
	source: Device
) -> Dictionary:
	var from_text := sender.strip_edges()
	var to_text := recipient.strip_edges()
	var subject_text := subject.strip_edges()
	var body_text := body.strip_edges()

	if from_text.is_empty():
		return {"ok": false, "reason": "Поле From не должно быть пустым."}
	if not is_valid_address(from_text):
		return {"ok": false, "reason": "Некорректный адрес отправителя."}
	if to_text.is_empty():
		return {"ok": false, "reason": "Поле To не должно быть пустым."}
	if not is_valid_address(to_text):
		return {"ok": false, "reason": "Некорректный адрес получателя."}
	if subject_text.is_empty():
		return {"ok": false, "reason": "Поле Subject не должно быть пустым."}
	if body_text.is_empty():
		return {"ok": false, "reason": "Введите текст письма."}

	var message := {
		"id": _next_id,
		"from": from_text,
		"to": to_text,
		"subject": subject_text,
		"body": body_text,
		"created_at": Time.get_datetime_string_from_system(false, true),
	}
	_next_id += 1

	var domain := to_text.get_slice("@", 1).to_lower()
	var server := find_server_for_domain(domain)
	if server != null:
		if not server.email_smtp_enabled:
			return {
				"ok": false,
				"reason": "SMTP выключен на сервере %s." % server.device_name,
			}
		var recipient_user := to_text.get_slice("@", 0).to_lower()
		if not server.email_users.is_empty() and not server.email_users.has(recipient_user):
			return {
				"ok": false,
				"reason": "Пользователь %s не зарегистрирован на сервере %s."
					% [recipient_user, server.device_name],
			}
		server.email_messages.append(message.duplicate(true))
		return {"ok": true, "reason": "", "message": message.duplicate(true), "server": server}

	_messages.append(message)
	return {"ok": true, "reason": "", "message": message.duplicate(true)}


static func get_inbox(address: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var target := address.strip_edges().to_lower()
	for message in _messages:
		if str(message.get("to", "")).to_lower() == target:
			result.append((message as Dictionary).duplicate(true))

	var domain := target.get_slice("@", 1).to_lower()
	var server := find_server_for_domain(domain)
	if server != null and server.email_pop3_enabled:
		for message in server.email_messages:
			if str(message.get("to", "")).to_lower() == target:
				result.append((message as Dictionary).duplicate(true))

	result.reverse()
	return result


static func get_message_count() -> int:
	var total := _messages.size()
	var simulator = _get_simulator()
	if simulator != null:
		for candidate in simulator.devices:
			if candidate != null and is_instance_valid(candidate) \
					and str(candidate.device_type) == "Server":
				total += candidate.email_messages.size()
	return total


static func find_server_for_domain(domain: String) -> Device:
	var simulator = _get_simulator()
	if simulator == null:
		return null
	var target := domain.strip_edges().to_lower()
	for candidate in simulator.devices:
		if candidate == null or not is_instance_valid(candidate):
			continue
		if str(candidate.device_type) != "Server" or not candidate.is_operational():
			continue
		if candidate.email_domain.to_lower() == target:
			return candidate
	return null


static func _get_simulator():
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("NetworkSimulator")
	return null


static func device_address(device: Device) -> String:
	if device == null:
		return "user@" + _default_domain
	var local := device.device_name.strip_edges().to_lower()
	local = local.replace(" ", ".")
	local = local.replace("@", "")
	if local.is_empty():
		local = "user"
	var domain := _default_domain
	var simulator = _get_simulator()
	if simulator != null:
		for candidate in simulator.devices:
			if candidate != null and is_instance_valid(candidate) \
					and str(candidate.device_type) == "Server" \
					and not str(candidate.email_domain).is_empty():
				domain = str(candidate.email_domain)
				break
	return local + "@" + domain


static func is_valid_address(value: String) -> bool:
	var text := value.strip_edges()
	if text.is_empty() or text.contains(" ") or text.contains("\n") or text.contains("\t"):
		return false
	if text.count("@") != 1:
		return false
	var at := text.find("@")
	if at <= 0 or at >= text.length() - 1:
		return false
	var local := text.substr(0, at)
	var domain := text.substr(at + 1)
	if local.is_empty() or domain.is_empty():
		return false
	if local.begins_with(".") or local.ends_with("."):
		return false
	if domain.begins_with(".") or domain.ends_with("."):
		return false
	return true
