extends Control
class_name MonsterSlots

## Monster Slots — 3-reel slot machine, in-game coins only, never real money.
##
## RULES
## - A spin costs 50 coins.
## - Each reel shows a monster face (a real MonsterTile, tier 1..highest
##   unlocked, so new monsters you unlock join the reels).
## - 3 MATCHING faces = BIG WIN: tier x 100 coins (e.g. three tier-3 dinos
##   pay 300 coins).
## - 2 MATCHING faces = small win: 25 coins.
## - No match = nothing (the coins are gone — the house always smiles).
## - Reels stop staggered: left, then middle, then right, with tick sounds.
##
## USAGE (wired by the coordinator in main.gd / main_menu.gd):
##   var slots := MonsterSlots.new()
##   add_child(slots); slots.setup(game_manager); slots.open()

const SPIN_COST := 50
const TWO_MATCH_WIN := 25

## v1.3 integration: missions wiring (set by Main) + win signal.
signal win_paid(win: int)
const ConfettiFXScript = preload("res://scripts/confetti_fx.gd")
const TileScript = preload("res://scripts/monster_tile.gd")

var manager: MonsterGameManager
var missions_manager = null  # v1.3 integration: MissionsManager (optional).
var spinning: bool = false

var _reels: Array = []
var _spin_button: Button
var _result_label: Label
var _spin_time: float = 0.0
var _stop_times: Array[float] = [0.7, 1.2, 1.7]
var _final_tiers: Array[int] = [1, 1, 1]
var _stopped: Array[bool] = [true, true, true]
var _shuffle_clock: float = 0.0

func setup(game_manager: MonsterGameManager) -> void:
	manager = game_manager
	visible = false
	_build()

func open() -> void:
	visible = true
	_result_label.text = "Match 3 monsters to win big! 🎰"
	_sound_click()

func close() -> void:
	visible = false
	_sound_click()

# Pure win evaluation — no side effects, used by the spin AND by tests.
# Returns the coins won for the three reel tiers.
static func evaluate_reels(a: int, b: int, c: int) -> int:
	if a == b and b == c:
		return a * 100
	if a == b or b == c or a == c:
		return TWO_MATCH_WIN
	return 0

# Start a spin. Returns false when spinning already or not enough coins.
func do_spin() -> bool:
	if spinning or manager == null:
		return false
	if not manager.spend_coins(SPIN_COST):
		_result_label.text = "Not enough coins! Need 50 🪙"
		return false
	manager.save_game()
	# v1.3 integration: daily-mission progress.
	if missions_manager != null and missions_manager.has_method("notify_slots_played"):
		missions_manager.notify_slots_played()
	_final_tiers = [_random_tier(), _random_tier(), _random_tier()]
	_stopped = [false, false, false]
	_spin_time = 0.0
	_shuffle_clock = 0.0
	spinning = true
	_spin_button.disabled = true
	_result_label.text = "Spinning… 🎰"
	_sound_pop()
	return true

func _process(delta: float) -> void:
	if not visible or not spinning:
		return
	_spin_time += delta
	_shuffle_clock += delta
	# Shuffle any reel that has not stopped yet.
	if _shuffle_clock >= 0.08:
		_shuffle_clock = 0.0
		for i in _reels.size():
			if not _stopped[i]:
				_reels[i].set_monster(_random_tier())
				_sound_click()
	# Staggered stops: left, middle, right.
	for i in _reels.size():
		if not _stopped[i] and _spin_time >= _stop_times[i]:
			_stopped[i] = true
			_reels[i].set_monster(_final_tiers[i])
			_sound_ding()
	if _stopped[0] and _stopped[1] and _stopped[2]:
		spinning = false
		_spin_button.disabled = false
		_pay_out()

# Test/settlement hook: force a reel result and pay it out immediately
# (used by headless tests; the normal path goes through the spin animation).
func settle_with(a: int, b: int, c: int) -> void:
	_final_tiers = [a, b, c]
	_pay_out()

func _pay_out() -> void:
	var win := evaluate_reels(_final_tiers[0], _final_tiers[1], _final_tiers[2])
	if win > 0:
		manager.add_coins(win)
		manager.save_game()
		# v1.3 integration: win signal (Main adds fanfare/voice).
		win_paid.emit(win)
	if _final_tiers[0] == _final_tiers[1] and _final_tiers[1] == _final_tiers[2]:
		var tier_name: String = MonsterGameManager.MONSTER_NAMES[_final_tiers[0] - 1]
		_result_label.text = "🎉 JACKPOT! Three %s — you won %d coins!" % [tier_name, win]
		_sound_unlock()
		_confetti()
		_flash_reels()
	elif win > 0:
		_result_label.text = "Nice! Two match — you won %d coins! 🪙" % win
		_sound_ding()
		_flash_reels()
	else:
		_result_label.text = "No match this time — spin again! 🍀"
		_sound_pop()

func _flash_reels() -> void:
	for reel in _reels:
		var tween: Tween = reel.create_tween()
		tween.tween_property(reel, "modulate", Color(1.6, 1.6, 1.2), 0.15)
		tween.tween_property(reel, "modulate", Color.WHITE, 0.35)

func _random_tier() -> int:
	var top := 1
	if manager != null:
		top = maxi(1, manager.highest_unlocked)
	return randi_range(1, top)

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
	panel.custom_minimum_size = Vector2(620, 640)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#fff8df")
	style.set_corner_radius_all(28)
	style.set_border_width_all(4)
	style.border_color = Color("#ffc93c")
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	panel.add_child(layout)

	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(header)
	var title := Label.new()
	title.text = "🎰 MONSTER SLOTS"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#b8860b"))
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "✕"
	close_button.custom_minimum_size = Vector2(56, 56)
	close_button.add_theme_font_size_override("font_size", 26)
	close_button.pressed.connect(close)
	header.add_child(close_button)

	var rules := Label.new()
	rules.text = "3 match = tier × 100 🪙   •   2 match = 25 🪙   •   Spin = 50 🪙"
	rules.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.add_theme_font_size_override("font_size", 20)
	rules.add_theme_color_override("font_color", Color("#714319"))
	layout.add_child(rules)

	var reel_row := HBoxContainer.new()
	reel_row.alignment = BoxContainer.ALIGNMENT_CENTER
	reel_row.add_theme_constant_override("separation", 16)
	layout.add_child(reel_row)
	for i in 3:
		var tile = TileScript.new()
		tile.custom_minimum_size = Vector2(150, 170)
		tile.set_monster(i + 1)
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reel_row.add_child(tile)
		_reels.append(tile)

	_spin_button = Button.new()
	_spin_button.text = "SPIN! 50 🪙"
	_spin_button.custom_minimum_size = Vector2(280, 72)
	_spin_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_spin_button.add_theme_font_size_override("font_size", 30)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color("#ffc93c")
	btn_style.set_corner_radius_all(36)
	btn_style.content_margin_top = 8
	btn_style.content_margin_bottom = 8
	_spin_button.add_theme_stylebox_override("normal", btn_style)
	_spin_button.add_theme_color_override("font_color", Color("#714319"))
	_spin_button.pressed.connect(do_spin)
	layout.add_child(_spin_button)

	_result_label = Label.new()
	_result_label.text = "Match 3 monsters to win big! 🎰"
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
