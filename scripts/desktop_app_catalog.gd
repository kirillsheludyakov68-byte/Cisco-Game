extends RefCounted
class_name DesktopAppCatalog

# Единственное место, где регистрируются приложения рабочего стола.
# Чтобы добавить приложение, достаточно добавить сюда запись и создать его сцену.
const APPS := [
	{
		"id": "ip_configuration",
		"title": "IP Configuration",
		"icon_path": "res://assets/Workstation/ipconfig.png",
		"scene_path": "res://scenes/apps/IPConfigurationWindow.tscn",
	},
	{
		"id": "command_prompt",
		"title": "Command Prompt",
		"icon_path": "res://assets/Workstation/cmdprompt.png",
		"scene_path": "res://scenes/apps/CommandPromptWindow.tscn",
	},
	{
		"id": "email",
		"title": "Email",
		"icon_path": "res://assets/Workstation/EmailClient.png",
		"scene_path": "res://scenes/apps/EmailWindow.tscn",
	},
	{
		"id": "web_browser",
		"title": "Web Browser",
		"icon_path": "res://assets/Workstation/browser.png",
		"scene_path": "res://scenes/apps/WebBrowserWindow.tscn",
	},
]

static var _icon_cache: Dictionary = {}
static var _scene_cache: Dictionary = {}


static func get_apps() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for app in APPS:
		result.append((app as Dictionary).duplicate(true))
	return result


static func get_app(app_id: String) -> Dictionary:
	for app in APPS:
		if str(app.get("id", "")) == app_id:
			return (app as Dictionary).duplicate(true)
	return {}


static func get_icon(app_id: String) -> Texture2D:
	var app := get_app(app_id)
	var path := str(app.get("icon_path", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		push_error("Desktop app icon not found: " + path)
		return null
	if _icon_cache.has(path):
		return _icon_cache[path] as Texture2D
	var icon := load(path) as Texture2D
	if icon != null:
		_icon_cache[path] = icon
	return icon


static func get_scene(app_id: String) -> PackedScene:
	var app := get_app(app_id)
	var path := str(app.get("scene_path", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		push_error("Desktop app scene not found: " + path)
		return null
	if _scene_cache.has(path):
		return _scene_cache[path] as PackedScene
	var scene := load(path) as PackedScene
	if scene != null:
		_scene_cache[path] = scene
	return scene
