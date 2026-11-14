extends Control
class_name StarGlow

## Rotating golden star with a pulsing radial glow, drawn behind the
## new monster in the unlock popup.

var _angle := 0.0
var _time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	_time += delta
	_angle += delta * 0.6
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	# Radial glow: concentric translucent gold circles, gently pulsing.
	var pulse := 0.05 * sin(_time * 2.0)
	for i in range(5):
		var t := float(i) / 5.0
		draw_circle(c, r * (1.0 - t * 0.55), Color(1.0, 0.85, 0.3, 0.10 + pulse))
	# Rotating 5-point star.
	var points := PackedVector2Array()
	var outer := r * 0.98
	var inner := r * 0.42
	for i in range(10):
		var ang := _angle + float(i) * PI / 5.0 - PI / 2.0
		var rad := outer if i % 2 == 0 else inner
		points.append(Vector2(cos(ang), sin(ang)) * rad)
	draw_set_transform(c, 0.0, Vector2.ONE)
	draw_colored_polygon(points, Color(1.0, 0.82, 0.25, 0.9))
	draw_set_transform(c, 0.0, Vector2(0.62, 0.62))
	draw_colored_polygon(points, Color(1.0, 0.94, 0.62, 0.9))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
