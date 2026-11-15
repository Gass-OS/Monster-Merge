extends Control
class_name BigWinOverlay

## Casino-style "BIG WIN" celebration, fully drawn in code (no emoji, no
## image files): dimmed backdrop, rotating gold sunburst, marquee panel with
## chasing light bulbs, a gold trophy with a shine sweep, a counting-up coin
## amount, coin rain and twinkling stars.
##
## Use through WinEffects.big_win(title, amount, level):
##   level 1 NICE WIN   (short, does not block input)
##   level 2 BIG WIN
##   level 3 MEGA WIN
##   level 4 SUPER / JACKPOT (rainbow title, longest, most coins)
## Tap anywhere (after ~0.9 s) to close early.

signal finished

const LEVELS := [
	{"secs": 2.8, "coins": 24, "rays": 10},
	{"secs": 3.8, "coins": 46, "rays": 12},
	{"secs": 4.6, "coins": 70, "rays": 14},
	{"secs": 5.6, "coins": 96, "rays": 16},
]

var _level: int = 2
var _t: float = 0.0
var _duration: float = 3.0
var _active: bool = false
var _closing: bool = false
var _modal: bool = true
var _amount: int = 0
var _dim: float = 0.0
var _flash: float = 0.0
var _shake: float = 0.0
var _spawned: int = 0
var _total_coins: int = 40
var _rays: int = 12
var _coins: Array = []
var _stars: Array = []
var _intro_done: bool = false
var _title_label: Label
var _amount_row: HBoxContainer
var _amount_label: Label
var _count_tween: Tween
var _intro_tween: Tween
var _close_tween: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_color_override("font_color", Color("#ffe27b"))
	_title_label.add_theme_color_override("font_outline_color", Color("#7a3b05"))
	_title_label.add_theme_constant_override("outline_size", 12)
	_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_title_label.add_theme_constant_override("shadow_offset_x", 3)
	_title_label.add_theme_constant_override("shadow_offset_y", 5)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_label)
	_amount_row = HBoxContainer.new()
	_amount_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_amount_row.add_theme_constant_override("separation", 12)
	_amount_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_amount_row)
	var coin := CoinIcon.new()
	coin.custom_minimum_size = Vector2(54, 54)
	_amount_row.add_child(coin)
	_amount_label = Label.new()
	_amount_label.add_theme_font_size_override("font_size", 54)
	_amount_label.add_theme_color_override("font_color", Color("#fff2a0"))
	_amount_label.add_theme_color_override("font_outline_color", Color("#7a3b05"))
	_amount_label.add_theme_constant_override("outline_size", 9)
	_amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_amount_row.add_child(_amount_label)

# ---------------------------------------------------------------- public

