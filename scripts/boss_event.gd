extends Control
class_name BossEvent

## Boss Rush event for Monster Merge v1.3 ("Deep Systems").
##
## TRIGGER: every 25 merges (game_manager.total_merges, persisted in the
## save; it counts merges SINCE THE LAST BOSS FIGHT ENDED and resets to 0
## when a fight ends, win or escape) the boss becomes READY and the BOSS
## button lights up and pulses. The player starts the fight from the button.
##
## FIGHT: a giant boss monster appears in a compact panel docked at the top
## of the screen (above the board; it covers the decorative title / progress
## rows, not the coins bar, and only the very top edge of the board). The
## panel shows the boss name + level, a big HP bar with numbers, and a
## 60-second countdown (label + bar). The boss bobs gently and its eyes
## glow red (angry overlay drawn over the existing MonsterTile creature art,
## drawn at large scale — no new art assets).
##
## ATTACK (two paths, both supported):
##   1. TAP: while a fight is active, tapping a board monster SELECTS it as
##      the attacker (glowing ring, same visual as tap-to-merge). Tapping
##      the boss then attacks with it. Tapping another monster switches the
##      attacker; tapping the selected monster again deselects.
##   2. DRAG: drag a board monster onto the boss panel and release — the
##      monster attacks on drop (gold ring appears on the boss while the
##      dragged monster hovers over it).
## The attacking monster is CONSUMED: its grid cell is emptied and it deals
## damage = tier x 10 (a tier-3 deals 30). Normal merging still works during
## a fight (the player may want to build a bigger monster first); merging
## the selected attacker clears the selection, and the merge result becomes
## the new selected attacker.
##
## BOSS NAMES (cycle after level 6): level 1 "Giga Slime King", 2 "Inferno
## Wyrm", 3 "Dark Dragon", 4 "Cosmic Terror", 5 "Void Phoenix", 6 "Doom
## Robo-Rex", 7+ repeats from the start of the list.
## BOSS HP: 300 + 150 x (boss_level - 1)  (level 1 = 300, level 2 = 450, ...).
## WIN (HP hits 0 before the timer ends): JACKPOT coins = 500 + 250 x
## boss_level, plus one Mystery Egg — a random tier 1-3 monster placed on a
## random empty board slot via GameManager.add_monster_tier(); if the board
## is full, the player instead gets tier x 50 coins. bosses_defeated += 1,
## boss_level += 1, total_merges resets to 0. WIN banner + confetti +
## fanfare (play_unlock + play_ding).
## FAIL (timer hits 0 with HP left): the boss escapes, taunt banner, NO
## reward, boss_level stays, total_merges resets to 0 (next boss ready
## after 25 more merges).
##
## PAUSE: the timer freezes while the tree is paused (the default process
## mode stops _process), and ALSO while `fight_paused` is set — the pause
## worker should call set_fight_paused(true) when its pause menu opens and
## set_fight_paused(false) when it closes.
##
## INTEGRATION (coordinator): create BossEvent, add it to the scene AFTER
## the UIManager (or on its own CanvasLayer, layer ~12, below the casino
## layer 15), then call setup(game_manager, ui_manager.grid). The node is a
## full-rect Control with mouse_filter IGNORE, so it never blocks the board
## except where its own panel / button / banner sit. `boss_button` is public:
## it defaults to a badge at the top-right (above the board, clear of the
## title and the coins bar); reposition or reparent it if the layout wants
## it elsewhere (e.g. next to the GALLERY button).
## API: setup(gm, grid), start_fight() -> bool, is_fighting(), is_ready(),
## set_fight_paused(bool), get_boss_hp/max/time_left/name/level().
## Signals: boss_defeated(level, reward), boss_escaped(level).

signal boss_defeated(level: int, reward: int)
signal boss_escaped(level: int)

## v1.3 integration: MissionsManager (set by Main) for the boss achievement.
var missions_manager = null

