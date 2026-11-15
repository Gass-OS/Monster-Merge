extends Control
class_name BackgroundFX

## Animated cartoon sky: vertical gradient, rotating-ray sun, drifting
## clouds and gently rising sparkles / bubbles. Pure procedural drawing,
## no external assets. Redraws every frame from _process.
##
## THEMES (v1.3, Worker D) — all cheerful, none of them the old dark look:
##   "sunny"  — the v1.2 bright sky + sun (DEFAULT, unchanged look)
##   "sunset" — warm orange/pink gradient, low big sun, pink clouds
##   "night"  — deep blue sky, twinkling stars, a SMILING moon, fireflies
##   "candy"  — pink/purple pastel gradient, candy clouds, heart sparkles
## API (the coordinator wires the settings worker to this):
##   apply_theme("sunset") -> String   # instant, queue_redraw; returns the
##                                     # theme actually applied ("sunny" on
##                                     # unknown names). The settings worker
##                                     # persists the choice; this only applies it.
##   get_current_theme() -> String    # (named so, not get_theme(), because
##                                     # Control already has a native get_theme)
##   get_accent_color() -> Color       # board-frame accent for this theme
##   show_rainbow()                    # rainbow fades in/out over ~4 s
## Attractions (cheap procedural life, drawn here, no new textures):
##   a hot-air balloon drifting across the sky (loops), 2-3 butterflies
##   fluttering on sine paths. Both run in every theme.

const THEME_NAMES := ["sunny", "sunset", "night", "candy", "shadow"]

# Stage backgrounds: the sky tint + signature particles change with the
# highest monster tier reached (stage 1..8).
const STAGE_NAMES := ["Sunny Meadow", "Slime Swamp", "Dino Valley", "Flame Peak",
	"Phoenix Sky", "Crystal Grove", "Robo City", "Cosmic Realm"]
const STAGE_TINTS := [Color(0, 0, 0, 0), Color("#2fbf6b"), Color("#d98a2b"), Color("#e8452c"),
	Color("#b04dff"), Color("#2fd6e8"), Color("#3a6bff"), Color("#7a2bd6")]
# Particle drift velocity per stage (index 0 = stage 1, unused).
const STAGE_VEL := [Vector2.ZERO, Vector2(0, -26), Vector2(-12, 38), Vector2(0, -60),
	Vector2(10, -20), Vector2(0, 14), Vector2(0, 190), Vector2(-140, 90)]

var current_theme: String = "sunny"
var _stage: int = 1
var _prev_stage: int = 1
var _stage_fade: float = 1.0
var _stage_fx: Array = []

var _time := 0.0
var _gradient: GradientTexture2D
var _clouds: Array = []
var _sparkles: Array = []
# Per-theme palette, set by _apply_palette().
var _sky_top := Color("#79d2f7")
var _sky_mid := Color("#a9e7f6")
var _sky_bottom := Color("#d8f8ef")
var _sun_color := Color("#ffd94d")
var _sun_core := Color("#ffe98a")
var _sun_pos := Vector2(642.0, 208.0)
var _sun_radius := 42.0
var _cloud_color := Color(1, 1, 1, 0.45)
var _sparkle_color := Color(1.0, 0.95, 0.6)
var _accent := Color("#168c91")
var _is_night := false
var _is_shadow := false
# Attractions.
var _balloon := {"pos": Vector2(-90.0, 170.0), "speed": 11.0}
var _butterflies: Array = []
var _rainbow_t := -1.0  # < 0 = hidden; 0..4 s while showing.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply_palette("sunny")
	_rebuild_gradient()
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
	for i in range(3):
		_butterflies.append({
			"base": Vector2(randf_range(80.0, 640.0), randf_range(300.0, 700.0)),
			"phase": randf() * TAU,
			"speed": 0.5 + randf() * 0.5,
			"color": [Color("#ff8fc7"), Color("#7fd4ff"), Color("#ffd94d")][i],
		})
	resized.connect(queue_redraw)

# --- Themes -----------------------------------------------------------------

func apply_theme(theme_name: String) -> String:
	var name := theme_name.to_lower().strip_edges()
	if not THEME_NAMES.has(name):
		name = "sunny"
	current_theme = name
	_apply_palette(name)
	_rebuild_gradient()
	queue_redraw()
	return current_theme

