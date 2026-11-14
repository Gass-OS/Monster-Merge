extends Control
class_name MonsterUIManager

const GridScript = preload("res://scripts/grid_manager.gd")
const TileScript = preload("res://scripts/monster_tile.gd")
const BackgroundFXScript = preload("res://scripts/background_fx.gd")
const RingBurstScript = preload("res://scripts/ring_burst.gd")
const ConfettiFXScript = preload("res://scripts/confetti_fx.gd")
const StarGlowScript = preload("res://scripts/star_glow.gd")
const NAMES := ["Blue Spotted Egg", "Cute Green Slime", "Baby Green Dino", "Winged Flame Wyrm", "Golden Phoenix", "Crystal Unicorn", "Robo-Rex", "Cosmic King Dragon"]
var manager: MonsterGameManager
var grid: MonsterGridManager
var coin_label: Label
var coin_panel: PanelContainer
var board_panel: PanelContainer
var next_label: Label
var progress: ProgressBar
var spawn_button: Button
var popup_layer: CanvasLayer
var _content_margin: MarginContainer
var _board_shake: Tween
var _margin_shake: Tween

func setup(game_manager: MonsterGameManager) -> void:
	manager = game_manager
	_build_interface()
	manager.coins_changed.connect(_update_coins)
	manager.state_changed.connect(_update_hud)
	manager.merge_happened.connect(_on_merge)
	manager.monster_unlocked.connect(_show_new_monster)
	_update_hud()

func _build_interface() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	var bg := BackgroundFXScript.new()
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)
	_content_margin = margin
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 13)
	margin.add_child(layout)

	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(top)
	coin_panel = _panel(Color("#121826"), 18)
	coin_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(coin_panel)
	coin_label = Label.new()
	coin_label.text = "🪙  0"
	coin_label.add_theme_font_size_override("font_size", 28)
	coin_label.add_theme_color_override("font_color", Color("#ffd36b"))
	coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coin_panel.add_child(coin_label)
	var gallery_button := Button.new()
	gallery_button.text = "🏆 GALLERY"
	gallery_button.custom_minimum_size = Vector2(150, 58)
	_style_button(gallery_button, Color("#1d2a44"))
	gallery_button.pressed.connect(_show_gallery)
	top.add_child(gallery_button)

	var title := Label.new()
	title.text = "MONSTER MERGE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color("#f1e7c8"))
	title.add_theme_color_override("font_shadow_color", Color("#8a1422"))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 4)
	layout.add_child(title)
	next_label = Label.new()
	next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_label.add_theme_font_size_override("font_size", 23)
	next_label.add_theme_color_override("font_color", Color("#9fb4d8"))
	layout.add_child(next_label)
	progress = ProgressBar.new()
	progress.custom_minimum_size.y = 22
	progress.max_value = 8
	progress.show_percentage = false
	progress.add_theme_stylebox_override("background", _flat_style(Color("#10141f"), 12, Color("#232c3d"), 2))
	progress.add_theme_stylebox_override("fill", _flat_style(Color("#e8a93a"), 12))
	layout.add_child(progress)

	board_panel = PanelContainer.new()
	board_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_panel.add_theme_stylebox_override("panel", _flat_style(Color("#0b0f18"), 24, Color("#7a5a22"), 6))
	layout.add_child(board_panel)
	var board_margin := MarginContainer.new()
	board_margin.add_theme_constant_override("margin_left", 12)
	board_margin.add_theme_constant_override("margin_right", 12)
	board_margin.add_theme_constant_override("margin_top", 12)
	board_margin.add_theme_constant_override("margin_bottom", 12)
	board_panel.add_child(board_margin)
	grid = GridScript.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_margin.add_child(grid)
	grid.setup(manager)

	var hint := Label.new()
	hint.text = "DRAG matching monsters together to evolve!"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", Color("#7f8fae"))
	layout.add_child(hint)
	spawn_button = Button.new()
	spawn_button.text = "🥚   SPAWN EGG"
	spawn_button.custom_minimum_size = Vector2(0, 92)
	spawn_button.add_theme_font_size_override("font_size", 31)
	_style_glossy_button(spawn_button)
	spawn_button.pressed.connect(_on_spawn_pressed)
	layout.add_child(spawn_button)

	popup_layer = CanvasLayer.new()
	popup_layer.layer = 10
	add_child(popup_layer)

func _panel(color: Color, radius: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _flat_style(color, radius, Color("#b8923a"), 2))
	return p

