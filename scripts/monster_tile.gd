extends Control
class_name MonsterTile

signal merge_requested(source_index: int, target_index: int)
# Tap-to-merge: a press + release without moving is a tap, not a drag.
signal tile_tapped(index: int)
# Emitted while dragging so the grid can highlight the drop target.
signal drag_hovered(source_index: int, global_position: Vector2)
signal drag_ended

const PALETTE := [
	Color("#49a9ed"), Color("#72d64e"), Color("#83c94d"), Color("#f27642"),
	Color("#f6c844"), Color("#8ce8ef"), Color("#8995a8"), Color("#9b6bdb")
]
const FACE_COLOR := Color("#26374c")
const CHEEK_COLOR := Color(1.0, 0.55, 0.6, 0.75)
const SILHOUETTE_COLOR := Color("#33475e")
const GLOW_COLORS := [
	Color("#4cc3ff"), Color("#58ff7a"), Color("#a6ff4f"), Color("#ff7a2e"),
	Color("#ffcc33"), Color("#7ff6ff"), Color("#5ad0ff"), Color("#c06bff")
]

var tile_index: int = -1
var tier: int = 0
var silhouette_mode: bool = false
var _press_position := Vector2.ZERO
var _dragging := false
var _pressed := false
# Tap-to-merge visuals (owned by the grid, drawn here).
var _selected := false
var _match_highlight := false
var _drop_highlight := false
var _drop_valid := true
var _pulse_t := 0.0
# --- Monster life (v1.3, Worker D; additive, cheap _draw/_process only) ----
var _anim_t := 0.0
var _bob_phase := 0.0
var _blink_timer := 3.0      # counts down to the next blink
var _blink_left := 0.0       # > 0 while the eyes are closed
var _blinking := false
var _wiggle_tween: Tween
var _pop_tween: Tween

func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(120, 136)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Different phase per tile so the board doesn't bob in sync.
	_bob_phase = float(tile_index if tile_index >= 0 else randi() % 16) * 0.9
	_blink_timer = randf_range(2.0, 5.0)
	queue_redraw()

func set_monster(new_tier: int) -> void:
	tier = clampi(new_tier, 0, 8)
	queue_redraw()

func set_silhouette(value: bool) -> void:
	silhouette_mode = value
	queue_redraw()

func _process(delta: float) -> void:
	_anim_t += delta
	_update_blink(delta)
	# Pulse the selection / match / drop rings while any of them is shown.
	if _selected or _match_highlight or _drop_highlight:
		_pulse_t += delta
	# Idle bob + blink need a redraw while a monster is shown; empty tiles
	# and highlight-only frames are the only ones that can skip it.
	if tier > 0:
		queue_redraw()
	elif _selected or _match_highlight or _drop_highlight:
		queue_redraw()

func _update_blink(delta: float) -> void:
	if _blinking:
		_blink_left -= delta
		if _blink_left <= 0.0:
			_blinking = false
			_blink_timer = randf_range(2.0, 5.0)
	else:
		_blink_timer -= delta
		if _blink_timer <= 0.0:
			_blinking = true
			_blink_left = 0.12  # eyes closed for ~0.12 s

## True while the eyes are drawn closed. The test scene reads this to
## prove the blink state cycles without watching pixels.
func is_blinking() -> bool:
	return _blinking

func _bob_offset() -> float:
	if tier <= 0:
		return 0.0
	return sin(_anim_t * 1.8 + _bob_phase) * 3.0

## Happy wiggle when tapped: quick side-to-side rotation wobble.
## Called from _finish_drag on a tap; the coordinator may also call it.
func play_wiggle() -> void:
	if tier <= 0 or not is_inside_tree():
		return
	pivot_offset = size * 0.5
	if _wiggle_tween != null and _wiggle_tween.is_valid():
		_wiggle_tween.kill()
	rotation = 0.0
	_wiggle_tween = create_tween()
	_wiggle_tween.tween_property(self, "rotation", 0.12, 0.07)
	_wiggle_tween.tween_property(self, "rotation", -0.10, 0.09)
	_wiggle_tween.tween_property(self, "rotation", 0.05, 0.07)
	_wiggle_tween.tween_property(self, "rotation", 0.0, 0.08)

