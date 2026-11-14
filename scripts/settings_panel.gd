class_name SettingsPanel
extends Control
## Settings panel for Monster Merge (v1.3, Worker A).
##
## One panel, usable from BOTH the main menu and the pause menu: Main owns
## a single instance (own CanvasLayer, layer 25 — above the pause menu at
## 20, below the quit dialog at 30) and opens it on settings_requested from
## either place. process_mode = PROCESS_MODE_ALWAYS so it works while the
## tree is paused (opened from the pause menu).
##
## Contents: music volume + on/off, sound volume + on/off, voices on/off,
## vibration on/off, theme selector (Sunny Day / Sunset / Starry Night /
## Candy Land), RESET PROGRESS with a DOUBLE confirm. Every change applies
## immediately and persists (SettingsManager saves on every setter).
##
## Signals: reset_confirmed (Main calls GameManager.reset_save()), closed.

signal reset_confirmed
signal closed

var _settings: SettingsManager = null
var _built := false

var _music_slider: HSlider
var _music_toggle: Button
var _sound_slider: HSlider
var _sound_toggle: Button
var _voices_toggle: Button
var _vibration_toggle: Button
var _theme_buttons: Dictionary = {}
var _confirm1: ColorRect = null
var _confirm2: ColorRect = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func setup(settings: SettingsManager) -> void:
	_settings = settings
	_refresh_all()


func open() -> void:
	_refresh_all()
	visible = true


func close_panel() -> void:
	visible = false
	_hide_confirms()
	closed.emit()


func is_open() -> bool:
	return visible


# --- Build -------------------------------------------------------------------

func _build() -> void:
	if _built:
		return
	_built = true
	var layer := CanvasLayer.new()
	layer.layer = 25
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.05, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _flat_style(Color("#24677b"), 22, Color("#f8d66b"), 5))
	center.add_child(frame)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	frame.add_child(margin)
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(560, 0)
	card.add_theme_constant_override("separation", 12)
	margin.add_child(card)

	var title := Label.new()
	title.text = "⚙️  SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color("#ffe27b"))
	card.add_child(title)

	# Music: slider + on/off toggle.
	_music_slider = _slider_row(card, "🎵  MUSIC", func(v: float) -> void: _on_music_volume(v))
	_music_toggle = _toggle_row(card, "Music", true, func() -> void: _on_music_toggle())
	# Sound: slider + on/off toggle.
	_sound_slider = _slider_row(card, "🔊  SOUND", func(v: float) -> void: _on_sound_volume(v))
	_sound_toggle = _toggle_row(card, "Sound", true, func() -> void: _on_sound_toggle())
	# Voices + vibration toggles (stored; other workers read them).
	_voices_toggle = _toggle_row(card, "🗣️  VOICES", true, func() -> void: _on_voices_toggle())
	_vibration_toggle = _toggle_row(card, "📳  VIBRATION", true, func() -> void: _on_vibration_toggle())

	# Theme selector: 4 buttons, 2x2.
	var theme_label := Label.new()
	theme_label.text = "🎨  THEME"
	theme_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	theme_label.add_theme_font_size_override("font_size", 22)
	theme_label.add_theme_color_override("font_color", Color("#ffe27b"))
	card.add_child(theme_label)
	var theme_grid := GridContainer.new()
	theme_grid.columns = 2
	theme_grid.add_theme_constant_override("h_separation", 10)
	theme_grid.add_theme_constant_override("v_separation", 10)
	card.add_child(theme_grid)
	for theme_id in SettingsManager.THEMES:
		var b := Button.new()
		b.text = SettingsManager.theme_display_name(theme_id)
		b.custom_minimum_size = Vector2(0, 56)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 22)
		_style_button(b, Color("#1d2a44"))
		var tid: String = theme_id
		b.pressed.connect(func() -> void: _on_theme(tid))
		theme_grid.add_child(b)
		_theme_buttons[theme_id] = b

	# Reset progress (double confirm) + close.
	var reset := Button.new()
	reset.text = "🗑️   RESET PROGRESS"
	reset.custom_minimum_size = Vector2(0, 64)
	reset.add_theme_font_size_override("font_size", 26)
	_style_button(reset, Color("#8a1c27"))
	reset.pressed.connect(_on_reset_pressed)
	card.add_child(reset)
	var close := Button.new()
	close.text = "DONE"
	close.custom_minimum_size = Vector2(0, 64)
	close.add_theme_font_size_override("font_size", 26)
	_style_button(close, Color("#2a6b4a"))
	close.pressed.connect(func() -> void: _sfx("play_click"))
	close.pressed.connect(close_panel)
	card.add_child(close)

	# Double-confirm dialogs for reset (built once, shown on demand).
	_confirm1 = _make_confirm(layer,
		"Reset all progress?",
		"Coins, monsters and unlocks will be lost.",
		func() -> void: _show_confirm2(),
		func() -> void: _hide_confirms())
	_confirm2 = _make_confirm(layer,
		"Are you really sure?",
		"This cannot be undone.",
		func() -> void: _hide_confirms(); reset_confirmed.emit(),
		func() -> void: _hide_confirms())