func play(title: String, amount: int = 0, level: int = 2) -> void:
	if not is_inside_tree() or _title_label == null:
		return
	_kill_tweens()
	_level = clampi(level, 1, 4)
	var cfg: Dictionary = LEVELS[_level - 1]
	_duration = float(cfg["secs"])
	_total_coins = int(cfg["coins"])
	_rays = int(cfg["rays"])
	_modal = _level >= 2
	mouse_filter = Control.MOUSE_FILTER_STOP if _modal else Control.MOUSE_FILTER_IGNORE
	_amount = maxi(0, amount)
	_t = 0.0
	_dim = 0.0
	_flash = 0.55
	_shake = 1.0
	_spawned = 0
	_closing = false
	_intro_done = false
	_active = true
	_coins.clear()
	_build_stars()
	modulate = Color(1, 1, 1, 1)
	visible = true

	var fs := clampi(int(68.0 - maxf(0.0, float(title.length() - 8)) * 2.8), 34, 68)
	_title_label.text = title
	_title_label.add_theme_font_size_override("font_size", fs)
	_title_label.modulate = Color.WHITE
	_layout()
	_title_label.pivot_offset = _title_label.size * 0.5
	_title_label.scale = Vector2(0.2, 0.2)
	_intro_tween = create_tween()
	_intro_tween.tween_property(_title_label, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_callback(_on_intro_done)

	_amount_row.visible = _amount > 0
	_amount_row.modulate.a = 0.0
	if _amount > 0:
		_set_shown(0.0)
		_count_tween = create_tween()
		_count_tween.tween_interval(0.35)
		_count_tween.tween_property(_amount_row, "modulate:a", 1.0, 0.2)
		var count_time := minf(1.9, _duration - 1.1)
		_count_tween.tween_method(_set_shown, 0.0, float(_amount), maxf(0.6, count_time)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if _level >= 2:
		var confetti := ConfettiFX.new()
		confetti.count = 80 + _level * 20
		confetti.duration = _duration
		add_child(confetti)
		move_child(confetti, 0)
	_sfx("play_fanfare")
	if _level >= 2:
		_sfx("play_applause")
	_sfx("play_coin_shower")

func is_playing() -> bool:
	return _active

# --------------------------------------------------------------- internals

func _on_intro_done() -> void:
	_intro_done = true

func _kill_tweens() -> void:
	for tw in [_count_tween, _intro_tween, _close_tween]:
		if tw != null and tw.is_valid():
			tw.kill()

func _set_shown(value: float) -> void:
	if _amount_label != null:
		_amount_label.text = "+" + _commas(int(value))

static func _commas(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out

func _view_size() -> Vector2:
	if size.x < 10.0 or size.y < 10.0:
		return Vector2(720.0, 1280.0)
	return size

func _center() -> Vector2:
	var v := _view_size()
	return Vector2(v.x * 0.5, v.y * 0.42)

func _layout() -> void:
	var c := _center()
	_title_label.size = Vector2(640.0, 100.0)
	_title_label.position = Vector2(c.x - 320.0, c.y + 4.0)
	_amount_row.size = Vector2(640.0, 66.0)
	_amount_row.position = Vector2(c.x - 320.0, c.y + 108.0)

func _build_stars() -> void:
	_stars.clear()
	for i in range(18):
		_stars.append({
			"ang": randf() * TAU,
			"rad": randf_range(110.0, 330.0),
			"size": randf_range(7.0, 16.0),
			"phase": randf() * TAU,
		})

func _gui_input(event: InputEvent) -> void:
	if not _active or not _modal or _closing or _t < 0.9:
		return
	var pressed := false
	if event is InputEventScreenTouch and event.pressed:
		pressed = true
	elif event is InputEventMouseButton and event.pressed:
		pressed = true
	if pressed:
		_close()
		accept_event()

func _close() -> void:
	if _closing:
		return
	_closing = true
	_close_tween = create_tween()
	_close_tween.tween_property(self, "modulate:a", 0.0, 0.35)
	_close_tween.tween_callback(_on_closed)

func _on_closed() -> void:
	_active = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coins.clear()
	finished.emit()

func _sfx(method_name: String) -> void:
	var sm := get_node_or_null("/root/SoundManager")
	if sm != null and sm.has_method(method_name):
		sm.call(method_name)

func _process(delta: float) -> void:
	if not _active:
		return
	_t += delta
	_dim = minf(1.0, _t * 4.0)
	_flash = maxf(0.0, _flash - delta * 2.2)
	_shake = maxf(0.0, _shake - delta * 2.4)
	_update_coins(delta)
	if _intro_done and _title_label != null:
		_title_label.scale = Vector2.ONE * (1.0 + 0.03 * sin(_t * 6.0))
	if _level >= 4 and _title_label != null:
		_title_label.modulate = Color.from_hsv(fposmod(_t * 0.45, 1.0), 0.35, 1.0)
	if _t >= _duration and not _closing:
		_close()
	queue_redraw()

func _update_coins(delta: float) -> void:
	var v := _view_size()
	var rain_secs := minf(_duration - 0.8, 2.6)
	var want := _total_coins
	if rain_secs > 0.0:
		want = mini(_total_coins, int(_t / rain_secs * float(_total_coins)))
	var c := _center()
	while _spawned < want:
		_spawned += 1
		var burst := _spawned <= 12
		var coin := {
			"pos": Vector2(c.x + randf_range(-40.0, 40.0), c.y - 120.0) if burst else Vector2(randf_range(0.0, v.x), -30.0),
			"vel": Vector2(randf_range(-320.0, 320.0), randf_range(-760.0, -420.0)) if burst else Vector2(randf_range(-60.0, 60.0), randf_range(120.0, 320.0)),
			"rot": randf() * TAU,
			"spin": randf_range(6.0, 14.0),
			"size": randf_range(11.0, 19.0),
		}
		_coins.append(coin)
	var alive: Array = []
	for coin in _coins:
		var vel: Vector2 = coin["vel"]
		vel.y += 1100.0 * delta
		var pos: Vector2 = coin["pos"] + vel * delta
		coin["vel"] = vel
		coin["pos"] = pos
		coin["rot"] = float(coin["rot"]) + float(coin["spin"]) * delta
		if pos.y < v.y + 40.0:
			alive.append(coin)
	_coins = alive

# ----------------------------------------------------------------- drawing

func _draw() -> void:
	if not _active:
		return
	var v := _view_size()
	var c := _center()
	draw_rect(Rect2(Vector2.ZERO, v), Color(0.02, 0.0, 0.06, 0.74 * _dim))
	var off := Vector2(sin(_t * 70.0), cos(_t * 63.0)) * 7.0 * _shake
	draw_set_transform(off, 0.0, Vector2.ONE)
	_draw_rays(c + Vector2(0, 60), v)
	_draw_marquee(c)
	_draw_trophy(c + Vector2(0, -150), 1.0 + 0.06 * float(_level - 1))
	_draw_stars(c + Vector2(0, -110))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_coins()
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, v), Color(1.0, 0.95, 0.7, _flash))

func _draw_rays(center: Vector2, v: Vector2) -> void:
	var radius := maxf(v.x, v.y) * 1.2
	var half := TAU / float(_rays) * 0.26
	var base := _t * 0.35
	for i in range(_rays):
		var ang := base + float(i) * TAU / float(_rays)
		var a1 := ang - half
		var a2 := ang + half
		var alpha := (0.20 if i % 2 == 0 else 0.11) * _dim
		draw_colored_polygon(PackedVector2Array([
			center,
			center + Vector2(cos(a1), sin(a1)) * radius,
			center + Vector2(cos(a2), sin(a2)) * radius]), Color(1.0, 0.82, 0.25, alpha))
	draw_circle(center, 300.0, Color(1.0, 0.8, 0.2, 0.07 * _dim))
	draw_circle(center, 210.0, Color(1.0, 0.85, 0.3, 0.09 * _dim))

func _draw_marquee(c: Vector2) -> void:
	var rect := Rect2(c.x - 330.0, c.y - 18.0, 660.0, 200.0)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.1, 0.04, 0.08, 0.92)
	panel.border_color = Color("#f8c43b")
	panel.set_border_width_all(6)
	panel.set_corner_radius_all(30)
	panel.shadow_color = Color(1.0, 0.7, 0.1, 0.35)
	panel.shadow_size = 18
	draw_style_box(panel, rect)
	var inner := StyleBoxFlat.new()
	inner.bg_color = Color(0, 0, 0, 0)
	inner.border_color = Color("#b3262e")
	inner.set_border_width_all(3)
	inner.set_corner_radius_all(22)
	draw_style_box(inner, rect.grow(-14.0))
	# Chasing bulbs around the frame.
	var step := 36.0
	var idx := 0
	var phase := int(_t * 10.0)
	var left := rect.position.x + 8.0
	var right := rect.end.x - 8.0
	var top := rect.position.y + 8.0
	var bottom := rect.end.y - 8.0
	var x := left + 22.0
	while x <= right - 22.0:
		_bulb(Vector2(x, top), idx, phase)
		idx += 1
		_bulb(Vector2(x, bottom), idx, phase)
		idx += 1
		x += step
	var y := top + 30.0
	while y <= bottom - 30.0:
		_bulb(Vector2(left, y), idx, phase)
		idx += 1
		_bulb(Vector2(right, y), idx, phase)
		idx += 1
		y += step

