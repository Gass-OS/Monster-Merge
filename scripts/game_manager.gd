extends Node
class_name MonsterGameManager

signal state_changed
signal coins_changed(value: int)
signal merge_happened(tier: int, bonus: int)
signal monster_unlocked(tier: int)
signal upgrades_changed
signal boss_changed
signal boss_damaged(amount: int)
signal boss_defeated(level: int, reward: int)
signal boss_failed(level: int)

const GRID_SIZE := 16
const MAX_TIER := 8
const SAVE_PATH := "user://monster_merge_save.json"
const MONSTER_NAMES := [
	"Blue Spotted Egg", "Cute Green Slime", "Baby Green Dino",
	"Winged Flame Wyrm", "Golden Phoenix", "Crystal Unicorn",
	"Robo-Rex", "Cosmic King Dragon"
]
const BOSS_NAMES := [
	"Gloom Imp", "Bone Warden", "Void Stalker", "Ember Tyrant",
	"Night Hydra", "Storm Colossus", "Hollow King", "Abyss Reaper"
]
# Battle power of one monster of each tier.
const POWER := [1, 3, 8, 20, 50, 125, 320, 800]

const UPGRADES := {
	"spawn": {"name": "Faster Hatch", "base": 50, "growth": 1.55, "max": 12},
	"merge": {"name": "Merge Bonus", "base": 80, "growth": 1.6, "max": 25},
	"income": {"name": "Passive Income", "base": 120, "growth": 1.65, "max": 25},
	"lucky": {"name": "Lucky Hatch", "base": 200, "growth": 1.8, "max": 10},
	"power": {"name": "Army Power", "base": 150, "growth": 1.7, "max": 25},
}
const UPGRADE_ORDER := ["spawn", "merge", "income", "lucky", "power"]

var coins: int = 0
var highest_unlocked: int = 1
var discovered: Array[bool] = [true, false, false, false, false, false, false, false]
var grid: Array[int] = []
var upgrades: Dictionary = {"spawn": 0, "merge": 0, "income": 0, "lucky": 0, "power": 0}
var total_merges: int = 0

var boss_level: int = 1
var boss_hp: float = 0.0
var boss_max_hp: float = 0.0
var boss_time_left: float = 0.0
var boss_active: bool = false

var pending_offline_reward: int = 0
var pending_offline_seconds: int = 0

var spawn_clock: float = 0.0
var passive_clock: float = 0.0
var save_clock: float = 0.0
var _damage_accum: float = 0.0
var _damage_clock: float = 0.0

func _ready() -> void:
	grid.resize(GRID_SIZE)
	grid.fill(0)
	_load_game()
	_reset_boss()
	state_changed.emit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()

func _process(delta: float) -> void:
	if not is_board_full():
		spawn_clock += delta
	passive_clock += delta
	save_clock += delta
	if spawn_clock >= get_spawn_interval():
		spawn_clock = 0.0
		spawn_monster()
	if passive_clock >= 1.0:
		passive_clock -= 1.0
		var income := get_income_per_second()
		if income > 0:
			add_coins(income)
	if boss_active:
		_update_boss(delta)
	if save_clock >= 5.0:
		save_clock = 0.0
		save_game()

# ---------------------------------------------------------------- board

func is_board_full() -> bool:
	for tier in grid:
		if tier == 0:
			return false
	return true

func spawn_monster() -> void:
	var empty: Array[int] = []
	for i in range(GRID_SIZE):
		if grid[i] == 0:
			empty.append(i)
	if empty.is_empty():
		return
	var chosen := empty[randi() % empty.size()]
	var tier := 1
	if randf() < get_lucky_chance():
		tier = 2
		_discover(2)
	grid[chosen] = tier
	state_changed.emit()
	save_game()

func _discover(tier: int) -> void:
	if tier < 1 or tier > MAX_TIER:
		return
	if not discovered[tier - 1]:
		discovered[tier - 1] = true
		highest_unlocked = maxi(highest_unlocked, tier)
		monster_unlocked.emit(tier)

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
	var bonus := get_merge_bonus()
	add_coins(bonus)
	total_merges += 1
	var new_tier: int = target_tier + 1
	_discover(new_tier)
	merge_happened.emit(new_tier, bonus)
	state_changed.emit()
	save_game()
	return true

