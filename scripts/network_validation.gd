extends RefCounted
class_name NetworkValidation


static func is_valid_ipv4(value: String) -> bool:
	var text := value.strip_edges()
	if text.is_empty():
		return false

	var parts := text.split(".")
	if parts.size() != 4:
		return false

	for part in parts:
		if part.is_empty() or part.length() > 3:
			return false
		for ch in part:
			if ch < "0" or ch > "9":
				return false
		var octet := int(part)
		if octet < 0 or octet > 255:
			return false

	return true


static func is_valid_subnet_mask(value: String) -> bool:
	if not is_valid_ipv4(value):
		return false

	# У корректной маски инвертированные биты — непрерывный блок единиц.
	var mask := ipv4_to_int(value)
	var inverted := (~mask) & 0xFFFFFFFF
	return (inverted & (inverted + 1)) == 0


static func is_valid_ipv6(value: String) -> bool:
	var text := value.strip_edges().to_lower()
	if text.is_empty():
		return false
	if text.count("::") > 1:
		return false

	var groups: Array = []
	var compressed := text.contains("::")

	if compressed:
		var halves := text.split("::", true, 1)
		if halves.size() != 2:
			return false
		var left = _split_ipv6_side(halves[0])
		var right = _split_ipv6_side(halves[1])
		if left == null or right == null:
			return false
		groups = left + right
		# "::" заменяет хотя бы одну группу, поэтому всего групп должно быть меньше восьми.
		if groups.size() >= 8:
			return false
	else:
		var side = _split_ipv6_side(text)
		if side == null:
			return false
		groups = side
		if groups.size() != 8:
			return false

	for group in groups:
		var part := str(group)
		if part.length() < 1 or part.length() > 4:
			return false
		for ch in part:
			var is_digit := ch >= "0" and ch <= "9"
			var is_hex_letter := ch >= "a" and ch <= "f"
			if not is_digit and not is_hex_letter:
				return false

	return true


static func is_valid_ipv6_prefix(value: String) -> bool:
	var text := value.strip_edges()
	if text.is_empty():
		return false
	for ch in text:
		if ch < "0" or ch > "9":
			return false
	var prefix := int(text)
	return prefix >= 0 and prefix <= 128


static func ipv4_to_int(value: String) -> int:
	var result := 0
	for part in value.split("."):
		result = (result << 8) | int(part)
	return result


static func _split_ipv6_side(text: String):
	if text.is_empty():
		return []

	var result: Array = []
	for part in text.split(":"):
		if part.is_empty():
			return null
		result.append(part)
	return result