## Called by the UI whenever the highest unlocked tier changes.
func set_stage(stage: int) -> void:
	var s := clampi(stage, 1, STAGE_NAMES.size())
	if s == _stage:
		return
	_prev_stage = _stage
	_stage = s
	_populate_stage_fx()
	if is_inside_tree():
		_stage_fade = 0.0
		var tw := create_tween()
		tw.tween_property(self, "_stage_fade", 1.0, 1.6)
	else:
		_stage_fade = 1.0
	queue_redraw()

func get_stage() -> int:
	return _stage

func _populate_stage_fx() -> void:
	_stage_fx.clear()
	if _stage <= 1:
		return
	var w := maxf(size.x, 720.0)
	var h := maxf(size.y, 1280.0)
	for i in range(26):
		_stage_fx.append({
			"pos": Vector2(randf_range(0.0, w), randf_range(0.0, h)),
			"speed": 0.6 + randf() * 0.9,
			"size": 2.0 + randf() * 4.0,
			"phase": randf() * TAU,
		})

func _update_stage_fx(delta: float) -> void:
	if _stage <= 1:
		return
	var vel: Vector2 = STAGE_VEL[_stage - 1]
	var w := maxf(size.x, 720.0)
	var h := maxf(size.y, 1280.0)
	for p in _stage_fx:
		var pos: Vector2 = p["pos"]
		pos += vel * float(p["speed"]) * delta
		if pos.y < -30.0:
			pos.y = h + 30.0
		elif pos.y > h + 30.0:
			pos.y = -30.0
		if pos.x < -30.0:
			pos.x = w + 30.0
		elif pos.x > w + 30.0:
			pos.x = -30.0
		p["pos"] = pos

func _draw_stage_tint() -> void:
	var strength := 0.16 if _is_shadow else 0.22
	var full := Rect2(Vector2.ZERO, size)
	if _stage > 1:
		var tint: Color = STAGE_TINTS[_stage - 1]
		draw_rect(full, Color(tint, strength * _stage_fade))
	if _prev_stage > 1 and _stage_fade < 1.0:
		var prev: Color = STAGE_TINTS[_prev_stage - 1]
		draw_rect(full, Color(prev, strength * (1.0 - _stage_fade)))

func _draw_stage_fx() -> void:
	if _stage <= 1:
		return
	var vel: Vector2 = STAGE_VEL[_stage - 1]
	for p in _stage_fx:
		var pos: Vector2 = p["pos"]
		var r: float = p["size"]
		var ph: float = p["phase"]
		var tw := 0.5 + 0.5 * sin(_time * 3.0 + ph)
		match _stage:
			2:
				# Swamp bubbles.
				draw_arc(pos, r * 2.0, 0.0, TAU, 16, Color(0.7, 1.0, 0.8, 0.55), 1.6, true)
				draw_circle(pos + Vector2(-r * 0.6, -r * 0.6), r * 0.4, Color(1, 1, 1, 0.6))
			3:
				# Drifting autumn leaves.
				draw_set_transform(pos, _time * 0.8 + ph, Vector2(1.0, 0.5))
				draw_circle(Vector2.ZERO, r * 2.2, Color(0.9, 0.55, 0.15, 0.7))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			4:
				# Rising embers.
				draw_circle(pos, r * 2.2, Color(1.0, 0.4, 0.1, 0.10 + 0.08 * tw))
				draw_circle(pos, r * 0.8, Color(1.0, 0.6 + 0.2 * tw, 0.2, 0.8))
			5:
				# Golden sparks.
				_draw_star(pos, r * 1.8, Color(1.0, 0.85, 0.3, 0.35 + 0.4 * tw))
			6:
				# Twinkling crystals.
				draw_colored_polygon(PackedVector2Array([
					pos + Vector2(0, -r * 2.2), pos + Vector2(r * 1.2, 0),
					pos + Vector2(0, r * 2.2), pos + Vector2(-r * 1.2, 0)]), Color(0.6, 0.95, 1.0, 0.25 + 0.4 * tw))
			7:
				# Digital rain.
				draw_line(pos, pos - Vector2(0, 34.0 + r * 4.0), Color(0.3, 0.9, 1.0, 0.35), 2.0, true)
				draw_circle(pos, 2.4, Color(0.8, 1.0, 1.0, 0.9))
			8:
				# Shooting stars.
				var dir := vel.normalized()
				draw_line(pos, pos - dir * (30.0 + r * 6.0), Color(1.0, 0.95, 1.0, 0.45), 2.0, true)
				draw_circle(pos, r * 0.7, Color(1, 1, 1, 0.9))

func get_current_theme() -> String:
	return current_theme

func get_accent_color() -> Color:
	return _accent

