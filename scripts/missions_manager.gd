extends Node
class_name MissionsManager

## Daily Missions + Daily Gift + Gift Boxes + Achievements (v1.3, Worker B).
##
## DAILY MISSIONS
## - Each calendar day (Time.get_date_string_from_system()) generates 3 fresh
##   missions, picked from MISSION_POOL with a RandomNumberGenerator seeded
##   by the day string, so every player sees the same 3 missions that day.
## - Progress is tracked by connecting to the GameManager signals
##   (merge_happened, monster_unlocked, coins_changed) plus the notify_*
##   methods below. Rewards are CLAIMED via a button in the missions panel
##   (never auto-paid): claim_mission() pays via game_manager.add_coins().
## - Unclaimed completed missions stay claimable until the day rolls over;
##   at rollover the set regenerates and unclaimed rewards are lost.
##
## DAILY GIFT
## - Claimable once per calendar day. Reward scales with the consecutive-day
##   streak: day 1 = 100 coins, +50 per day; day 7+ = 500 coins + a FREE
##   Lucky Spin (sets game_manager.free_spin_used = false — the exact key
##   the wheel's spin_cost() checks). Claiming on the next calendar day
##   increments the streak; a missed day resets it to 1.
## - Persisted as game_manager.last_gift_date + gift_streak.
##
## GIFT BOXES
## - While playing, every 120-240 s (randomized) a gift box appears on a
##   random EMPTY board tile. It overlays the tile (it does NOT occupy the
##   grid cell — the tile index is stored separately in _box_tile). If that
##   tile gets filled by a spawn/merge, the box moves to another empty tile
##   (or waits hidden until one frees up). The box expires after 60 s if
##   untapped (gift_box_lifetime, tunable for tests).
## - Tap to open: coins 50-150, a free tier-1 egg on the board, or a free
##   Lucky Spin. Celebration: confetti + floating reward label.
##
## ACHIEVEMENTS
## - Fixed list (ACHIEVEMENTS), each claimable once for coins. Lifetime
##   counters (lifetime_merges, total_coins_earned) live on the GameManager.
## - Completed-but-unclaimed achievements show a badge via
##   pending_badge_count() (the UI manager puts a ❗ on the MISSIONS button).
##
## COORDINATOR WIRING (casino / boss code must call these — this file only
## exposes them; it never edits the casino scripts):
## - LuckySpin.do_spin() success (or _on_spin_finished) -> notify_wheel_spun()
## - LuckySpin.apply_prize() when the JACKPOT 1000 prize lands
##   -> notify_jackpot_won()
## - MonsterSlots.do_spin() success -> notify_slots_played()
## - MysteryEgg.hatch() success (or _reveal) -> notify_egg_hatched()
## - Boss system on boss kill -> notify_boss_defeated()
## All notify_* methods are safe to call any time (no-op when the day or
## manager is not ready); the missions panel is opened via open_panel().
##
## SETUP (wired by ui_manager.setup(); coordinator can also call
## ui_manager.attach_missions_manager(mm) with a fresh instance):
##   missions_manager.setup(game_manager, grid, popup_layer, ui_manager)
## - grid: the MonsterGridManager (for the gift-box tile positions).
## - popup_layer: the CanvasLayer the missions panel is added to.
## - box_parent: a full-rect Control the gift-box button is added to
##   (the UIManager itself).
## Date handling: a bad/empty system date never crashes anything — the day
## key is "" and every daily method fails closed (returns false / no-op).

signal missions_changed
signal achievement_completed(achievement_id: String)

const ConfettiFXScript = preload("res://scripts/confetti_fx.gd")

# kind, desc, target, reward (coins). 3 of these are picked per day.
const MISSION_POOL := [
	{"kind": "merge_5", "desc": "Merge 5 monsters", "target": 5, "reward": 100},
	{"kind": "merge_10", "desc": "Merge 10 monsters", "target": 10, "reward": 200},
	{"kind": "reach_tier_4", "desc": "Reach Tier 4", "target": 1, "reward": 200},
	{"kind": "wheel_once", "desc": "Spin the Lucky Wheel once", "target": 1, "reward": 150},
	{"kind": "slots_3", "desc": "Play Monster Slots 3 times", "target": 3, "reward": 200},
	{"kind": "earn_500", "desc": "Earn 500 coins today", "target": 500, "reward": 200},
	{"kind": "hatch_egg", "desc": "Hatch a Mystery Egg", "target": 1, "reward": 150},
	{"kind": "discover_tier", "desc": "Discover a new monster tier", "target": 1, "reward": 150},
]

