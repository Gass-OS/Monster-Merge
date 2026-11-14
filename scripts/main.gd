extends Control
## Entry point: builds the game manager, the (initially hidden) board UI,
## the main menu shown on launch, the pause menu, the settings panel and
## the reusable quit-confirmation dialog.
## Handles the Android back button (and Escape on desktop): an open popup
## closes first, otherwise the PAUSE menu appears (v1.3 — the quit dialog
## only appears from the pause menu's QUIT GAME, or from the main menu's
## QUIT button). Nothing here touches saving, merging or the board — those
## live in GameManager / UIManager untouched, and the GameManager keeps
## running behind the menu (auto-spawn every 3 s, passive coins, autosave)
## exactly as before. While the pause menu is open the tree is paused, so
## auto-spawn / passive income freeze and resume cleanly.

const GameManagerScript = preload("res://scripts/game_manager.gd")
const UIManagerScript = preload("res://scripts/ui_manager.gd")
const MainMenuScript = preload("res://scripts/main_menu.gd")
const ExitDialogScript = preload("res://scripts/exit_dialog.gd")
const LuckySpinScript = preload("res://scripts/lucky_spin.gd")
const MonsterSlotsScript = preload("res://scripts/monster_slots.gd")
const MysteryEggScript = preload("res://scripts/mystery_egg.gd")
const PauseMenuScript = preload("res://scripts/pause_menu.gd")
const SettingsPanelScript = preload("res://scripts/settings_panel.gd")
const BossEventScript = preload("res://scripts/boss_event.gd")
const ComboManagerScript = preload("res://scripts/combo_manager.gd")
const WinEffectsScript = preload("res://scripts/win_effects.gd")

var _game_manager: MonsterGameManager
var _ui: MonsterUIManager
var _menu: MainMenu
var _exit_dialog: ExitDialog
var _spin: LuckySpin
var _slots: MonsterSlots
var _egg: MysteryEgg
var _pause_menu: PauseMenu
var _settings_panel: SettingsPanel
var _boss: BossEvent
var _combo: ComboManager
var _win_fx: WinEffects
var _how_to_overlay: ColorRect = null  # In-game HOW TO PLAY (from pause).


func _ready() -> void:
	# BUG 2 (v1.3.1): stop the engine quitting the app on Android Back.
	# SceneTree.quit_on_go_back defaults to true, so the engine exits on
	# every back press no matter what _on_back_pressed() does. Must be
	# the first thing here, before any other setup.
	get_tree().quit_on_go_back = false
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

	# Quit dialog on its own top layer (30): above the pause menu (20),
	# the settings panel (25) and everything else, and alive in the menu
	# and in the game. PROCESS_MODE_ALWAYS so it still works when opened
	# from the pause menu while the tree is paused.
	_exit_dialog = ExitDialogScript.new()
	_exit_dialog.name = "ExitDialog"
	_exit_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	var dialog_layer := CanvasLayer.new()
	dialog_layer.layer = 30
	add_child(dialog_layer)
	dialog_layer.add_child(_exit_dialog)
	_exit_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_exit_dialog.confirmed.connect(_on_quit_confirmed)
	_exit_dialog.cancelled.connect(_on_quit_cancelled)

	# Casino panels on their own layer (15): above the board popups (10),
	# below the pause menu (20). Hidden until opened from the menu.
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

	# Pause menu (own CanvasLayer 20, built by the script) — hidden until
	# the back button (or Escape) opens it in-game.
	_pause_menu = PauseMenuScript.new()
	_pause_menu.name = "PauseMenu"
	add_child(_pause_menu)
	_pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_menu.resume_requested.connect(_on_pause_resume)
	_pause_menu.settings_requested.connect(_on_pause_settings)
	_pause_menu.howto_requested.connect(_on_pause_howto)
	_pause_menu.quit_to_menu_requested.connect(_on_pause_quit_to_menu)
	_pause_menu.quit_game_requested.connect(_on_pause_quit_game)

	# Settings panel (own CanvasLayer 25, built by the script) — one
	# instance shared by the main menu and the pause menu.
	_settings_panel = SettingsPanelScript.new()
	_settings_panel.name = "SettingsPanel"
	add_child(_settings_panel)
	_settings_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_panel.setup(_game_manager.settings)
	_settings_panel.reset_confirmed.connect(_on_settings_reset_confirmed)

	# v1.3 integration: Boss Rush, combo meter and win effects.
	_boss = BossEventScript.new()
	_boss.name = "BossEvent"
	add_child(_boss)
	_boss.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_boss.setup(_game_manager, _ui.grid)
	_boss.boss_defeated.connect(_on_boss_defeated)
	_combo = ComboManagerScript.new()
	_combo.name = "ComboManager"
	_ui.add_child(_combo)
	_combo.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_combo.position = Vector2(-110, 86)
	_combo.size = Vector2(220, 64)
	_combo.setup(_game_manager)
	_win_fx = WinEffectsScript.new()
	_win_fx.name = "WinEffects"
	_win_fx.layer = 18
	add_child(_win_fx)
	_win_fx.set_shake_target(_ui.board_panel)

	# v1.3 integration: missions wiring for the casino + boss (Worker B).
	var missions_mgr = _ui.missions_manager
	_spin.missions_manager = missions_mgr
	_slots.missions_manager = missions_mgr
	_egg.missions_manager = missions_mgr
	_boss.missions_manager = missions_mgr
	_spin.prize_won.connect(_on_spin_prize)
	_slots.win_paid.connect(_on_slots_win)

	# v1.3 integration: merge blips + vibration, unlock celebrations.
	_game_manager.merge_happened.connect(_on_merge_effects)
	_game_manager.monster_unlocked.connect(_on_monster_unlocked)

	# v1.3 integration: theme changes repaint both skies (menu + board).
	_game_manager.settings.theme_changed.connect(_apply_theme)

	_show_menu()
	_apply_theme(_game_manager.settings.get_theme())

	# Start the soundtrack once the game is on screen (MusicManager never
	# auto-starts; playback is a no-op on headless runs).
	var mm := get_node_or_null("/root/MusicManager")
	if mm != null and mm.has_method("play"):
		mm.play()


