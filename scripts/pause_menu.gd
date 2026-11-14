class_name PauseMenu
extends Control
## Pause overlay for Monster Merge (v1.3, Worker A).
##
## Own CanvasLayer, layer 20 — above the board popups (10) and the casino
## panels (15), below the settings panel (25) and the quit dialog (30).
## Main sets get_tree().paused = true while this is open; this node runs
## with process_mode = PROCESS_MODE_ALWAYS so its buttons (and Escape on
## desktop) still work while the tree is paused. It never pauses the tree
## itself — Main owns that, so the pause/unpause state stays in one place.
##
## Signals: Main wires them up (resume / settings / how-to / quit-to-menu /
## quit-game). show_menu()/hide_menu() are the public API; Control.show()/
## hide() do the same thing and also work.

signal resume_requested
signal settings_requested
signal howto_requested
signal quit_to_menu_requested
signal quit_game_requested

var _built := false
# v1.3.1 fix (BUG 1): same internal-CanvasLayer trap as SettingsPanel —
# the layer does NOT follow the parent Control's visibility, so `visible`
# alone never hid the pause dim. The layer's own `visible` is toggled
# together with the Control's in every show/hide path (plus the
# visibility_changed backstop below, so plain show()/hide() stay correct).
var _layer: CanvasLayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visibility_changed.connect(_on_visibility_changed)
	visible = false
	_build()


## Backstop: any path that flips this Control's `visible` keeps the
## internal layer in sync.
func _on_visibility_changed() -> void:
	if _layer != null:
		_layer.visible = visible


func show_menu() -> void:
	visible = true
	if _layer != null:
		_layer.visible = true


func hide_menu() -> void:
	visible = false
	if _layer != null:
		_layer.visible = false


func is_open() -> bool:
	return _layer != null and _layer.visible


## Escape on desktop while paused: Main's _unhandled_input is paused with
## the tree, so this node (PROCESS_MODE_ALWAYS) handles it itself and
## resumes. Android back arrives via Main._notification instead.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if OS.has_feature("android"):
		return
	if event.is_action_pressed("ui_cancel"):
		_sfx("play_click")
		resume_requested.emit()
		get_viewport().set_input_as_handled()


func _build() -> void:
	if _built:
		return
	_built = true
	var layer := CanvasLayer.new()
	layer.layer = 20
	_layer = layer
	_layer.visible = false
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
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 26)
	frame.add_child(margin)
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(520, 0)
	card.add_theme_constant_override("separation", 14)
	margin.add_child(card)

	var title := Label.new()
	title.text = "⏸  PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color("#ffe27b"))
	title.add_theme_color_override("font_shadow_color", Color("#7a3c10"))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 4)
	card.add_child(title)
	var sub := Label.new()
	sub.text = "Take a breather — your monsters wait for you!"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 19)
	sub.add_theme_color_override("font_color", Color("#9fb4d8"))
	card.add_child(sub)

	card.add_child(_pause_button("▶   RESUME", Color("#2a6b4a"), func() -> void: resume_requested.emit()))
	card.add_child(_pause_button("⚙️   SETTINGS", Color("#1d2a44"), func() -> void: settings_requested.emit()))
	card.add_child(_pause_button("❓   HOW TO PLAY", Color("#4a3a1d"), func() -> void: howto_requested.emit()))
	card.add_child(_pause_button("🏠   QUIT TO MENU", Color("#287e8b"), func() -> void: quit_to_menu_requested.emit()))
	card.add_child(_pause_button("🚪   QUIT GAME", Color("#8a1c27"), func() -> void: quit_game_requested.emit()))


func _pause_button(value: String, color: Color, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(0, 76)
	button.add_theme_font_size_override("font_size", 30)
	_style_button(button, color)
	button.pressed.connect(func() -> void: _sfx("play_click"))
	button.pressed.connect(on_pressed)
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

func _sfx(method_name: String) -> void:
	var sm := get_node_or_null("/root/SoundManager")
	if sm != null and sm.has_method(method_name):
		sm.call(method_name)