func _bulb(pos: Vector2, idx: int, phase: int) -> void:
	var on := ((idx + phase) % 3) != 0
	if on:
		draw_circle(pos, 11.0, Color(1.0, 0.85, 0.3, 0.30))
		draw_circle(pos, 5.5, Color("#fff2a0"))
	else:
		draw_circle(pos, 5.0, Color("#6b5420"))

func _draw_trophy(c: Vector2, s: float) -> void:
	var gold := Color("#ffcf3d")
	var dark := Color("#c98716")
	var light := Color("#fff0a0")
	var pop := 1.0 + 0.04 * sin(_t * 5.0)
	var k := s * pop
	draw_circle(c, 130.0 * k, Color(1.0, 0.85, 0.3, 0.10 * _dim))
	draw_circle(c, 92.0 * k, Color(1.0, 0.85, 0.3, 0.14 * _dim))
	# Base and stem.
	draw_rect(Rect2(c + Vector2(-48, 72) * k, Vector2(96, 18) * k), dark)
	draw_rect(Rect2(c + Vector2(-36, 56) * k, Vector2(72, 18) * k), gold)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-11, 58) * k, c + Vector2(11, 58) * k,
		c + Vector2(17, 22) * k, c + Vector2(-17, 22) * k]), dark)
	# Handles.
	draw_arc(c + Vector2(-58, -42) * k, 26.0 * k, PI * 0.5, PI * 1.5, 16, gold, 9.0 * k, true)
	draw_arc(c + Vector2(58, -42) * k, 26.0 * k, -PI * 0.5, PI * 0.5, 16, gold, 9.0 * k, true)
	# Cup bowl: flat top, half-ellipse bottom.
	var bowl := PackedVector2Array()
	bowl.append(c + Vector2(-56, -74) * k)
	bowl.append(c + Vector2(56, -74) * k)
	for i in range(13):
		var a := PI * float(i) / 12.0
		bowl.append(c + Vector2(cos(a) * 56.0, -74.0 + sin(a) * 104.0) * k)
	draw_colored_polygon(bowl, gold)
	# Right-side shading and left highlight.
	draw_set_transform(c + Vector2(30, -26) * k + off_hold(), 0.0, Vector2(0.3, 1.0))
	draw_circle(Vector2.ZERO, 36.0 * k, Color(0.78, 0.5, 0.08, 0.35))
	draw_set_transform(c + Vector2(-28, -30) * k + off_hold(), 0.0, Vector2(0.26, 1.0))
	draw_circle(Vector2.ZERO, 38.0 * k, Color(1, 1, 1, 0.38))
	draw_set_transform(off_hold(), 0.0, Vector2.ONE)
	draw_rect(Rect2(c + Vector2(-62, -84) * k, Vector2(124, 14) * k), light)
	# Star emblem.
	var star := PackedVector2Array()
	for i in range(10):
		var ang := -PI * 0.5 + float(i) * PI / 5.0
		var rad := (21.0 if i % 2 == 0 else 9.0) * k
		star.append(c + Vector2(0, -36) * k + Vector2(cos(ang), sin(ang)) * rad)
	draw_colored_polygon(star, light)
	# Shine sweep across the cup.
	var sweep := fposmod(_t * 0.9, 1.8)
	if sweep < 1.0:
		var sx := (sweep - 0.5) * 120.0
		_sparkle(c + Vector2(sx, -52) * k, 15.0 * k, Color(1, 1, 1, 0.9))

