extends CanvasLayer
class_name WinEffects

## Winner effects (v1.3, Worker D) — self-contained helpers the coordinator
## calls for jackpot / Tier 7+ unlock / boss wins.
##
## WIRING (coordinator): add a WinEffects node to the game scene (it is a
## CanvasLayer, so it draws above the board) and call:
##   show_win_banner("JACKPOT!")     # big gold WIN banner, scales in with a
##                                   # back-ease, stays ~1.5 s, fades out
##   coin_fountain(center)           # 10-14 gold coins burst from the board
##                                   # with gravity arcs + fade
##   screen_flash()                  # brief white/gold fullscreen flash
##   set_shake_target(board_panel)   # once, for big_shake()
##   big_shake()                     # stronger board shake than the normal
##                                   # merge shake (route jackpot/boss board
##                                   # shakes through here)
## Every method is guarded: calling it twice in a row, before the node is
## in the tree, or without a shake target set never errors.

var shake_target: Control

var _banner: Label
var _banner_tween: Tween
var _flash: ColorRect
var _flash_tween: Tween
var _shake_tween: Tween

func set_shake_target(target: Control) -> void:
	shake_target = target

func show_win_banner(text: String) -> void:
	if not is_inside_tree():
		return
	if _banner != null and is_instance_valid(_banner):
		if _banner_tween != null and _banner_tween.is_valid():
			_banner_tween.kill()
		_banner.queue_free()
	_banner = Label.new()
	_banner.text = text
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 64)
	_banner.add_theme_color_override("font_color", Color("#ffdf58"))
	_banner.add_theme_color_override("font_shadow_color", Color("#854c12"))
	_banner.add_theme_constant_override("shadow_offset_x", 3)
	_banner.add_theme_constant_override("shadow_offset_y", 4)
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.position = Vector2(-300, 300)
	_banner.size = Vector2(600, 90)
	_banner.pivot_offset = Vector2(300, 45)
	_banner.scale = Vector2(0.3, 0.3)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(1.5)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.4)
	_banner_tween.tween_callback(_banner.queue_free)

func coin_fountain(center: Vector2) -> void:
	if not is_inside_tree():
		return
	var count := 12
	for i in range(count):
		var coin := Label.new()
		coin.text = "🪙"
		coin.add_theme_font_size_override("font_size", 32)
		coin.position = center + Vector2(randf_range(-20.0, 20.0), randf_range(-10.0, 10.0))
		coin.size = Vector2(40, 40)
		coin.pivot_offset = Vector2(20, 20)
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(coin)
		var vx := randf_range(-260.0, 260.0)
		var vy := randf_range(-520.0, -260.0)
		var start := coin.position
		var tw := create_tween()
		tw.tween_method(func(t: float) -> void:
			if is_instance_valid(coin):
				var p := start + Vector2(vx * t, vy * t + 900.0 * t * t * 0.5)
				coin.position = p
				coin.rotation = lerpf(0.0, TAU, t) * 0.6
				if t > 0.7:
					coin.modulate.a = 1.0 - (t - 0.7) / 0.3
		, 0.0, 1.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_callback(coin.queue_free)

func screen_flash() -> void:
	if not is_inside_tree():
		return
	if _flash != null and is_instance_valid(_flash):
		if _flash_tween != null and _flash_tween.is_valid():
			_flash_tween.kill()
		_flash.queue_free()
	_flash = ColorRect.new()
	_flash.color = Color(1.0, 0.95, 0.7, 0.45)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "color:a", 0.0, 0.45)
	_flash_tween.tween_callback(_flash.queue_free)

func big_shake() -> void:
	if not is_inside_tree() or shake_target == null or not is_instance_valid(shake_target):
		return
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
		shake_target.rotation = 0.0
		shake_target.position = Vector2.ZERO
	shake_target.pivot_offset = shake_target.size * 0.5
	var base_pos := shake_target.position
	_shake_tween = create_tween()
	_shake_tween.tween_property(shake_target, "rotation", 0.03, 0.06)
	_shake_tween.parallel().tween_property(shake_target, "position", base_pos + Vector2(10, -6), 0.06)
	_shake_tween.tween_property(shake_target, "rotation", -0.025, 0.08)
	_shake_tween.parallel().tween_property(shake_target, "position", base_pos + Vector2(-9, 5), 0.08)
	_shake_tween.tween_property(shake_target, "rotation", 0.012, 0.08)
	_shake_tween.parallel().tween_property(shake_target, "position", base_pos + Vector2(5, -3), 0.08)
	_shake_tween.tween_property(shake_target, "rotation", 0.0, 0.1)
	_shake_tween.parallel().tween_property(shake_target, "position", base_pos, 0.1)