## (Re)creates the main menu and wires its signals. Used at launch and
## after QUIT TO MENU (the menu is freed on PLAY).
func _show_menu() -> void:
	if _menu != null and is_instance_valid(_menu):
		return
	_menu = MainMenuScript.new()
	_menu.name = "MainMenu"
	add_child(_menu)
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.setup(_ui, _game_manager.settings)
	_menu.play_requested.connect(_on_play_requested)
	_menu.quit_requested.connect(_on_quit_requested)
	_menu.settings_requested.connect(func() -> void: _settings_panel.open())
	_menu.spin_requested.connect(func() -> void: _spin.open())
	_menu.slots_requested.connect(func() -> void: _slots.open())
	_menu.egg_requested.connect(func() -> void: _egg.open())
	_menu.missions_requested.connect(_on_menu_missions)
	_menu.gift_requested.connect(_on_menu_gift)


func _on_play_requested() -> void:
	if _menu != null and is_instance_valid(_menu):
		_menu.queue_free()
		_menu = null
	if _ui != null:
		_ui.visible = true


## v1.3 integration: missions / daily gift from the main menu. The panel
## lives in the UI manager's popup_layer, which renders above the menu
## like the gallery — but the board must be shown first for its buttons
## to receive input, so we start the game and open the panel next frame.
func _on_menu_missions() -> void:
	_on_play_requested()
	await get_tree().process_frame
	if _ui != null:
		_ui.open_missions_panel()


func _on_menu_gift() -> void:
	_on_menu_missions()


func _on_quit_requested() -> void:
	_show_exit_dialog()


func _on_quit_confirmed() -> void:
	get_tree().quit()


func _on_quit_cancelled() -> void:
	if _exit_dialog != null:
		_exit_dialog.hide_dialog()


# --- Pause menu ---------------------------------------------------------------

func _on_pause_resume() -> void:
	_resume_game()


func _on_pause_settings() -> void:
	# Pause stays open underneath (panel is layer 25, above pause at 20);
	# back closes the panel first and lands back on the pause menu.
	_settings_panel.open()


func _on_pause_howto() -> void:
	_show_how_to()


func _on_pause_quit_to_menu() -> void:
	_resume_game()
	if _boss != null:
		_boss.set_fight_paused(false)
	if _ui != null:
		_ui.visible = false
	_show_menu()


func _on_pause_quit_game() -> void:
	# Tree stays paused behind the dialog; NO just hides it and the user
	# is back at the (still paused) pause menu. YES quits.
	_show_exit_dialog()


func _on_settings_reset_confirmed() -> void:
	# Double-confirmed inside the settings panel; reset the save and
	# close the panel. Settings themselves are NOT reset.
	if _game_manager != null:
		_game_manager.reset_save()
	if _settings_panel != null:
		_settings_panel.close_panel()


func _show_pause() -> void:
	if _pause_menu == null:
		return
	_sfx("play_click")
	_pause_menu.show_menu()
	get_tree().paused = true
	# v1.3 integration: freeze the boss timer while paused.
	if _boss != null:
		_boss.set_fight_paused(true)


func _resume_game() -> void:
	if _pause_menu != null:
		_pause_menu.hide_menu()
	get_tree().paused = false
	if _boss != null:
		_boss.set_fight_paused(false)


## In-game HOW TO PLAY overlay (from the pause menu — the menu's own
## overlay belongs to the freed MainMenu). PROCESS_MODE_ALWAYS so its
## CLOSE button works while the tree is paused. Same text as the menu's.
func _show_how_to() -> void:
	if _how_to_overlay != null and is_instance_valid(_how_to_overlay):
		return
	var overlay := ColorRect.new()
	overlay.color = Color(0.01, 0.01, 0.03, 0.9)
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	_how_to_overlay = overlay
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _flat_style(Color("#24677b"), 22, Color("#f8d66b"), 5))
	center.add_child(frame)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	frame.add_child(margin)
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(520, 0)
	card.add_theme_constant_override("separation", 14)
	margin.add_child(card)
	card.add_child(_label("HOW TO PLAY", 30, Color("#ffe27b")))
	card.add_child(_label("🥚  Tap SPAWN EGG — or just wait, a new egg hatches every few seconds.", 19, Color.WHITE))
	card.add_child(_label("👆  Drag one monster onto a matching one — or tap two matching monsters — to evolve it into the next tier!", 19, Color.WHITE))
	card.add_child(_label("🪙  Higher tiers earn more coins every second. Evolve all the way to the Cosmic King Dragon!", 19, Color.WHITE))
	card.add_child(_label("🏆  Open the GALLERY to see every monster you have discovered.", 19, Color("#9fb4d8")))
	var close := Button.new()
	close.text = "GOT IT!"
	close.custom_minimum_size.y = 60
	close.add_theme_font_size_override("font_size", 26)
	_style_button(close, Color("#2a6b4a"))
	close.pressed.connect(_close_how_to)
	card.add_child(close)


func _close_how_to() -> void:
	_sfx("play_click")
	if _how_to_overlay != null and is_instance_valid(_how_to_overlay):
		_how_to_overlay.queue_free()
		_how_to_overlay = null


# --- Back button / Escape ----------------------------------------------------
# Android back arrives as NOTIFICATION_WM_GO_BACK_REQUEST. On desktop,
# Escape arrives as ui_cancel; on Android that branch is skipped so one
# physical press is never handled twice. While paused, Main's
# _unhandled_input does not run (Main is paused with the tree) — the
# pause menu itself handles Escape, and the back notification still
# reaches _notification, so both paths land here.

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_pressed()


func _unhandled_input(event: InputEvent) -> void:
	if OS.has_feature("android"):
		return
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()


## Back priority (v1.3): (0) casino panel, (1) quit dialog dismiss,
## (2) topmost board popup, (3) menu popup (settings / how-to / about),
## (4) pause open -> RESUME, (5) nothing open -> PAUSE in-game, or the
## quit dialog when the main menu is showing (no game to pause there).
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
	# 3. Close a menu popup: settings panel, in-game how-to, then the
	# menu's own popups (HOW TO PLAY / ABOUT).
	if _settings_panel != null and _settings_panel.is_open():
		_settings_panel.close_panel()
		return
	if _how_to_overlay != null and is_instance_valid(_how_to_overlay):
		_close_how_to()
		return
	if _menu != null and is_instance_valid(_menu) and _menu.close_top_popup():
		return
	# 4. Pause open: back resumes the game.
	if _pause_menu != null and _pause_menu.is_open():
		_resume_game()
		return
	# 5. Nothing open: pause in-game; quit dialog from the main menu.
	if _menu != null and is_instance_valid(_menu):
		_show_exit_dialog()
	else:
		_show_pause()


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


