extends Node

# Хранит профили игроков и их лучшие результаты по уровням.
# Общий счёт профиля — сумма лучших результатов, чтобы очки нельзя было
# бесконечно фармить повторными прохождениями одного уровня.

signal profiles_changed
signal active_profile_changed(profile_id: String)
signal total_score_changed(total: int)

const SAVE_PATH := "user://progress.json"
const SAVE_VERSION := 2

var _profiles: Dictionary = {}
var _active_profile_id := ""


func _ready() -> void:
	_load()


func has_profiles() -> bool:
	return not _profiles.is_empty()


func has_active_profile() -> bool:
	return _profiles.has(_active_profile_id)


func get_active_profile_id() -> String:
	return _active_profile_id


func get_active_profile() -> Dictionary:
	if not has_active_profile():
		return {}
	var profile = _profiles.get(_active_profile_id, {})
	if not profile is Dictionary:
		return {}
	return {
		"id": _active_profile_id,
		"name": str(profile.get("name", "Профиль")),
	}


func get_active_profile_name() -> String:
	return str(get_active_profile().get("name", ""))


func create_profile(profile_name: String) -> Dictionary:
	var clean_name := profile_name.strip_edges()
	if clean_name.is_empty():
		return {"ok": false, "reason": "Введите имя профиля."}
	if clean_name.length() > 24:
		return {"ok": false, "reason": "Имя не должно быть длиннее 24 символов."}

	for id in _profiles:
		var profile = _profiles[id]
		if profile is Dictionary:
			var existing_name := str(profile.get("name", ""))
			if existing_name.to_lower() == clean_name.to_lower():
				return {"ok": false, "reason": "Профиль с таким именем уже существует."}

	var profile_id := _make_profile_id()
	_profiles[profile_id] = {
		"name": clean_name,
		"created_at": Time.get_unix_time_from_system(),
		"levels": {},
	}
	_active_profile_id = profile_id

	_save()
	profiles_changed.emit()
	active_profile_changed.emit(profile_id)
	total_score_changed.emit(0)
	return {"ok": true, "id": profile_id}


func get_profiles() -> Array:
	var result: Array = []
	for id in _profiles:
		var profile = _profiles[id]
		if not profile is Dictionary:
			continue

		var levels = profile.get("levels", {})
		var total := 0
		var completed := 0
		if levels is Dictionary:
			for level in levels.values():
				if level is Dictionary:
					total += int(level.get("best_score", 0))
					if bool(level.get("completed", false)):
						completed += 1

		result.append({
			"id": id,
			"name": str(profile.get("name", "Профиль")),
			"created_at": float(profile.get("created_at", 0.0)),
			"total_score": total,
			"completed_levels": completed,
		})

	result.sort_custom(_sort_profiles)
	return result


func set_active_profile(profile_id: String) -> bool:
	if not _profiles.has(profile_id):
		return false
	_active_profile_id = profile_id
	_save()
	active_profile_changed.emit(profile_id)
	total_score_changed.emit(get_total_score())
	return true


func delete_profile(profile_id: String) -> bool:
	if not _profiles.has(profile_id):
		return false

	_profiles.erase(profile_id)
	if _active_profile_id == profile_id:
		_active_profile_id = ""

	_save()
	profiles_changed.emit()
	active_profile_changed.emit(_active_profile_id)
	total_score_changed.emit(get_total_score())
	return true


func get_total_score() -> int:
	var levels := _get_active_levels()
	var total := 0
	for level in levels.values():
		if level is Dictionary:
			total += int(level.get("best_score", 0))
	return total


func get_level_result(level_id: String) -> Dictionary:
	return _get_active_levels().get(level_id, {})


func record_completion(level_id: String, score: int, stats: Dictionary = {}) -> Dictionary:
	if level_id.is_empty():
		push_warning("ProgressManager: пустой id уровня")
		return {"is_new_best": false, "best_score": score, "total": get_total_score()}

	var profile := _ensure_active_profile()
	if profile.is_empty():
		return {"is_new_best": false, "best_score": score, "total": get_total_score()}

	var levels = profile.get("levels", {})
	if not levels is Dictionary:
		levels = {}
		profile["levels"] = levels

	var old_value = levels.get(level_id, {})
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
	levels[level_id] = old

	_save()
	total_score_changed.emit(get_total_score())
	return {
		"is_new_best": is_new_best,
		"best_score": int(old["best_score"]),
		"total": get_total_score(),
	}


func _get_active_levels() -> Dictionary:
	if not has_active_profile():
		return {}
	var profile = _profiles.get(_active_profile_id, {})
	if not profile is Dictionary:
		return {}
	var levels = profile.get("levels", {})
	return levels if levels is Dictionary else {}


func _ensure_active_profile() -> Dictionary:
	if has_active_profile():
		var profile = _profiles.get(_active_profile_id, {})
		if profile is Dictionary:
			return profile

	if _profiles.is_empty():
		var created := create_profile("Игрок")
		if not bool(created.get("ok", false)):
			return {}
		var created_profile = _profiles.get(_active_profile_id, {})
		return created_profile if created_profile is Dictionary else {}

	for id in _profiles:
		var profile = _profiles[id]
		if profile is Dictionary:
			_active_profile_id = id
			_save()
			active_profile_changed.emit(id)
			return profile

	return {}


func _make_profile_id() -> String:
	var profile_id := "%d_%d" % [int(Time.get_unix_time_from_system()), randi()]
	while _profiles.has(profile_id):
		profile_id = "%d_%d" % [int(Time.get_unix_time_from_system()), randi()]
	return profile_id


func _sort_profiles(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("created_at", 0.0)) < float(b.get("created_at", 0.0))


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

	if parsed.get("profiles") is Dictionary:
		_profiles = parsed.get("profiles", {})
		_active_profile_id = str(parsed.get("active_profile_id", ""))
	elif parsed.get("levels") is Dictionary:
		# Миграция старого формата без профилей в профиль «Игрок».
		var profile_id := _make_profile_id()
		_profiles[profile_id] = {
			"name": "Игрок",
			"created_at": Time.get_unix_time_from_system(),
			"levels": parsed.get("levels", {}),
		}
		_active_profile_id = profile_id
		_save()

	if not _profiles.has(_active_profile_id):
		_active_profile_id = ""


func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("ProgressManager: не удалось сохранить прогресс")
		return

	file.store_string(JSON.stringify({
		"version": SAVE_VERSION,
		"profiles": _profiles,
		"active_profile_id": _active_profile_id,
	}, "\t"))
	file.close()
