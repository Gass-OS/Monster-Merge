extends Node
## Procedural sound manager for Monster Merge.
## Generates all audio in code (no audio assets): sine/triangle tones with
## simple envelopes, baked into AudioStreamWAV resources at startup and
## played through a small pool of AudioStreamPlayer children.
## Registered as autoload "SoundManager" (see sound_manager_autoload.txt).
## Other scripts should call it via get_node_or_null("/root/SoundManager")
## with null/method guards, so the game still works if it is absent.

const MIX_RATE: int = 22050
const POOL_SIZE: int = 6
const PEAK: float = 0.5  # Gentle master peak volume for every sound.

# Cached generated streams, keyed "pop" / "ding" / "unlock" / "click".
var streams: Dictionary = {}

var muted: bool = false

var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0


func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	streams["pop"] = _make_glide(300.0, 750.0, 0.12, 0, 0.5)
	streams["ding"] = _make_chime([1046.5, 1567.98], 0.15, 1, 0.45)
	streams["unlock"] = _make_chime([523.25, 659.25, 783.99, 1046.5, 1318.51], 0.16, 1, 0.45)
	streams["click"] = _make_glide(1200.0, 800.0, 0.06, 0, 0.35)


func set_muted(value: bool) -> void:
	muted = value
	if muted:
		for p in _players:
			p.stop()


func toggle_mute() -> bool:
	set_muted(not muted)
	return muted


func play_pop() -> void:
	_play("pop")


func play_ding() -> void:
	_play("ding")


func play_unlock() -> void:
	_play("unlock")


func play_click() -> void:
	_play("click")


func get_stream(sound_name: String) -> AudioStreamWAV:
	return streams.get(sound_name, null)


func _play(sound_name: String) -> void:
	if muted:
		return
	var wav: AudioStreamWAV = streams.get(sound_name, null)
	if wav == null or _players.is_empty():
		return
	var p: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = wav
	p.play()


# --- Procedural generation helpers ---------------------------------------

# One gliding tone: sine (waveform 0) or triangle (waveform 1), frequency
# sweeping linearly from freq_from to freq_to over `duration` seconds,
# with a 5 ms attack and exponential decay envelope.
func _make_glide(freq_from: float, freq_to: float, duration: float, waveform: int, volume: float) -> AudioStreamWAV:
	var count: int = int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase: float = 0.0
	for i in count:
		var t: float = float(i) / MIX_RATE
		var frac: float = float(i) / float(count)
		var freq: float = lerpf(freq_from, freq_to, frac)
		phase += TAU * freq / MIX_RATE
		var s: float = _osc(phase, waveform)
		samples[i] = s * volume * PEAK * _envelope(frac, duration)
	return _pack_wav(samples)


# A sequence of equal-length notes (triangle wave, bright chime timbre),
# each `note_duration` seconds, back to back. Total = notes.size() * note_duration.
func _make_chime(freqs: Array, note_duration: float, waveform: int, volume: float) -> AudioStreamWAV:
	var per_note: int = int(MIX_RATE * note_duration)
	var samples := PackedFloat32Array()
	samples.resize(per_note * freqs.size())
	var phase: float = 0.0
	for n in freqs.size():
		var freq: float = float(freqs[n])
		for i in per_note:
			var frac: float = float(i) / float(per_note)
			phase += TAU * freq / MIX_RATE
			var s: float = _osc(phase, waveform)
			# Slight overlap ring: previous note keeps decaying under the next.
			samples[n * per_note + i] = s * volume * PEAK * _envelope(frac, note_duration)
	return _pack_wav(samples)


# Oscillator: 0 = sine, 1 = triangle (softer than square, brighter than sine).
func _osc(phase: float, waveform: int) -> float:
	if waveform == 1:
		return 2.0 * absf(2.0 * (phase / TAU - floorf(phase / TAU + 0.5))) - 1.0
	return sin(phase)


# Envelope: fast linear attack (first 5 ms), then exponential-style decay
# to ~0 by the end of the note, so nothing clicks or rings.
func _envelope(frac: float, duration: float) -> float:
	var attack: float = 0.005 / duration
	if frac < attack:
		return frac / attack
	return pow(1.0 - frac, 2.0)


func _pack_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var v: int = int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav
