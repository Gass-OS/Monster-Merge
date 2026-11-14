extends Control
class_name MonsterTile

signal merge_requested(source_index: int, target_index: int)

const PALETTE := [
	Color("#49a9ed"), Color("#72d64e"), Color("#83c94d"), Color("#f27642"),
	Color("#f6c844"), Color("#8ce8ef"), Color("#8995a8"), Color("#9b6bdb")
]
var tile_index: int = -1
var tier: int = 0
var _press_position := Vector2.ZERO
var _dragging := false
var _pressed := false

func _ready() -> void:
	custom_minimum_size = Vector2(120, 136)
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func set_monster(new_tier: int) -> void:
	tier = clampi(new_tier, 0, 8)
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

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("#d8f4f2") if tier == 0 else Color("#fff8df")
	panel.border_color = Color("#8ac9c5")
	panel.set_border_width_all(3)
	panel.set_corner_radius_all(18)
	draw_style_box(panel, rect)
	if tier == 0:
		draw_circle(size * 0.5, 13.0, Color("#b9dedb"))
		return
	var center := Vector2(size.x * 0.5, size.y * 0.47)
	var body_color: Color = PALETTE[tier - 1]
	_draw_creature(center, body_color)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(8, size.y - 9), "TIER %d" % tier, HORIZONTAL_ALIGNMENT_CENTER, size.x - 16, 16, Color.WHITE)
	draw_rect(Rect2(8, size.y - 26, size.x - 16, 22), Color("#273b52"), true, 7.0)
	draw_string(font, Vector2(8, size.y - 9), "TIER %d" % tier, HORIZONTAL_ALIGNMENT_CENTER, size.x - 16, 14, Color.WHITE)

func _draw_creature(c: Vector2, color: Color) -> void:
	var s := minf(size.x, size.y) * 0.31
	if tier == 1:
		draw_colored_polygon(PackedVector2Array([c + Vector2(0,-s*1.3), c+Vector2(s*0.9,-s*0.4), c+Vector2(s*0.75,s*0.8), c+Vector2(0,s*1.1), c+Vector2(-s*0.75,s*0.8), c+Vector2(-s*0.9,-s*0.4)]), color)
		draw_circle(c + Vector2(-s*0.4,0), 5, Color("#eafaff"))
		draw_circle(c + Vector2(s*0.35,s*0.4), 6, Color("#eafaff"))
	elif tier == 2:
		draw_circle(c, s, color)
		draw_circle(c + Vector2(-s*0.45,-s*0.75), s*0.3, color.lightened(0.15))
		draw_circle(c + Vector2(s*0.45,-s*0.75), s*0.3, color.lightened(0.15))
	elif tier == 3:
		draw_circle(c, s*0.9, color)
		draw_colored_polygon(PackedVector2Array([c+Vector2(-s*0.6,-s*0.5),c+Vector2(-s*0.9,-s*1.35),c+Vector2(-s*0.1,-s*0.85)]), color.darkened(0.08))
		draw_colored_polygon(PackedVector2Array([c+Vector2(s*0.6,-s*0.5),c+Vector2(s*0.9,-s*1.35),c+Vector2(s*0.1,-s*0.85)]), color.darkened(0.08))
	elif tier == 4 or tier == 5:
		draw_colored_polygon(PackedVector2Array([c+Vector2(-s*0.35,0),c+Vector2(-s*1.6,-s*0.9),c+Vector2(-s*1.25,s*0.6)]), color.lightened(0.12))
		draw_colored_polygon(PackedVector2Array([c+Vector2(s*0.35,0),c+Vector2(s*1.6,-s*0.9),c+Vector2(s*1.25,s*0.6)]), color.lightened(0.12))
		draw_circle(c, s*0.9, color)
	elif tier == 6:
		draw_circle(c, s*0.95, color)
		draw_colored_polygon(PackedVector2Array([c+Vector2(0,-s*1.9),c+Vector2(-s*0.3,-s*0.6),c+Vector2(s*0.3,-s*0.6)]), Color("#f7ffff"))
		draw_circle(c+Vector2(0,-s*0.3), s*0.25, Color("#ffffff"))
	elif tier == 7:
		draw_rect(Rect2(c-Vector2(s*0.85,s*0.75),Vector2(s*1.7,s*1.5)), color, true)
		draw_rect(Rect2(c+Vector2(-s*1.2,-s*0.3),Vector2(s*0.4,s*1.3)), color.darkened(0.18), true)
		draw_rect(Rect2(c+Vector2(s*0.8,-s*0.3),Vector2(s*0.4,s*1.3)), color.darkened(0.18), true)
	else:
		draw_circle(c, s*1.05, color)
		draw_circle(c, s*1.35, Color("#d8b8ff"), false, 5)
		draw_colored_polygon(PackedVector2Array([c+Vector2(0,-s*1.9),c+Vector2(-s*0.25,-s*0.8),c+Vector2(s*0.25,-s*0.8)]), Color("#ffe78c"))
	# Eyes and smile are shared across the evolution family.
	draw_circle(c + Vector2(-s*0.32,-s*0.08), maxf(3.5,s*0.13), Color("#26374c"))
	draw_circle(c + Vector2(s*0.32,-s*0.08), maxf(3.5,s*0.13), Color("#26374c"))
	draw_circle(c + Vector2(-s*0.36,-s*0.13), maxf(1.5,s*0.05), Color.WHITE)
	draw_circle(c + Vector2(s*0.28,-s*0.13), maxf(1.5,s*0.05), Color.WHITE)
	draw_arc(c+Vector2(0,s*0.1), s*0.28, 0.25, PI-0.25, 16, Color("#26374c"), 3.0)