# Fixed achievements, each claimable once. Rewards in coins.
const ACHIEVEMENTS := [
	{"id": "first_tier5", "desc": "Reach Tier 5 for the first time", "reward": 300},
	{"id": "merges_100", "desc": "Merge 100 monsters (total)", "reward": 500},
	{"id": "coins_1000", "desc": "Earn 1,000 coins in total", "reward": 300},
	{"id": "jackpot", "desc": "Win the Lucky Spin jackpot", "reward": 500},
	{"id": "boss_defeated", "desc": "Defeat the Boss", "reward": 500},
	{"id": "streak_7", "desc": "Claim the daily gift 7 days in a row", "reward": 500},
]

const GIFT_BOX_MIN_INTERVAL := 120.0
const GIFT_BOX_MAX_INTERVAL := 240.0

var manager: MonsterGameManager = null
var gift_box_lifetime: float = 60.0

var _grid: MonsterGridManager = null
var _panel_parent: Node = null
var _box_parent: Control = null
var _is_setup := false
var _last_coins := 0
var _rollover_clock := 0.0
var _box_timer := 0.0
var _next_box_in := GIFT_BOX_MIN_INTERVAL
var _box_button: Button = null
var _box_tile := -1
var _box_age := 0.0
var _box_waiting := false
var _last_box_pos := Vector2.ZERO
var _panel_overlay: ColorRect = null
var _panel_content: VBoxContainer = null


func setup(game_manager: MonsterGameManager, grid: MonsterGridManager, panel_parent: Node, box_parent: Control) -> void:
	if _is_setup:
		return
	if game_manager == null:
		return
	manager = game_manager
	_grid = grid
	_panel_parent = panel_parent
	_box_parent = box_parent
	_last_coins = manager.coins
	_is_setup = true
	manager.merge_happened.connect(_on_merge)
	manager.monster_unlocked.connect(_on_unlocked)
	manager.coins_changed.connect(_on_coins_changed)
	manager.state_changed.connect(_on_state_changed)
	_next_box_in = randf_range(GIFT_BOX_MIN_INTERVAL, GIFT_BOX_MAX_INTERVAL)
	_ensure_today()
	check_achievements()


func _process(delta: float) -> void:
	if not _is_setup or manager == null:
		return
	_rollover_clock += delta
	if _rollover_clock >= 1.0:
		_rollover_clock = 0.0
		_ensure_today()
	_tick_gift_box(delta)


# --- Date helpers ------------------------------------------------------------
# "" means the system date is unusable; every daily method fails closed.

func today_string() -> String:
	var d := Time.get_date_string_from_system()
	return d if d.length() == 10 else ""


func yesterday_string() -> String:
	var u := Time.get_unix_time_from_system()
	if u <= 0.0:
		return ""
	var d := Time.get_date_string_from_unix_time(int(u) - 86400)
	return d if d.length() == 10 else ""


## Coins for claiming the daily gift at the given streak.
## Day 1 = 100, +50/day; day 7 and beyond = 500 (+ free spin, see claim).
static func daily_gift_coins(streak: int) -> int:
	if streak >= 7:
		return 500
	return 100 + 50 * maxi(0, streak - 1)


# --- Daily missions ----------------------------------------------------------

## Make sure today's mission set exists; regenerate on day rollover.
## Returns false when the system date is unusable.
func _ensure_today() -> bool:
	if manager == null:
		return false
	var today := today_string()
	if today == "":
		return false
	var data: Dictionary = manager.missions_data
	var stored_date := str(data.get("date", ""))
	var stored = data.get("missions", [])
	if stored_date == today and stored is Array and not (stored as Array).is_empty():
		return true
	_generate_missions(today)
	return true


func _generate_missions(day: String) -> void:
	var pool: Array = MISSION_POOL.duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(hash(day))
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var chosen: Array = []
	for k in range(mini(3, pool.size())):
		var def: Dictionary = pool[k]
		chosen.append({
			"id": "daily_" + String(def["kind"]),
			"kind": String(def["kind"]),
			"desc": String(def["desc"]),
			"target": int(def["target"]),
			"progress": 0,
			"reward": int(def["reward"]),
			"done": false,
			"claimed": false,
		})
	manager.missions_data = {"date": day, "missions": chosen}
	_save()
	missions_changed.emit()


