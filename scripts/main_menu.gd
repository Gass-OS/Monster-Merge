class_name MainMenu
extends Control
## Main menu for Monster Merge, built entirely in code.
## Shows the bright sky (its own BackgroundFX instance — the same script the
## board uses, not a rebuilt sky), the title, three monster previews and the
## menu buttons. The board UI stays hidden until PLAY.
## Emits signals; Main (main.gd) wires them up.
## NOTE: the HOW TO PLAY text advertises tap-to-merge; that input is being
## added to MonsterTile by a parallel worker (v1.2 scope).

signal play_requested
signal quit_requested
signal spin_requested
signal slots_requested
signal egg_requested

const TileScript = preload("res://scripts/monster_tile.gd")
const BackgroundFXScript = preload("res://scripts/background_fx.gd")

const PREVIEW_TIERS := [1, 2, 3]
const PREVIEW_NAMES := ["EGG", "SLIME", "DINO"]

var _ui_manager: MonsterUIManager
var _menu_layer: CanvasLayer
var _how_to_overlay: ColorRect = null
var _sound_button: Button
var _music_button: Button
var _muted: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_layer = CanvasLayer.new()
	_menu_layer.layer = 5
	add_child(_menu_layer)
	# Own sky instance: the board's BackgroundFX is a child of the (hidden)
	# UIManager, so it is hidden too while the menu is up.
	var bg := BackgroundFXScript.new()
	_menu_layer.add_child(bg)
	_build_layout()
	var sm := _sound_manager()
	if sm != null:
		_muted = bool(sm.get("muted"))
	_refresh_sound_button()
	_refresh_music_button()


func setup(ui_manager: MonsterUIManager) -> void:
	_ui_manager = ui_manager


## Closes the topmost menu-owned popup (HOW TO PLAY). Returns true if one
## was open. The gallery is owned by the UIManager, not the menu — Main
## closes that one via the ui popup_layer instead.
func close_top_popup() -> bool:
	if _how_to_overlay != null and is_instance_valid(_how_to_overlay):
		_how_to_overlay.queue_free()
		_how_to_overlay = null
		return true
	return false


func _build_layout() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 56)
	margin.add_theme_constant_override("margin_bottom", 36)
	_menu_layer.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	margin.add_child(layout)

	# Title.
	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 0)
	layout.add_child(title_box)
	var title1 := _label("MONSTER", 72, Color("#ffd94d"))
	title1.add_theme_color_override("font_shadow_color", Color("#7a3c10"))
	title1.add_theme_constant_override("shadow_offset_x", 4)
	title1.add_theme_constant_override("shadow_offset_y", 5)
	title_box.add_child(title1)
	var title2 := _label("MERGE", 72, Color("#ffd94d"))
	title2.add_theme_color_override("font_shadow_color", Color("#7a3c10"))
	title2.add_theme_constant_override("shadow_offset_x", 4)
	title2.add_theme_constant_override("shadow_offset_y", 5)
	title_box.add_child(title2)
	layout.add_child(_label("MERGE  •  EVOLVE  •  COLLECT!", 20, Color("#d7f5ff")))

	# Cute monster previews (Egg, Slime, Dino).
	var previews := HBoxContainer.new()
	previews.alignment = BoxContainer.ALIGNMENT_CENTER
	previews.add_theme_constant_override("separation", 20)
	layout.add_child(previews)
	for i in PREVIEW_TIERS.size():
		var item := VBoxContainer.new()
		item.add_theme_constant_override("separation", 4)
		var tile := TileScript.new()
		tile.set_monster(PREVIEW_TIERS[i])
		tile.custom_minimum_size = Vector2(150, 165)
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(tile)
		item.add_child(_label(PREVIEW_NAMES[i], 16, Color("#d7f5ff")))
		previews.add_child(item)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(spacer)

	# Buttons.
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	layout.add_child(buttons)
	var play := _menu_button("▶   PLAY", 96, 34, Color("#2a6b4a"))
	play.pressed.connect(_on_play_pressed)
	buttons.add_child(play)
	var gallery := _menu_button("🏆   GALLERY", 68, 26, Color("#1d2a44"))
	gallery.pressed.connect(_on_gallery_pressed)
	buttons.add_child(gallery)
	var how_to := _menu_button("❓   HOW TO PLAY", 68, 26, Color("#4a3a1d"))
	how_to.pressed.connect(_on_how_to_pressed)
	buttons.add_child(how_to)
	# Casino fun: one row of three so the menu still fits on a 720x1280 screen.
	var fun_row := HBoxContainer.new()
	fun_row.add_theme_constant_override("separation", 10)
	buttons.add_child(fun_row)
	var spin := _menu_button("🎡   SPIN", 64, 20, Color("#7b1fa2"))
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.pressed.connect(func() -> void: spin_requested.emit())
	fun_row.add_child(spin)
	var slots := _menu_button("🎰   SLOTS", 64, 20, Color("#b8860b"))
	slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots.pressed.connect(func() -> void: slots_requested.emit())
	fun_row.add_child(slots)
	var egg := _menu_button("🥚   EGG", 64, 20, Color("#287e8b"))
	egg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	egg.pressed.connect(func() -> void: egg_requested.emit())
	fun_row.add_child(egg)
	_music_button = _menu_button("🎵   MUSIC: ON", 68, 26, Color("#1d2a44"))
	_music_button.pressed.connect(_on_music_pressed)
	buttons.add_child(_music_button)
	_sound_button = _menu_button("🔊   SOUND: ON", 68, 26, Color("#1d2a44"))
	_sound_button.pressed.connect(_on_sound_pressed)
	buttons.add_child(_sound_button)
	var quit := _menu_button("🚪   QUIT", 68, 26, Color("#8a1c27"))
	quit.pressed.connect(_on_quit_pressed)
	buttons.add_child(quit)

	layout.add_child(_label("Your progress saves automatically  •  v1.2", 15, Color("#7f8fae")))


