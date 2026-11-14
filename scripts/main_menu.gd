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
signal settings_requested  # v1.3 (Worker A): opens the settings panel.
signal missions_requested  # v1.3 integration: opens the missions panel.
signal gift_requested  # v1.3 integration: opens the missions panel (gift card).

const TileScript = preload("res://scripts/monster_tile.gd")
const BackgroundFXScript = preload("res://scripts/background_fx.gd")

const PREVIEW_TIERS := [1, 2, 3]
const PREVIEW_NAMES := ["EGG", "SLIME", "DINO"]

var _ui_manager: MonsterUIManager
var _settings: SettingsManager = null  # v1.3 (Worker A): set via setup().
var _bg: BackgroundFX = null  # v1.3 integration: own sky, for theme changes.
var _menu_layer: CanvasLayer
var _how_to_overlay: ColorRect = null
var _about_overlay: ColorRect = null  # v1.3 (Worker A)
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
	_bg = BackgroundFXScript.new()
	_menu_layer.add_child(_bg)
	_build_layout()
	var sm := _sound_manager()
	if sm != null:
		_muted = bool(sm.get("muted"))
	_refresh_sound_button()
	_refresh_music_button()


## v1.3 integration: repaint this menu's sky when the theme changes.
func apply_theme(theme_id: String) -> void:
	if _bg != null:
		_bg.apply_theme(theme_id)


## v1.3 integration: rainbow celebration on the menu sky.
func show_rainbow() -> void:
	if _bg != null:
		_bg.show_rainbow()


func setup(ui_manager: MonsterUIManager, settings: SettingsManager = null) -> void:
	_ui_manager = ui_manager
	_settings = settings
	# Sync the quick-toggle state with the persisted settings.
	if _settings != null:
		_muted = not _settings.sound_enabled
		_refresh_sound_button()
		_refresh_music_button()


## Closes the topmost menu-owned popup (HOW TO PLAY / ABOUT). Returns true
## if one was open. The gallery is owned by the UIManager, not the menu —
## Main closes that one via the ui popup_layer instead. The settings panel
## is owned by Main, not the menu — Main closes it directly.
func close_top_popup() -> bool:
	if _how_to_overlay != null and is_instance_valid(_how_to_overlay):
		_how_to_overlay.queue_free()
		_how_to_overlay = null
		return true
	if _about_overlay != null and is_instance_valid(_about_overlay):
		_about_overlay.queue_free()
		_about_overlay = null
		return true
	return false


## v1.3 (Worker A): shows the About overlay. Closed by its button or by
## the Android back button (via close_top_popup()).
func show_about() -> void:
	_sfx("play_click")
	if _about_overlay != null and is_instance_valid(_about_overlay):
		return
	var overlay := ColorRect.new()
	overlay.color = Color(0.01, 0.01, 0.03, 0.9)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_layer.add_child(overlay)
	_about_overlay = overlay
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
	card.add_child(_label("ABOUT", 34, Color("#ffe27b")))
	card.add_child(_label("Monster Merge", 28, Color.WHITE))
	card.add_child(_label("Developed by Wael Gharsalli", 22, Color("#ffe27b")))
	card.add_child(_label("Version 1.3.0", 20, Color("#9fb4d8")))
	card.add_child(_label("Hatch mysterious eggs, merge matching creatures, earn coins and evolve your collection through eight magical monster tiers — all the way to the Cosmic King Dragon!", 19, Color.WHITE))
	card.add_child(_label("Daily missions • Gifts • Achievements • Lucky Spin • Four animated sky themes", 17, Color("#ffe27b")))
	card.add_child(_label("Built with Godot • Music & art generated in-game", 17, Color("#9fb4d8")))
	var close := Button.new()
	close.text = "CLOSE"
	close.custom_minimum_size.y = 60
	close.add_theme_font_size_override("font_size", 26)
	_style_button(close, Color("#2a6b4a"))
	close.pressed.connect(_close_about)
	card.add_child(close)


func _close_about() -> void:
	_sfx("play_click")
	if _about_overlay != null and is_instance_valid(_about_overlay):
		_about_overlay.queue_free()
		_about_overlay = null


