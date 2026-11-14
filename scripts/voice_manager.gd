extends Node
## (No class_name: the autoload provides the global name "VoiceManager".)

## TTS winner lines (v1.3, Worker D). No TTS anywhere else in the game.
##
## WIRING (coordinator): add as autoload "VoiceManager", or instantiate and
## add to the scene tree. Either way the methods below are the API:
##   play_jackpot_line() / play_tier8_line() / play_boss_line()
##   set_voices_enabled(bool) / is_voices_enabled()
##   tts_available() -> bool   (false headless / when the feature is absent)
##
## RULES (all enforced here, not by callers):
##   - Guarded by DisplayServer.has_feature(FEATURE_TEXT_TO_SPEECH).
##   - Never on headless (editor import / headless test runs): guarded by
##     DisplayServer.get_name() == "headless" and OS.has_feature("headless").
##   - Never while muted: checks SoundManager.muted when the autoload exists.
##   - Never while voices are off: `voices_enabled` (the settings worker
##     persists it and calls set_voices_enabled(); default true).
##   - Throttled: at least 3 s between lines, never overlapping — speaking
##     state is tracked simply by time since the last line was started.
##   - Lines are picked randomly per event from the lists below.

const MIN_GAP_SECONDS := 3.0

const JACKPOT_LINES := ["Amazing!", "Jackpot!", "You win!"]
const TIER8_LINES := ["Monster Master!", "Cosmic King Dragon!"]
const BOSS_LINES := ["Boss defeated!", "You are the champion!"]

var voices_enabled: bool = true

var _last_spoke_msec := -100000
var _headless := false

func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless" or OS.has_feature("headless")

func set_voices_enabled(value: bool) -> void:
	voices_enabled = value

func is_voices_enabled() -> bool:
	return voices_enabled

## True only when a real TTS line could actually be spoken right now.
func tts_available() -> bool:
	if _headless or not voices_enabled:
		return false
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return false
	return not _is_muted()

func play_jackpot_line() -> void:
	_speak(JACKPOT_LINES[randi() % JACKPOT_LINES.size()])

func play_tier8_line() -> void:
	_speak(TIER8_LINES[randi() % TIER8_LINES.size()])

func play_boss_line() -> void:
	_speak(BOSS_LINES[randi() % BOSS_LINES.size()])

func _is_muted() -> bool:
	var sm := get_node_or_null("/root/SoundManager")
	if sm != null and "muted" in sm:
		return bool(sm.muted)
	return false

func _speak(line: String) -> void:
	if not voices_enabled:
		return
	if _headless:
		return
	if _is_muted():
		return
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return
	var now := Time.get_ticks_msec()
	if float(now - _last_spoke_msec) / 1000.0 < MIN_GAP_SECONDS:
		return
	_last_spoke_msec = now
	# Godot 4.4: tts_speak(text, voice, ...) — voice is required, "" = default.
	DisplayServer.tts_speak(line, "")
