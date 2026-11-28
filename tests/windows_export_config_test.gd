extends Node

# Headless test for the Windows desktop export configuration.
# Run with:
#   godot --headless --path . res://tests/windows_export_config_test.tscn

const BRAND_DIR := "res://assets/branding"

var _failures: Array[String] = []


func _ready() -> void:
	_test_project_settings()
	_test_export_preset()
	_test_icon_files()
	_finish()


func _test_project_settings() -> void:
	var icon_path := str(ProjectSettings.get_setting("application/config/icon", ""))
	_expect(icon_path == BRAND_DIR + "/cisco_game_icon.png", "Project icon must use the branded PNG.")
	_expect(ProjectSettings.get_setting("application/config/version", "") == "1.0.0", "Project version must be 1.0.0.")
	_expect(ResourceLoader.exists(icon_path), "Project icon must exist: " + icon_path)

	var icon := load(icon_path) as Texture2D
	_expect(icon != null, "Project icon must be importable as a Texture2D.")
	if icon != null:
		_expect(icon.get_width() == 512 and icon.get_height() == 512, "Project icon must be 512x512.")


func _test_export_preset() -> void:
	var config := ConfigFile.new()
	var error := config.load("res://export_presets.cfg")
	_expect(error == OK, "export_presets.cfg must be readable.")
	if error != OK:
		return

	_expect(str(config.get_value("preset.0", "name", "")) == "Windows Desktop", "First export preset must target Windows Desktop.")
	_expect(str(config.get_value("preset.0", "platform", "")) == "Windows Desktop", "Export platform must be Windows Desktop.")
	_expect(str(config.get_value("preset.0", "export_path", "")) == "build/windows/CiscoGame.exe", "Export path must point to build/windows/CiscoGame.exe.")
	_expect(bool(config.get_value("preset.0.options", "binary_format/embed_pck", false)), "The PCK must be embedded into the EXE.")
	_expect(str(config.get_value("preset.0.options", "binary_format/architecture", "")) == "x86_64", "Windows build must target x86_64.")
	_expect(str(config.get_value("preset.0.options", "application/icon", "")) == BRAND_DIR + "/cisco_game.ico", "Windows EXE must use the branded ICO.")
	_expect(str(config.get_value("preset.0.options", "application/product_name", "")) == "Cisco Game", "Product name must be Cisco Game.")
	_expect(str(config.get_value("preset.0.options", "application/file_version", "")) == "1.0.0", "File version must be 1.0.0.")
	_expect(not bool(config.get_value("preset.0.options", "codesign/enable", true)), "Codesigning must stay disabled for the local build.")


func _test_icon_files() -> void:
	for path in [
		BRAND_DIR + "/cisco_game_icon.png",
		BRAND_DIR + "/cisco_game.ico",
		BRAND_DIR + "/cisco_game_icon_source.png",
	]:
		_expect(FileAccess.file_exists(path), "Missing branding asset: " + path)

	var ico := FileAccess.open(BRAND_DIR + "/cisco_game.ico", FileAccess.READ)
	_expect(ico != null, "The ICO file must be readable.")
	if ico == null:
		return

	_expect(ico.get_16() == 0, "ICO reserved field must be zero.")
	_expect(ico.get_16() == 1, "ICO type must be 1.")
	var icon_count := ico.get_16()
	_expect(icon_count >= 6, "ICO must contain at least six image sizes.")

	var sizes: Array[int] = []
	for index in range(icon_count):
		var width := ico.get_8()
		var height := ico.get_8()
		ico.get_8() # Palette colors.
		ico.get_8() # Reserved.
		ico.get_16() # Color planes.
		ico.get_16() # Bits per pixel.
		ico.get_32() # Image size.
		ico.get_32() # Image offset.
		_expect(width == height, "ICO entry %d must be square." % index)
		sizes.append(256 if width == 0 else width)

	ico.close()
	for expected_size in [16, 32, 48, 64, 128, 256]:
		_expect(sizes.has(expected_size), "ICO must contain the %dpx size." % expected_size)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: Windows export configuration")
		get_tree().quit(0)
		return

	for failure in _failures:
		printerr("FAIL: " + failure)
	get_tree().quit(1)