## Dropping on an empty slot moves the monster; on a different monster swaps them.
func move_or_swap(source_index: int, target_index: int) -> bool:
	if source_index < 0 or target_index < 0 or source_index >= GRID_SIZE or target_index >= GRID_SIZE:
		return false
	if source_index == target_index or grid[source_index] <= 0:
		return false
	var temp: int = grid[target_index]
	grid[target_index] = grid[source_index]
	grid[source_index] = temp
	state_changed.emit()
	save_game()
	return true

func add_coins(amount: int) -> void:
	coins += maxi(0, amount)
	coins_changed.emit(coins)

func get_next_tier_text() -> String:
	return "NEXT MERGE: Tier %d!" % mini(highest_unlocked + 1, MAX_TIER)

# ------------------------------------------------------------- upgrades

func get_upgrade_level(id: String) -> int:
	return int(upgrades.get(id, 0))

func _effect_value(id: String, lvl: int) -> float:
	match id:
		"spawn":
			return maxf(0.8, 3.0 - 0.18 * float(lvl))
		"merge":
			return float(10 + 6 * lvl)
		"income":
			return 1.0 + 0.25 * float(lvl)
		"lucky":
			return minf(0.6, 0.06 * float(lvl))
		"power":
			return 1.0 + 0.2 * float(lvl)
	return 0.0

func get_spawn_interval() -> float:
	return _effect_value("spawn", get_upgrade_level("spawn"))

func get_merge_bonus() -> int:
	return int(_effect_value("merge", get_upgrade_level("merge")))

func get_income_multiplier() -> float:
	return _effect_value("income", get_upgrade_level("income"))

func get_lucky_chance() -> float:
	return _effect_value("lucky", get_upgrade_level("lucky"))

func get_power_multiplier() -> float:
	return _effect_value("power", get_upgrade_level("power"))

func get_upgrade_cost(id: String) -> int:
	var info: Dictionary = UPGRADES[id]
	return int(float(info["base"]) * pow(float(info["growth"]), float(get_upgrade_level(id))))

func is_upgrade_maxed(id: String) -> bool:
	var info: Dictionary = UPGRADES[id]
	return get_upgrade_level(id) >= int(info["max"])

func get_upgrade_effect_text(id: String) -> String:
	var info: Dictionary = UPGRADES[id]
	var lvl := get_upgrade_level(id)
	var cur := _effect_value(id, lvl)
	var nxt := _effect_value(id, mini(lvl + 1, int(info["max"])))
	match id:
		"spawn":
			return "Egg every %.1fs  >  %.1fs" % [cur, nxt]
		"merge":
			return "+%d coins per merge  >  +%d" % [int(cur), int(nxt)]
		"income":
			return "Passive income x%.2f  >  x%.2f" % [cur, nxt]
		"lucky":
			return "Tier 2 egg chance %d%%  >  %d%%" % [roundi(cur * 100.0), roundi(nxt * 100.0)]
		"power":
			return "Boss damage x%.1f  >  x%.1f" % [cur, nxt]
	return ""

func buy_upgrade(id: String) -> bool:
	if not UPGRADES.has(id) or is_upgrade_maxed(id):
		return false
	var cost := get_upgrade_cost(id)
	if coins < cost:
		return false
	coins -= cost
	upgrades[id] = get_upgrade_level(id) + 1
	coins_changed.emit(coins)
	upgrades_changed.emit()
	save_game()
	return true

func get_income_per_second() -> int:
	var base := 0
	for tier in grid:
		if tier > 1:
			base += tier - 1
	return roundi(float(base) * get_income_multiplier())

# ---------------------------------------------------------------- boss

func get_boss_name_for(level: int) -> String:
	return "%s  Lv.%d" % [BOSS_NAMES[(level - 1) % BOSS_NAMES.size()], level]

func boss_max_hp_for(level: int) -> float:
	return 150.0 * pow(1.5, float(level - 1))

func boss_time_for(level: int) -> float:
	return minf(45.0, 25.0 + float(level) * 0.8)

