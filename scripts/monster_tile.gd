extends Control
class_name MonsterTile

signal merge_requested(source_index: int, target_index: int)

const PALETTE := [
	Color("#49a9ed"), Color("#72d64e"), Color("#83c94d"), Color("#f27642"),
	Color("#f6c844"), Color("#8ce8ef"), Color("#8995a8"), Color("#9b6bdb")
]
const FACE_COLOR := Color("#26374c")
const CHEEK_COLOR := Color(1.0, 0.55, 0.6, 0.75)
const SILHOUETTE_COLOR := Color("#080b12")
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

func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(120, 136)
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func set_monster(new_tier: int) -> void:
	tier = clampi(new_tier, 0, 8)
	queue_redraw()

func set_silhouette(value: bool) -> void:
	silhouette_mode = value
	queue_redraw()

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

func _finish_drag(global_position: Vector2) -> void:
	if not _pressed:
		return
	_pressed = false
	if tier <= 0:
		return
	if _dragging:
		var parent_grid := get_parent()
		if parent_grid:
			for tile in parent_grid.get_children():
				if tile is MonsterTile and tile.tile_index != tile_index and tile.get_global_rect().has_point(global_position):
					merge_requested.emit(tile_index, tile.tile_index)
					break
	_dragging = false

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
	panel.bg_color = Color("#0b0f17") if tier == 0 else Color("#121826")
	panel.border_color = Color("#222b3d") if tier == 0 else gc.darkened(0.35)
	panel.set_border_width_all(2 if tier == 0 else 3)
	panel.set_corner_radius_all(14)
	if tier > 0 and not was_sil:
		panel.shadow_color = Color(gc, 0.28)
		panel.shadow_size = 7
	draw_style_box(panel, rect)
	if tier == 0:
		draw_arc(size * 0.5, 12.0, 0.0, TAU, 28, Color("#2a3550"), 2.0, true)
		return
	var center := Vector2(size.x * 0.5, size.y * 0.47)
	var s := minf(size.x, size.y) * 0.31
	# Soft coloured aura behind the creature.
	if not was_sil:
		for i in range(4):
			draw_circle(center, s * (1.75 - float(i) * 0.38), Color(gc, 0.045 + 0.008 * float(tier)))
	# Ground shadow.
	draw_set_transform(center + Vector2(0, s * 1.2), 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, s, Color(0, 0, 0, 0.55))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Rim light: draw the flat silhouette offset in the glow colour first.
	silhouette_mode = true
	_draw_creature(center + Vector2(-3.0, -3.0), Color(gc, 0.95))
	_draw_creature(center + Vector2(2.5, 3.0), Color(gc.darkened(0.45), 0.55))
	silhouette_mode = was_sil
	var body_color: Color = SILHOUETTE_COLOR if was_sil else PALETTE[tier - 1].darkened(0.55)
	_draw_creature(center, body_color)
	# Tier plate.
	var font := ThemeDB.fallback_font
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color("#080b12")
	plate.border_color = gc.darkened(0.3)
	plate.set_border_width_all(1)
	plate.set_corner_radius_all(6)
	draw_style_box(plate, Rect2(8, size.y - 26, size.x - 16, 20))
	draw_string(font, Vector2(8, size.y - 11), "TIER %d" % tier, HORIZONTAL_ALIGNMENT_CENTER, size.x - 16, 14, gc.lightened(0.25))

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
	# Menacing glowing eyes and a stern mouth.
	var gc := _glow_color()
	var er := maxf(3.5, s * 0.12)
	var eye_l := c + Vector2(-s * 0.32, -s * 0.08)
	var eye_r := c + Vector2(s * 0.32, -s * 0.08)
	for e: Vector2 in [eye_l, eye_r]:
		draw_circle(e, er * 2.4, Color(gc, 0.16))
		draw_circle(e, er * 1.6, Color(gc, 0.35))
		draw_circle(e, er, gc.lightened(0.3))
		draw_circle(e, er * 0.45, Color.WHITE)
	draw_line(c + Vector2(-s * 0.2, s * 0.3), c + Vector2(s * 0.2, s * 0.3), Color(0, 0, 0, 0.6), 3.0, true)

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
