extends Control
class_name LuckySpin

## Lucky Spin wheel — casino-style fun, in-game coins only, never real money.
##
## RULES
## - 8 segments: 50 / 100 / 250 / 500 coins, FREE EGG, 2X PASSIVE (60 s),
##   JACKPOT 1000 coins, TRY AGAIN.
## - The FIRST spin on a save is FREE. Every further spin costs 100 coins.
## - The free-spin state is persisted in the save file ("free_spin_used").
## - FREE EGG spawns a tier-1 egg on a random empty board slot; if the board
##   is full it pays 50 coins instead (same fallback as the Mystery Egg).
## - 2X PASSIVE doubles passive income for 60 seconds (see game_manager).
## - TRY AGAIN pays nothing — but the wheel is kind, it still celebrates.
##
## USAGE (wired by the coordinator in main.gd / main_menu.gd):
##   var spin := LuckySpin.new()
##   add_child(spin); spin.setup(game_manager); spin.open()

## v1.3 integration: missions wiring (set by Main) + win signal.
signal prize_won(kind: String, value: int)

const SPIN_COST := 100
const PASSIVE_2X_SECONDS := 60.0
const ConfettiFXScript = preload("res://scripts/confetti_fx.gd")

# kind: "coins" | "egg" | "passive2x" | "try_again"
const PRIZES := [
	{"label": "50", "short": "50 🪙", "kind": "coins", "value": 50,
		"color": Color("#4dd0e1")},
	{"label": "100", "short": "100 🪙", "kind": "coins", "value": 100,
		"color": Color("#81c784")},
	{"label": "250", "short": "250 🪙", "kind": "coins", "value": 250,
		"color": Color("#ffc93c")},
	{"label": "500", "short": "500 🪙", "kind": "coins", "value": 500,
		"color": Color("#ff8a65")},
	{"label": "FREE\nEGG", "short": "FREE EGG 🥚", "kind": "egg", "value": 1,
		"color": Color("#ba68c8")},
	{"label": "2X\nPASSIVE", "short": "2X PASSIVE 60s ⚡", "kind": "passive2x",
		"value": 60, "color": Color("#4cc3ff")},
	{"label": "JACKPOT\n1000", "short": "JACKPOT 1000! 🎉", "kind": "coins",
		"value": 1000, "color": Color("#ff5d8f")},
	{"label": "TRY\nAGAIN", "short": "TRY AGAIN 🍀", "kind": "try_again",
		"value": 0, "color": Color("#b0bec5")},
]

var manager: MonsterGameManager
var missions_manager = null  # v1.3 integration: MissionsManager (optional).
var spinning: bool = false

var _wheel: WheelView
var _spin_button: Button
var _cost_label: Label
var _result_label: Label
var _last_tick_segment: int = -1
var _pending_prize: int = -1

func setup(game_manager: MonsterGameManager) -> void:
	manager = game_manager
	visible = false
	_build()

func open() -> void:
	visible = true
	_update_cost_label()
	_result_label.text = "Spin the wheel, good luck! 🍀"
	_sound_click()

func close() -> void:
	visible = false
	_sound_click()

func spin_cost() -> int:
	if manager == null:
		return SPIN_COST
	return 0 if not manager.free_spin_used else SPIN_COST

func can_spin() -> bool:
	return manager != null and not spinning and manager.coins >= spin_cost()

# Start a spin. Returns false when spinning already or not enough coins.
func do_spin() -> bool:
	if spinning or manager == null:
		return false
	var cost := spin_cost()
	if not manager.spend_coins(cost):
		_result_label.text = "Not enough coins! Need %d 🪙" % cost
		return false
	if cost == 0:
		manager.mark_free_spin_used()
	manager.save_game()
	# v1.3 integration: daily-mission progress.
	if missions_manager != null and missions_manager.has_method("notify_wheel_spun"):
		missions_manager.notify_wheel_spun()
	_result_label.text = "Spinning… 🎡"
	_spin_button.disabled = true
	spinning = true
	_pending_prize = randi() % PRIZES.size()
	_animate_to_prize(_pending_prize)
	return true

