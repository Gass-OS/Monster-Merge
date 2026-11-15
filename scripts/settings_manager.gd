class_name SettingsManager
extends RefCounted
## Settings for Monster Merge (v1.3, Worker A).
##
## Plain RefCounted — no node, no _process, no scene-tree dependency — so it
## can be owned by the GameManager and read by any worker's system (theme,
## voices, vibration) without a scene-tree lookup.
##
## Persistence: the settings live in the SAME save file as the game,
## user://monster_merge_save.json, under a "settings" dict. The GameManager
## writes that dict in save_game() and reads it in _load_game() (see the
## delimited "v1.3 settings" section there). save() below does a merge-write
## of the same file so a settings change persists immediately without
## touching the game state. All keys are read with .get() defaults, so old
## saves (v1.0–v1.2, no "settings" key) load with the defaults below.
##
## Defaults: everything ON, volumes 0.8, theme "sunny".

const SAVE_PATH := "user://monster_merge_save.json"

const THEMES := ["sunny", "sunset", "night", "candy", "shadow"]
const THEME_NAMES := {
	"sunny": "Sunny Day",
	"sunset": "Sunset",
	"night": "Starry Night",
	"candy": "Candy Land",
	"shadow": "Shadow Night",
}

## v1.3 integration: emitted whenever the theme changes (settings panel,
## or any other caller of set_theme), so Main can repaint the backgrounds.
signal theme_changed(theme_id: String)

var music_enabled: bool = true
var music_volume: float = 0.8
var sound_enabled: bool = true
var sound_volume: float = 0.8
var voices_enabled: bool = true
var vibration_enabled: bool = true
var theme: String = "sunny"


func to_dict() -> Dictionary:
	return {
		"music_enabled": music_enabled,
		"music_volume": music_volume,
		"sound_enabled": sound_enabled,
		"sound_volume": sound_volume,
		"voices_enabled": voices_enabled,
		"vibration_enabled": vibration_enabled,
		"theme": theme,
	}


func load_from_dict(data: Dictionary) -> void:
	music_enabled = bool(data.get("music_enabled", true))
	music_volume = clampf(float(data.get("music_volume", 0.8)), 0.0, 1.0)
	sound_enabled = bool(data.get("sound_enabled", true))
	sound_volume = clampf(float(data.get("sound_volume", 0.8)), 0.0, 1.0)
	voices_enabled = bool(data.get("voices_enabled", true))
	vibration_enabled = bool(data.get("vibration_enabled", true))
	var t := String(data.get("theme", "sunny"))
	theme = t if t in THEMES else "sunny"


## Merge-write just the "settings" dict into the save file, preserving
## every other key (coins, grid, ...). Used on every settings change so a
## change persists immediately, even if the app is killed right after.
func save() -> void:
	var payload: Dictionary = {}
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file != null:
			var parsed = JSON.parse_string(file.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				payload = parsed
	payload["settings"] = to_dict()
	var out := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if out:
		out.store_string(JSON.stringify(payload))


# --- Setters: apply immediately (managers + persist) ------------------------

func set_music_enabled(value: bool) -> void:
	music_enabled = value
	_apply_to_managers()
	save()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_to_managers()
	save()


func set_sound_enabled(value: bool) -> void:
	sound_enabled = value
	_apply_to_managers()
	save()


func set_sound_volume(value: float) -> void:
	sound_volume = clampf(value, 0.0, 1.0)
	_apply_to_managers()
	save()


func set_voices_enabled(value: bool) -> void:
	voices_enabled = value
	save()


func set_vibration_enabled(value: bool) -> void:
	vibration_enabled = value
	save()


func set_theme(value: String) -> void:
	if value in THEMES:
		theme = value
		save()
		theme_changed.emit(theme)


func get_theme() -> String:
	return theme


static func theme_display_name(theme_id: String) -> String:
	return String(THEME_NAMES.get(theme_id, theme_id))


## Push the current music/sound state into the autoload managers. Called
## after load (GameManager._ready) and after every change. Guarded so a
## missing autoload (headless import, unit test) is a silent no-op.
func apply_to_managers() -> void:
	_apply_to_managers()


func _apply_to_managers() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var mm := tree.root.get_node_or_null("MusicManager")
	if mm != null:
		if mm.has_method("set_volume"):
			mm.call("set_volume", music_volume)
		if mm.has_method("set_music_enabled"):
			mm.call("set_music_enabled", music_enabled)
	var sm := tree.root.get_node_or_null("SoundManager")
	if sm != null:
		if sm.has_method("set_volume"):
			sm.call("set_volume", sound_volume)
		if sm.has_method("set_muted"):
			sm.call("set_muted", not sound_enabled)
	# VoiceManager (Worker B, autoload when present): push the voices flag
	# the same way, guarded so absence is a silent no-op.
	var vm := tree.root.get_node_or_null("VoiceManager")
	if vm != null and vm.has_method("set_voices_enabled"):
		vm.call("set_voices_enabled", voices_enabled)


## Vibrate once, only when vibration is enabled. Guarded for headless runs
## (no device to vibrate) and for desktop (harmless no-op there). Merge/win
## code should call this instead of Input.vibrate_handheld() directly.
func vibrate() -> void:
	if not vibration_enabled:
		return
	if DisplayServer.get_name() == "headless":
		return
	Input.vibrate_handheld(60)
