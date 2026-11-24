extends RefCounted
class_name WebBrowserRequestHandler

# Точка расширения для будущих HTTP-серверов внутри симулятора.
# Приложение браузера вызывает fetch(url) и ожидает словарь:
# {ok: bool, status: int, title: String, text: String, url: String}.
# Базовая реализация намеренно ничего не загружает из интернета.
func fetch(url: String) -> Dictionary:
	return {
		"ok": false,
		"status": 0,
		"url": url,
		"title": "HTTP недоступен",
		"text": (
			"В текущей модели сети HTTP-серверы не реализованы.\n\n"
			+ "Запрошенный ресурс: " + url + "\n\n"
			+ "Браузер не обращается к настоящему интернету и не загружает файлы "
			+ "из файловой системы. Для интеграции нужно передать приложению "
			+ "собственный WebBrowserRequestHandler."
		),
	}
