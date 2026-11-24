extends RefCounted
class_name EmailStore

# Локальная модель почты для симулятора. Она не изображает SMTP/POP3:
# сообщения живут в памяти текущей сессии и доступны приложениям Email.
# Этого достаточно для обмена между устройствами внутри одного запуска.

static var _messages: Array[Dictionary] = []
static var _next_id := 1
static var _default_domain := "local"


static func reset() -> void:
	_messages.clear()
	_next_id = 1


static func send(sender: String, recipient: String, subject: String, body: String) -> Dictionary:
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
	_messages.append(message)
	return {"ok": true, "reason": "", "message": message.duplicate(true)}


static func get_inbox(address: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var target := address.strip_edges().to_lower()
	for message in _messages:
		if str(message.get("to", "")).to_lower() == target:
			result.append((message as Dictionary).duplicate(true))
	result.reverse()
	return result


static func get_message_count() -> int:
	return _messages.size()


static func device_address(device: Device) -> String:
	if device == null:
		return "user@" + _default_domain
	var local := device.device_name.strip_edges().to_lower()
	local = local.replace(" ", ".")
	local = local.replace("@", "")
	if local.is_empty():
		local = "user"
	return local + "@" + _default_domain


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
