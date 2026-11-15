extends Control
class_name CoinIcon

## Drawn gold coin (emoji do not render reliably on Android).

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(32, 32)

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.46
	draw_circle(c + Vector2(0, r * 0.08), r, Color("#8a5410"))
	draw_circle(c, r, Color("#c98716"))
	draw_circle(c, r * 0.86, Color("#ffcf3d"))
	draw_circle(c, r * 0.62, Color("#ffe27b"))
	draw_arc(c, r * 0.62, 0.0, TAU, 24, Color("#d99a1e"), maxf(1.5, r * 0.08), true)
	draw_rect(Rect2(c + Vector2(-r * 0.07, -r * 0.34), Vector2(r * 0.14, r * 0.68)), Color("#c98716"))
	draw_circle(c + Vector2(-r * 0.4, -r * 0.45), r * 0.12, Color(1, 1, 1, 0.55))