# Apply a prize immediately (used by the spin animation end AND by tests).
func apply_prize(prize_index: int) -> String:
	var prize: Dictionary = PRIZES[clampi(prize_index, 0, PRIZES.size() - 1)]
	var kind: String = prize["kind"]
	var value: int = int(prize["value"])
	var message := ""
	match kind:
		"coins":
			manager.add_coins(value)
			message = "You won %d coins! 🪙" % value
		"egg":
			if manager.add_monster_tier(1):
				message = "FREE EGG! A new egg hatched on your board! 🥚"
			else:
				manager.add_coins(50)
				message = "Board full! FREE EGG paid 50 coins instead 🥚"
		"passive2x":
			manager.grant_passive_2x(PASSIVE_2X_SECONDS)
			message = "2X PASSIVE for 60 seconds! ⚡"
		_:
			message = "TRY AGAIN — so close! Spin once more 🍀"
	_result_label.text = message
	manager.save_game()
	# v1.3 integration: win signal (Main adds fanfare/voice) + jackpot mission.
	prize_won.emit(kind, value)
	if kind == "coins" and value >= 1000 and missions_manager != null and missions_manager.has_method("notify_jackpot_won"):
		missions_manager.notify_jackpot_won()
	if kind == "coins" and value >= 500:
		_sound_unlock()
		_confetti()
	elif kind != "try_again":
		_sound_ding()
		_confetti()
	else:
		_sound_pop()
	return message

func _animate_to_prize(prize_index: int) -> void:
	var step := TAU / float(PRIZES.size())
	var center: float = (float(prize_index) + 0.5) * step
	# Pointer sits at the top (-PI/2). Final wheel angle must put the prize
	# centre under the pointer.
	var pointer := -PI * 0.5
	var current: float = _wheel.angle
	var current_mod := fposmod(current, TAU)
	var delta := fposmod(pointer - center - current_mod, TAU)
	var target: float = current + TAU * 5.0 + delta
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_wheel, "angle", target, 3.2)
	tween.tween_callback(_on_spin_finished)

func _on_spin_finished() -> void:
	if _pending_prize < 0:
		return  # Already settled (e.g. finished twice) — never pay twice.
	spinning = false
	_spin_button.disabled = false
	apply_prize(_pending_prize)
	_update_cost_label()
	_pending_prize = -1

func _process(_delta: float) -> void:
	if not visible or not spinning or _wheel == null:
		return
	# Tick sound each time the pointer crosses into a new segment.
	var step := TAU / float(PRIZES.size())
	var seg := int(fposmod(-PI * 0.5 - _wheel.angle, TAU) / step)
	if seg != _last_tick_segment:
		_last_tick_segment = seg
		_sound_click()

