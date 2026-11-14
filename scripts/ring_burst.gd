extends Control
class_name RingBurst

## Expanding white ring (plus a soft flash) spawned at a merged tile.
## Frees itself when the animation finishes.

var max_radius := 95.0
var duration := 0.45
var ring_color := Color.WHITE
var _age := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t := _age / duration
	var r := max_radius * (1.0 - pow(1.0 - t, 2.0))
	var a := 1.0 - t
	var width := lerpf(10.0, 2.0, t)
	draw_circle(Vector2.ZERO, r * 0.9, Color(1, 1, 1, 0.18 * a))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(ring_color, a), width, true)