func boss_reward_for(level: int) -> int:
	return int(120.0 * pow(1.42, float(level - 1)))

func get_army_power() -> float:
	var total := 0.0
	for tier in grid:
		if tier > 0:
			total += float(POWER[tier - 1])
	return total

func get_army_dps() -> float:
	return get_army_power() * 0.9 * get_power_multiplier()

func _reset_boss() -> void:
	boss_active = false
	boss_max_hp = boss_max_hp_for(boss_level)
	boss_hp = boss_max_hp
	boss_time_left = boss_time_for(boss_level)
	boss_changed.emit()

func start_boss_fight() -> void:
	if boss_active:
		return
	boss_active = true
	boss_max_hp = boss_max_hp_for(boss_level)
	boss_hp = boss_max_hp
	boss_time_left = boss_time_for(boss_level)
	_damage_accum = 0.0
	_damage_clock = 0.0
	boss_changed.emit()

func _update_boss(delta: float) -> void:
	boss_time_left -= delta
	var dmg := get_army_dps() * delta
	boss_hp -= dmg
	_damage_accum += dmg
	_damage_clock += delta
	if _damage_clock >= 0.6:
		_damage_clock = 0.0
		if _damage_accum >= 1.0:
			boss_damaged.emit(int(_damage_accum))
		_damage_accum = 0.0
	if boss_hp <= 0.0:
		var level := boss_level
		var reward := boss_reward_for(level)
		boss_level += 1
		_reset_boss()
		add_coins(reward)
		boss_defeated.emit(level, reward)
		save_game()
	elif boss_time_left <= 0.0:
		var failed_level := boss_level
		_reset_boss()
		boss_failed.emit(failed_level)

# ------------------------------------------------------------- offline

func claim_offline_reward() -> void:
	if pending_offline_reward > 0:
		add_coins(pending_offline_reward)
	pending_offline_reward = 0
	pending_offline_seconds = 0

# ---------------------------------------------------------------- save

func save_game() -> void:
	var payload := {
		"version": 2,
		"coins": coins,
		"highest_unlocked": highest_unlocked,
		"discovered": discovered,
		"grid": grid,
		"upgrades": upgrades,
		"boss_level": boss_level,
		"total_merges": total_merges,
		"last_seen": int(Time.get_unix_time_from_system())
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
	var saved_discovered = parsed.get("discovered", [])
	if saved_discovered is Array and saved_discovered.size() == MAX_TIER:
		for i in range(MAX_TIER):
			discovered[i] = bool(saved_discovered[i])
	discovered[0] = true
	var saved_grid = parsed.get("grid", [])
	if saved_grid is Array and saved_grid.size() == GRID_SIZE:
		for i in range(GRID_SIZE):
			grid[i] = clampi(int(saved_grid[i]), 0, MAX_TIER)
	var saved_upgrades = parsed.get("upgrades", {})
	if saved_upgrades is Dictionary:
		for id in UPGRADE_ORDER:
			var info: Dictionary = UPGRADES[id]
			upgrades[id] = clampi(int(saved_upgrades.get(id, 0)), 0, int(info["max"]))
	boss_level = maxi(1, int(parsed.get("boss_level", 1)))
	total_merges = maxi(0, int(parsed.get("total_merges", 0)))
	var last_seen := int(parsed.get("last_seen", 0))
	if last_seen > 0:
		var elapsed := clampi(int(Time.get_unix_time_from_system()) - last_seen, 0, 7200)
		var income := get_income_per_second()
		if elapsed >= 60 and income > 0:
			pending_offline_seconds = elapsed
			pending_offline_reward = int(float(income) * float(elapsed) * 0.5)

func reset_save() -> void:
	coins = 0
	highest_unlocked = 1
	discovered = [true, false, false, false, false, false, false, false]
	grid.fill(0)
	upgrades = {"spawn": 0, "merge": 0, "income": 0, "lucky": 0, "power": 0}
	boss_level = 1
	total_merges = 0
	_reset_boss()
	save_game()
	state_changed.emit()
	coins_changed.emit(coins)
	upgrades_changed.emit()