const TileScript = preload("res://scripts/monster_tile.gd")
const ConfettiFXScript = preload("res://scripts/confetti_fx.gd")

const MERGES_PER_BOSS := 25
const FIGHT_DURATION := 60.0
const BOSS_NAMES := [
	"Giga Slime King", "Inferno Wyrm", "Dark Dragon",
	"Cosmic Terror", "Void Phoenix", "Doom Robo-Rex",
]
# Creature tier drawn for each boss name (reuses MonsterTile art).
const BOSS_TIERS := [2, 4, 8, 8, 5, 7]
const PANEL_WIDTH := 660.0
const PANEL_TOP := 96.0
const PANEL_HEIGHT := 180.0
const BOSS_SIZE := 150.0

var boss_button: Button

var _gm: MonsterGameManager
var _grid: MonsterGridManager
var _setup_done := false
var _ui_built := false

var _fighting := false
var _fight_paused := false
var _fight_level := 1
var _boss_name := ""
var _boss_hp := 0
var _boss_max_hp := 1
var _time_left := 0.0
var _last_timer_sec := -1
var _selected_attacker := -1
var _last_drag_source := -1
var _drag_over_boss := false

var _bob_t := 0.0
var _pulse_t := 0.0
var _shake_x := 0.0
var _hit_tween: Tween

var _boss_panel: PanelContainer
var _boss_visual: Control
var _boss_tile: MonsterTile
var _eyes_overlay: AngryEyesOverlay
var _name_label: Label
var _hp_bar: ProgressBar
var _hp_label: Label
var _timer_label: Label
var _timer_bar: ProgressBar
var _banner: ColorRect
var _banner_title: Label
var _banner_sub: Label
var _banner_reward: Label
var _banner_button: Button


# --- Static rules (documented formulas, also used by tests) -----------------

static func boss_name_for_level(level: int) -> String:
	return BOSS_NAMES[(level - 1) % BOSS_NAMES.size()]


static func boss_tier_for_level(level: int) -> int:
	return BOSS_TIERS[(level - 1) % BOSS_TIERS.size()]


static func boss_hp_for_level(level: int) -> int:
	return 300 + 150 * (level - 1)


static func boss_reward_for_level(level: int) -> int:
	return 500 + 250 * level


static func damage_for_tier(tier: int) -> int:
	return tier * 10


# --- Setup / public API ------------------------------------------------------

func _ready() -> void:
	_build_ui()


func setup(game_manager: MonsterGameManager, grid_manager: MonsterGridManager) -> void:
	if _setup_done:
		return
	_setup_done = true
	_gm = game_manager
	_grid = grid_manager
	if not _ui_built:
		_build_ui()
	if _gm != null:
		_gm.merge_happened.connect(_on_merge_happened)
		_gm.state_changed.connect(_on_state_changed)
	if _grid != null:
		for tile in _grid.tiles:
			tile.tile_tapped.connect(_on_board_tile_tapped)
			tile.drag_hovered.connect(_on_board_drag_hovered)
			tile.drag_ended.connect(_on_board_drag_ended)
	_refresh_button()


func is_ready() -> bool:
	return _gm != null and not _fighting and _gm.total_merges >= MERGES_PER_BOSS


func is_fighting() -> bool:
	return _fighting


func set_fight_paused(value: bool) -> void:
	# Called by the pause worker when its pause menu opens / closes. The
	# tree pause also freezes _process on its own; this flag covers a pause
	# menu that does NOT pause the tree.
	_fight_paused = value


func get_boss_hp() -> int:
	return _boss_hp


func get_boss_max_hp() -> int:
	return _boss_max_hp


func get_time_left() -> float:
	return _time_left


func get_boss_name() -> String:
	return _boss_name


func get_boss_level() -> int:
	return _fight_level