func _missions() -> Array:
	# v1.3 integration fix: reads must never go stale. After an old save is
	# loaded (no "missions_data" key) the stored set is empty until the next
	# mission event — ensure today exists on every read so the panel and
	# badge counts regenerate immediately instead of showing nothing.
	_ensure_today()
	if manager == null:
		return []
	var m = manager.missions_data.get("missions", [])
	return m if m is Array else []


## Deep copy for tests / UI (mutating the result must not touch state).
func get_missions() -> Array:
	return _missions().duplicate(true)


func _bump_mission(kind: String, amount: int) -> void:
	if amount <= 0 or not _ensure_today():
		return
	var completed := false
	for m in _missions():
		if String(m.get("kind", "")) == kind and not bool(m.get("done", false)):
			var target := maxi(1, int(m.get("target", 1)))
			var p := mini(int(m.get("progress", 0)) + amount, target)
			m["progress"] = p
			if p >= target:
				m["done"] = true
				completed = true
	if completed:
		_save()
		missions_changed.emit()
		_sfx("play_ding")


func _set_mission_done(kind: String) -> void:
	if not _ensure_today():
		return
	var completed := false
	for m in _missions():
		if String(m.get("kind", "")) == kind and not bool(m.get("done", false)):
			m["progress"] = maxi(1, int(m.get("target", 1)))
			m["done"] = true
			completed = true
	if completed:
		_save()
		missions_changed.emit()
		_sfx("play_ding")


## Claim a completed mission's reward. Pays once; a second claim is refused.
func claim_mission(mission_id: String) -> bool:
	if manager == null or not _ensure_today():
		return false
	for m in _missions():
		if String(m.get("id", "")) == mission_id:
			if not bool(m.get("done", false)) or bool(m.get("claimed", false)):
				return false
			m["claimed"] = true
			manager.add_coins(int(m.get("reward", 0)))
			_save()
			missions_changed.emit()
			_refresh_panel()
			_sfx("play_unlock")
			return true
	return false


## Test hook: replace today's mission list with the given pool kinds.
func set_missions_for_test(kinds: Array) -> void:
	if manager == null:
		return
	var today := today_string()
	var chosen: Array = []
	for def in MISSION_POOL:
		if String(def["kind"]) in kinds:
			chosen.append({
				"id": "daily_" + String(def["kind"]),
				"kind": String(def["kind"]),
				"desc": String(def["desc"]),
				"target": int(def["target"]),
				"progress": 0,
				"reward": int(def["reward"]),
				"done": false,
				"claimed": false,
			})
	manager.missions_data = {"date": today, "missions": chosen}
	_save()
	missions_changed.emit()


# --- Progress tracking (signals + coordinator notify methods) ----------------

func _on_merge(tier: int, _bonus: int) -> void:
	_bump_mission("merge_5", 1)
	_bump_mission("merge_10", 1)
	if tier >= 4:
		_set_mission_done("reach_tier_4")
	check_achievements()


func _on_unlocked(tier: int) -> void:
	_set_mission_done("discover_tier")
	if tier >= 4:
		_set_mission_done("reach_tier_4")
	check_achievements()


func _on_coins_changed(value: int) -> void:
	var delta := value - _last_coins
	_last_coins = value
	if delta > 0:
		_bump_mission("earn_500", delta)
	check_achievements()


## COORDINATOR: call once per completed Lucky Wheel spin.
func notify_wheel_spun() -> void:
	_bump_mission("wheel_once", 1)


## COORDINATOR: call once per completed Monster Slots spin.
func notify_slots_played() -> void:
	_bump_mission("slots_3", 1)


## COORDINATOR: call once per hatched Mystery Egg.
func notify_egg_hatched() -> void:
	_set_mission_done("hatch_egg")


## COORDINATOR: call when the Lucky Spin JACKPOT 1000 prize lands.
func notify_jackpot_won() -> void:
	_complete_achievement("jackpot")


## COORDINATOR (boss worker): call when the Boss is defeated.
func notify_boss_defeated() -> void:
	_complete_achievement("boss_defeated")