## Merge squash-and-stretch, two steps: squash wide, then stretch tall,
## then settle. Replaces / complements the grid's single scale bounce;
## the coordinator calls this on the merged tile instead of (or after)
## the grid tween — both are guarded, calling twice is harmless.
func play_merge_pop() -> void:
	if tier <= 0 or not is_inside_tree():
		return
	pivot_offset = size * 0.5
	if _pop_tween != null and _pop_tween.is_valid():
		_pop_tween.kill()
	scale = Vector2.ONE
	_pop_tween = create_tween()
	_pop_tween.tween_property(self, "scale", Vector2(1.22, 0.78), 0.09)
	_pop_tween.tween_property(self, "scale", Vector2(0.92, 1.10), 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pop_tween.tween_property(self, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# --- Tap-to-merge visual state (set by the grid) ----------------------------

func set_selected(value: bool) -> void:
	_selected = value
	queue_redraw()

func is_selected() -> bool:
	return _selected

func set_match_highlight(value: bool) -> void:
	_match_highlight = value
	queue_redraw()

func is_match_highlighted() -> bool:
	return _match_highlight

func set_drop_highlight(value: bool, valid: bool = true) -> void:
	_drop_highlight = value
	_drop_valid = valid
	queue_redraw()

func is_drop_highlighted() -> bool:
	return _drop_highlight

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_pressed = true
			_dragging = false
			_press_position = event.position
		else:
			_finish_drag(get_global_transform_with_canvas() * event.position)
	elif event is InputEventScreenDrag and _pressed:
		if event.position.distance_to(_press_position) > 12.0:
			_dragging = true
		if _dragging and tier > 0:
			drag_hovered.emit(tile_index, get_global_transform_with_canvas() * event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressed = true
			_dragging = false
			_press_position = get_global_mouse_position()
		else:
			_finish_drag(get_global_mouse_position())
	elif event is InputEventMouseMotion and _pressed:
		if get_global_mouse_position().distance_to(_press_position) > 12.0:
			_dragging = true
		if _dragging and tier > 0:
			drag_hovered.emit(tile_index, get_global_mouse_position())

func _finish_drag(global_position: Vector2) -> void:
	if not _pressed:
		return
	_pressed = false
	drag_ended.emit()
	if _dragging:
		_dragging = false
		if tier > 0:
			var parent_grid := get_parent()
			if parent_grid:
				for tile in parent_grid.get_children():
					if tile is MonsterTile and tile.tile_index != tile_index and tile.get_global_rect().has_point(global_position):
						merge_requested.emit(tile_index, tile.tile_index)
						break
	else:
		# A press + release without moving is a tap, even on an empty tile
		# (the grid uses empty-tile taps to clear the selection).
		if tier > 0:
			play_wiggle()
		tile_tapped.emit(tile_index)

func _glow_color() -> Color:
	if silhouette_mode:
		return Color("#34425e")
	if tier <= 0:
		return Color("#27324a")
	return GLOW_COLORS[clampi(tier - 1, 0, GLOW_COLORS.size() - 1)]

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var was_sil := silhouette_mode
	var gc := _glow_color()
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("#d8f4f2") if tier == 0 else Color("#fff8df")
	panel.border_color = Color("#8ac9c5")
	panel.set_border_width_all(3)
	panel.set_corner_radius_all(18)
	draw_style_box(panel, rect)
	if tier == 0:
		draw_circle(size * 0.5, 13.0, Color("#b9dedb"))
		_draw_highlights(gc)
		return
	var center := Vector2(size.x * 0.5, size.y * 0.47 + _bob_offset())
	var s := minf(size.x, size.y) * 0.31
	# Soft coloured aura behind the creature (kept from v2, subtle and light).
	if not was_sil:
		for i in range(4):
			draw_circle(center, s * (1.75 - float(i) * 0.38), Color(gc, 0.045 + 0.008 * float(tier)))
	# Soft ground shadow (kept from v2, lightened for the bright theme).
	draw_set_transform(center + Vector2(0, s * 1.2), 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, s, Color(0, 0, 0, 0.15))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var body_color: Color = SILHOUETTE_COLOR if was_sil else PALETTE[tier - 1]
	_draw_creature(center, body_color)
	# Tier plate (kept from v2, recolored bright: cream plate, glow border,
	# dark navy text).
	var font := ThemeDB.fallback_font
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color("#fff8df")
	plate.border_color = gc
	plate.set_border_width_all(1)
	plate.set_corner_radius_all(6)
	draw_style_box(plate, Rect2(8, size.y - 26, size.x - 16, 20))
	draw_string(font, Vector2(8, size.y - 11), "TIER %d" % tier, HORIZONTAL_ALIGNMENT_CENTER, size.x - 16, 14, Color("#273b52"))
	_draw_highlights(gc)

func _draw_highlights(gc: Color) -> void:
	# Bright cartoon rings for tap-to-merge, drawn on top so they stay
	# visible. _pulse_t only advances while a ring is shown (_process).
	var pulse := 0.5 + 0.5 * sin(_pulse_t * 5.0)
	var rect := Rect2(Vector2.ZERO, size)
	if _match_highlight and not _selected:
		# Same-tier tiles pulse softly in the tier's glow colour:
		# "tap me, we can merge".
		var ring := StyleBoxFlat.new()
		ring.bg_color = Color(gc, 0.10 + 0.08 * pulse)
		ring.border_color = Color(gc, 0.55 + 0.35 * pulse)
		ring.set_border_width_all(4)
		ring.set_corner_radius_all(18)
		draw_style_box(ring, rect)
	if _drop_highlight:
		# Tile under the finger while dragging. Valid target: the tier's
		# glow colour; anything else: a neutral white ring.
		var ring := StyleBoxFlat.new()
		if _drop_valid:
			ring.bg_color = Color(gc, 0.12 + 0.06 * pulse)
			ring.border_color = Color(gc, 0.9)
			ring.set_border_width_all(6)
		else:
			ring.bg_color = Color(1, 1, 1, 0.05)
			ring.border_color = Color(1, 1, 1, 0.75)
			ring.set_border_width_all(3)
		ring.set_corner_radius_all(18)
		draw_style_box(ring, rect.grow(-2))
	if _selected:
		# Thick glowing ring + soft halo + white pinstripe.
		var halo := StyleBoxFlat.new()
		halo.bg_color = Color(gc, 0.08 + 0.06 * pulse)
		halo.border_color = Color(gc, 0.35 + 0.25 * pulse)
		halo.set_border_width_all(3)
		halo.set_corner_radius_all(20)
		draw_style_box(halo, rect.grow(3))
		var ring := StyleBoxFlat.new()
		ring.bg_color = Color(gc, 0.10)
		ring.border_color = Color(gc, 0.95)
		ring.set_border_width_all(5)
		ring.set_corner_radius_all(18)
		draw_style_box(ring, rect.grow(-2))
		var inner := StyleBoxFlat.new()
		inner.bg_color = Color(0, 0, 0, 0)
		inner.border_color = Color(1, 1, 1, 0.85)
		inner.set_border_width_all(2)
		inner.set_corner_radius_all(15)
		draw_style_box(inner, rect.grow(-8))

func _draw_creature(c: Vector2, color: Color) -> void:
	var s := minf(size.x, size.y) * 0.31
	# Shade ramp: dark base, main, light, belly. Silhouette mode flattens
	# everything to one dark tone and skips the face / bright details.
	var c_main := color
	var c_dark := color.darkened(0.18)
	var c_light := color.lightened(0.16)
	var c_belly := color.lightened(0.38)
	if silhouette_mode:
		c_dark = color
		c_light = color
		c_belly = color
	match tier:
		1:
			_egg(c, s, c_main, c_dark, c_light)
		2:
			_slime(c, s, c_main, c_dark, c_belly)
		3:
			_dino(c, s, c_main, c_dark, c_belly)
		4:
			_wyrm(c, s, c_main, c_dark, c_light, c_belly)
		5:
			_phoenix(c, s, c_main, c_dark, c_light, c_belly)
		6:
			_unicorn(c, s, c_main, c_dark, c_belly)
		7:
			_robo(c, s, c_main, c_dark, c_light)
		_:
			_dragon(c, s, c_main, c_dark, c_belly)
	if silhouette_mode:
		return
	if tier == 7:
		_robo_face(c, s)
	else:
		_face(c, s)

# --- Shared shading / face helpers ----------------------------------------

func _round_body(c: Vector2, s: float, r: float, c_main: Color, c_dark: Color, c_belly: Color) -> void:
	# Soft drop shade, main body, light belly, top-left highlight.
	draw_circle(c + Vector2(0, s * 0.09), r, c_dark)
	draw_circle(c, r, c_main)
	draw_set_transform(c + Vector2(0, r * 0.42), 0.0, Vector2(1.0, 0.62))
	draw_circle(Vector2.ZERO, r * 0.58, c_belly)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not silhouette_mode:
		draw_circle(c + Vector2(-r * 0.38, -r * 0.44), r * 0.2, Color(1, 1, 1, 0.35))

func _face(c: Vector2, s: float) -> void:
	var er := maxf(3.5, s * 0.13)
	var eye_l := c + Vector2(-s * 0.32, -s * 0.08)
	var eye_r := c + Vector2(s * 0.32, -s * 0.08)
	if _blinking:
		# Eyes closed: short horizontal lines instead of dots.
		draw_line(eye_l + Vector2(-er, 0), eye_l + Vector2(er, 0), FACE_COLOR, 3.0, true)
		draw_line(eye_r + Vector2(-er, 0), eye_r + Vector2(er, 0), FACE_COLOR, 3.0, true)
	else:
		draw_circle(eye_l, er, FACE_COLOR)
		draw_circle(eye_r, er, FACE_COLOR)
		# Eye sparkle: big highlight + tiny glint.
		draw_circle(eye_l + Vector2(-er * 0.3, -er * 0.35), maxf(1.5, s * 0.055), Color.WHITE)
		draw_circle(eye_r + Vector2(-er * 0.3, -er * 0.35), maxf(1.5, s * 0.055), Color.WHITE)
		draw_circle(eye_l + Vector2(er * 0.35, er * 0.3), maxf(1.0, s * 0.03), Color(1, 1, 1, 0.85))
		draw_circle(eye_r + Vector2(er * 0.35, er * 0.3), maxf(1.0, s * 0.03), Color(1, 1, 1, 0.85))
	# Cheeks.
	draw_circle(c + Vector2(-s * 0.62, s * 0.2), maxf(2.5, s * 0.09), CHEEK_COLOR)
	draw_circle(c + Vector2(s * 0.62, s * 0.2), maxf(2.5, s * 0.09), CHEEK_COLOR)
	# Smile.
	draw_arc(c + Vector2(0, s * 0.1), s * 0.28, 0.25, PI - 0.25, 16, FACE_COLOR, 3.0)

func _sparkle(pos: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array([
		pos + Vector2(0, -r), pos + Vector2(r * 0.28, -r * 0.28),
		pos + Vector2(r, 0), pos + Vector2(r * 0.28, r * 0.28),
		pos + Vector2(0, r), pos + Vector2(-r * 0.28, r * 0.28),
		pos + Vector2(-r, 0), pos + Vector2(-r * 0.28, -r * 0.28)])
	draw_colored_polygon(pts, col)

func _flame(pos: Vector2, r: float) -> void:
	draw_circle(pos + Vector2(0, r * 0.25), r * 0.75, Color("#ff7a1a"))
	draw_circle(pos + Vector2(0, -r * 0.1), r * 0.55, Color("#ffb52e"))
	draw_circle(pos + Vector2(0, -r * 0.35), r * 0.32, Color("#ffe66d"))
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-r * 0.3, -r * 0.2), pos + Vector2(0, -r * 1.15),
		pos + Vector2(r * 0.3, -r * 0.2)]), Color("#ffe66d"))