func _flat_style(color: Color, radius: int, border: Color = Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = border
	style.set_border_width_all(border_width)
	return style

func _style_button(button: Button, color: Color) -> void:
	button.add_theme_stylebox_override("normal", _flat_style(color, 22, color.darkened(0.2), 4))
	button.add_theme_stylebox_override("hover", _flat_style(color.lightened(0.08), 22, color.darkened(0.2), 4))
	button.add_theme_stylebox_override("pressed", _flat_style(color.darkened(0.12), 22, color.darkened(0.25), 4))
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)

# --- Glossy SPAWN EGG button ------------------------------------------------
# Bakes a rounded vertical orange gradient with a white shine stripe across
# the top into one ImageTexture, then reuses it for normal / hover / pressed
# via StyleBoxTexture modulate. The button itself stays a plain Button, so
# its pressed signal is untouched.

func _make_glossy_texture(top: Color, mid: Color, bottom: Color) -> ImageTexture:
	var w := 512
	var h := 96
	var radius := 22
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		var t := float(y) / float(h - 1)
		var col: Color
		if t < 0.5:
			col = top.lerp(mid, t * 2.0)
		else:
			col = mid.lerp(bottom, (t - 0.5) * 2.0)
		# White shine stripe across the top third, fading downward.
		if t < 0.38:
			col = col.lerp(Color.WHITE, 0.30 * (1.0 - t / 0.38))
		for x in range(w):
			# Rounded-corner mask: skip pixels outside the corner arc.
			var cx := minf(float(x), float(w - 1 - x))
			var cy := minf(float(y), float(h - 1 - y))
			if cx < radius and cy < radius:
				var dx := float(radius) - cx
				var dy := float(radius) - cy
				if dx * dx + dy * dy > float(radius * radius):
					continue
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)

func _style_glossy_button(button: Button) -> void:
	var tex := _make_glossy_texture(Color("#e0414f"), Color("#a8202e"), Color("#6b121c"))
	var normal := StyleBoxTexture.new()
	normal.texture = tex
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover := normal.duplicate() as StyleBoxTexture
	hover.modulate_color = Color(1.12, 1.12, 1.12)
	var pressed := normal.duplicate() as StyleBoxTexture
	pressed.modulate_color = Color(0.82, 0.82, 0.82)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)

# --- Sound (Worker C's SoundManager autoload, guarded) -----------------------
# Safe no-op when the autoload does not exist yet.

func _sfx(method_name: String) -> void:
	var sm := get_node_or_null("/root/SoundManager")
	if sm != null and sm.has_method(method_name):
		sm.call(method_name)

func _update_coins(value: int) -> void:
	coin_label.text = "🪙  %s" % _format_number(value)

func _update_hud() -> void:
	if manager == null:
		return
	coin_label.text = "🪙  %s" % _format_number(manager.coins)
	next_label.text = manager.get_next_tier_text()
	progress.value = manager.highest_unlocked

func _format_number(value: int) -> String:
	if value >= 1000000:
		return "%.1fM" % (float(value) / 1000000.0)
	if value >= 1000:
		return "%.1fK" % (float(value) / 1000.0)
	return str(value)

func _on_spawn_pressed() -> void:
	_sfx("play_click")
	manager.spawn_monster()
	var tween := create_tween()
	tween.tween_property(spawn_button, "scale", Vector2(0.94, 0.94), 0.07)
	tween.tween_property(spawn_button, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK)

# --- Merge juice --------------------------------------------------------------
# Ring burst + flying coins + DING badge + big bouncy toast + board shake,
# on top of the existing bouncy scale-up in grid_manager.