# --- Daily gift --------------------------------------------------------------

func gift_available_today() -> bool:
	if manager == null:
		return false
	var today := today_string()
	if today == "":
		return false
	return manager.last_gift_date != today


## What claiming right now would pay (streak the claim would reach).
func gift_preview() -> Dictionary:
	if manager == null:
		return {"coins": 100, "free_spin": false, "streak": 1}
	var today := today_string()
	var next_streak := 1
	if manager.last_gift_date == today:
		next_streak = manager.gift_streak + 1
	elif manager.last_gift_date != "" and manager.last_gift_date == yesterday_string():
		next_streak = manager.gift_streak + 1
	var coins := daily_gift_coins(next_streak)
	return {"coins": coins, "free_spin": next_streak >= 7, "streak": next_streak}


## Claim the daily gift. Returns {"ok": bool, "coins": int,
## "free_spin": bool, "streak": int} or {"ok": false, "reason": String}.
func claim_daily_gift() -> Dictionary:
	if manager == null:
		return {"ok": false, "reason": "no_manager"}
	var today := today_string()
	if today == "":
		return {"ok": false, "reason": "bad_date"}
	if manager.last_gift_date == today:
		return {"ok": false, "reason": "already_claimed"}
	var yesterday := yesterday_string()
	if manager.last_gift_date != "" and manager.last_gift_date == yesterday:
		manager.gift_streak += 1
	else:
		manager.gift_streak = 1
	manager.last_gift_date = today
	var reward := daily_gift_coins(manager.gift_streak)
	var free_spin := manager.gift_streak >= 7
	manager.add_coins(reward)
	if free_spin:
		# Day-7 free spin: the wheel treats free_spin_used == false as free.
		manager.free_spin_used = false
	check_achievements()
	_save()
	missions_changed.emit()
	_refresh_panel()
	_sfx("play_unlock")
	return {"ok": true, "coins": reward, "free_spin": free_spin, "streak": manager.gift_streak}


# --- Achievements ------------------------------------------------------------

func _achievement_state(achievement_id: String) -> Dictionary:
	if manager == null:
		return {}
	var st = manager.achievements_state.get(achievement_id, {})
	return st if st is Dictionary else {}


func _achievement_hint(achievement_id: String) -> String:
	if manager == null:
		return ""
	match achievement_id:
		"first_tier5":
			return "Highest tier: %d / 5" % manager.highest_unlocked
		"merges_100":
			return "%d / 100 merges" % manager.lifetime_merges
		"coins_1000":
			return "%d / 1,000 coins earned" % manager.total_coins_earned
		"jackpot":
			return "Win the 1000-coin jackpot"
		"boss_defeated":
			return "Defeat the Boss in Boss Rush"
		"streak_7":
			return "%d / 7 day streak" % manager.gift_streak
	return ""


## Full achievement list with live done/claimed state + progress hint.
func get_achievements() -> Array:
	var out: Array = []
	for def in ACHIEVEMENTS:
		var achievement_id := String(def["id"])
		var st := _achievement_state(achievement_id)
		out.append({
			"id": achievement_id,
			"desc": String(def["desc"]),
			"reward": int(def["reward"]),
			"done": bool(st.get("done", false)),
			"claimed": bool(st.get("claimed", false)),
			"hint": _achievement_hint(achievement_id),
		})
	return out


## Re-check every counter-based achievement. Safe to call on any event.
func check_achievements() -> void:
	if manager == null:
		return
	if manager.highest_unlocked >= 5:
		_complete_achievement("first_tier5")
	if manager.lifetime_merges >= 100:
		_complete_achievement("merges_100")
	if manager.total_coins_earned >= 1000:
		_complete_achievement("coins_1000")
	if manager.gift_streak >= 7:
		_complete_achievement("streak_7")


func _complete_achievement(achievement_id: String) -> void:
	if manager == null:
		return
	var st := _achievement_state(achievement_id)
	if bool(st.get("done", false)):
		return
	st["done"] = true
	st["claimed"] = false
	manager.achievements_state[achievement_id] = st
	_save()
	missions_changed.emit()
	achievement_completed.emit(achievement_id)
	_sfx("play_unlock")


