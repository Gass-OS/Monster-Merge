extends Node
## MusicManager — procedural soundtrack player for Monster Merge (v1.2).
##
## Registered as autoload "MusicManager" (see project.godot).
## Loads the tracks from res://assets/music/ (track1..3, .ogg preferred,
## .wav fallback), plays them in order, looping forever.
##
## API:
##   play()           — start (or resume) the playlist from the current track
##   stop()           — stop playback
##   toggle_music() -> bool  — flip on/off, returns true when music is now on
##   is_playing() -> bool
##   next_track()     — skip to the next track
##   set_music_enabled(value) / music_enabled — persisted by the caller
##
## HEADLESS SAFETY: playback is a no-op when running headless (editor import
## and headless test runs stay silent and error-free). Streams are still
## loaded so the autoload never errors on a missing file — a missing track
## is simply skipped.

const TRACK_FILES := [
	"res://assets/music/track1.ogg",
	"res://assets/music/track2.ogg",
	"res://assets/music/track3.ogg",
	"res://assets/music/track4.ogg",
	"res://assets/music/track5.ogg",
]
const TRACK_NAMES := ["Sunny Morning", "Bouncy Buddies", "Starlight Parade", "Candy Carnival", "Dragon Dance Party"]
const VOLUME_DB := -14.0  # Gentle: music sits under the sound effects.

var music_enabled: bool = true

var _player: AudioStreamPlayer
var _tracks: Array[AudioStream] = []
var _current: int = 0
var _headless: bool = false

func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player.volume_db = VOLUME_DB
	add_child(_player)
	_player.finished.connect(_on_track_finished)
	for path in TRACK_FILES:
		var p: String = path
		var stream: AudioStream = load(p) if ResourceLoader.exists(p) else null
		if stream == null:
			var wav_path: String = p.replace(".ogg", ".wav")
			if ResourceLoader.exists(wav_path):
				stream = load(wav_path)
		if stream != null:
			_tracks.append(stream)
	# NOTE: deliberately does NOT auto-start. The coordinator calls
	# MusicManager.play() from main.gd once the game is on screen.

func play() -> void:
	if _headless or _tracks.is_empty() or not music_enabled:
		return
	if _player.playing:
		return
	_play_current()

func stop() -> void:
	if _player != null:
		_player.stop()

func toggle_music() -> bool:
	music_enabled = not music_enabled
	if music_enabled:
		play()
	else:
		stop()
	return music_enabled

func set_music_enabled(value: bool) -> void:
	music_enabled = value
	if music_enabled:
		play()
	else:
		stop()

## v1.3: music volume for the settings worker (SettingsManager calls this
## guarded via has_method; 1.0 = full). Relative to VOLUME_DB.
func set_volume(value: float) -> void:
	var v := clampf(value, 0.0, 1.0)
	if _player != null:
		_player.volume_db = VOLUME_DB if v >= 0.999 else (-80.0 if v <= 0.001 else VOLUME_DB + linear_to_db(v))

func is_playing() -> bool:
	if _headless or _player == null:
		return false
	return _player.playing

func current_track_name() -> String:
	if _tracks.is_empty():
		return ""
	return TRACK_NAMES[clampi(_current, 0, TRACK_NAMES.size() - 1)]

func track_count() -> int:
	return _tracks.size()

func next_track() -> void:
	if _tracks.is_empty():
		return
	_current = (_current + 1) % _tracks.size()
	if music_enabled and not _headless:
		_play_current()

func _play_current() -> void:
	if _tracks.is_empty():
		return
	_player.stream = _tracks[_current]
	_player.play()

func _on_track_finished() -> void:
	if not music_enabled or _headless:
		return
	_current = (_current + 1) % _tracks.size()
	_play_current()