func start_fight() -> bool:
	if _fighting or not is_ready() or _gm == null:
		return false
	_fight_level = _gm.boss_level
	_boss_name = boss_name_for_level(_fight_level)
	_boss_max_hp = boss_hp_for_level(_fight_level)
	_boss_hp = _boss_max_hp
	_time_left = FIGHT_DURATION
	_last_timer_sec = -1
	_fighting = true
	_fight_paused = false
	_selected_attacker = -1
	_last_drag_source = -1
	_drag_over_boss = false
	_boss_tile.set_monster(boss_tier_for_level(_fight_level))
	_boss_tile.modulate = Color.WHITE
	_name_label.text = "👹 %s  •  LV %d" % [_boss_name, _fight_level]
	_hp_bar.max_value = _boss_max_hp
	_update_hp_ui()
	_update_timer_ui()
	_boss_panel.visible = true
	_refresh_button()
	# Roar on spawn (guarded: falls back silently if SoundManager is absent).
	_sfx("play_roar")
	return true


# --- Per-frame: timer, bobbing, glow, button pulse ---------------------------

func _process(delta: float) -> void:
	_pulse_t += delta
	if _fighting:
		_bob_t += delta
		if not _fight_paused:
			_time_left -= delta
			_update_timer_ui()
			if _time_left <= 0.0:
				_time_left = 0.0
				_escape()
				return
		# Gentle bobbing (keeps animating while fight_paused; the timer is
		# what freezes) + pulsing angry-eye glow.
		var bob := sin(_bob_t * 2.4) * 5.0
		_boss_tile.position = Vector2(_shake_x, bob)
		_eyes_overlay.position = Vector2(0, bob)
		_eyes_overlay.pulse = _bob_t
		_eyes_overlay.queue_redraw()
	if boss_button != null and boss_button.visible and is_ready():
		boss_button.modulate = Color(1, 1, 1, 0.82 + 0.18 * sin(_pulse_t * 5.0))


# --- Attack: tap-select-then-tap-boss, and drag-onto-boss --------------------

func _on_board_tile_tapped(index: int) -> void:
	if not _fighting or _grid == null:
		return
	if index < 0 or index >= _grid.tiles.size():
		return
	if _grid.tiles[index].tier <= 0:
		_clear_attacker_selection()
		return
	if _selected_attacker == index:
		_clear_attacker_selection()
		return
	# Tapping another monster switches the attacker. (If the grid just
	# merged the old attacker into this tile, the merge result becomes the
	# attacker — see _on_merge_happened, which runs first.)
	_clear_attacker_selection()
	_selected_attacker = index
	_grid.tiles[index].set_selected(true)
	_sfx("play_click")


func _on_boss_tapped(_index: int) -> void:
	if not _fighting:
		return
	if _selected_attacker >= 0:
		_attack(_selected_attacker)
	else:
		_sfx("play_click")


func _on_board_drag_hovered(source_index: int, global_position: Vector2) -> void:
	if not _fighting:
		return
	_last_drag_source = source_index
	_drag_over_boss = _boss_visual != null and _boss_visual.get_global_rect().has_point(global_position)
	_eyes_overlay.drop_target = _drag_over_boss
	_eyes_overlay.queue_redraw()


func _on_board_drag_ended() -> void:
	var src := _last_drag_source
	var over := _drag_over_boss
	_last_drag_source = -1
	_drag_over_boss = false
	if _eyes_overlay != null:
		_eyes_overlay.drop_target = false
		_eyes_overlay.queue_redraw()
	if _fighting and over and src >= 0:
		_attack(src)


