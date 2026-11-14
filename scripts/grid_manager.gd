extends GridContainer
class_name MonsterGridManager

const TileScript = preload("res://scripts/monster_tile.gd")
var game_manager: MonsterGameManager
var tiles: Array[MonsterTile] = []
var last_merged_index: int = -1
# Tap-to-merge selection: index of the currently selected tile, or -1.
var selected_index: int = -1
var _drop_index: int = -1
var _merge_in_progress: bool = false

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
		tile.tile_tapped.connect(_on_tile_tapped)
		tile.drag_hovered.connect(_on_drag_hovered)
		tile.drag_ended.connect(_on_drag_ended)
		add_child(tile)
		tiles.append(tile)
	game_manager.state_changed.connect(refresh)
	refresh()

func refresh() -> void:
	if game_manager == null:
		return
	for i in range(tiles.size()):
		tiles[i].set_monster(game_manager.grid[i])
	# A state change can invalidate the selection (a merge emptied the
	# source tile, a spawn added a new matching tier, ...): re-validate it.
	if selected_index >= 0:
		if selected_index >= tiles.size() or tiles[selected_index].tier <= 0:
			clear_selection()
		else:
			_apply_match_highlights()

func _on_merge_requested(source: int, target: int) -> void:
	# Ignore duplicate touch-up / drag events while one merge is being applied.
	if _merge_in_progress or game_manager == null:
		return
	if source < 0 or target < 0 or source >= tiles.size() or target >= tiles.size():
		return
	if source == target or tiles[source].tier <= 0 or tiles[source].tier != tiles[target].tier:
		return
	_merge_in_progress = true
	last_merged_index = target
	var merged := game_manager.merge_tiles(source, target)
	if merged and target < tiles.size() and is_instance_valid(tiles[target]):
		var tile := tiles[target]
		tile.pivot_offset = tile.size * 0.5
		tile.scale = Vector2(0.82, 0.82)
		var tween := create_tween()
		tween.tween_property(tile, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_merge_in_progress = false

# --- Tap-to-merge ------------------------------------------------------------
# Tap a monster to select it (glow ring + all same-tier tiles pulse).
# Tap a second monster of the same tier to merge: this goes through the
# same _on_merge_requested path as drag-merge, so merge juice, sounds,
# coins and the unlock popup all fire identically.
# Tap the selected tile again, an empty tile, or a different-tier monster
# to deselect (different tier: no merge, selection clears).

func select_tile(index: int) -> void:
	if index < 0 or index >= tiles.size():
		return
	if tiles[index].tier <= 0:
		return
	selected_index = index
	tiles[index].set_selected(true)
	_apply_match_highlights()

func clear_selection() -> void:
	if selected_index >= 0 and selected_index < tiles.size():
		tiles[selected_index].set_selected(false)
	selected_index = -1
	_clear_match_highlights()

func _on_tile_tapped(index: int) -> void:
	if index < 0 or index >= tiles.size():
		return
	if selected_index == index:
		clear_selection()
		return
	if selected_index >= 0:
		var tapped := tiles[index]
		var selected := tiles[selected_index]
		if tapped.tier > 0 and tapped.tier == selected.tier:
			var source := selected_index
			clear_selection()
			_on_merge_requested(source, index)
		else:
			# Different tier (or empty tile): no merge, selection clears.
			clear_selection()
		return
	if tiles[index].tier > 0:
		select_tile(index)

func _apply_match_highlights() -> void:
	if selected_index < 0 or selected_index >= tiles.size():
		return
	var tier := tiles[selected_index].tier
	for i in range(tiles.size()):
		tiles[i].set_match_highlight(i != selected_index and tier > 0 and tiles[i].tier == tier)

func _clear_match_highlights() -> void:
	for tile in tiles:
		tile.set_match_highlight(false)

# --- Drag drop-target highlight ----------------------------------------------

func _on_drag_hovered(source_index: int, global_position: Vector2) -> void:
	var idx := _tile_index_at(global_position)
	if idx == source_index:
		idx = -1
	if idx == _drop_index:
		return
	clear_drop_highlight()
	_drop_index = idx
	if idx >= 0:
		var valid := source_index >= 0 and tiles[source_index].tier > 0 and tiles[idx].tier == tiles[source_index].tier
		tiles[idx].set_drop_highlight(true, valid)

func _on_drag_ended() -> void:
	clear_drop_highlight()

func clear_drop_highlight() -> void:
	if _drop_index >= 0 and _drop_index < tiles.size():
		tiles[_drop_index].set_drop_highlight(false)
	_drop_index = -1

func _tile_index_at(global_position: Vector2) -> int:
	for tile in tiles:
		if tile.get_global_rect().has_point(global_position):
			return tile.tile_index
	return -1