# --- Local style helpers (same look as the menu / board UI) ------------------

func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


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


# --- v1.3 integration: themes, voices, combos, win effects ------------------

func _apply_theme(theme_id: String) -> void:
	if _ui != null:
		_ui.apply_theme(theme_id)
	if _menu != null and is_instance_valid(_menu):
		_menu.apply_theme(theme_id)


func _show_rainbow() -> void:
	if _ui != null:
		_ui.show_rainbow()
	if _menu != null and is_instance_valid(_menu):
		_menu.show_rainbow()


## Merge voice blip (pitch rises with tier) + a tiny vibration when enabled.
func _on_merge_effects(tier: int, _bonus: int) -> void:
	# Keep device vibration out of the critical merge signal chain. Some
	# Android builds/drivers can fail inside the native vibration call.
	# Sound remains optional and is isolated from the model transaction.
	var sm := get_node_or_null("/root/SoundManager")
	if sm != null and sm.has_method("play_blip"):
		call_deferred("_play_merge_blip", tier)


func _play_merge_blip(tier: int) -> void:
	var sm := get_node_or_null("/root/SoundManager")
	if sm != null and sm.has_method("play_blip"):
		sm.call("play_blip", tier)


## New-tier celebrations: Tier 8 gets the full treatment, Tier 7+ a rainbow.
func _on_monster_unlocked(tier: int) -> void:
	if tier >= 7:
		_show_rainbow()
	if tier == 8:
		_fanfare()
		if _win_fx != null:
			_win_fx.show_win_banner("👑 COSMIC KING DRAGON!")
			_win_fx.coin_fountain(Vector2(360, 500))
			_win_fx.screen_flash()
		_voice("play_tier8_line")


## Lucky Spin prizes: jackpot (1000) and big wins (500+) get the treatment.
func _on_spin_prize(kind: String, value: int) -> void:
	if kind == "coins" and value >= 1000:
		_jackpot_effects(Vector2(360, 500), "🎉 JACKPOT! +1000 🪙")
		_voice("play_jackpot_line")
	elif kind == "coins" and value >= 500:
		_fanfare()
		if _win_fx != null:
			_win_fx.show_win_banner("BIG WIN! +%d 🪙" % value)
			_win_fx.coin_fountain(Vector2(360, 500))


## Slots wins: 3-match (300+) gets banner + fountain + fanfare.
func _on_slots_win(win: int) -> void:
	if win >= 300:
		_fanfare()
		if _win_fx != null:
			_win_fx.show_win_banner("🎰 SLOT WIN! +%d 🪙" % win)
			_win_fx.coin_fountain(Vector2(360, 500))
		if win >= 500:
			_voice("play_jackpot_line")


## Boss defeated: the boss panel already shows its own WIN banner, so this
## adds the fountain / flash / shake / rainbow / voice on top.
func _on_boss_defeated(_level: int, _reward: int) -> void:
	_jackpot_effects(Vector2(360, 320), "")
	_voice("play_boss_line")


## Shared jackpot treatment (banner optional — pass "" to skip it).
func _jackpot_effects(center: Vector2, banner_text: String) -> void:
	_fanfare()
	if _win_fx != null:
		if banner_text != "":
			_win_fx.show_win_banner(banner_text)
		_win_fx.coin_fountain(center)
		_win_fx.screen_flash()
		_win_fx.big_shake()
	_show_rainbow()
	if _game_manager != null and _game_manager.settings != null:
		_game_manager.settings.vibrate()


func _fanfare() -> void:
	_sfx("play_fanfare")


func _voice(method_name: String) -> void:
	var vm := get_node_or_null("/root/VoiceManager")
	if vm != null and vm.has_method(method_name):
		vm.call(method_name)


# --- Sound (SoundManager autoload, guarded) ----------------------------------

func _sfx(method_name: String) -> void:
	var sm := get_node_or_null("/root/SoundManager")
	if sm != null and sm.has_method(method_name):
		sm.call(method_name)