## Claim a completed achievement's reward. Pays once; second claim refused.
func claim_achievement(achievement_id: String) -> bool:
	if manager == null:
		return false
	var st := _achievement_state(achievement_id)
	if st.is_empty() or not bool(st.get("done", false)) or bool(st.get("claimed", false)):
		return false
	var reward := 0
	for def in ACHIEVEMENTS:
		if String(def["id"]) == achievement_id:
			reward = int(def["reward"])
	if reward <= 0:
		return false
	st["claimed"] = true
	manager.achievements_state[achievement_id] = st
	manager.add_coins(reward)
	_save()
	missions_changed.emit()
	_refresh_panel()
	_sfx("play_unlock")
	return true


func unclaimed_mission_count() -> int:
	var n := 0
	for m in _missions():
		if bool(m.get("done", false)) and not bool(m.get("claimed", false)):
			n += 1
	return n


func unclaimed_achievement_count() -> int:
	var n := 0
	if manager == null:
		return 0
	for def in ACHIEVEMENTS:
		var st := _achievement_state(String(def["id"]))
		if bool(st.get("done", false)) and not bool(st.get("claimed", false)):
			n += 1
	return n


func pending_badge_count() -> int:
	return unclaimed_mission_count() + unclaimed_achievement_count()


# --- Gift boxes --------------------------------------------------------------

func gift_box_active() -> bool:
	return _box_button != null and is_instance_valid(_box_button) and _box_button.visible


## Test hook: spawn a gift box immediately, bypassing the 120-240 s timer.
func force_spawn_gift_box() -> bool:
	_box_timer = 0.0
	return _try_spawn_gift_box()


func _tick_gift_box(delta: float) -> void:
	if _box_button != null and is_instance_valid(_box_button):
		_box_age += delta
		_position_box()
		if _box_age >= gift_box_lifetime:
			_remove_gift_box(true)
		return
	if _box_waiting:
		return
	_box_timer += delta
	if _box_timer >= _next_box_in:
		if not _try_spawn_gift_box():
			_box_timer = _next_box_in - 5.0


func _empty_tiles() -> Array[int]:
	var out: Array[int] = []
	if manager == null:
		return out
	for i in range(MonsterGameManager.GRID_SIZE):
		if manager.grid[i] == 0:
			out.append(i)
	return out