func _attack(index: int) -> void:
	if not _fighting or _gm == null:
		return
	if index < 0 or index >= MonsterGameManager.GRID_SIZE:
		return
	var tier: int = _gm.grid[index]
	if tier <= 0:
		_clear_attacker_selection()
		return
	var damage := damage_for_tier(tier)
	# The attacking monster is CONSUMED: its grid cell is emptied.
	_gm.grid[index] = 0
	_clear_attacker_selection()
	_boss_hp = maxi(0, _boss_hp - damage)
	_update_hp_ui()
	_sfx("play_pop")
	_sfx("play_ding")
	# Hit shake + red flash on the boss.
	_shake_x = 0.0
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	_hit_tween = create_tween()
	_hit_tween.tween_property(self, "_shake_x", 10.0, 0.06)
	_hit_tween.tween_property(self, "_shake_x", -8.0, 0.06)
	_hit_tween.tween_property(self, "_shake_x", 0.0, 0.08)
	_boss_tile.modulate = Color(1.6, 0.6, 0.6)
	var flash := create_tween()
	flash.tween_property(_boss_tile, "modulate", Color.WHITE, 0.25)
	_gm.state_changed.emit()
	_gm.save_game()
	if _boss_hp <= 0:
		_win()


func _clear_attacker_selection() -> void:
	if _selected_attacker >= 0 and _grid != null and _selected_attacker < _grid.tiles.size():
		_grid.tiles[_selected_attacker].set_selected(false)
	_selected_attacker = -1


# --- Win / escape -------------------------------------------------------------

func _win() -> void:
	var level := _fight_level
	var reward := boss_reward_for_level(level)
	_fighting = false
	_reset_boss_visual()
	_boss_panel.visible = false
	# Mystery Egg: random tier 1-3 monster on a random empty slot. Board
	# full -> compensation of tier x 50 coins instead.
	var egg_tier := randi_range(1, 3)
	var egg_placed := _gm.add_monster_tier(egg_tier)
	var egg_bonus := 0
	if not egg_placed:
		egg_bonus = egg_tier * 50
		_gm.add_coins(egg_bonus)
	_gm.add_coins(reward)
	_gm.bosses_defeated += 1
	_gm.boss_level += 1
	_gm.total_merges = 0
	_gm.save_game()
	# v1.3 integration: boss achievement.
	if missions_manager != null and missions_manager.has_method("notify_boss_defeated"):
		missions_manager.notify_boss_defeated()
	_sfx("play_unlock")
	_sfx("play_ding")
	boss_defeated.emit(level, reward)
	var egg_text := "🥚 Mystery Egg: Tier %d monster joined your board!" % egg_tier
	if not egg_placed:
		egg_text = "🥚 Board was full: +%d coins instead of a Mystery Egg!" % egg_bonus
	_show_banner(
		"🏆 BOSS DEFEATED!",
		"%s (LV %d) is down!" % [_boss_name, level],
		"💰 Jackpot: +%d coins\n%s" % [reward, egg_text],
		"COLLECT",
		true
	)
	_refresh_button()


func _escape() -> void:
	var level := _fight_level
	_fighting = false
	_reset_boss_visual()
	_boss_panel.visible = false
	_clear_attacker_selection()
	_gm.total_merges = 0
	_gm.save_game()
	_sfx("play_click")
	boss_escaped.emit(level)
	_show_banner(
		"💨 THE BOSS ESCAPED…",
		"%s (LV %d) slipped away!" % [_boss_name, level],
		"It will return stronger!\nMerge 25 more times to face it again.",
		"OK",
		false
	)
	_refresh_button()


func _reset_boss_visual() -> void:
	_shake_x = 0.0
	_boss_tile.position = Vector2.ZERO
	_boss_tile.modulate = Color.WHITE
	_eyes_overlay.position = Vector2.ZERO
	_eyes_overlay.drop_target = false
	_eyes_overlay.queue_redraw()


# --- GameManager hooks ---------------------------------------------------------

func _on_merge_happened(_tier: int, _bonus: int) -> void:
	# Merging the selected attacker consumes it, so the selection is gone;
	# the grid's tap handler then selects the merge result as the attacker.
	_clear_attacker_selection()
	_refresh_button()