# --- Tier art ---------------------------------------------------------------

func _egg(c: Vector2, s: float, c_main: Color, c_dark: Color, c_light: Color) -> void:
	var pts := PackedVector2Array([
		c + Vector2(0, -s * 1.3), c + Vector2(s * 0.9, -s * 0.4),
		c + Vector2(s * 0.75, s * 0.8), c + Vector2(0, s * 1.1),
		c + Vector2(-s * 0.75, s * 0.8), c + Vector2(-s * 0.9, -s * 0.4)])
	var shadow := PackedVector2Array()
	for p in pts:
		shadow.append(p + Vector2(0, s * 0.08))
	draw_colored_polygon(shadow, c_dark)
	draw_colored_polygon(pts, c_main)
	if silhouette_mode:
		return
	# Spots.
	draw_circle(c + Vector2(-s * 0.42, s * 0.05), s * 0.16, c_dark)
	draw_circle(c + Vector2(s * 0.38, s * 0.42), s * 0.19, c_dark)
	draw_circle(c + Vector2(s * 0.05, s * 0.72), s * 0.12, c_dark)
	draw_circle(c + Vector2(-s * 0.15, -s * 0.55), s * 0.13, c_light)
	# Crack shine: a bright zigzag near the top.
	var crack := PackedVector2Array([
		c + Vector2(-s * 0.45, -s * 0.75), c + Vector2(-s * 0.2, -s * 0.55),
		c + Vector2(-s * 0.38, -s * 0.38), c + Vector2(-s * 0.12, -s * 0.22)])
	draw_polyline(crack, Color(1, 1, 1, 0.75), 3.0, true)
	# Glossy highlight.
	draw_set_transform(c + Vector2(-s * 0.42, -s * 0.85), -0.5, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, s * 0.22, Color(1, 1, 1, 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _slime(c: Vector2, s: float, c_main: Color, c_dark: Color, c_belly: Color) -> void:
	_round_body(c, s, s, c_main, c_dark, c_belly)
	# Wobbly bumps on top and a drip underneath.
	draw_circle(c + Vector2(-s * 0.5, -s * 0.72), s * 0.3, c_main)
	draw_circle(c + Vector2(s * 0.48, -s * 0.74), s * 0.28, c_main)
	draw_circle(c + Vector2(s * 0.55, s * 0.95), s * 0.16, c_main)
	draw_circle(c + Vector2(s * 0.55, s * 1.18), s * 0.08, c_main)
	if silhouette_mode:
		return
	# Wobble shine: glossy ellipse top-left.
	draw_set_transform(c + Vector2(-s * 0.38, -s * 0.45), -0.6, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, s * 0.3, Color(1, 1, 1, 0.55))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(c + Vector2(s * 0.3, -s * 0.6), s * 0.09, Color(1, 1, 1, 0.6))

func _dino(c: Vector2, s: float, c_main: Color, c_dark: Color, c_belly: Color) -> void:
	# Back spikes (behind the body).
	for i in range(3):
		var bx := -s * 0.55 + float(i) * s * 0.55
		var by := -s * 0.62 - float(i % 2) * s * 0.12
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(bx - s * 0.22, by + s * 0.3),
			c + Vector2(bx, by - s * 0.45),
			c + Vector2(bx + s * 0.22, by + s * 0.3)]), c_dark)
	_round_body(c, s, s * 0.92, c_main, c_dark, c_belly)
	if silhouette_mode:
		return
	# Tiny arms.
	draw_circle(c + Vector2(-s * 0.85, s * 0.35), s * 0.14, c_dark)
	draw_circle(c + Vector2(s * 0.85, s * 0.35), s * 0.14, c_dark)