func _try_spawn_gift_box() -> bool:
	if manager == null or _grid == null or _box_parent == null:
		return false
	if _box_button != null and is_instance_valid(_box_button):
		return true
	var empty := _empty_tiles()
	if empty.is_empty():
		return false
	_box_tile = empty[randi() % empty.size()]
	var btn := Button.new()
	btn.text = "🎁"
	btn.custom_minimum_size = Vector2(120, 120)
	btn.size = Vector2(120, 120)
	btn.add_theme_font_size_override("font_size", 56)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#ff5d8f")
	style.set_corner_radius_all(28)
	style.set_border_width_all(4)
	style.border_color = Color("#ffe27b")
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.pressed.connect(open_gift_box)
	_box_parent.add_child(btn)
	_box_button = btn
	_box_age = 0.0
	_box_waiting = false
	_position_box()
	btn.pivot_offset = Vector2(60, 60)
	btn.scale = Vector2(0.5, 0.5)
	var tw := btn.create_tween()
	tw.tween_property(btn, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return true


func _position_box() -> void:
	if _box_button == null or not is_instance_valid(_box_button):
		return
	if _grid == null or _box_tile < 0 or _box_tile >= _grid.tiles.size():
		return
	var rect := _grid.tiles[_box_tile].get_global_rect()
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return
	var parent_pos := Vector2.ZERO
	if _box_parent != null:
		parent_pos = _box_parent.get_global_rect().position
	var center := rect.get_center() - parent_pos
	_box_button.position = center - _box_button.size * 0.5
	_last_box_pos = center


## A spawn/merge filled the box's tile: move it, or wait hidden for a free tile.
func _on_state_changed() -> void:
	if manager == null:
		return
	if _box_button != null and is_instance_valid(_box_button):
		if _box_tile >= 0 and _box_tile < MonsterGameManager.GRID_SIZE and manager.grid[_box_tile] != 0:
			var empty := _empty_tiles()
			if empty.is_empty():
				_box_button.visible = false
				_box_waiting = true
			else:
				_box_tile = empty[randi() % empty.size()]
				_position_box()
	elif _box_waiting:
		var empty2 := _empty_tiles()
		if not empty2.is_empty():
			_box_tile = empty2[randi() % empty2.size()]
			_box_waiting = false
			if _box_button != null and is_instance_valid(_box_button):
				_box_button.visible = true
				_position_box()


func _remove_gift_box(expired: bool) -> void:
	if _box_button != null and is_instance_valid(_box_button):
		_box_button.queue_free()
	_box_button = null
	_box_tile = -1
	_box_waiting = false
	if expired:
		_box_timer = 0.0
		_next_box_in = randf_range(GIFT_BOX_MIN_INTERVAL, GIFT_BOX_MAX_INTERVAL)


## Tap the box: roll a reward and celebrate. Returns a reward message,
## or "" when no box is open.
func open_gift_box() -> String:
	if manager == null:
		return ""
	if _box_button == null or not is_instance_valid(_box_button):
		return ""
	var message := ""
	var roll := randi() % 3
	match roll:
		0:
			var c := randi_range(50, 150)
			manager.add_coins(c)
			message = "+%d coins! 🪙" % c
		1:
			if manager.add_monster_tier(1):
				message = "A FREE EGG hatched on your board! 🥚"
			else:
				manager.add_coins(50)
				message = "Board full! Free egg paid 50 coins 🥚"
		_:
			manager.free_spin_used = false
			message = "FREE Lucky Spin! 🎡"
	_remove_gift_box(false)
	_box_timer = 0.0
	_next_box_in = randf_range(GIFT_BOX_MIN_INTERVAL, GIFT_BOX_MAX_INTERVAL)
	_show_box_celebration(message)
	_save()
	_sfx("play_unlock")
	return message


func _show_box_celebration(message: String) -> void:
	var fx_parent: Node = _panel_parent if _panel_parent != null else _box_parent
	if fx_parent != null:
		var fx := ConfettiFXScript.new()
		fx.count = 40
		fx_parent.add_child(fx)
	if _box_parent == null:
		return
	var label := Label.new()
	label.text = "🎁 " + message
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color("#ffe27b"))
	label.add_theme_color_override("font_shadow_color", Color("#854c12"))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(560, 44)
	label.position = _last_box_pos + Vector2(-280, -60)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box_parent.add_child(label)
	var tw := label.create_tween()
	tw.tween_property(label, "position:y", label.position.y - 60.0, 0.9)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.9)
	tw.tween_callback(label.queue_free)


# --- Missions panel ----------------------------------------------------------

func is_panel_open() -> bool:
	return _panel_overlay != null and is_instance_valid(_panel_overlay)


func open_panel() -> void:
	if _panel_parent == null:
		return
	_ensure_today()
	if _panel_overlay != null and is_instance_valid(_panel_overlay):
		_refresh_panel()
		return
	var overlay := ColorRect.new()
	overlay.color = Color(0.04, 0.12, 0.2, 0.84)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel_parent.add_child(overlay)
	_panel_overlay = overlay
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _flat_style(Color("#24677b"), 22, Color("#f8d66b"), 5))
	center.add_child(frame)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	frame.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(580, 980)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	_panel_content = content
	_refresh_panel()


func close_panel() -> void:
	if _panel_overlay != null and is_instance_valid(_panel_overlay):
		_panel_overlay.queue_free()
	_panel_overlay = null
	_panel_content = null