func _on_state_changed() -> void:
	# A state change can empty the selected attacker's cell (attack, merge,
	# reset): drop a stale selection.
	if _selected_attacker >= 0 and (_gm == null or _selected_attacker >= _gm.grid.size() or _gm.grid[_selected_attacker] <= 0):
		_clear_attacker_selection()


# --- UI ------------------------------------------------------------------------

func _build_ui() -> void:
	if _ui_built:
		return
	_ui_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# BOSS button: top-right badge, above the board, clear of the title and
	# the coins bar. Public (boss_button) so the coordinator can move it.
	boss_button = Button.new()
	boss_button.anchor_left = 1.0
	boss_button.anchor_right = 1.0
	boss_button.offset_left = -190.0
	boss_button.offset_right = -24.0
	boss_button.offset_top = PANEL_TOP
	boss_button.offset_bottom = PANEL_TOP + 54.0
	boss_button.add_theme_font_size_override("font_size", 24)
	boss_button.pressed.connect(_on_boss_button_pressed)
	add_child(boss_button)

	# Boss panel: compact strip docked at the top of the screen.
	_boss_panel = PanelContainer.new()
	_boss_panel.anchor_left = 0.5
	_boss_panel.anchor_right = 0.5
	_boss_panel.offset_left = -PANEL_WIDTH * 0.5
	_boss_panel.offset_right = PANEL_WIDTH * 0.5
	_boss_panel.offset_top = PANEL_TOP
	_boss_panel.offset_bottom = PANEL_TOP + PANEL_HEIGHT
	_boss_panel.add_theme_stylebox_override("panel", _flat_style(Color("#4a1e2e"), 20, Color("#ff5d5d"), 4))
	_boss_panel.visible = false
	add_child(_boss_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_boss_panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	# Boss creature: a big MonsterTile (reuses the existing creature art)
	# plus a red angry-eyes overlay drawn on top of it.
	_boss_visual = Control.new()
	_boss_visual.custom_minimum_size = Vector2(BOSS_SIZE, BOSS_SIZE)
	row.add_child(_boss_visual)
	_boss_tile = TileScript.new()
	_boss_tile.tile_index = -1
	_boss_tile.custom_minimum_size = Vector2(BOSS_SIZE, BOSS_SIZE)
	_boss_tile.size = Vector2(BOSS_SIZE, BOSS_SIZE)
	_boss_tile.tile_tapped.connect(_on_boss_tapped)
	_boss_visual.add_child(_boss_tile)
	_eyes_overlay = AngryEyesOverlay.new()
	_eyes_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_eyes_overlay.size = Vector2(BOSS_SIZE, BOSS_SIZE)
	_boss_visual.add_child(_eyes_overlay)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 6)
	row.add_child(info)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 28)
	_name_label.add_theme_color_override("font_color", Color.WHITE)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_child(_name_label)

	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	info.add_child(hp_row)
	_hp_bar = ProgressBar.new()
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_bar.custom_minimum_size = Vector2(0, 26)
	_hp_bar.max_value = 300
	_hp_bar.show_percentage = false
	_hp_bar.add_theme_stylebox_override("background", _flat_style(Color("#2a0f1c"), 12))
	_hp_bar.add_theme_stylebox_override("fill", _flat_style(Color("#ff4d4d"), 12))
	hp_row.add_child(_hp_bar)
	_hp_label = Label.new()
	_hp_label.text = "❤ 300 / 300"
	_hp_label.add_theme_font_size_override("font_size", 20)
	_hp_label.add_theme_color_override("font_color", Color.WHITE)
	hp_row.add_child(_hp_label)

	var timer_row := HBoxContainer.new()
	timer_row.add_theme_constant_override("separation", 8)
	info.add_child(timer_row)
	_timer_label = Label.new()
	_timer_label.text = "⏱ 60s"
	_timer_label.add_theme_font_size_override("font_size", 22)
	_timer_label.add_theme_color_override("font_color", Color("#ffd166"))
	timer_row.add_child(_timer_label)
	_timer_bar = ProgressBar.new()
	_timer_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timer_bar.custom_minimum_size = Vector2(0, 18)
	_timer_bar.max_value = FIGHT_DURATION
	_timer_bar.value = FIGHT_DURATION
	_timer_bar.show_percentage = false
	_timer_bar.add_theme_stylebox_override("background", _flat_style(Color("#2a0f1c"), 9))
	_timer_bar.add_theme_stylebox_override("fill", _flat_style(Color("#ff9f1c"), 9))
	timer_row.add_child(_timer_bar)

	var hint := Label.new()
	hint.text = "Tap a monster, then tap the boss — or drag a monster onto it!"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color("#ffd9d9"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_child(hint)

	# WIN / escape banner: full-screen dim + centred card (modal).
	_banner = ColorRect.new()
	_banner.color = Color(0, 0, 0, 0.62)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_banner.visible = false
	add_child(_banner)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_banner.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _flat_style(Color("#fff8df"), 24, Color("#ffb52e"), 5))
	center.add_child(card)
	var card_margin := MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 32)
	card_margin.add_theme_constant_override("margin_right", 32)
	card_margin.add_theme_constant_override("margin_top", 28)
	card_margin.add_theme_constant_override("margin_bottom", 28)
	card.add_child(card_margin)
	var card_box := VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 14)
	card_margin.add_child(card_box)
	_banner_title = Label.new()
	_banner_title.add_theme_font_size_override("font_size", 44)
	_banner_title.add_theme_color_override("font_color", Color("#c0392b"))
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_box.add_child(_banner_title)
	_banner_sub = Label.new()
	_banner_sub.add_theme_font_size_override("font_size", 24)
	_banner_sub.add_theme_color_override("font_color", Color("#273b52"))
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_box.add_child(_banner_sub)
	_banner_reward = Label.new()
	_banner_reward.add_theme_font_size_override("font_size", 26)
	_banner_reward.add_theme_color_override("font_color", Color("#714319"))
	_banner_reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_box.add_child(_banner_reward)
	_banner_button = Button.new()
	_banner_button.custom_minimum_size = Vector2(260, 70)
	_banner_button.add_theme_font_size_override("font_size", 28)
	_banner_button.add_theme_stylebox_override("normal", _flat_style(Color("#f27642"), 22, Color("#c0392b"), 4))
	_banner_button.add_theme_stylebox_override("pressed", _flat_style(Color("#d35400"), 22, Color("#c0392b"), 4))
	_banner_button.add_theme_color_override("font_color", Color.WHITE)
	_banner_button.pressed.connect(func() -> void: _banner.visible = false)
	card_box.add_child(_banner_button)


