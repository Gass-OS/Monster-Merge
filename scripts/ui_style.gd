extends RefCounted
class_name UIStyle

## Small shared helpers for the dark-fantasy look.

static func flat(color: Color, radius: int, border: Color = Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = border
	style.set_border_width_all(border_width)
	return style

static func style_button(button: Button, color: Color) -> void:
	button.add_theme_stylebox_override("normal", flat(color, 22, color.darkened(0.2), 4))
	button.add_theme_stylebox_override("hover", flat(color.lightened(0.08), 22, color.darkened(0.2), 4))
	button.add_theme_stylebox_override("pressed", flat(color.darkened(0.12), 22, color.darkened(0.25), 4))
	button.add_theme_stylebox_override("disabled", flat(Color("#1a2130"), 22, Color("#2a3448"), 4))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("#5d6b86"))

static func compact(value: float) -> String:
	if value >= 1000000000.0:
		return "%.1fB" % (value / 1000000000.0)
	if value >= 1000000.0:
		return "%.1fM" % (value / 1000000.0)
	if value >= 10000.0:
		return "%.1fK" % (value / 1000.0)
	return str(int(value))
