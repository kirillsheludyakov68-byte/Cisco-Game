extends RefCounted
class_name SwitchConsole

# Локальный журнал коммутатора. Он общий для CLI и панели
# Equivalent IOS Commands в Config, поэтому события не дублируются.

signal line_added(line: String)
signal cleared

var _lines: Array[String] = []


func clear() -> void:
	_lines.clear()
	cleared.emit()


func append_line(line: String) -> void:
	_lines.append(line)
	line_added.emit(line)


func append_lines(lines: Array[String]) -> void:
	for line in lines:
		append_line(line)


func get_text() -> String:
	return "\n".join(_lines)


func is_empty() -> bool:
	return _lines.is_empty()


func get_lines() -> Array[String]:
	return _lines.duplicate()