func _show_banner(title: String, subtitle: String, reward_text: String, button_text: String, is_win: bool) -> void:
	_banner_title.text = title
	_banner_sub.text = subtitle
	_banner_reward.text = reward_text
	_banner_button.text = button_text
	_banner.visible = true
	if is_win:
		var confetti := ConfettiFXScript.new()
		confetti.count = 120
		confetti.duration = 3.5
		_banner.add_child(confetti)


func _on_boss_button_pressed() -> void:
	if is_ready():
		start_fight()
	else:
		_sfx("play_click")


func _refresh_button() -> void:
	if boss_button == null:
		return
	if _fighting:
		boss_button.visible = false
		return
	boss_button.visible = true
	boss_button.modulate = Color.WHITE
	if _gm == null:
		boss_button.disabled = true
		boss_button.text = "⚔ BOSS"
		return
	if is_ready():
		boss_button.disabled = false
		boss_button.text = "⚔ BOSS READY!"
		_style_button(boss_button, Color("#c0392b"))
	else:
		boss_button.disabled = true
		boss_button.text = "⚔ BOSS %d/%d" % [_gm.total_merges, MERGES_PER_BOSS]
		_style_button(boss_button, Color("#7a8a99"))


func _update_hp_ui() -> void:
	if _hp_bar != null:
		_hp_bar.value = _boss_hp
	if _hp_label != null:
		_hp_label.text = "❤ %d / %d" % [_boss_hp, _boss_max_hp]


