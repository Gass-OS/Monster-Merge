extends Control
class_name ComboManager

## Combo system (v1.3, Worker D).
##
## WIRING (coordinator): add a ComboManager node to the game scene and call
##   combo_manager.setup(game_manager)
## then parent/position it near the coin counter (it is a Control; its root
## is itself — place it with anchors/offsets like any Control). It shows
## nothing while the combo is below x2.
##
## RULES:
##   - Listens to GameManager.merge_happened(tier, bonus).
##   - A merge within COMBO_WINDOW (5 s) of the previous one chains the
##     combo: x2, x3, x4... (no cap; the label shows up to x9+).
##   - Each chained merge pays bonus coins = 10 x (combo_level - 1) extra,
##     on top of the normal +10, via game_manager.add_coins().
##   - The combo resets when 5 s pass without a merge; a shrinking timer
##     bar under the label shows the time left.
##   - signal combo_changed(level) fires on every change (level 0 = reset).
##   - Plays SoundManager.play_combo(level) when the autoload exists.

signal combo_changed(level: int)

const COMBO_WINDOW := 5.0
const COMBO_BONUS_PER_LEVEL := 10

var combo_label: Label
var timer_bar: ProgressBar

var _manager: MonsterGameManager
var _combo := 0
var _time_left := 0.0
var _connected := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	_update_ui()

func setup(manager: MonsterGameManager) -> void:
	_manager = manager
	if _manager != null and not _connected:
		_manager.merge_happened.connect(_on_merge)
		_connected = true

func get_combo() -> int:
	return _combo

func get_time_left() -> float:
	return maxf(0.0, _time_left)

func reset_combo() -> void:
	_combo = 0
	_time_left = 0.0
	_update_ui()
	combo_changed.emit(0)

func _build_ui() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	combo_label = Label.new()
	combo_label.text = ""
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.add_theme_font_size_override("font_size", 26)
	combo_label.add_theme_color_override("font_color", Color("#ffdf58"))
	combo_label.add_theme_color_override("font_shadow_color", Color("#854c12"))
	combo_label.add_theme_constant_override("shadow_offset_x", 2)
	combo_label.add_theme_constant_override("shadow_offset_y", 2)
	combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(combo_label)
	timer_bar = ProgressBar.new()
	timer_bar.min_value = 0.0
	timer_bar.max_value = COMBO_WINDOW
	timer_bar.value = 0.0
	timer_bar.show_percentage = false
	timer_bar.custom_minimum_size = Vector2(120, 8)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.25)
	bg.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#ffdf58")
	fill.set_corner_radius_all(4)
	timer_bar.add_theme_stylebox_override("background", bg)
	timer_bar.add_theme_stylebox_override("fill", fill)
	timer_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(timer_bar)

func _process(delta: float) -> void:
	if _combo <= 0:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		reset_combo()
	else:
		timer_bar.value = _time_left

func _on_merge(_tier: int, _bonus: int) -> void:
	if _time_left > 0.0 and _combo > 0:
		_combo += 1
	else:
		_combo = 1
	_time_left = COMBO_WINDOW
	if _combo > 1 and _manager != null:
		# Bonus on top of the normal +10: 10 x (level - 1).
		_manager.add_coins(COMBO_BONUS_PER_LEVEL * (_combo - 1))
	_update_ui()
	combo_changed.emit(_combo)
	var sm := get_node_or_null("/root/SoundManager")
	if sm != null and sm.has_method("play_combo"):
		sm.call("play_combo", _combo)

func _update_ui() -> void:
	if combo_label == null:
		return
	if _combo >= 2:
		combo_label.text = "COMBO x%d  +%d" % [_combo, COMBO_BONUS_PER_LEVEL * (_combo - 1)]
		timer_bar.value = _time_left
		visible = true
	else:
		combo_label.text = ""
		timer_bar.value = 0.0
		visible = false
