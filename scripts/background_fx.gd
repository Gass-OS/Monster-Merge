extends Control
class_name BackgroundFX

## Animated cartoon sky: vertical gradient, rotating-ray sun, drifting
## clouds and gently rising sparkles / bubbles. Pure procedural drawing,
## no external assets. Redraws every frame from _process.

var _time := 0.0
var _gradient: GradientTexture2D
var _clouds: Array = []
var _sparkles: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var grad := Gradient.new()
	grad.set_color(0, Color("#79d2f7"))
	grad.set_color(1, Color("#d8f8ef"))
	grad.add_point(0.55, Color("#a9e7f6"))
	_gradient = GradientTexture2D.new()
	_gradient.gradient = grad
	_gradient.fill_from = Vector2(0.5, 0.0)
	_gradient.fill_to = Vector2(0.5, 1.0)
	_gradient.width = 16
	_gradient.height = 512
	for i in range(6):
		_clouds.append({
			"pos": Vector2(randf_range(0.0, 720.0), randf_range(60.0, 560.0)),
			"speed": 6.0 + randf() * 10.0,
			"scale": 0.7 + randf() * 0.7,
		})
	for i in range(14):
		_sparkles.append({
			"pos": Vector2(randf_range(0.0, 720.0), randf_range(0.0, 1280.0)),
			"speed": 12.0 + randf() * 22.0,
			"size": 2.0 + randf() * 3.5,
			"phase": randf() * TAU,
			"sway": 8.0 + randf() * 14.0,
			"star": randi() % 3 == 0,
		})
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	_time += delta
	var w := size.x
	for cloud in _clouds:
		var pos: Vector2 = cloud["pos"]
		pos.x += float(cloud["speed"]) * delta
		if pos.x > w + 130.0:
			pos.x = -130.0
			pos.y = randf_range(60.0, 560.0)
		cloud["pos"] = pos
	for sp in _sparkles:
		var pos: Vector2 = sp["pos"]
		pos.y -= float(sp["speed"]) * delta
		if pos.y < -20.0:
			pos.y = size.y + 20.0
			pos.x = randf_range(0.0, maxf(w, 1.0))
		sp["pos"] = pos
	queue_redraw()

func _draw() -> void:
	if _gradient != null:
		draw_texture_rect(_gradient, Rect2(Vector2.ZERO, size), false)
	_draw_sun()
	_draw_clouds()
	_draw_sparkles()

func _draw_sun() -> void:
	# Tucked into the right-hand gap between the title and the board.
	var c := Vector2(size.x - 78.0, 208.0)
	draw_circle(c, 82.0, Color(1.0, 0.9, 0.45, 0.10))
	draw_circle(c, 64.0, Color(1.0, 0.9, 0.45, 0.14))
	for i in range(12):
		var ang := _time * 0.12 + float(i) * TAU / 12.0
		var dir := Vector2(cos(ang), sin(ang))
		draw_line(c + dir * 50.0, c + dir * 72.0, Color(1.0, 0.85, 0.3, 0.55), 5.0, true)
	draw_circle(c, 42.0, Color("#ffd94d"))
	draw_circle(c, 33.0, Color("#ffe98a"))

func _draw_clouds() -> void:
	for cloud in _clouds:
		var pos: Vector2 = cloud["pos"]
		var sc: float = cloud["scale"]
		var col := Color(1, 1, 1, 0.45)
		draw_circle(pos, 34.0 * sc, col)
		draw_circle(pos + Vector2(30, 5) * sc, 27.0 * sc, col)
		draw_circle(pos + Vector2(-28, 10) * sc, 24.0 * sc, col)

func _draw_sparkles() -> void:
	for sp in _sparkles:
		var base: Vector2 = sp["pos"]
		var alpha := 0.35 + 0.3 * sin(_time * 2.0 + float(sp["phase"]))
		var pos := Vector2(base.x + sin(_time * 0.8 + float(sp["phase"])) * float(sp["sway"]), base.y)
		var r: float = sp["size"]
		if bool(sp["star"]):
			_draw_star(pos, r * 1.6, Color(1.0, 0.95, 0.6, alpha))
		else:
			draw_arc(pos, r, 0.0, TAU, 16, Color(1, 1, 1, alpha), 1.5, true)
			draw_circle(pos + Vector2(-r * 0.3, -r * 0.3), r * 0.35, Color(1, 1, 1, alpha))

func _draw_star(pos: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(8):
		var ang := float(i) * PI / 4.0
		var rad := r if i % 2 == 0 else r * 0.3
		pts.append(pos + Vector2(cos(ang), sin(ang)) * rad)
	draw_colored_polygon(pts, col)