func _wyrm(c: Vector2, s: float, c_main: Color, c_dark: Color, c_light: Color, c_belly: Color) -> void:
	# Wings behind the body.
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-s * 0.35, 0), c + Vector2(-s * 1.6, -s * 0.9),
		c + Vector2(-s * 1.25, s * 0.6)]), c_light)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(s * 0.35, 0), c + Vector2(s * 1.6, -s * 0.9),
		c + Vector2(s * 1.25, s * 0.6)]), c_light)
	# Flame tail at the lower right.
	if not silhouette_mode:
		_flame(c + Vector2(s * 0.85, s * 0.75), s * 0.55)
	_round_body(c, s, s * 0.9, c_main, c_dark, c_belly)

func _phoenix(c: Vector2, s: float, c_main: Color, c_dark: Color, c_light: Color, c_belly: Color) -> void:
	if not silhouette_mode:
		# Golden glow behind the bird.
		draw_circle(c, s * 1.3, Color(1.0, 0.8, 0.25, 0.16))
		draw_circle(c, s * 1.05, Color(1.0, 0.85, 0.35, 0.2))
	# Feathered wings.
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-s * 0.35, 0), c + Vector2(-s * 1.6, -s * 0.9),
		c + Vector2(-s * 1.25, s * 0.6)]), c_light)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(s * 0.35, 0), c + Vector2(s * 1.6, -s * 0.9),
		c + Vector2(s * 1.25, s * 0.6)]), c_light)
	# Flame tail at the lower right.
	if not silhouette_mode:
		_flame(c + Vector2(s * 0.8, s * 0.8), s * 0.45)
	_round_body(c, s, s * 0.9, c_main, c_dark, c_belly)
	if silhouette_mode:
		return
	# Feather tufts on the head.
	for i in range(3):
		var tx := -s * 0.3 + float(i) * s * 0.3
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(tx - s * 0.12, -s * 0.8),
			c + Vector2(tx, -s * 1.25),
			c + Vector2(tx + s * 0.12, -s * 0.8)]), Color("#ff9d2e"))

