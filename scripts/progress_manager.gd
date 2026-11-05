extends Node

# Хранит лучшие результаты по уровням и общий счёт.
# Общий счёт — сумма лучших результатов, чтобы очки нельзя было
# бесконечно фармить повторными прохождениями одного уровня.

signal total_score_changed(total: int)

const SAVE_PATH := "user://progress.json"
const SAVE_VERSION := 1

var _levels: Dictionary = {}


func _ready() -> void:
	_load()


func record_completion(level_id: String, score: int, stats: Dictionary = {}) -> Dictionary:
	if level_id.is_empty():
		push_warning("ProgressManager: пустой id уровня")
		return {"is_new_best": false, "best_score": score, "total": get_total_score()}

	var old_value = _levels.get(level_id, {})
	var old: Dictionary = old_value if old_value is Dictionary else {}
	var best_score := int(old.get("best_score", 0))
	var is_new_best := score > best_score

	old["best_score"] = best_score
	if is_new_best:
		old["best_score"] = score
		old["best_time"] = float(stats.get("time", 0.0))
		old["best_hints"] = int(stats.get("hints_used", 0))

	old["completed"] = true
	old["completions"] = int(old.get("completions", 0)) + 1
	_levels[level_id] = old

	_save()
	total_score_changed.emit(get_total_score())

	return {
		"is_new_best": is_new_best,
		"best_score": int(old["best_score"]),
		"total": get_total_score(),
	}


func get_total_score() -> int:
	var total := 0
	for level in _levels.values():
		if level is Dictionary:
			total += int(level.get("best_score", 0))
	return total


func get_level_result(level_id: String) -> Dictionary:
	return _levels.get(level_id, {})


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return

	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_warning("ProgressManager: повреждён файл прогресса")
		return

	var levels = parsed.get("levels", {})
	if levels is Dictionary:
		_levels = levels


func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("ProgressManager: не удалось сохранить прогресс")
		return

	file.store_string(JSON.stringify({
		"version": SAVE_VERSION,
		"levels": _levels,
	}, "\t"))
	file.close()
