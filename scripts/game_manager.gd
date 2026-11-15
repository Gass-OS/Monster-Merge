extends Node
class_name MonsterGameManager

signal state_changed
signal coins_changed(value: int)
signal merge_happened(tier: int, bonus: int)
signal monster_unlocked(tier: int)

const GRID_SIZE := 16
const MAX_TIER := 8
const SAVE_PATH := "user://monster_merge_save.json"
const MONSTER_NAMES := [
	"Blue Spotted Egg", "Cute Green Slime", "Baby Green Dino",
	"Winged Flame Wyrm", "Golden Phoenix", "Crystal Unicorn",
	"Robo-Rex", "Cosmic King Dragon"
]

var coins: int = 0
var highest_unlocked: int = 1
var discovered: Array[bool] = [true, false, false, false, false, false, false, false]
var grid: Array[int] = []
var spawn_clock: float = 0.0
var passive_clock: float = 0.0
var save_clock: float = 0.0
# --- Casino / v1.2 additions (new save keys, backwards-compatible) -------
var free_spin_used: bool = false  # Lucky Spin: one free spin per save.
var passive_2x_seconds: float = 0.0  # Remaining 2x passive-income time.
# --- v1.3 Daily Missions / Gifts / Achievements (Worker B) ------------------
# Persisted via save/load below with .get() defaults (old saves load fine).
# NOTE: `total_merges` is Worker C's Boss Rush counter (merges SINCE the
# last boss fight — it resets when a fight ends), so the LIFETIME counter
# this system needs lives here as `lifetime_merges` instead.
var missions_data: Dictionary = {}  # {"date": "YYYY-MM-DD", "missions": [ {...}, x3 ]}
var last_gift_date: String = ""
var gift_streak: int = 0
var lifetime_merges: int = 0
var total_coins_earned: int = 0
var achievements_state: Dictionary = {}  # id -> {"done": bool, "claimed": bool}
# --- Boss Rush / v1.3 additions (new save keys, backwards-compatible) -----
# total_merges counts merges SINCE THE LAST BOSS FIGHT ENDED: it resets to
# 0 when a fight ends (win or escape), so the next boss is ready after 25
# more merges. bosses_defeated / boss_level never reset.
var total_merges: int = 0
var bosses_defeated: int = 0
var boss_level: int = 1  # Level of the NEXT boss to face; +1 after a win.
# --- v1.3 settings (Worker A) ------------------------------------------------
# Settings live in the SAME save file under a "settings" dict (see the
# delimited block in save_game() / _load_game() below). The SettingsManager
# is a plain RefCounted owned here; other systems read it via
# game_manager.settings (theme, voices, vibration) and the settings panel
# writes through it. This is the ONLY v1.3 addition to this file.
const SettingsManagerScript = preload("res://scripts/settings_manager.gd")
var settings: SettingsManager = SettingsManagerScript.new()

func _ready() -> void:
	grid.resize(GRID_SIZE)
	grid.fill(0)
	_load_game()
	# --- v1.3 settings (Worker A): push loaded settings into the managers.
	settings.apply_to_managers()
	state_changed.emit()

func _process(delta: float) -> void:
	spawn_clock += delta
	passive_clock += delta
	save_clock += delta
	if spawn_clock >= 3.0:
		spawn_clock = 0.0
		spawn_monster()
	if passive_clock >= 1.0:
		passive_clock -= 1.0
		var income := 0
		for tier in grid:
			if tier > 1:
				income += tier - 1
		if passive_2x_seconds > 0.0:
			income *= 2
		if income > 0:
			add_coins(income)
	if passive_2x_seconds > 0.0:
		passive_2x_seconds = maxf(0.0, passive_2x_seconds - delta)
	if save_clock >= 5.0:
		save_clock = 0.0
		save_game()

func spawn_monster() -> void:
	var empty: Array[int] = []
	for i in range(GRID_SIZE):
		if grid[i] == 0:
			empty.append(i)
	if empty.is_empty():
		return
	var chosen := empty[randi() % empty.size()]
	grid[chosen] = 1
	state_changed.emit()
	save_game()

func merge_tiles(source_index: int, target_index: int) -> bool:
	if source_index < 0 or target_index < 0 or source_index >= GRID_SIZE or target_index >= GRID_SIZE:
		return false
	if source_index == target_index:
		return false
	var source_tier: int = grid[source_index]
	var target_tier: int = grid[target_index]
	if source_tier <= 0 or source_tier != target_tier or source_tier >= MAX_TIER:
		return false
	grid[target_index] = source_tier + 1
	grid[source_index] = 0
	# --- v1.3 counters (Worker B: lifetime merges; Worker C's
	# total_merges below counts merges since the last boss fight) ---
	lifetime_merges += 1
	add_coins(10)
	# Boss Rush (v1.3): every successful merge counts toward the next boss.
	total_merges += 1
	var new_tier: int = target_tier + 1
	if not discovered[new_tier - 1]:
		discovered[new_tier - 1] = true
		highest_unlocked = maxi(highest_unlocked, new_tier)
		monster_unlocked.emit(new_tier)
	merge_happened.emit(new_tier, 10)
	state_changed.emit()
	save_game()
	return true

func add_coins(amount: int) -> void:
	# --- v1.3 counters (Worker B): only positive gains count as earned. ---
	if amount > 0:
		total_coins_earned += amount
	coins += maxi(0, amount)
	coins_changed.emit(coins)