func _refresh_panel() -> void:
	if manager == null:
		return
	if _panel_overlay == null or not is_instance_valid(_panel_overlay):
		return
	if _panel_content == null:
		return
	for c in _panel_content.get_children():
		c.queue_free()
	_panel_content.add_child(_panel_label("📋 DAILY MISSIONS", 28, Color("#ffe27b")))
	_panel_content.add_child(_panel_label("Today: " + today_string(), 16, Color("#d7f5ff")))
	# Daily gift card.
	var gift := PanelContainer.new()
	gift.add_theme_stylebox_override("panel", _flat_style(Color("#fff0a9"), 16, Color("#b8923a"), 2))
	_panel_content.add_child(gift)
	var gv := VBoxContainer.new()
	gv.add_theme_constant_override("separation", 6)
	gift.add_child(gv)
	gv.add_child(_panel_label("🎁 DAILY GIFT  —  🔥 Streak: %d day(s)" % manager.gift_streak, 22, Color("#714319")))
	var preview := gift_preview()
	if gift_available_today():
		var extra := " + FREE SPIN 🎡" if bool(preview["free_spin"]) else ""
		gv.add_child(_panel_label("Claim now: +%d coins%s" % [int(preview["coins"]), extra], 18, Color("#714319")))
		gv.add_child(_claim_button("CLAIM 🎁", true, _on_gift_claim_pressed))
	else:
		gv.add_child(_panel_label("Claimed today ✓ — come back tomorrow!", 18, Color("#714319")))
	# Today's missions.
	_panel_content.add_child(_panel_label("— TODAY'S MISSIONS —", 20, Color.WHITE))
	for m in _missions():
		_panel_content.add_child(_mission_row(m))
	# Achievements.
	_panel_content.add_child(_panel_label("— 🏆 ACHIEVEMENTS —", 20, Color.WHITE))
	for a in get_achievements():
		_panel_content.add_child(_achievement_row(a))
	var close := Button.new()
	close.text = "CLOSE"
	close.custom_minimum_size.y = 54
	_style_button(close, Color("#ff8c32"))
	close.pressed.connect(close_panel)
	_panel_content.add_child(close)


func _mission_row(m: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _flat_style(Color("#2c7d8c"), 14))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	row.add_child(hb)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)
	var desc := Label.new()
	desc.text = String(m.get("desc", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 20)
	desc.add_theme_color_override("font_color", Color.WHITE)
	vb.add_child(desc)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = maxi(1, int(m.get("target", 1)))
	bar.value = int(m.get("progress", 0))
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 16)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(bar)
	var status := Label.new()
	status.text = "%d / %d" % [int(m.get("progress", 0)), int(m.get("target", 1))]
	status.add_theme_font_size_override("font_size", 16)
	status.add_theme_color_override("font_color", Color("#d7f5ff"))
	vb.add_child(status)
	var done := bool(m.get("done", false))
	var claimed := bool(m.get("claimed", false))
	var btn: Button
	if claimed:
		btn = _claim_button("CLAIMED ✓", false, Callable())
	elif done:
		btn = _claim_button("CLAIM +%d 🪙" % int(m.get("reward", 0)), true, _on_claim_mission_pressed.bind(String(m.get("id", ""))))
	else:
		btn = _claim_button("LOCKED", false, Callable())
	hb.add_child(btn)
	return row


func _achievement_row(a: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _flat_style(Color("#2c4a6b"), 14))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	row.add_child(hb)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)
	var desc := Label.new()
	desc.text = String(a.get("desc", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 20)
	desc.add_theme_color_override("font_color", Color.WHITE)
	vb.add_child(desc)
	var hint := Label.new()
	hint.text = "%s  •  +%d 🪙" % [String(a.get("hint", "")), int(a.get("reward", 0))]
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color("#d7f5ff"))
	vb.add_child(hint)
	var done := bool(a.get("done", false))
	var claimed := bool(a.get("claimed", false))
	var btn: Button
	if claimed:
		btn = _claim_button("CLAIMED ✓", false, Callable())
	elif done:
		btn = _claim_button("CLAIM 🪙", true, _on_claim_achievement_pressed.bind(String(a.get("id", ""))))
	else:
		btn = _claim_button("LOCKED", false, Callable())
	hb.add_child(btn)
	return row


func _on_claim_mission_pressed(mission_id: String) -> void:
	claim_mission(mission_id)


func _on_claim_achievement_pressed(achievement_id: String) -> void:
	claim_achievement(achievement_id)


func _on_gift_claim_pressed() -> void:
	claim_daily_gift()


# --- Panel style helpers (same look as the board UI) -------------------------

func _panel_label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _claim_button(text: String, enabled: bool, callable: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.custom_minimum_size = Vector2(150, 56)
	b.add_theme_font_size_override("font_size", 20)
	_style_button(b, Color("#36b95f") if enabled else Color("#5a6b7a"))
	if callable.is_valid():
		b.pressed.connect(callable)
	return b


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


func _save() -> void:
	if manager != null:
		manager.save_game()


func _sfx(method_name: String) -> void:
	var sm := get_node_or_null("/root/SoundManager")
	if sm != null and sm.has_method(method_name):
		sm.call(method_name)
