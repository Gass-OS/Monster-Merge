extends Control
class_name ConfettiFX

## Falling confetti rectangles and 4-point sparkle stars, used over the
## new-monster popup. Frees itself when the animation finishes.

const COLORS := [
	Color("#ff5d8f"), Color("#ffc93c"), Color("#4dd0e1"),
	Color("#81c784"), Color("#ba68c8"), Color("#ff8a65"),
]

var count := 90
var duration := 2.8
var _age := 0.0
var _pieces: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var w := size.x
	if w <= 0.0:
		w = 720.0
	for i in range(count):
		_pieces.append({
			"pos": Vector2(randf_range(0.0, w), -20.0 - randf() * 260.0),
			"speed": 220.0 + randf() * 180.0,
			"sway": 20.0 + randf() * 40.0,
			"phase": randf() * TAU,
			"rot": randf() * TAU,
			"rot_speed": (randf() * 2.0 - 1.0) * 6.0,
			"size": Vector2(7.0 + randf() * 6.0, 10.0 + randf() * 8.0),
			"color": COLORS[randi() % COLORS.size()],
			"sparkle": randi() % 3 == 0,
		})

func _process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		queue_free()
		return
	for p in _pieces:
		var pos: Vector2 = p["pos"]
		pos.y += float(p["speed"]) * delta
		pos.x += sin(_age * 2.0 + float(p["phase"])) * float(p["sway"]) * delta
		p["pos"] = pos
		p["rot"] = float(p["rot"]) + float(p["rot_speed"]) * delta
	queue_redraw()

func _draw() -> void:
	for p in _pieces:
		var alpha := 1.0
		if _age > duration - 0.6:
			alpha = (duration - _age) / 0.6
		var col: Color = p["color"]
		col.a = alpha
		var pos: Vector2 = p["pos"]
		if bool(p["sparkle"]):
			var s: float = float(p["size"].x) * 0.6
			var pts := PackedVector2Array([
				pos + Vector2(0, -s), pos + Vector2(s * 0.3, -s * 0.3),
				pos + Vector2(s, 0), pos + Vector2(s * 0.3, s * 0.3),
				pos + Vector2(0, s), pos + Vector2(-s * 0.3, s * 0.3),
				pos + Vector2(-s, 0), pos + Vector2(-s * 0.3, -s * 0.3)])
			draw_colored_polygon(pts, col)
		else:
			var piece_size: Vector2 = p["size"]
			draw_set_transform(pos, float(p["rot"]), Vector2.ONE)
			draw_rect(Rect2(-piece_size * 0.5, piece_size), col)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