# Spend coins if affordable. Returns false (and spends nothing) when broke.
func spend_coins(amount: int) -> bool:
	if amount < 0:
		return false
	if coins < amount:
		return false
	coins -= amount
	coins_changed.emit(coins)
	return true

# Place a monster of `tier` on a random EMPTY board slot.
# Returns false when the board is full (caller should pay compensation).
func add_monster_tier(tier: int) -> bool:
	var empty: Array[int] = []
	for i in range(GRID_SIZE):
		if grid[i] == 0:
			empty.append(i)
	if empty.is_empty():
		return false
	var chosen: int = empty[randi() % empty.size()]
	grid[chosen] = clampi(tier, 1, MAX_TIER)
	if not discovered[grid[chosen] - 1]:
		discovered[grid[chosen] - 1] = true
		highest_unlocked = maxi(highest_unlocked, grid[chosen])
		monster_unlocked.emit(grid[chosen])
	state_changed.emit()
	save_game()
	return true

# 2x passive income for `seconds` (stacks by taking the longer duration).
func grant_passive_2x(seconds: float) -> void:
	passive_2x_seconds = maxf(passive_2x_seconds, seconds)
	save_game()

func is_passive_2x_active() -> bool:
	return passive_2x_seconds > 0.0

func mark_free_spin_used() -> void:
	free_spin_used = true
	save_game()

func get_next_tier_text() -> String:
	return "NEXT MERGE: Tier %d!" % mini(highest_unlocked + 1, MAX_TIER)

func save_game() -> void:
	var payload := {
		"version": 1,
		"coins": coins,
		"highest_unlocked": highest_unlocked,
		"discovered": discovered,
		"grid": grid,
		"free_spin_used": free_spin_used,
		"passive_2x_seconds": passive_2x_seconds,
		# --- v1.3 settings (Worker A) ---
		"settings": settings.to_dict(),
		# --- Boss Rush (v1.3, Worker C) ---
		"total_merges": total_merges,
		"bosses_defeated": bosses_defeated,
		"boss_level": boss_level,
		# --- v1.3 Daily Missions / Gifts / Achievements (Worker B) ---
		"missions_data": missions_data,
		"last_gift_date": last_gift_date,
		"gift_streak": gift_streak,
		"lifetime_merges": lifetime_merges,
		"total_coins_earned": total_coins_earned,
		"achievements_state": achievements_state,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(payload))

func _load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	coins = int(parsed.get("coins", 0))
	highest_unlocked = clampi(int(parsed.get("highest_unlocked", 1)), 1, MAX_TIER)
	# New v1.2 keys: .get() defaults keep old saves (which lack them) loading.
	free_spin_used = bool(parsed.get("free_spin_used", false))
	passive_2x_seconds = maxf(0.0, float(parsed.get("passive_2x_seconds", 0.0)))
	# --- v1.3 keys (Worker B): .get() defaults keep old saves loading. ---
	var saved_missions = parsed.get("missions_data", {})
	missions_data = saved_missions if saved_missions is Dictionary else {}
	last_gift_date = str(parsed.get("last_gift_date", ""))
	gift_streak = maxi(0, int(parsed.get("gift_streak", 0)))
	lifetime_merges = maxi(0, int(parsed.get("lifetime_merges", 0)))
	total_coins_earned = maxi(0, int(parsed.get("total_coins_earned", 0)))
	var saved_ach = parsed.get("achievements_state", {})
	achievements_state = saved_ach if saved_ach is Dictionary else {}
	# New v1.3 Boss Rush keys: same .get() defaults — an old save loads
	# with all counters at 0 / boss level 1.
	total_merges = maxi(0, int(parsed.get("total_merges", 0)))
	bosses_defeated = maxi(0, int(parsed.get("bosses_defeated", 0)))
	boss_level = maxi(1, int(parsed.get("boss_level", 1)))
	# --- v1.3 settings (Worker A) ---
	# Old saves have no "settings" key: .get() defaults to {} and the
	# manager keeps its defaults (all ON, volumes 0.8, theme "sunny").
	var saved_settings = parsed.get("settings", {})
	if saved_settings is Dictionary:
		settings.load_from_dict(saved_settings)
	var saved_discovered = parsed.get("discovered", [])
	if saved_discovered is Array and saved_discovered.size() == MAX_TIER:
		for i in range(MAX_TIER):
			discovered[i] = bool(saved_discovered[i])
	discovered[0] = true
	var saved_grid = parsed.get("grid", [])
	if saved_grid is Array and saved_grid.size() == GRID_SIZE:
		for i in range(GRID_SIZE):
			grid[i] = clampi(int(saved_grid[i]), 0, MAX_TIER)

func reset_save() -> void:
	coins = 0
	highest_unlocked = 1
	discovered = [true, false, false, false, false, false, false, false]
	free_spin_used = false
	passive_2x_seconds = 0.0
	# Boss Rush (v1.3): reset the counters too.
	total_merges = 0
	bosses_defeated = 0
	boss_level = 1
	# --- v1.3 Daily Missions / Gifts / Achievements (Worker B) reset ---
	missions_data = {}
	last_gift_date = ""
	gift_streak = 0
	lifetime_merges = 0
	total_coins_earned = 0
	achievements_state = {}
	grid.fill(0)
	save_game()
	state_changed.emit()
	coins_changed.emit(coins)