func _update_timer_ui() -> void:
	if _timer_bar != null:
		_timer_bar.value = maxf(0.0, _time_left)
	var sec := int(ceil(maxf(0.0, _time_left)))
	if sec != _last_timer_sec:
		_last_timer_sec = sec
		if _timer_label != null:
			_timer_label.text = "⏱ %ds" % sec


func _flat_style(color: Color, radius: int, border: Color = Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = border
	style.set_border_width_all(border_width)
	return style


func _style_button(button: Button, color: Color) -> void:
	button.add_theme_stylebox_override("normal", _flat_style(color, 18, color.darkened(0.2), 3))
	button.add_theme_stylebox_override("hover", _flat_style(color.lightened(0.08), 18, color.darkened(0.2), 3))
	button.add_theme_stylebox_override("pressed", _flat_style(color.darkened(0.12), 18, color.darkened(0.25), 3))
	button.add_theme_stylebox_override("disabled", _flat_style(color, 18, color.darkened(0.2), 3))
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.75))


func _sfx(method_name: String) -> void:
	var sm := get_node_or_null("/root/SoundManager")
	if sm != null and sm.has_method(method_name):
		sm.call(method_name)


## Red glowing angry eyes + brow slashes drawn over the boss creature, plus
## a gold ring while a dragged monster hovers over the boss (drop target).
## Eye positions mirror MonsterTile._draw: centre (0.5w, 0.47h), s = 0.31 x
## min(w, h), eyes at centre +/- (0.32s, -0.08s).
class AngryEyesOverlay:
	extends Control
	var pulse: float = 0.0
	var drop_target: bool = false

	func _draw() -> void:
		var center := Vector2(size.x * 0.5, size.y * 0.47)
		var s := minf(size.x, size.y) * 0.31
		var eye_l := center + Vector2(-s * 0.32, -s * 0.08)
		var eye_r := center + Vector2(s * 0.32, -s * 0.08)
		var er := maxf(3.5, s * 0.13)
		var glow_a := 0.55 + 0.35 * sin(pulse * 4.0)
		draw_circle(eye_l, er * 2.2, Color(1, 0.15, 0.1, glow_a * 0.35))
		draw_circle(eye_r, er * 2.2, Color(1, 0.15, 0.1, glow_a * 0.35))
		draw_circle(eye_l, er * 1.15, Color(1, 0.1, 0.05, glow_a))
		draw_circle(eye_r, er * 1.15, Color(1, 0.1, 0.05, glow_a))
		draw_circle(eye_l, er * 0.45, Color(1, 0.9, 0.6, 0.9))
		draw_circle(eye_r, er * 0.45, Color(1, 0.9, 0.6, 0.9))
		# Angry brows: slashes angled down toward the centre.
		var bw := er * 1.9
		var brow := Color(0.45, 0.02, 0.02, 0.95)
		draw_line(eye_l + Vector2(-bw, -er * 1.6), eye_l + Vector2(bw, -er * 0.4), brow, 4.0, true)
		draw_line(eye_r + Vector2(-bw, -er * 0.4), eye_r + Vector2(bw, -er * 1.6), brow, 4.0, true)
		if drop_target:
			var ring := StyleBoxFlat.new()
			ring.bg_color = Color(1, 0.85, 0.3, 0.12)
			ring.border_color = Color(1, 0.85, 0.3, 0.95)
			ring.set_border_width_all(6)
			ring.set_corner_radius_all(18)
			draw_style_box(ring, Rect2(Vector2.ZERO, size).grow(-2))