func off_hold() -> Vector2:
	return Vector2(sin(_t * 70.0), cos(_t * 63.0)) * 7.0 * _shake

func _draw_stars(center: Vector2) -> void:
	for st in _stars:
		var phase: float = st["phase"]
		var a := 0.25 + 0.75 * absf(sin(_t * 3.0 + phase))
		var ang: float = float(st["ang"]) + _t * 0.15
		var pos := center + Vector2(cos(ang), sin(ang)) * float(st["rad"])
		_sparkle(pos, float(st["size"]) * (0.6 + 0.6 * a), Color(1.0, 0.95, 0.7, a * _dim))

func _sparkle(pos: Vector2, r: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(0, -r), pos + Vector2(r * 0.25, -r * 0.25),
		pos + Vector2(r, 0), pos + Vector2(r * 0.25, r * 0.25),
		pos + Vector2(0, r), pos + Vector2(-r * 0.25, r * 0.25),
		pos + Vector2(-r, 0), pos + Vector2(-r * 0.25, -r * 0.25)]), col)

func _draw_coins() -> void:
	for coin in _coins:
		var p: Vector2 = coin["pos"]
		var flip := maxf(0.18, absf(cos(float(coin["rot"]))))
		var r: float = coin["size"]
		draw_set_transform(p, 0.0, Vector2(flip, 1.0))
		draw_circle(Vector2.ZERO, r, Color("#c98716"))
		draw_circle(Vector2.ZERO, r * 0.84, Color("#ffcf3d"))
		draw_circle(Vector2.ZERO, r * 0.58, Color("#ffe27b"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