func _on_play_pressed() -> void:
	_sfx("play_click")
	play_requested.emit()


func _on_gallery_pressed() -> void:
	_sfx("play_click")
	if _ui_manager != null:
		# Existing gallery. It lives in the UIManager's popup_layer
		# (CanvasLayer 10), which renders above the menu even while the
		# board UI itself is hidden.
		_ui_manager._show_gallery()


func _on_how_to_pressed() -> void:
	_sfx("play_click")
	if _how_to_overlay != null and is_instance_valid(_how_to_overlay):
		return
	var overlay := ColorRect.new()
	overlay.color = Color(0.01, 0.01, 0.03, 0.9)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_layer.add_child(overlay)
	_how_to_overlay = overlay
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _flat_style(Color("#24677b"), 22, Color("#f8d66b"), 5))
	center.add_child(frame)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	frame.add_child(margin)
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(520, 0)
	card.add_theme_constant_override("separation", 14)
	margin.add_child(card)
	card.add_child(_label("HOW TO PLAY", 30, Color("#ffe27b")))
	card.add_child(_label("🥚  Tap SPAWN EGG — or just wait, a new egg hatches every few seconds.", 19, Color.WHITE))
	card.add_child(_label("👆  Drag one monster onto a matching one — or tap two matching monsters — to evolve it into the next tier!", 19, Color.WHITE))
	card.add_child(_label("🪙  Higher tiers earn more coins every second. Evolve all the way to the Cosmic King Dragon!", 19, Color.WHITE))
	card.add_child(_label("🏆  Open the GALLERY to see every monster you have discovered.", 19, Color("#9fb4d8")))
	var close := Button.new()
	close.text = "GOT IT!"
	close.custom_minimum_size.y = 60
	close.add_theme_font_size_override("font_size", 26)
	_style_button(close, Color("#2a6b4a"))
	close.pressed.connect(_close_how_to)
	card.add_child(close)


func _close_how_to() -> void:
	_sfx("play_click")
	if _how_to_overlay != null and is_instance_valid(_how_to_overlay):
		_how_to_overlay.queue_free()
		_how_to_overlay = null


func _on_sound_pressed() -> void:
	_sfx("play_click")
	var sm := _sound_manager()
	if sm != null and sm.has_method("toggle_mute"):
		_muted = bool(sm.call("toggle_mute"))
	else:
		_muted = not _muted
	_refresh_sound_button()


func _on_music_pressed() -> void:
	_sfx("play_click")
	var mm := get_node_or_null("/root/MusicManager")
	if mm != null and mm.has_method("toggle_music"):
		mm.toggle_music()
	_refresh_music_button()


func _on_quit_pressed() -> void:
	_sfx("play_click")
	quit_requested.emit()


func _refresh_music_button() -> void:
	if _music_button == null:
		return
	var mm := get_node_or_null("/root/MusicManager")
	var on := true
	if mm != null and "music_enabled" in mm:
		on = bool(mm.music_enabled)
	_music_button.text = "🎵   MUSIC: ON" if on else "🔇   MUSIC: OFF"


func _refresh_sound_button() -> void:
	if _sound_button == null:
		return
	_sound_button.text = "🔇   SOUND: OFF" if _muted else "🔊   SOUND: ON"


# --- Local style helpers (same look as the board UI) -------------------------

func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _menu_button(value: String, height: int, font_size: int, color: Color) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(0, height)
	button.add_theme_font_size_override("font_size", font_size)
	_style_button(button, color)
	return button


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


# --- Sound (SoundManager autoload, guarded) ----------------------------------
# Safe no-op when the autoload does not exist yet.

func _sound_manager() -> Node:
	return get_node_or_null("/root/SoundManager")


func _sfx(method_name: String) -> void:
	var sm := _sound_manager()
	if sm != null and sm.has_method(method_name):
		sm.call(method_name)