func _build_layout() -> void:
	# Compact, responsive menu: every important control fits on a portrait
	# phone without pushing SPIN / EGG below the bottom edge.
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 22)
	_menu_layer.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var title := _label("MONSTER MERGE", 56, Color("#fff0a6"))
	title.add_theme_color_override("font_shadow_color", Color("#713c19"))
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 5)
	layout.add_child(title)
	layout.add_child(_label("HATCH  •  MERGE  •  EVOLVE  •  COLLECT!", 16, Color("#f4fbff")))

	# Three animated monster previews, scaled down to leave room for controls.
	var previews := HBoxContainer.new()
	previews.alignment = BoxContainer.ALIGNMENT_CENTER
	previews.add_theme_constant_override("separation", 12)
	layout.add_child(previews)
	for i in PREVIEW_TIERS.size():
		var item := VBoxContainer.new()
		item.add_theme_constant_override("separation", 2)
		var tile := TileScript.new()
		tile.set_monster(PREVIEW_TIERS[i])
		tile.custom_minimum_size = Vector2(112, 112)
		tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(tile)
		item.add_child(_label(PREVIEW_NAMES[i], 14, Color("#d7f5ff")))
		previews.add_child(item)

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 7)
	layout.add_child(buttons)

	var play := _menu_button("▶   PLAY", 72, 30, Color("#23864f"))
	play.pressed.connect(_on_play_pressed)
	buttons.add_child(play)

	var browse_row := HBoxContainer.new()
	browse_row.add_theme_constant_override("separation", 8)
	buttons.add_child(browse_row)
	var gallery := _menu_button("🏆  GALLERY", 52, 19, Color("#1d2a44"))
	gallery.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gallery.pressed.connect(_on_gallery_pressed)
	browse_row.add_child(gallery)
	var how_to := _menu_button("❓  HOW TO PLAY", 52, 19, Color("#4a3a1d"))
	how_to.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	how_to.pressed.connect(_on_how_to_pressed)
	browse_row.add_child(how_to)

	# Keep all three arcade actions together and immediately visible.
	var fun_row := HBoxContainer.new()
	fun_row.add_theme_constant_override("separation", 8)
	buttons.add_child(fun_row)
	var spin := _menu_button("🎡  SPIN", 54, 19, Color("#7b1fa2"))
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.pressed.connect(func() -> void: spin_requested.emit())
	fun_row.add_child(spin)
	var slots := _menu_button("🎰  SLOTS", 54, 19, Color("#b8860b"))
	slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots.pressed.connect(func() -> void: slots_requested.emit())
	fun_row.add_child(slots)
	var egg := _menu_button("🥚  MYSTERY EGG", 54, 18, Color("#287e8b"))
	egg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	egg.pressed.connect(func() -> void: egg_requested.emit())
	fun_row.add_child(egg)

	var quest_row := HBoxContainer.new()
	quest_row.add_theme_constant_override("separation", 8)
	buttons.add_child(quest_row)
	var missions_btn := _menu_button("📋  MISSIONS", 50, 18, Color("#6a4a9e"))
	missions_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	missions_btn.pressed.connect(func() -> void: missions_requested.emit())
	quest_row.add_child(missions_btn)
	var gift_btn := _menu_button("🎁  DAILY GIFT", 50, 18, Color("#b8860b"))
	gift_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gift_btn.pressed.connect(func() -> void: gift_requested.emit())
	quest_row.add_child(gift_btn)

	var settings_row := HBoxContainer.new()
	settings_row.add_theme_constant_override("separation", 8)
	buttons.add_child(settings_row)
	_music_button = _menu_button("🎵 MUSIC: ON", 46, 16, Color("#1d2a44"))
	_music_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_music_button.pressed.connect(_on_music_pressed)
	settings_row.add_child(_music_button)
	_sound_button = _menu_button("🔊 SOUND: ON", 46, 16, Color("#1d2a44"))
	_sound_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sound_button.pressed.connect(_on_sound_pressed)
	settings_row.add_child(_sound_button)
	var settings_btn := _menu_button("⚙️ SETTINGS", 46, 16, Color("#1d2a44"))
	settings_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_btn.pressed.connect(_on_settings_pressed)
	settings_row.add_child(settings_btn)

	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 8)
	buttons.add_child(bottom_row)
	var quit := _menu_button("🚪 QUIT", 44, 16, Color("#8a1c27"))
	quit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quit.pressed.connect(_on_quit_pressed)
	bottom_row.add_child(quit)
	var about := _menu_button("ℹ️ ABOUT", 44, 16, Color("#1d2a44"))
	about.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	about.pressed.connect(show_about)
	bottom_row.add_child(about)

	layout.add_child(_label("Developed by Wael Gharsalli", 14, Color("#ffe27b")))
	layout.add_child(_label("Progress saves automatically  •  v1.3.2", 13, Color("#9fb4d8")))


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


func _on_settings_pressed() -> void:
	_sfx("play_click")
	settings_requested.emit()


# v1.3 (Worker A): the quick toggles write through the SettingsManager when
# one is attached, so the choice persists; otherwise they fall back to the
# old direct-manager behaviour.
func _on_sound_pressed() -> void:
	_sfx("play_click")
	if _settings != null:
		_settings.set_sound_enabled(not _settings.sound_enabled)
		_muted = not _settings.sound_enabled
	else:
		var sm := _sound_manager()
		if sm != null and sm.has_method("toggle_mute"):
			_muted = bool(sm.call("toggle_mute"))
		else:
			_muted = not _muted
	_refresh_sound_button()


func _on_music_pressed() -> void:
	_sfx("play_click")
	if _settings != null:
		_settings.set_music_enabled(not _settings.music_enabled)
	else:
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
	var on := true
	if _settings != null:
		on = _settings.music_enabled
	else:
		var mm := get_node_or_null("/root/MusicManager")
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
