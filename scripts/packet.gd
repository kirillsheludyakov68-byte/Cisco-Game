extends Node2D
class_name PingPacket

const RADIUS := 13.0


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	# Пакет рисуется нейтральным, а цвет задаётся modulate: синий в полёте,
	# красный при ошибке и зелёный при успехе.
	draw_circle(Vector2.ZERO, RADIUS + 5.0, Color(1.0, 1.0, 1.0, 0.22))
	draw_circle(Vector2.ZERO, RADIUS, Color(1.0, 1.0, 1.0, 1.0))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, Color(0.1, 0.1, 0.1, 0.85), 2.5, true)
	draw_circle(Vector2(-4.0, -4.0), 3.5, Color(1.0, 1.0, 1.0, 0.85))
