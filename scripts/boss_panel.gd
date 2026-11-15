extends Control
class_name BossPanel

## Boss strip shown above the board: portrait, HP bar, live DPS, FIGHT button.

signal fight_pressed

var manager: MonsterGameManager
var portrait: BossPortrait
var name_label: Label
var hp_bar: ProgressBar
var info_label: Label
var fight_button: Button
var _info_clock: float = 0.0

func setup(game_manager: MonsterGameManager) -> void:
	manager = game_manager
	custom_minimum_size = Vector2(0, 132)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var frame := PanelContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_stylebox_override("panel", UIStyle.flat(Color("#0e121c"), 18, Color("#5a2a33"), 3))
	add_child(frame)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	frame.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	portrait = BossPortrait.new()
	portrait.custom_minimum_size = Vector2(112, 112)
	row.add_child(portrait)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 6)
	row.add_child(info)

	name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color("#f1e7c8"))
	info.add_child(name_label)

	hp_bar = ProgressBar.new()
	hp_bar.min_value = 0.0
	hp_bar.max_value = 100.0
	hp_bar.value = 100.0
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size = Vector2(0, 20)
	hp_bar.add_theme_stylebox_override("background", UIStyle.flat(Color("#1a0f14"), 10, Color("#3a1c24"), 2))
	hp_bar.add_theme_stylebox_override("fill", UIStyle.flat(Color("#d8333f"), 10))
	info.add_child(hp_bar)

	info_label = Label.new()
	info_label.add_theme_font_size_override("font_size", 16)
	info_label.add_theme_color_override("font_color", Color("#9fb4d8"))
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(info_label)

	fight_button = Button.new()
	fight_button.text = "FIGHT"
	fight_button.custom_minimum_size = Vector2(128, 0)
	fight_button.add_theme_font_size_override("font_size", 26)
	UIStyle.style_button(fight_button, Color("#a8202e"))
	fight_button.pressed.connect(_on_fight_pressed)
	row.add_child(fight_button)

	manager.boss_changed.connect(_on_boss_changed)
	manager.boss_damaged.connect(_on_boss_damaged)
	_on_boss_changed()

func _on_fight_pressed() -> void:
	fight_pressed.emit()
	manager.start_boss_fight()

func _on_boss_changed() -> void:
	portrait.set_level(manager.boss_level)
	var col := portrait.get_boss_color()
	name_label.text = manager.get_boss_name_for(manager.boss_level)
	name_label.add_theme_color_override("font_color", col.lightened(0.35))
	_refresh_info()

func _on_boss_damaged(amount: int) -> void:
	portrait.hit()
	var label := Label.new()
	label.text = "-%s" % UIStyle.compact(float(amount))
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color("#ffd36b"))
	label.add_theme_color_override("font_outline_color", Color("#3a0a10"))
	label.add_theme_constant_override("outline_size", 8)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = portrait.global_position - global_position + Vector2(randf_range(20.0, 56.0), 18.0)
	add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 54.0, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tween.chain().tween_callback(label.queue_free)

func _process(delta: float) -> void:
	if manager == null:
		return
	var ratio := 0.0
	if manager.boss_max_hp > 0.0:
		ratio = clampf(manager.boss_hp / manager.boss_max_hp, 0.0, 1.0)
	hp_bar.value = ratio * 100.0
	_info_clock += delta
	if _info_clock >= 0.1:
		_info_clock = 0.0
		_refresh_info()

func _refresh_info() -> void:
	if manager == null or info_label == null:
		return
	var dps := UIStyle.compact(manager.get_army_dps())
	if manager.boss_active:
		info_label.text = "%s HP  |  %ds left  |  %s DPS" % [UIStyle.compact(maxf(manager.boss_hp, 0.0)), int(ceil(manager.boss_time_left)), dps]
		fight_button.disabled = true
		fight_button.text = "FIGHTING"
	else:
		info_label.text = "%s HP  |  Army %s DPS  |  Reward %s" % [UIStyle.compact(manager.boss_max_hp), dps, UIStyle.compact(float(manager.boss_reward_for(manager.boss_level)))]
		fight_button.disabled = false
		fight_button.text = "FIGHT"
