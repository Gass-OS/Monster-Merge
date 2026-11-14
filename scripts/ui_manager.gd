extends Control
class_name MonsterUIManager

const GridScript = preload("res://scripts/grid_manager.gd")
const TileScript = preload("res://scripts/monster_tile.gd")
const NAMES := ["Blue Spotted Egg", "Cute Green Slime", "Baby Green Dino", "Winged Flame Wyrm", "Golden Phoenix", "Crystal Unicorn", "Robo-Rex", "Cosmic King Dragon"]
var manager: MonsterGameManager
var grid: MonsterGridManager
var coin_label: Label
var next_label: Label
var progress: ProgressBar
var spawn_button: Button
var popup_layer: CanvasLayer

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
	var bg := ColorRect.new()
	bg.color = Color("#83d9f4")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var clouds := Control.new()
	clouds.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clouds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clouds.draw.connect(func(): _draw_clouds(clouds))
	add_child(clouds)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 13)
	margin.add_child(layout)

	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(top)
	var coin_panel := _panel(Color("#fff0a9"), 22)
	coin_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(coin_panel)
	coin_label = Label.new()
	coin_label.text = "🪙  0"
	coin_label.add_theme_font_size_override("font_size", 28)
	coin_label.add_theme_color_override("font_color", Color("#714319"))
	coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coin_panel.add_child(coin_label)
	var gallery_button := Button.new()
	gallery_button.text = "🏆 GALLERY"
	gallery_button.custom_minimum_size = Vector2(150, 58)
	_style_button(gallery_button, Color("#287e8b"))
	gallery_button.pressed.connect(_show_gallery)
	top.add_child(gallery_button)

	var title := Label.new()
	title.text = "MONSTER MERGE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color("#ffffff"))
	title.add_theme_color_override("font_shadow_color", Color("#287d9a"))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 4)
	layout.add_child(title)
	next_label = Label.new()
	next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_label.add_theme_font_size_override("font_size", 23)
	next_label.add_theme_color_override("font_color", Color("#164d69"))
	layout.add_child(next_label)
	progress = ProgressBar.new()
	progress.custom_minimum_size.y = 22
	progress.max_value = 8
	progress.show_percentage = false
	progress.add_theme_stylebox_override("background", _flat_style(Color("#d4f2f4"), 12))
	progress.add_theme_stylebox_override("fill", _flat_style(Color("#ffc64b"), 12))
	layout.add_child(progress)

	var board_panel := PanelContainer.new()
	board_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_panel.add_theme_stylebox_override("panel", _flat_style(Color("#168c91"), 28, Color("#0c6976"), 8))
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
	hint.add_theme_color_override("font_color", Color("#15556c"))
	layout.add_child(hint)
	spawn_button = Button.new()
	spawn_button.text = "🥚   SPAWN EGG"
	spawn_button.custom_minimum_size = Vector2(0, 92)
	spawn_button.add_theme_font_size_override("font_size", 31)
	_style_button(spawn_button, Color("#ff8c32"))
	spawn_button.pressed.connect(_on_spawn_pressed)
	layout.add_child(spawn_button)

	popup_layer = CanvasLayer.new()
	popup_layer.layer = 10
	add_child(popup_layer)

func _draw_clouds(control: Control) -> void:
	var w := control.size.x
	for i in range(7):
		var x := fposmod(float(i) * 173.0 + 45.0, maxf(w, 1.0))
		var y := 80.0 + float((i * 97) % 420)
		control.draw_circle(Vector2(x, y), 34, Color(1,1,1,0.35))
		control.draw_circle(Vector2(x+30, y+5), 27, Color(1,1,1,0.35))
		control.draw_circle(Vector2(x-28, y+10), 24, Color(1,1,1,0.35))

func _panel(color: Color, radius: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _flat_style(color, radius))
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
	manager.spawn_monster()
	var tween := create_tween()
	tween.tween_property(spawn_button, "scale", Vector2(0.94, 0.94), 0.07)
	tween.tween_property(spawn_button, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK)

func _on_merge(tier: int, bonus: int) -> void:
	var toast := Label.new()
	toast.text = "POP!   +%d COINS!   ✨" % bonus
	toast.add_theme_font_size_override("font_size", 28)
	toast.add_theme_color_override("font_color", Color("#fff36b"))
	toast.add_theme_color_override("font_shadow_color", Color("#854c12"))
	toast.add_theme_constant_override("shadow_offset_x", 2)
	toast.add_theme_constant_override("shadow_offset_y", 3)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast.position = Vector2(-250, 130)
	toast.size = Vector2(500, 50)
	popup_layer.add_child(toast)
	var tw := create_tween()
	tw.tween_property(toast, "position:y", 65.0, 0.65)
	tw.parallel().tween_property(toast, "modulate:a", 0.0, 0.8)
	tw.tween_callback(toast.queue_free)

func _show_new_monster(tier: int) -> void:
	var overlay := _make_overlay()
	var card := _popup_card(overlay)
	var heading := _popup_label("★  NEW MONSTER FOUND!  ★", 27, Color("#ffdf58"))
	card.add_child(heading)
	var preview := TileScript.new()
	preview.set_monster(tier)
	preview.custom_minimum_size = Vector2(180, 190)
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.add_child(preview)
	card.add_child(_popup_label("TIER %d: %s" % [tier, NAMES[tier-1]], 22, Color.WHITE))
	card.add_child(_popup_label("Makes extra coins every second!", 17, Color("#d5f6d9")))
	var ok := Button.new()
	ok.text = "OK!"
	ok.custom_minimum_size.y = 58
	_style_button(ok, Color("#36b95f"))
	ok.pressed.connect(overlay.queue_free)
	card.add_child(ok)
	var gallery := Button.new()
	gallery.text = "VIEW GALLERY"
	gallery.custom_minimum_size.y = 50
	_style_button(gallery, Color("#287eaa"))
	gallery.pressed.connect(func():
		overlay.queue_free()
		_show_gallery()
	)
	card.add_child(gallery)

func _show_gallery() -> void:
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
		item.custom_minimum_size = Vector2(190, 112)
		var label := Label.new()
		label.text = "TIER %d" % (i+1)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color.WHITE)
		item.add_child(label)
		if manager.discovered[i]:
			var name_label := Label.new()
			name_label.text = NAMES[i]
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_label.add_theme_font_size_override("font_size", 14)
			name_label.add_theme_color_override("font_color", Color("#d7f5ff"))
			item.add_child(name_label)
		else:
			var locked := Label.new()
			locked.text = "?"
			locked.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			locked.add_theme_font_size_override("font_size", 36)
			locked.add_theme_color_override("font_color", Color("#b9c4d3"))
			item.add_child(locked)
		gallery_grid.add_child(item)
	var close := Button.new()
	close.text = "CLOSE"
	close.custom_minimum_size.y = 54
	_style_button(close, Color("#ff8c32"))
	close.pressed.connect(overlay.queue_free)
	card.add_child(close)

func _make_overlay() -> ColorRect:
	var overlay := ColorRect.new()
	overlay.color = Color(0.04, 0.12, 0.2, 0.84)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_layer.add_child(overlay)
	return overlay

func _popup_card(overlay: ColorRect) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(480, 0)
	card.add_theme_constant_override("separation", 12)
	card.add_theme_stylebox_override("panel", _flat_style(Color("#24677b"), 28, Color("#f8d66b"), 5))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	center.add_child(margin)
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
