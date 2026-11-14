extends GridContainer
class_name MonsterGridManager

const TileScript = preload("res://scripts/monster_tile.gd")
var game_manager: MonsterGameManager
var tiles: Array[MonsterTile] = []
var last_merged_index: int = -1

func setup(manager: MonsterGameManager) -> void:
	game_manager = manager
	columns = 4
	add_theme_constant_override("h_separation", 9)
	add_theme_constant_override("v_separation", 9)
	for i in range(16):
		var tile: MonsterTile = TileScript.new()
		tile.tile_index = i
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tile.merge_requested.connect(_on_merge_requested)
		add_child(tile)
		tiles.append(tile)
	game_manager.state_changed.connect(refresh)
	refresh()

func refresh() -> void:
	if game_manager == null:
		return
	for i in range(tiles.size()):
		tiles[i].set_monster(game_manager.grid[i])

func _on_merge_requested(source: int, target: int) -> void:
	# Recorded BEFORE merge_tiles so ui_manager can read it from the
	# merge_happened signal, which fires synchronously inside merge_tiles.
	last_merged_index = target
	if game_manager.merge_tiles(source, target):
		var tile := tiles[target]
		tile.scale = Vector2(0.72, 0.72)
		var tween := create_tween()
		tween.tween_property(tile, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