func _unicorn(c: Vector2, s: float, c_main: Color, c_dark: Color, c_belly: Color) -> void:
	_round_body(c, s, s * 0.95, c_main, c_dark, c_belly)
	if silhouette_mode:
		return
	# Mane: pastel tufts along the top-right.
	draw_circle(c + Vector2(s * 0.55, -s * 0.72), s * 0.26, Color("#ff9ecf"))
	draw_circle(c + Vector2(s * 0.78, -s * 0.35), s * 0.24, Color("#b79cff"))
	draw_circle(c + Vector2(s * 0.72, s * 0.05), s * 0.2, Color("#7fd4ff"))
	# Horn.
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-s * 0.14, -s * 0.85), c + Vector2(0, -s * 1.95),
		c + Vector2(s * 0.14, -s * 0.85)]), Color("#fff3b0"))
	draw_circle(c + Vector2(0, -s * 1.35), s * 0.07, Color("#ffcf3d"))
	# Sparkles.
	_sparkle(c + Vector2(-s * 1.05, -s * 0.7), s * 0.16, Color("#ffffff"))
	_sparkle(c + Vector2(s * 1.05, -s * 1.15), s * 0.13, Color("#ffe98a"))
	_sparkle(c + Vector2(-s * 0.9, s * 0.85), s * 0.12, Color("#ffffff"))