func _slider_row(parent: VBoxContainer, label_text: String, on_changed: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(150, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = 0.8
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0, 44)
	slider.value_changed.connect(on_changed)
	row.add_child(slider)
	return slider


func _toggle_row(parent: VBoxContainer, label_text: String, initial: bool, on_pressed: Callable) -> Button:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(label)
	var toggle := Button.new()
	toggle.text = "ON" if initial else "OFF"
	toggle.custom_minimum_size = Vector2(120, 52)
	toggle.add_theme_font_size_override("font_size", 24)
	_style_button(toggle, Color("#2a6b4a"))
	toggle.pressed.connect(func() -> void: _sfx("play_click"))
	toggle.pressed.connect(on_pressed)
	row.add_child(toggle)
	return toggle


func _make_confirm(layer: CanvasLayer, title_text: String, body_text: String, on_yes: Callable, on_no: Callable) -> ColorRect:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.62)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	layer.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _flat_style(Color("#24677b"), 22, Color("#f8d66b"), 5))
	center.add_child(frame)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	frame.add_child(margin)
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(500, 0)
	card.add_theme_constant_override("separation", 14)
	margin.add_child(card)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#ffe27b"))
	card.add_child(title)
	var body := Label.new()
	body.text = body_text
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 19)
	body.add_theme_color_override("font_color", Color("#9fb4d8"))
	card.add_child(body)
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 14)
	card.add_child(btn_row)
	var yes := Button.new()
	yes.text = "YES"
	yes.custom_minimum_size = Vector2(0, 62)
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.add_theme_font_size_override("font_size", 26)
	_style_button(yes, Color("#8a1c27"))
	yes.pressed.connect(func() -> void: _sfx("play_click"))
	yes.pressed.connect(on_yes)
	btn_row.add_child(yes)
	var no := Button.new()
	no.text = "NO"
	no.custom_minimum_size = Vector2(0, 62)
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.add_theme_font_size_override("font_size", 26)
	_style_button(no, Color("#2a6b4a"))
	no.pressed.connect(func() -> void: _sfx("play_click"))
	no.pressed.connect(on_no)
	btn_row.add_child(no)
	return overlay


# --- Handlers (every change applies + persists via SettingsManager) ---------

func _on_music_volume(value: float) -> void:
	if _settings != null:
		_settings.set_music_volume(value)


func _on_music_toggle() -> void:
	if _settings != null:
		_settings.set_music_enabled(not _settings.music_enabled)
	_refresh_all()


func _on_sound_volume(value: float) -> void:
	if _settings != null:
		_settings.set_sound_volume(value)


func _on_sound_toggle() -> void:
	if _settings != null:
		_settings.set_sound_enabled(not _settings.sound_enabled)
	_refresh_all()


func _on_voices_toggle() -> void:
	if _settings != null:
		_settings.set_voices_enabled(not _settings.voices_enabled)
	_refresh_all()


func _on_vibration_toggle() -> void:
	if _settings != null:
		_settings.set_vibration_enabled(not _settings.vibration_enabled)
		_settings.vibrate()
	_refresh_all()


func _on_theme(theme_id: String) -> void:
	if _settings != null:
		_settings.set_theme(theme_id)
	_refresh_all()


func _on_reset_pressed() -> void:
	_sfx("play_click")
	if _confirm1 != null:
		_confirm1.visible = true


func _show_confirm2() -> void:
	if _confirm1 != null:
		_confirm1.visible = false
	if _confirm2 != null:
		_confirm2.visible = true


func _hide_confirms() -> void:
	if _confirm1 != null:
		_confirm1.visible = false
	if _confirm2 != null:
		_confirm2.visible = false


# --- Refresh UI from the stored settings -------------------------------------

func _refresh_all() -> void:
	if _settings == null or not _built:
		return
	_music_slider.set_value_no_signal(_settings.music_volume)
	_sound_slider.set_value_no_signal(_settings.sound_volume)
	_set_toggle(_music_toggle, _settings.music_enabled)
	_set_toggle(_sound_toggle, _settings.sound_enabled)
	_set_toggle(_voices_toggle, _settings.voices_enabled)
	_set_toggle(_vibration_toggle, _settings.vibration_enabled)
	for theme_id in _theme_buttons:
		var b: Button = _theme_buttons[theme_id]
		var selected: bool = theme_id == _settings.theme
		# Selected theme gets the gold border; the rest keep the plain style.
		var base := Color("#2a6b4a") if selected else Color("#1d2a44")
		_style_button(b, base)
		if selected:
			b.add_theme_stylebox_override("normal", _flat_style(base, 22, Color("#f8d66b"), 5))
			b.add_theme_stylebox_override("hover", _flat_style(base.lightened(0.08), 22, Color("#f8d66b"), 5))
			b.add_theme_stylebox_override("pressed", _flat_style(base.darkened(0.12), 22, Color("#f8d66b"), 5))


func _set_toggle(button: Button, on: bool) -> void:
	if button == null:
		return
	button.text = "ON" if on else "OFF"
	_style_button(button, Color("#2a6b4a") if on else Color("#5a5a6e"))


# --- Local style helpers (same look as the menu / board UI) ------------------

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

func _sfx(method_name: String) -> void:
	var sm := get_node_or_null("/root/SoundManager")
	if sm != null and sm.has_method(method_name):
		sm.call(method_name)