func _update_cost_label() -> void:
	if manager == null:
		return
	if manager.free_spin_used:
		_cost_label.text = "Next spin: 100 🪙"
	else:
		_cost_label.text = "Your FIRST spin is FREE! 🎁"

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.1, 0.2, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	# v1.3.2: centre via a full-rect CenterContainer (same pattern as the
	# Settings/Pause panels). PRESET_CENTER on the panel itself was wrong:
	# at build time the panel size is (0,0), so its top-left landed at the
	# screen centre and the panel ran off the right/bottom edges.
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 860)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#fff8df")
	style.set_corner_radius_all(28)
	style.set_border_width_all(4)
	style.border_color = Color("#ff5d8f")
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	panel.add_child(layout)

	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(header)
	var title := Label.new()
	title.text = "🎡 LUCKY SPIN"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color("#d6336c"))
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "✕"
	close_button.custom_minimum_size = Vector2(56, 56)
	close_button.add_theme_font_size_override("font_size", 26)
	close_button.pressed.connect(close)
	header.add_child(close_button)

	var pointer := Label.new()
	pointer.text = "▼"
	pointer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pointer.add_theme_font_size_override("font_size", 34)
	pointer.add_theme_color_override("font_color", Color("#d6336c"))
	layout.add_child(pointer)

	_wheel = WheelView.new()
	_wheel.custom_minimum_size = Vector2(460, 460)
	_wheel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	layout.add_child(_wheel)

	_cost_label = Label.new()
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost_label.add_theme_font_size_override("font_size", 24)
	_cost_label.add_theme_color_override("font_color", Color("#714319"))
	layout.add_child(_cost_label)

	_spin_button = Button.new()
	_spin_button.text = "SPIN! 🎡"
	_spin_button.custom_minimum_size = Vector2(280, 72)
	_spin_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_spin_button.add_theme_font_size_override("font_size", 30)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color("#ff5d8f")
	btn_style.set_corner_radius_all(36)
	btn_style.content_margin_top = 8
	btn_style.content_margin_bottom = 8
	_spin_button.add_theme_stylebox_override("normal", btn_style)
	_spin_button.add_theme_color_override("font_color", Color.WHITE)
	_spin_button.pressed.connect(do_spin)
	layout.add_child(_spin_button)

	_result_label = Label.new()
	_result_label.text = "Spin the wheel, good luck! 🍀"
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_label.add_theme_font_size_override("font_size", 24)
	_result_label.add_theme_color_override("font_color", Color("#26374c"))
	layout.add_child(_result_label)

func _sound_click() -> void:
	var sm := get_node_or_null("/root/SoundManager")
	if sm != null and sm.has_method("play_click"):
		sm.play_click()

func _sound_pop() -> void:
	var sm := get_node_or_null("/root/SoundManager")
	if sm != null and sm.has_method("play_pop"):
		sm.play_pop()

func _sound_ding() -> void:
	var sm := get_node_or_null("/root/SoundManager")
	if sm != null and sm.has_method("play_ding"):
		sm.play_ding()

func _sound_unlock() -> void:
	var sm := get_node_or_null("/root/SoundManager")
	if sm != null and sm.has_method("play_unlock"):
		sm.play_unlock()

func _confetti() -> void:
	var fx := ConfettiFXScript.new()
	add_child(fx)

# --- Wheel drawing ---------------------------------------------------------
class WheelView extends Control:
	var angle: float = 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.5 - 6.0
		var step := TAU / float(LuckySpin.PRIZES.size())
		var font := ThemeDB.fallback_font
		for i in LuckySpin.PRIZES.size():
			var prize: Dictionary = LuckySpin.PRIZES[i]
			var a0: float = angle + float(i) * step
			var a1: float = a0 + step
			var pts := PackedVector2Array([center])
			var segments := 24
			for s in range(segments + 1):
				var a: float = lerpf(a0, a1, float(s) / float(segments))
				pts.append(center + Vector2(cos(a), sin(a)) * radius)
			draw_colored_polygon(pts, Color(prize["color"]))
			# Segment label near the middle of the wedge.
			var mid: float = (a0 + a1) * 0.5
			var label_pos := center + Vector2(cos(mid), sin(mid)) * radius * 0.62
			var text: String = prize["label"]
			var lines := text.split("\n")
			for li in lines.size():
				var y := label_pos.y + (float(li) - float(lines.size() - 1) * 0.5) * 22.0
				draw_string(font, Vector2(label_pos.x - 70.0, y + 7.0), lines[li],
					HORIZONTAL_ALIGNMENT_CENTER, 140.0, 20, Color.WHITE)
		# Rim + hub.
		draw_arc(center, radius, 0, TAU, 64, Color("#d6336c"), 6.0)
		draw_circle(center, 34.0, Color("#fff8df"))
		draw_arc(center, 34.0, 0, TAU, 32, Color("#d6336c"), 4.0)
		draw_string(font, center + Vector2(-34, 9), "★",
			HORIZONTAL_ALIGNMENT_CENTER, 68.0, 30, Color("#d6336c"))
