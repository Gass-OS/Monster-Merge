extends Control
class_name MysteryEgg

## Mystery Egg — gacha hatch, in-game coins only, never real money.
##
## RULES
## - Costs 150 coins per hatch.
## - Hatches a RANDOM monster of tier 1–3, capped at the highest tier you
##   have unlocked: the tier range is 1..min(3, highest_unlocked).
##   (So a brand-new player can only hatch tiers 1..1, i.e. eggs, until they
##   merge up and unlock higher tiers.)
## - The monster goes onto a RANDOM EMPTY board slot (via
##   game_manager.add_monster_tier()).
## - BOARD-FULL RULE: if the board has no empty slot, you do NOT lose the
##   monster — instead you are paid its coin value, tier x 50 coins
##   (e.g. a tier-3 hatch on a full board pays 150 coins). This is the same
##   fallback the Lucky Spin FREE EGG prize uses.
## - The egg cracks with a shake + scale + flash animation before the
##   monster is revealed, with confetti on tier 3.
##
## USAGE (wired by the coordinator in main.gd / main_menu.gd):
##   var egg := MysteryEgg.new()
##   add_child(egg); egg.setup(game_manager); egg.open()

const HATCH_COST := 150
const MAX_HATCH_TIER := 3
const ConfettiFXScript = preload("res://scripts/confetti_fx.gd")
const TileScript = preload("res://scripts/monster_tile.gd")

var manager: MonsterGameManager
var missions_manager = null  # v1.3 integration: MissionsManager (optional).

var _egg_label: Label
var _reveal_tile: MonsterTile
var _reveal_name: Label
var _result_label: Label
var _hatch_button: Button
var _cracking: bool = false
var _crack_time: float = 0.0
var _pending_tier: int = 1
var _egg_base_pos: Vector2 = Vector2.ZERO

func setup(game_manager: MonsterGameManager) -> void:
	manager = game_manager
	visible = false
	_build()

func open() -> void:
	visible = true
	_show_egg()
	_result_label.text = "150 🪙 — what will hatch? 🥚"
	_sound_click()

func close() -> void:
	visible = false
	_sound_click()

# Random hatch tier, capped by unlocks: 1..min(3, highest_unlocked).
func roll_tier() -> int:
	var top := 1
	if manager != null:
		top = mini(MAX_HATCH_TIER, maxi(1, manager.highest_unlocked))
	return randi_range(1, top)

# Start a hatch (with the cracking animation). Returns false when broke.
# Pass instant=true to skip the animation (used by headless tests).
func hatch(instant: bool = false) -> bool:
	if manager == null or _cracking:
		return false
	if not manager.spend_coins(HATCH_COST):
		_result_label.text = "Not enough coins! Need 150 🪙"
		return false
	manager.save_game()
	# v1.3 integration: daily-mission progress.
	if missions_manager != null and missions_manager.has_method("notify_egg_hatched"):
		missions_manager.notify_egg_hatched()
	_pending_tier = roll_tier()
	_sound_pop()
	if instant:
		_reveal(_pending_tier)
		return true
	_cracking = true
	_crack_time = 0.0
	_egg_base_pos = _egg_label.position
	_hatch_button.disabled = true
	_result_label.text = "Cracking… 🥚"
	return true

# Apply the hatch result immediately (used by the animation end AND tests).
# Returns a description of what the player got.
func _reveal(tier: int) -> String:
	_cracking = false
	_hatch_button.disabled = false
	_show_reveal(tier)
	var tier_name: String = MonsterGameManager.MONSTER_NAMES[tier - 1]
	var message := ""
	if manager.add_monster_tier(tier):
		message = "It hatched a %s! (Tier %d) 🎉" % [tier_name, tier]
	else:
		var payout := tier * 50
		manager.add_coins(payout)
		manager.save_game()
		message = "Board full! %s paid %d coins instead 🪙" % [tier_name, payout]
	_result_label.text = message
	if tier >= 3:
		_sound_unlock()
		_confetti()
	else:
		_sound_ding()
	return message

func _process(delta: float) -> void:
	if not visible or not _cracking:
		return
	_crack_time += delta
	# Shake harder as the crack builds, then pop the reveal.
	var shake := 4.0 + _crack_time * 26.0
	_egg_label.position = _egg_base_pos + Vector2(
		randf_range(-shake, shake), randf_range(-shake, shake))
	var scale_pulse := 1.0 + sin(_crack_time * 18.0) * 0.06
	_egg_label.scale = Vector2(scale_pulse, scale_pulse)
	if int(_crack_time * 10.0) % 3 == 0:
		_sound_click()
	if _crack_time >= 1.4:
		_egg_label.position = _egg_base_pos
		_egg_label.scale = Vector2.ONE
		_reveal(_pending_tier)

func _show_egg() -> void:
	_egg_label.visible = true
	_egg_label.text = "🥚"
	_egg_label.modulate = Color.WHITE
	_reveal_tile.visible = false
	_reveal_name.visible = false

func _show_reveal(tier: int) -> void:
	_egg_label.visible = false
	_reveal_tile.visible = true
	_reveal_tile.set_monster(tier)
	_reveal_name.visible = true
	_reveal_name.text = MonsterGameManager.MONSTER_NAMES[tier - 1]
	# Flash the reveal in.
	_reveal_tile.modulate = Color(2.0, 2.0, 2.0)
	var tween := _reveal_tile.create_tween()
	tween.tween_property(_reveal_tile, "modulate", Color.WHITE, 0.4)

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
	style.border_color = Color("#ba68c8")
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
	title.text = "🥚 MYSTERY EGG"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#7b1fa2"))
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "✕"
	close_button.custom_minimum_size = Vector2(56, 56)
	close_button.add_theme_font_size_override("font_size", 26)
	close_button.pressed.connect(close)
	header.add_child(close_button)

	var rules := Label.new()
	rules.text = "Hatch a random monster, tier 1–3 (up to your highest unlock).\nBoard full? You get tier × 50 coins instead."
	rules.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.add_theme_font_size_override("font_size", 20)
	rules.add_theme_color_override("font_color", Color("#714319"))
	layout.add_child(rules)

	_egg_label = Label.new()
	_egg_label.text = "🥚"
	_egg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_egg_label.add_theme_font_size_override("font_size", 170)
	_egg_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	layout.add_child(_egg_label)

	_reveal_tile = TileScript.new()
	_reveal_tile.custom_minimum_size = Vector2(190, 210)
	_reveal_tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_reveal_tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reveal_tile.visible = false
	layout.add_child(_reveal_tile)

	_reveal_name = Label.new()
	_reveal_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reveal_name.add_theme_font_size_override("font_size", 26)
	_reveal_name.add_theme_color_override("font_color", Color("#26374c"))
	_reveal_name.visible = false
	layout.add_child(_reveal_name)

	_hatch_button = Button.new()
	_hatch_button.text = "HATCH! 150 🪙"
	_hatch_button.custom_minimum_size = Vector2(280, 72)
	_hatch_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_hatch_button.add_theme_font_size_override("font_size", 30)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color("#ba68c8")
	btn_style.set_corner_radius_all(36)
	btn_style.content_margin_top = 8
	btn_style.content_margin_bottom = 8
	_hatch_button.add_theme_stylebox_override("normal", btn_style)
	_hatch_button.add_theme_color_override("font_color", Color.WHITE)
	_hatch_button.pressed.connect(func() -> void: hatch(false))
	layout.add_child(_hatch_button)

	_result_label = Label.new()
	_result_label.text = "150 🪙 — what will hatch? 🥚"
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
