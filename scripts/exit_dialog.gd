class_name ExitDialog
extends Control
## Reusable quit-confirmation dialog: "Quit Monster Merge?" with YES / NO.
## Owned by Main (its own CanvasLayer, layer 20) so it works from the menu
## and from the board, and above every other popup. Emits confirmed /
## cancelled; Main decides what to do (quit, or just hide the dialog).

signal confirmed
signal cancelled

var _built := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func show_dialog() -> void:
	visible = true


func hide_dialog() -> void:
	visible = false


func is_open() -> bool:
	return visible


func _build() -> void:
	if _built:
		return
	_built = true
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
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
	card.add_theme_constant_override("separation", 16)
	margin.add_child(card)

	var title := Label.new()
	title.text = "Quit Monster Merge?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("#ffe27b"))
	card.add_child(title)
	var sub := Label.new()
	sub.text = "Your progress is saved automatically."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 19)
	sub.add_theme_color_override("font_color", Color("#9fb4d8"))
	card.add_child(sub)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	var yes := Button.new()
	yes.text = "YES, QUIT"
	yes.custom_minimum_size = Vector2(0, 66)
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.add_theme_font_size_override("font_size", 26)
	_style_button(yes, Color("#8a1c27"))
	yes.pressed.connect(_on_yes)
	row.add_child(yes)
	var no := Button.new()
	no.text = "NO, KEEP PLAYING"
	no.custom_minimum_size = Vector2(0, 66)
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.add_theme_font_size_override("font_size", 26)
	_style_button(no, Color("#2a6b4a"))
	no.pressed.connect(_on_no)
	row.add_child(no)


func _on_yes() -> void:
	_sfx("play_click")
	confirmed.emit()


func _on_no() -> void:
	_sfx("play_click")
	cancelled.emit()


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
