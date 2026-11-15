extends Control
class_name BackgroundFX

## Dark-fantasy night backdrop: deep gradient sky, twinkling stars, a blood
## moon, drifting fog banks, rising embers and a heavy vignette.
## Pure procedural drawing, no external assets.

var _time := 0.0
var _gradient: GradientTexture2D
var _fog: Array = []
var _embers: Array = []
var _stars: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var grad := Gradient.new()
	grad.set_color(0, Color("#04050b"))
	grad.set_color(1, Color("#220d18"))
	grad.add_point(0.5, Color("#0f1a35"))
	_gradient = GradientTexture2D.new()
	_gradient.gradient = grad
	_gradient.fill_from = Vector2(0.5, 0.0)
	_gradient.fill_to = Vector2(0.5, 1.0)
	_gradient.width = 16
	_gradient.height = 512
	resized.connect(queue_redraw)

func _populate() -> void:
	var w := size.x
	var h := size.y
	for i in range(7):
		_fog.append({
			"pos": Vector2(randf_range(0.0, w), randf_range(h * 0.2, h * 0.95)),
			"speed": 4.0 + randf() * 9.0,
			"scale": 1.3 + randf() * 1.2,
			"alpha": 0.045 + randf() * 0.04,
		})
	for i in range(28):
		_embers.append({
			"pos": Vector2(randf_range(0.0, w), randf_range(0.0, h)),
			"speed": 18.0 + randf() * 42.0,
			"size": 1.2 + randf() * 2.4,
			"phase": randf() * TAU,
			"sway": 8.0 + randf() * 18.0,
		})
	for i in range(45):
		_stars.append({
			"pos": Vector2(randf_range(0.0, w), randf_range(0.0, h * 0.5)),
			"size": 0.8 + randf() * 1.4,
			"phase": randf() * TAU,
		})

func _process(delta: float) -> void:
	if _fog.is_empty() and size.y > 100.0:
		_populate()
	_time += delta
	var w := size.x
	for f in _fog:
		var pos: Vector2 = f["pos"]
		pos.x += float(f["speed"]) * delta
		if pos.x > w + 260.0:
			pos.x = -260.0
			pos.y = randf_range(size.y * 0.2, size.y * 0.95)
		f["pos"] = pos
	for e in _embers:
		var pos: Vector2 = e["pos"]
		pos.y -= float(e["speed"]) * delta
		if pos.y < -20.0:
			pos.y = size.y + 20.0
			pos.x = randf_range(0.0, maxf(w, 1.0))
		e["pos"] = pos
	queue_redraw()

func _draw() -> void:
	if _gradient != null:
		draw_texture_rect(_gradient, Rect2(Vector2.ZERO, size), false)
	_draw_stars()
	_draw_moon()
	_draw_fog()
	_draw_embers()
	_draw_vignette()

func _draw_stars() -> void:
	for st in _stars:
		var a := 0.25 + 0.4 * (0.5 + 0.5 * sin(_time * 1.6 + float(st["phase"])))
		draw_circle(st["pos"], float(st["size"]), Color(0.8, 0.88, 1.0, a))

func _draw_moon() -> void:
	var c := Vector2(size.x - 70.0, 150.0)
	var pulse := 0.02 * sin(_time * 1.2)
	draw_circle(c, 110.0, Color(0.85, 0.15, 0.2, 0.06 + pulse))
	draw_circle(c, 82.0, Color(0.9, 0.3, 0.3, 0.09 + pulse))
	draw_circle(c, 60.0, Color(0.95, 0.5, 0.45, 0.12))
	draw_circle(c, 42.0, Color("#e9d7d0"))
	draw_circle(c + Vector2(-12, -8), 9.0, Color("#cdb7b3"))
	draw_circle(c + Vector2(12, 10), 6.0, Color("#cdb7b3"))
	draw_circle(c + Vector2(6, -16), 4.0, Color("#d8c3be"))

func _draw_fog() -> void:
	for f in _fog:
		var pos: Vector2 = f["pos"]
		var sc: float = f["scale"]
		var a: float = f["alpha"]
		draw_set_transform(pos, 0.0, Vector2(1.0, 0.32))
		draw_circle(Vector2.ZERO, 140.0 * sc, Color(0.45, 0.52, 0.75, a))
		draw_circle(Vector2(40.0, 0.0) * sc, 90.0 * sc, Color(0.55, 0.6, 0.85, a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_embers() -> void:
	for e in _embers:
		var base: Vector2 = e["pos"]
		var ph: float = e["phase"]
		var flicker := 0.5 + 0.5 * sin(_time * 5.0 + ph)
		var pos := Vector2(base.x + sin(_time * 0.9 + ph) * float(e["sway"]), base.y)
		var r: float = e["size"]
		draw_circle(pos, r * 2.8, Color(1.0, 0.4, 0.1, 0.07 + 0.05 * flicker))
		draw_circle(pos, r, Color(1.0, 0.55 + 0.25 * flicker, 0.18, 0.5 + 0.4 * flicker))

func _draw_vignette() -> void:
	var w := size.x
	var h := size.y
	var d := 200.0
	var dark := Color(0, 0, 0, 0.7)
	var clear := Color(0, 0, 0, 0)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, d), Vector2(0, d)]),
		PackedColorArray([dark, dark, clear, clear]))
	draw_polygon(PackedVector2Array([Vector2(0, h - d), Vector2(w, h - d), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([clear, clear, dark, dark]))
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(d, 0), Vector2(d, h), Vector2(0, h)]),
		PackedColorArray([dark, clear, clear, dark]))
	draw_polygon(PackedVector2Array([Vector2(w - d, 0), Vector2(w, 0), Vector2(w, h), Vector2(w - d, h)]),
		PackedColorArray([clear, dark, dark, clear]))