func _robo(c: Vector2, s: float, c_main: Color, c_dark: Color, c_light: Color) -> void:
	var body := Rect2(c - Vector2(s * 0.85, s * 0.75), Vector2(s * 1.7, s * 1.5))
	var style := StyleBoxFlat.new()
	style.bg_color = c_dark
	style.set_corner_radius_all(10)
	draw_style_box(style, body.grow(3))
	style.bg_color = c_main
	draw_style_box(style, body)
	if silhouette_mode:
		return
	# Metal plates.
	draw_rect(Rect2(c + Vector2(-s * 0.65, -s * 0.55), Vector2(s * 1.3, s * 0.4)), c_light, true)
	draw_rect(Rect2(c + Vector2(-s * 0.65, s * 0.35), Vector2(s * 1.3, s * 0.3)), c_dark, true)
	# Bolts / rivets on the corners.
	for bx: float in [-s * 0.62, s * 0.62]:
		for by: float in [-s * 0.52, s * 0.52]:
			draw_circle(c + Vector2(bx, by), s * 0.07, Color("#e8f4f8"))
			draw_circle(c + Vector2(bx, by), s * 0.035, Color("#5a6b7a"))
	# Antenna with a red tip.
	draw_line(c + Vector2(s * 0.3, -s * 0.75), c + Vector2(s * 0.3, -s * 1.15), Color("#5a6b7a"), 3.0, true)
	draw_circle(c + Vector2(s * 0.3, -s * 1.2), s * 0.09, Color("#ff5d5d"))
	# Side vents.
	draw_rect(Rect2(c + Vector2(-s * 1.2, -s * 0.3), Vector2(s * 0.4, s * 1.3)), c_dark, true)
	draw_rect(Rect2(c + Vector2(s * 0.8, -s * 0.3), Vector2(s * 0.4, s * 1.3)), c_dark, true)