func _on_merge(tier: int, bonus: int) -> void:
	_sfx("play_pop")
	_sfx("play_ding")
	var tile_center := Vector2(size.x * 0.5, 620.0)
	if grid != null and grid.last_merged_index >= 0 and grid.last_merged_index < grid.tiles.size():
		tile_center = grid.tiles[grid.last_merged_index].get_global_rect().get_center()
	# White ring burst from the merged tile.
	var ring := RingBurstScript.new()
	ring.ring_color = MonsterTile.GLOW_COLORS[clampi(tier - 1, 0, 7)]
	ring.position = tile_center
	popup_layer.add_child(ring)
	# Gold coins fly along a curve up to the coin counter.
	var coin_target := Vector2(110, 52)
	if coin_label != null:
		coin_target = coin_label.get_global_rect().get_center()
	for i in range(4):
		_fly_coin(
			tile_center + Vector2(randf_range(-24.0, 24.0), randf_range(-8.0, 8.0)),
			coin_target, float(i) * 0.07, i == 3)
	# Small "DING!" badge popping above the tile.
	var ding := Label.new()
	ding.text = "DING! 🔔"
	ding.add_theme_font_size_override("font_size", 24)
	ding.add_theme_color_override("font_color", Color("#ffe27b"))
	ding.add_theme_color_override("font_shadow_color", Color("#854c12"))
	ding.add_theme_constant_override("shadow_offset_x", 2)
	ding.add_theme_constant_override("shadow_offset_y", 2)
	ding.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ding.size = Vector2(160, 40)
	ding.position = tile_center + Vector2(-80, -84)
	ding.pivot_offset = Vector2(80, 20)
	ding.scale = Vector2(0.5, 0.5)
	ding.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_layer.add_child(ding)
	var dtw := create_tween()
	dtw.tween_property(ding, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	dtw.parallel().tween_property(ding, "position:y", ding.position.y - 46.0, 0.6)
	dtw.tween_property(ding, "modulate:a", 0.0, 0.3)
	dtw.tween_callback(ding.queue_free)
	# Big bouncy toast.
	var toast := Label.new()
	toast.text = "POP!   +%d COINS!   ✨" % bonus
	toast.add_theme_font_size_override("font_size", 36)
	toast.add_theme_color_override("font_color", Color("#fff36b"))
	toast.add_theme_color_override("font_shadow_color", Color("#854c12"))
	toast.add_theme_constant_override("shadow_offset_x", 2)
	toast.add_theme_constant_override("shadow_offset_y", 3)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast.position = Vector2(-280, 130)
	toast.size = Vector2(560, 60)
	toast.pivot_offset = Vector2(280, 30)
	toast.scale = Vector2(0.6, 0.6)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_layer.add_child(toast)
	var tw := create_tween()
	tw.tween_property(toast, "scale", Vector2(1.1, 1.1), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(toast, "position:y", 70.0, 0.7)
	tw.tween_property(toast, "scale", Vector2.ONE, 0.15)
	tw.parallel().tween_property(toast, "modulate:a", 0.0, 0.35)
	tw.tween_callback(toast.queue_free)
	# Tiny board shake.
	_shake_board()
	if tier >= 5:
		_flash(MonsterTile.GLOW_COLORS[clampi(tier - 1, 0, 7)])
	if tier >= 6:
		Engine.time_scale = 0.35
		get_tree().create_timer(0.25, true, false, true).timeout.connect(func() -> void:
			Engine.time_scale = 1.0
		)

func _flash(col: Color) -> void:
	var f := ColorRect.new()
	f.color = Color(col, 0.35)
	f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_layer.add_child(f)
	var tw := create_tween()
	tw.tween_property(f, "color:a", 0.0, 0.3)
	tw.tween_callback(f.queue_free)

func _fly_coin(from: Vector2, to: Vector2, delay: float, is_last: bool) -> void:
	var coin := Label.new()
	coin.text = "🪙"
	coin.add_theme_font_size_override("font_size", 30)
	coin.position = from
	coin.size = Vector2(40, 40)
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_layer.add_child(coin)
	var control := Vector2((from.x + to.x) * 0.5, minf(from.y, to.y) - 160.0)
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_method(func(t: float) -> void:
		if is_instance_valid(coin):
			coin.position = _quad_bezier(from, control, to, t) - Vector2(20, 20)
			coin.rotation = lerpf(0.0, TAU, t) * 0.5
	, 0.0, 1.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		if is_instance_valid(coin):
			coin.queue_free()
		if is_last:
			_pop_coin_panel()
	)

func _quad_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return u * u * p0 + 2.0 * u * t * p1 + t * t * p2

func _pop_coin_panel() -> void:
	if coin_panel == null:
		return
	coin_panel.pivot_offset = coin_panel.size * 0.5
	var tw := create_tween()
	tw.tween_property(coin_panel, "scale", Vector2(1.18, 1.18), 0.1)
	tw.tween_property(coin_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _shake_board() -> void:
	if board_panel != null:
		if _board_shake != null and _board_shake.is_valid():
			_board_shake.kill()
		board_panel.pivot_offset = board_panel.size * 0.5
		_board_shake = create_tween()
		_board_shake.tween_property(board_panel, "rotation", 0.014, 0.05)
		_board_shake.tween_property(board_panel, "rotation", -0.011, 0.07)
		_board_shake.tween_property(board_panel, "rotation", 0.006, 0.07)
		_board_shake.tween_property(board_panel, "rotation", 0.0, 0.08)
	if _content_margin != null:
		if _margin_shake != null and _margin_shake.is_valid():
			_margin_shake.kill()
			_content_margin.position = Vector2.ZERO
		_margin_shake = create_tween()
		_margin_shake.tween_method(func(t: float) -> void:
			var s := (1.0 - t) * 5.0
			_content_margin.position = Vector2(randf_range(-s, s), randf_range(-s, s))
		, 0.0, 1.0, 0.28)
		_margin_shake.tween_callback(func() -> void:
			_content_margin.position = Vector2.ZERO
		)

func _show_new_monster(tier: int) -> void:
	_sfx("play_unlock")
	var overlay := _make_overlay()
	var card := _popup_card(overlay)
	var heading := _popup_label("★  NEW MONSTER FOUND!  ★", 27, Color("#ffdf58"))
	card.add_child(heading)
	# Glowing golden star behind the new monster.
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(220, 210)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow := StarGlowScript.new()
	stage.add_child(glow)
	var preview := TileScript.new()
	preview.set_monster(tier)
	preview.custom_minimum_size = Vector2(180, 190)
	preview.size = Vector2(180, 190)
	preview.set_anchors_preset(Control.PRESET_CENTER)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(preview)
	card.add_child(stage)
	card.add_child(_popup_label("TIER %d: %s" % [tier, NAMES[tier - 1]], 22, Color.WHITE))
	card.add_child(_popup_label("Makes extra coins every second!", 17, Color("#9fb4d8")))
	var ok := Button.new()
	ok.text = "OK!"
	ok.custom_minimum_size.y = 58
	_style_button(ok, Color("#2a6b4a"))
	ok.pressed.connect(overlay.queue_free)
	card.add_child(ok)
	var gallery := Button.new()
	gallery.text = "VIEW GALLERY"
	gallery.custom_minimum_size.y = 50
	_style_button(gallery, Color("#1d2a44"))
	gallery.pressed.connect(func():
		overlay.queue_free()
		_show_gallery()
	)
	card.add_child(gallery)
	# Confetti falling over the whole overlay.
	var confetti := ConfettiFXScript.new()
	overlay.add_child(confetti)

func _show_gallery() -> void:
	_sfx("play_click")
	var overlay := _make_overlay()
	var card := _popup_card(overlay)
	card.add_child(_popup_label("MONSTER GALLERY", 28, Color("#ffe27b")))
	var gallery_grid := GridContainer.new()
	gallery_grid.columns = 2
	gallery_grid.add_theme_constant_override("h_separation", 10)
	gallery_grid.add_theme_constant_override("v_separation", 10)
	card.add_child(gallery_grid)
	for i in range(8):
		var item := VBoxContainer.new()
		item.custom_minimum_size = Vector2(190, 190)
		var label := Label.new()
		label.text = "TIER %d" % (i + 1)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color.WHITE)
		item.add_child(label)
		var tile := TileScript.new()
		tile.set_monster(i + 1)
		tile.custom_minimum_size = Vector2(150, 118)
		tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if manager.discovered[i]:
			item.add_child(tile)
			var name_label := Label.new()
			name_label.text = NAMES[i]
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_label.add_theme_font_size_override("font_size", 14)
			name_label.add_theme_color_override("font_color", Color("#d7f5ff"))
			item.add_child(name_label)
		else:
			# Locked tiers show the actual creature as a dark silhouette.
			tile.set_silhouette(true)
			item.add_child(tile)
			var locked := Label.new()
			locked.text = "?"
			locked.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			locked.add_theme_font_size_override("font_size", 24)
			locked.add_theme_color_override("font_color", Color("#b9c4d3"))
			item.add_child(locked)
		gallery_grid.add_child(item)
	var close := Button.new()
	close.text = "CLOSE"
	close.custom_minimum_size.y = 54
	_style_button(close, Color("#8a1c27"))
	close.pressed.connect(overlay.queue_free)
	card.add_child(close)

func _make_overlay() -> ColorRect:
	var overlay := ColorRect.new()
	overlay.color = Color(0.01, 0.01, 0.03, 0.9)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_layer.add_child(overlay)
	return overlay

func _popup_card(overlay: ColorRect) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _flat_style(Color("#0d121c"), 22, Color("#b8923a"), 4))
	center.add_child(frame)
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(480, 0)
	card.add_theme_constant_override("separation", 12)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	frame.add_child(margin)
	margin.add_child(card)
	return card

func _popup_label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
