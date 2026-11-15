extends Control
class_name BossPortrait

## Boss artwork. Uses res://art/bosses/boss_N.png when present,
## otherwise draws a procedural horned demon in the boss colour.

const COLORS := [
	Color("#ff4a3d"), Color("#b04dff"), Color("#3dd6ff"),
	Color("#ffb02e"), Color("#4dff88")
]

var level: int = 1
var shake: float = 0.0
var _time: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_level(value: int) -> void:
	level = maxi(1, value)
	queue_redraw()

func hit() -> void:
	shake = 1.0

func get_boss_color() -> Color:
	return COLORS[(level - 1) % COLORS.size()]

func _process(delta: float) -> void:
	_time += delta
	shake = maxf(0.0, shake - delta * 4.0)
	queue_redraw()

func _draw() -> void:
	var col := get_boss_color()
	var jitter := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 5.0 * shake
	var c := size * 0.5 + jitter + Vector2(0, sin(_time * 1.8) * 3.0)
	var r := minf(size.x, size.y) * 0.3
	for i in range(4):
		draw_circle(size * 0.5, r * (2.0 - float(i) * 0.4), Color(col, 0.05 + 0.012 * float(i)))
	var tex := ArtLoader.boss(level)
	if tex != null:
		var ts := tex.get_size()
		var sc := (minf(size.x, size.y) * 0.95) / maxf(ts.x, ts.y)
		var dst := ts * sc
		var tint := Color.WHITE.lerp(Color(1.0, 0.35, 0.3), shake * 0.6)
		draw_texture_rect(tex, Rect2(c - dst * 0.5, dst), false, tint)
		return
	var body := Color("#10131d").lerp(Color("#4a1218"), shake * 0.7)
	# Horns: coloured rim first, dark core on top.
	for sgn: float in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(sgn * r * 0.35, -r * 0.6), c + Vector2(sgn * r * 1.25, -r * 1.5),
			c + Vector2(sgn * r * 0.95, -r * 0.2)]), col)
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(sgn * r * 0.42, -r * 0.55), c + Vector2(sgn * r * 1.05, -r * 1.3),
			c + Vector2(sgn * r * 0.85, -r * 0.25)]), body)
	# Head with rim light.
	draw_circle(c + Vector2(-2.5, -2.5), r * 1.02, Color(col, 0.9))
	draw_circle(c, r, body)
	# Glowing eyes.
	for sgn: float in [-1.0, 1.0]:
		var e := c + Vector2(sgn * r * 0.42, -r * 0.12)
		draw_circle(e, r * 0.36, Color(col, 0.18))
		draw_circle(e, r * 0.22, Color(col, 0.4))
		draw_colored_polygon(PackedVector2Array([
			e + Vector2(-sgn * r * 0.22, -r * 0.12), e + Vector2(sgn * r * 0.2, r * 0.02),
			e + Vector2(-sgn * r * 0.12, r * 0.14)]), col.lightened(0.35))
	# Fanged mouth.
	var m := c + Vector2(0, r * 0.5)
	draw_line(m + Vector2(-r * 0.5, 0), m + Vector2(r * 0.5, 0), Color(col, 0.9), 3.0, true)
	for i in range(4):
		var tx := -r * 0.36 + float(i) * r * 0.24
		draw_colored_polygon(PackedVector2Array([
			m + Vector2(tx - r * 0.08, 0), m + Vector2(tx, r * 0.22), m + Vector2(tx + r * 0.08, 0)]), Color("#e8e2d0"))