func _apply_palette(name: String) -> void:
	_is_night = false
	_is_shadow = false
	match name:
		"sunset":
			_sky_top = Color("#ff8c5a")
			_sky_mid = Color("#ff7a9e")
			_sky_bottom = Color("#ffd6a5")
			_sun_color = Color("#ff7a3d")
			_sun_core = Color("#ffb347")
			_sun_pos = Vector2(630.0, 320.0)
			_sun_radius = 58.0
			_cloud_color = Color(1.0, 0.82, 0.86, 0.55)
			_sparkle_color = Color(1.0, 0.75, 0.55)
			_accent = Color("#e2703a")
		"night":
			_is_night = true
			_sky_top = Color("#16265e")
			_sky_mid = Color("#274b8f")
			_sky_bottom = Color("#4a7ab5")
			_sun_color = Color("#fff8d0")
			_sun_core = Color("#fffbe8")
			_sun_pos = Vector2(642.0, 208.0)
			_sun_radius = 42.0
			_cloud_color = Color(0.56, 0.69, 0.88, 0.28)
			_sparkle_color = Color(1.0, 0.95, 0.6)
			_accent = Color("#3b6fd4")
		"shadow":
			# Dark-fantasy night: near-black sky, blood moon, fog, rising embers.
			_is_shadow = true
			_sky_top = Color("#04050b")
			_sky_mid = Color("#0f1a35")
			_sky_bottom = Color("#220d18")
			_sun_color = Color("#e9d7d0")
			_sun_core = Color("#f3e6e0")
			_sun_pos = Vector2(642.0, 208.0)
			_sun_radius = 40.0
			_cloud_color = Color(0.45, 0.52, 0.75, 0.07)
			_sparkle_color = Color(1.0, 0.55, 0.2)
			_accent = Color("#7a5a22")
		"candy":
			_sky_top = Color("#ffb3e6")
			_sky_mid = Color("#d9a7ff")
			_sky_bottom = Color("#ffe6f7")
			_sun_color = Color("#ff8fb3")
			_sun_core = Color("#ffc2d9")
			_sun_pos = Vector2(642.0, 208.0)
			_sun_radius = 42.0
			_cloud_color = Color(1.0, 0.94, 0.98, 0.6)
			_sparkle_color = Color(1.0, 0.65, 0.85)
			_accent = Color("#d6339c")
		_:
			# "sunny" — the exact v1.2 look. Do not change these values.
			_sky_top = Color("#79d2f7")
			_sky_mid = Color("#a9e7f6")
			_sky_bottom = Color("#d8f8ef")
			_sun_color = Color("#ffd94d")
			_sun_core = Color("#ffe98a")
			_sun_pos = Vector2(642.0, 208.0)
			_sun_radius = 42.0
			_cloud_color = Color(1, 1, 1, 0.45)
			_sparkle_color = Color(1.0, 0.95, 0.6)
			_accent = Color("#168c91")

func _rebuild_gradient() -> void:
	var grad := Gradient.new()
	grad.set_color(0, _sky_top)
	grad.set_color(1, _sky_bottom)
	grad.add_point(0.55, _sky_mid)
	_gradient = GradientTexture2D.new()
	_gradient.gradient = grad
	_gradient.fill_from = Vector2(0.5, 0.0)
	_gradient.fill_to = Vector2(0.5, 1.0)
	_gradient.width = 16
	_gradient.height = 512

# --- Attractions ------------------------------------------------------------

func show_rainbow() -> void:
	_rainbow_t = 0.0
	queue_redraw()

func _rainbow_alpha() -> float:
	if _rainbow_t < 0.0:
		return 0.0
	if _rainbow_t < 0.5:
		return _rainbow_t / 0.5
	if _rainbow_t < 3.0:
		return 1.0
	if _rainbow_t < 4.0:
		return 1.0 - (_rainbow_t - 3.0)
	return 0.0

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
	# Hot-air balloon drifts slowly across the sky, then loops back.
	var bpos: Vector2 = _balloon["pos"]
	bpos.x += float(_balloon["speed"]) * delta
	bpos.y = 170.0 + sin(_time * 0.25) * 18.0
	if bpos.x > w + 100.0:
		bpos.x = -100.0
	_balloon["pos"] = bpos
	if _rainbow_t >= 0.0:
		_rainbow_t += delta
		if _rainbow_t >= 4.0:
			_rainbow_t = -1.0
	_update_stage_fx(delta)
	queue_redraw()

