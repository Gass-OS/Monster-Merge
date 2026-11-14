extends Control

const GameManagerScript = preload("res://scripts/game_manager.gd")
const UIManagerScript = preload("res://scripts/ui_manager.gd")

func _ready() -> void:
	get_viewport().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var game_manager = GameManagerScript.new()
	game_manager.name = "GameManager"
	add_child(game_manager)
	var ui = UIManagerScript.new()
	ui.name = "UIManager"
	add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.setup(game_manager)