func _robo_face(c: Vector2, s: float) -> void:
	# Visor with glowing eyes.
	var visor := StyleBoxFlat.new()
	visor.bg_color = Color("#1d2b3a")
	visor.set_corner_radius_all(8)
	draw_style_box(visor, Rect2(c + Vector2(-s * 0.55, -s * 0.35), Vector2(s * 1.1, s * 0.42)))
	if _blinking:
		draw_line(c + Vector2(-s * 0.40, -s * 0.14), c + Vector2(-s * 0.16, -s * 0.14), Color("#54e0ff"), 3.0, true)
		draw_line(c + Vector2(s * 0.16, -s * 0.14), c + Vector2(s * 0.40, -s * 0.14), Color("#54e0ff"), 3.0, true)
	else:
		draw_circle(c + Vector2(-s * 0.28, -s * 0.14), s * 0.11, Color("#54e0ff"))
		draw_circle(c + Vector2(s * 0.28, -s * 0.14), s * 0.11, Color("#54e0ff"))
		draw_circle(c + Vector2(-s * 0.28, -s * 0.14), s * 0.05, Color.WHITE)
		draw_circle(c + Vector2(s * 0.28, -s * 0.14), s * 0.05, Color.WHITE)
	# Grille mouth.
	for i in range(3):
		var mx := -s * 0.24 + float(i) * s * 0.24
		draw_line(c + Vector2(mx, s * 0.38), c + Vector2(mx, s * 0.55), Color("#1d2b3a"), 3.0, true)

func _dragon(c: Vector2, s: float, c_main: Color, c_dark: Color, c_belly: Color) -> void:
	if not silhouette_mode:
		# Purple aura.
		draw_circle(c, s * 1.35, Color(0.61, 0.42, 0.86, 0.18))
		draw_circle(c, s * 1.12, Color(0.61, 0.42, 0.86, 0.22))
	_round_body(c, s, s * 1.0, c_main, c_dark, c_belly)
	if silhouette_mode:
		return
	# Crown.
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-s * 0.5, -s * 0.85), c + Vector2(-s * 0.5, -s * 1.35),
		c + Vector2(-s * 0.25, -s * 1.05), c + Vector2(0, -s * 1.5),
		c + Vector2(s * 0.25, -s * 1.05), c + Vector2(s * 0.5, -s * 1.35),
		c + Vector2(s * 0.5, -s * 0.85)]), Color("#ffd94d"))
	draw_circle(c + Vector2(0, -s * 1.5), s * 0.08, Color("#ff5d8f"))
	# Stars around the crown.
	_sparkle(c + Vector2(-s * 1.15, -s * 0.9), s * 0.14, Color("#ffe98a"))
	_sparkle(c + Vector2(s * 1.2, -s * 0.7), s * 0.12, Color("#ffffff"))
	_sparkle(c + Vector2(s * 0.9, s * 0.9), s * 0.11, Color("#ffe98a"))