func _draw() -> void:
	if _gradient != null:
		draw_texture_rect(_gradient, Rect2(Vector2.ZERO, size), false)
	_draw_stage_tint()
	if _is_shadow:
		_draw_shadow_moon()
		_draw_clouds()
		_draw_sparkles()
		_draw_stage_fx()
		_draw_vignette()
		return
	if _is_night:
		_draw_moon()
	else:
		_draw_sun()
	_draw_clouds()
	_draw_balloon()
	_draw_butterflies()
	_draw_rainbow()
	_draw_sparkles()
	_draw_stage_fx()

func _draw_sun() -> void:
	# Tucked into the right-hand gap between the title and the board.
	var c := Vector2(size.x - 78.0, _sun_pos.y)
	var r := _sun_radius
	draw_circle(c, r * 1.95, Color(_sun_color, 0.10))
	draw_circle(c, r * 1.52, Color(_sun_color, 0.14))
	for i in range(12):
		var ang := _time * 0.12 + float(i) * TAU / 12.0
		var dir := Vector2(cos(ang), sin(ang))
		draw_line(c + dir * (r + 8.0), c + dir * (r + 30.0), Color(1.0, 0.85, 0.3, 0.55), 5.0, true)
	draw_circle(c, r, _sun_color)
	draw_circle(c, r * 0.78, _sun_core)

func _draw_moon() -> void:
	# A friendly smiling moon in the same spot as the sun.
	var c := Vector2(size.x - 78.0, _sun_pos.y)
	var r := _sun_radius
	draw_circle(c, r * 1.6, Color(1.0, 0.98, 0.8, 0.10))
	draw_circle(c, r * 1.25, Color(1.0, 0.98, 0.8, 0.14))
	draw_circle(c, r, _sun_color)
	draw_circle(c, r * 0.85, _sun_core)
	# Sleepy happy face: closed smiling eyes + big smile.
	var eye_y := c.y - r * 0.15
	for ex in [-r * 0.35, r * 0.35]:
		draw_arc(c + Vector2(ex, eye_y), r * 0.16, PI * 0.15, PI * 0.85, 10, Color("#5a4a2a"), 2.5)
	draw_arc(c + Vector2(0, r * 0.05), r * 0.4, 0.3, PI - 0.3, 16, Color("#5a4a2a"), 2.5)
	# Rosy cheeks.
	draw_circle(c + Vector2(-r * 0.55, r * 0.25), r * 0.12, Color(1.0, 0.6, 0.65, 0.6))
	draw_circle(c + Vector2(r * 0.55, r * 0.25), r * 0.12, Color(1.0, 0.6, 0.65, 0.6))

func _draw_shadow_moon() -> void:
	# Blood moon with a slow pulsing halo, same spot as the sun.
	var c := Vector2(size.x - 78.0, _sun_pos.y)
	var r := _sun_radius
	var pulse := 0.02 * sin(_time * 1.2)
	draw_circle(c, r * 2.6, Color(0.85, 0.15, 0.2, 0.06 + pulse))
	draw_circle(c, r * 1.95, Color(0.9, 0.3, 0.3, 0.09 + pulse))
	draw_circle(c, r * 1.45, Color(0.95, 0.5, 0.45, 0.12))
	draw_circle(c, r, _sun_color)
	draw_circle(c + Vector2(-r * 0.28, -r * 0.2), r * 0.21, Color("#cdb7b3"))
	draw_circle(c + Vector2(r * 0.3, r * 0.25), r * 0.15, Color("#cdb7b3"))
	draw_circle(c + Vector2(r * 0.15, -r * 0.38), r * 0.1, Color("#d8c3be"))

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

func _draw_clouds() -> void:
	for cloud in _clouds:
		var pos: Vector2 = cloud["pos"]
		var sc: float = cloud["scale"]
		var col := _cloud_color
		draw_circle(pos, 34.0 * sc, col)
		draw_circle(pos + Vector2(30, 5) * sc, 27.0 * sc, col)
		draw_circle(pos + Vector2(-28, 10) * sc, 24.0 * sc, col)

