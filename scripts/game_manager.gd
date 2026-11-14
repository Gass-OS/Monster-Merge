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

func _ready() -> void:
	grid.resize(GRID_SIZE)
	grid.fill(0)
	_load_game()
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
	add_coins(10)
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
		"passive_2x_seconds": passive_2x_seconds
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
	grid.fill(0)
	save_game()
	state_changed.emit()
	coins_changed.emit(coins)
