extends VBoxContainer
class_name WebBrowserWindow

@onready var back_button: Button = $NavRow/BackButton
@onready var forward_button: Button = $NavRow/ForwardButton
@onready var uri_edit: LineEdit = $NavRow/UriEdit
@onready var go_button: Button = $NavRow/GoButton
@onready var page_panel: PanelContainer = $PagePanel
@onready var page_text: RichTextLabel = $PagePanel/PageMargin/PageText
@onready var status_label: Label = $StatusLabel

var device: Device = null
var request_handler: WebBrowserRequestHandler = WebBrowserRequestHandler.new()

var _history: Array[String] = []
var _history_index := -1


func _ready() -> void:
	_apply_styles()
	go_button.pressed.connect(_on_go_pressed)
	back_button.pressed.connect(_go_back)
	forward_button.pressed.connect(_go_forward)
	uri_edit.text_submitted.connect(_on_uri_submitted)
	_show_home()
	_update_navigation_buttons()


func setup(device_value: Device) -> void:
	device = device_value
	uri_edit.grab_focus()


func activate() -> void:
	if uri_edit != null:
		uri_edit.grab_focus()


func commit_pending() -> void:
	# Браузер не сохраняет адреса и не выполняет отложенных запросов.
	pass


func set_request_handler(handler: WebBrowserRequestHandler) -> void:
	if handler != null:
		request_handler = handler


func go_to_address(address: String) -> void:
	var value := address.strip_edges()
	if value.is_empty():
		_show_error_page("Пустой адрес", "Введите адрес в адресной строке.", "", true)
		return
	if value.to_lower() == "about:blank":
		_show_home()
		return

	var lower := value.to_lower()
	if not lower.contains("://") and not lower.begins_with("about:"):
		value = "http://" + value

	if value.to_lower().begins_with("about:"):
		_show_error_page(
			"Неподдерживаемый адрес",
			"Поддерживаются только http:// и https://.",
			value,
			true
		)
		return

	var scheme := value.get_slice("://", 0).to_lower()
	if scheme != "http" and scheme != "https":
		_show_error_page(
			"Неподдерживаемый адрес",
			"Разрешены только http:// и https://. Доступ к файлам и локальным ресурсам запрещён.",
			value,
			true
		)
		return

	_add_to_history(value)
	_load_url(value)


func _apply_styles() -> void:
	DesktopStyles.apply_action_button(back_button)
	DesktopStyles.apply_action_button(forward_button)
	DesktopStyles.apply_action_button(go_button)
	ConfigStyles.apply_line_edit(uri_edit)
	ConfigStyles.apply_status_label(status_label)
	page_panel.add_theme_stylebox_override("panel", ConfigStyles.content_panel())
	page_text.add_theme_stylebox_override("normal", ConfigStyles.line_edit_style())
	page_text.add_theme_color_override("default_color", ConfigStyles.TEXT_COLOR)
	page_text.add_theme_font_size_override("normal_font_size", 13)
	status_label.visible = false


func _on_go_pressed() -> void:
	go_to_address(uri_edit.text)


func _on_uri_submitted(_text: String) -> void:
	go_to_address(uri_edit.text)


func _go_back() -> void:
	if _history_index <= 0:
		return
	_history_index -= 1
	_load_url(_history[_history_index])
	_update_navigation_buttons()


func _go_forward() -> void:
	if _history_index >= _history.size() - 1:
		return
	_history_index += 1
	_load_url(_history[_history_index])
	_update_navigation_buttons()


func _add_to_history(url: String) -> void:
	if _history_index >= 0 and _history_index < _history.size() and _history[_history_index] == url:
		return
	if _history_index < _history.size() - 1:
		_history = _history.slice(0, _history_index + 1)
	_history.append(url)
	_history_index = _history.size() - 1
	_update_navigation_buttons()


func _load_url(url: String) -> void:
	uri_edit.text = url
	var result := request_handler.fetch(url)
	if result.is_empty():
		_show_error_page("Ошибка запроса", "Обработчик запросов вернул пустой ответ.", url, true)
		return

	var title := str(result.get("title", "Страница"))
	var body := str(result.get("text", ""))
	var ok := bool(result.get("ok", false))
	var status := int(result.get("status", 0))
	page_text.text = title + "\n\n" + body
	page_text.scroll_to_line(0)
	if ok:
		ConfigStyles.set_status(status_label, "Загружено: " + url, false, true)
	else:
		var suffix := ""
		if status > 0:
			suffix = " (HTTP " + str(status) + ")"
		ConfigStyles.set_status(status_label, "Не удалось загрузить страницу" + suffix + ".", true)
	_update_navigation_buttons()


func _show_home() -> void:
	uri_edit.text = ""
	page_text.text = (
		"Web Browser\n\n"
		+ "Введите http:// или https:// адрес и нажмите Go.\n\n"
		+ "HTTP-серверы в сети симулятора пока не реализованы. "
		+ "Браузер не обращается к настоящему интернету и не загружает файлы "
		+ "из файловой системы."
	)
	page_text.scroll_to_line(0)
	status_label.visible = false
	_update_navigation_buttons()


func _show_error_page(title: String, message: String, url: String, add_to_history: bool = false) -> void:
	if url.is_empty():
		uri_edit.text = ""
	page_text.text = title + "\n\n" + message
	page_text.scroll_to_line(0)
	ConfigStyles.set_status(status_label, message, true)
	_update_navigation_buttons()
	if add_to_history and not url.is_empty():
		_add_to_history(url)
		uri_edit.text = url


func _update_navigation_buttons() -> void:
	back_button.disabled = _history_index <= 0
	forward_button.disabled = _history_index >= _history.size() - 1