func _draw_balloon() -> void:
	var pos: Vector2 = _balloon["pos"]
	# Envelope: squashed circle, red with a yellow band.
	draw_set_transform(pos, 0.0, Vector2(1.0, 0.85))
	draw_circle(Vector2.ZERO, 34.0, Color("#ff6b6b"))
	draw_circle(Vector2.ZERO, 34.0, Color(0, 0, 0, 0))  # no-op keeps transform obvious
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_set_transform(pos, 0.0, Vector2(1.0, 0.85))
	draw_arc(Vector2.ZERO, 34.0, -0.6, 0.6, 12, Color("#ffd94d"), 10.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Ropes + basket.
	var basket := pos + Vector2(0, 52.0)
	draw_line(pos + Vector2(-18, 24), basket + Vector2(-10, -6), Color("#8a5a2b"), 2.0)
	draw_line(pos + Vector2(18, 24), basket + Vector2(10, -6), Color("#8a5a2b"), 2.0)
	draw_rect(Rect2(basket - Vector2(11, 6), Vector2(22, 16)), Color("#a06a35"))
	draw_rect(Rect2(basket - Vector2(11, 6), Vector2(22, 16)), Color("#6e4420"), false, 2.0)

func _draw_butterflies() -> void:
	for bf in _butterflies:
		var base: Vector2 = bf["base"]
		var phase: float = bf["phase"]
		var speed: float = bf["speed"]
		var pos := base + Vector2(sin(_time * speed + phase) * 46.0, sin(_time * speed * 1.7 + phase * 2.0) * 26.0)
		var flap := 0.45 + 0.55 * absf(sin(_time * 9.0 + phase))
		var col: Color = bf["color"]
		# Two wings flapping (radius breathes with the flap) + tiny body.
		draw_circle(pos + Vector2(-7.0 * flap, -4.0), 6.0 * flap + 2.0, col)
		draw_circle(pos + Vector2(7.0 * flap, -4.0), 6.0 * flap + 2.0, col)
		draw_circle(pos + Vector2(-5.0 * flap, 5.0), 4.5 * flap + 1.5, Color(col, 0.75))
		draw_circle(pos + Vector2(5.0 * flap, 5.0), 4.5 * flap + 1.5, Color(col, 0.75))
		draw_circle(pos, 2.5, Color("#26374c"))

func _draw_rainbow() -> void:
	var a := _rainbow_alpha()
	if a <= 0.0:
		return
	var center := Vector2(size.x * 0.5, 980.0)
	var bands := [Color("#ff5d5d"), Color("#ff9f2e"), Color("#ffd94d"),
		Color("#72d64e"), Color("#4cc3ff"), Color("#7a6cff"), Color("#c06bff")]
	for i in range(bands.size()):
		var r := 420.0 - float(i) * 14.0
		draw_arc(center, r, PI, TAU, 64, Color(bands[i], 0.55 * a), 13.0, true)

func _draw_sparkles() -> void:
	for sp in _sparkles:
		var base: Vector2 = sp["pos"]
		var alpha := 0.35 + 0.3 * sin(_time * 2.0 + float(sp["phase"]))
		var pos := Vector2(base.x + sin(_time * 0.8 + float(sp["phase"])) * float(sp["sway"]), base.y)
		var r: float = sp["size"]
		if _is_shadow:
			# Dim stars; the rest are orange embers rising off the ground.
			if bool(sp["star"]):
				_draw_star(pos, r * 1.2, Color(0.8, 0.88, 1.0, alpha * 0.8))
			else:
				var flicker := 0.5 + 0.5 * sin(_time * 5.0 + float(sp["phase"]))
				draw_circle(pos, r * 2.4, Color(1.0, 0.4, 0.1, 0.07 + 0.05 * flicker))
				draw_circle(pos, r * 0.8, Color(1.0, 0.55 + 0.25 * flicker, 0.18, 0.5 + 0.4 * flicker))
		elif _is_night:
			# Stars twinkle; the rest are warm fireflies glowing softly.
			if bool(sp["star"]):
				_draw_star(pos, r * 1.6, Color(1.0, 0.98, 0.8, alpha + 0.25))
			else:
				draw_circle(pos, r * 1.4, Color(0.75, 1.0, 0.35, alpha * 0.8))
				draw_circle(pos, r * 0.6, Color(0.9, 1.0, 0.6, alpha))
		elif current_theme == "candy":
			# Pink hearts + white sparkles.
			if bool(sp["star"]):
				_draw_heart(pos, r * 1.8, Color(_sparkle_color, alpha + 0.2))
			else:
				_draw_star(pos, r * 1.6, Color(1, 1, 1, alpha))
		else:
			if bool(sp["star"]):
				_draw_star(pos, r * 1.6, Color(_sparkle_color, alpha))
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

func _draw_heart(pos: Vector2, r: float, col: Color) -> void:
	draw_circle(pos + Vector2(-r * 0.38, -r * 0.25), r * 0.5, col)
	draw_circle(pos + Vector2(r * 0.38, -r * 0.25), r * 0.5, col)
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-r * 0.85, -r * 0.05),
		pos + Vector2(r * 0.85, -r * 0.05),
		pos + Vector2(0, r * 0.95)]), col)
