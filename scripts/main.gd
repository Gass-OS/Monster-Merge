extends Control
## Entry point: builds the game manager, the (initially hidden) board UI,
## the main menu shown on launch, and the reusable quit-confirmation dialog.
## Handles the Android back button (and Escape on desktop): an open popup
## closes first, otherwise the quit dialog appears. Nothing here touches
## saving, merging or the board — those live in GameManager / UIManager
## untouched, and the GameManager keeps running behind the menu (auto-spawn
## every 3 s, passive coins, autosave) exactly as before.

const GameManagerScript = preload("res://scripts/game_manager.gd")
const UIManagerScript = preload("res://scripts/ui_manager.gd")
const MainMenuScript = preload("res://scripts/main_menu.gd")
const ExitDialogScript = preload("res://scripts/exit_dialog.gd")
const LuckySpinScript = preload("res://scripts/lucky_spin.gd")
const MonsterSlotsScript = preload("res://scripts/monster_slots.gd")
const MysteryEggScript = preload("res://scripts/mystery_egg.gd")

var _game_manager: MonsterGameManager
var _ui: MonsterUIManager
var _menu: MainMenu
var _exit_dialog: ExitDialog
var _spin: LuckySpin
var _slots: MonsterSlots
var _egg: MysteryEgg


func _ready() -> void:
	get_viewport().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	_game_manager = GameManagerScript.new()
	_game_manager.name = "GameManager"
	add_child(_game_manager)
	_ui = UIManagerScript.new()
	_ui.name = "UIManager"
	add_child(_ui)
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.setup(_game_manager)
	# Board stays hidden behind the menu until PLAY.
	_ui.visible = false

	# Quit dialog on its own top layer (20): above the menu (5) and the
	# board popups (10), and alive in the menu and in the game.
	_exit_dialog = ExitDialogScript.new()
	_exit_dialog.name = "ExitDialog"
	var dialog_layer := CanvasLayer.new()
	dialog_layer.layer = 20
	add_child(dialog_layer)
	dialog_layer.add_child(_exit_dialog)
	_exit_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_exit_dialog.confirmed.connect(_on_quit_confirmed)
	_exit_dialog.cancelled.connect(_on_quit_cancelled)

	# Casino panels on their own layer (15): above the board popups (10),
	# below the quit dialog (20). Hidden until opened from the menu.
	var casino_layer := CanvasLayer.new()
	casino_layer.layer = 15
	add_child(casino_layer)
	_spin = LuckySpinScript.new()
	casino_layer.add_child(_spin)
	_spin.setup(_game_manager)
	_slots = MonsterSlotsScript.new()
	casino_layer.add_child(_slots)
	_slots.setup(_game_manager)
	_egg = MysteryEggScript.new()
	casino_layer.add_child(_egg)
	_egg.setup(_game_manager)

	_menu = MainMenuScript.new()
	_menu.name = "MainMenu"
	add_child(_menu)
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.setup(_ui)
	_menu.play_requested.connect(_on_play_requested)
	_menu.quit_requested.connect(_on_quit_requested)
	_menu.spin_requested.connect(func() -> void: _spin.open())
	_menu.slots_requested.connect(func() -> void: _slots.open())
	_menu.egg_requested.connect(func() -> void: _egg.open())

	# Start the soundtrack once the game is on screen (MusicManager never
	# auto-starts; playback is a no-op on headless runs).
	var mm := get_node_or_null("/root/MusicManager")
	if mm != null and mm.has_method("play"):
		mm.play()


func _on_play_requested() -> void:
	if _menu != null and is_instance_valid(_menu):
		_menu.queue_free()
		_menu = null
	if _ui != null:
		_ui.visible = true


func _on_quit_requested() -> void:
	_show_exit_dialog()


func _on_quit_confirmed() -> void:
	get_tree().quit()


func _on_quit_cancelled() -> void:
	if _exit_dialog != null:
		_exit_dialog.hide_dialog()


# --- Back button / Escape ----------------------------------------------------
# Android back arrives as NOTIFICATION_WM_GO_BACK_REQUEST. On desktop,
# Escape arrives as ui_cancel; on Android that branch is skipped so one
# physical press is never handled twice.

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_pressed()


func _unhandled_input(event: InputEvent) -> void:
	if OS.has_feature("android"):
		return
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()


func _on_back_pressed() -> void:
	# 0. An open casino panel closes first.
	if _spin != null and _spin.visible:
		_spin.close()
		return
	if _slots != null and _slots.visible:
		_slots.close()
		return
	if _egg != null and _egg.visible:
		_egg.close()
		return
	# 1. A quit dialog already open: dismiss it, don't quit.
	if _exit_dialog != null and _exit_dialog.is_open():
		_exit_dialog.hide_dialog()
		return
	# 2. Close the topmost board popup (gallery / new-monster) first.
	if _close_top_ui_popup():
		return
	# 3. Close a menu popup (HOW TO PLAY) next.
	if _menu != null and is_instance_valid(_menu) and _menu.close_top_popup():
		return
	# 4. Nothing to close: ask before quitting.
	_show_exit_dialog()


## Finds the topmost board popup in the UIManager's popup_layer and closes
## it. Popups are the dim ColorRect overlays (alpha 0.9); the merge flash is
## a short-lived ColorRect at alpha 0.35 and is not a popup. Returns true
## if a popup was closed.
func _close_top_ui_popup() -> bool:
	if _ui == null or _ui.popup_layer == null:
		return false
	var children := _ui.popup_layer.get_children()
	for i in range(children.size() - 1, -1, -1):
		var child := children[i]
		if child is ColorRect and child.color.a > 0.5:
			child.queue_free()
			return true
	return false


func _show_exit_dialog() -> void:
	if _exit_dialog == null:
		return
	_sfx("play_click")
	_exit_dialog.show_dialog()


# --- Sound (SoundManager autoload, guarded) ----------------------------------

func _sfx(method_name: String) -> void:
	var sm := get_node_or_null("/root/SoundManager")
	if sm != null and sm.has_method(method_name):
		sm.call(method_name)
