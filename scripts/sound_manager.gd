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
	# --- Boss Rush (v1.3, Worker C) ---
	# Low descending saw-ish growl: a triangle glide from 160 Hz down to
	# 55 Hz over 0.7 s. Played once when a boss spawns.
	streams["roar"] = _make_glide(160.0, 55.0, 0.7, 1, 0.65)
	# Winner sounds (v1.3, Worker D): fanfare baked once; blips and combos
	# are built lazily per tier/level and cached in `streams`.
	streams["fanfare"] = _make_chime([523.25, 659.25, 783.99, 1046.5, 1318.51, 1567.98], 0.15, 1, 0.45)


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


# --- Boss Rush (v1.3, Worker C) ------------------------------------------------
# Low roar played when a boss spawns. Procedural (see _ready).
func play_roar() -> void:
	_play("roar")

# --- Voice blips + winner sounds (v1.3, Worker D) ---------------------------
# play_blip(tier): short cute gibberish-style blip — 2 quick sine notes,
# pitch rising with tier (base 500 + tier x 80 Hz), ~0.09 s total.
# Call sites (coordinator): on monster spawn and on merge.
func play_blip(tier: int) -> void:
	var t := clampi(tier, 1, 8)
	var key := "blip%d" % t
	if not streams.has(key):
		var base := 500.0 + float(t) * 80.0
		streams[key] = _make_chime([base, base * 1.25], 0.045, 0, 0.5)
	_play(key)

# play_fanfare(): rising 6-note arpeggio, ~0.9 s, for jackpot / boss win.
func play_fanfare() -> void:
	_play("fanfare")

# play_combo(level): short rising chime; pitch rises with the combo level.
func play_combo(level: int) -> void:
	var lv := maxi(1, level)
	var key := "combo%d" % lv
	if not streams.has(key):
		var base := 600.0 + float(lv) * 60.0
		streams[key] = _make_chime([base, base * 1.25, base * 1.5], 0.09, 1, 0.45)
	_play(key)


# Casino celebration sounds (built lazily the first time, then cached).
func play_applause() -> void:
	if not streams.has("applause"):
		streams["applause"] = _make_applause(2.4)
	_play("applause")

func play_coin_shower() -> void:
	if not streams.has("coin_shower"):
		streams["coin_shower"] = _make_coin_shower(1.8)
	_play("coin_shower")

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


# Crowd applause: a soft noise bed plus many short random claps.
func _make_applause(duration: float) -> AudioStreamWAV:
	var count: int = int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var lp: float = 0.0
	for i in count:
		var frac: float = float(i) / float(count)
		var env: float = minf(1.0, frac * 6.0) * minf(1.0, (1.0 - frac) * 3.0)
		lp = lp * 0.82 + rng.randf_range(-1.0, 1.0) * 0.18
		samples[i] = lp * 0.45 * env * PEAK
	for n in 70:
		var start: int = rng.randi_range(0, count - 700)
		var amp: float = rng.randf_range(0.25, 0.6)
		for k in 330:
			var decay: float = pow(1.0 - float(k) / 330.0, 3.0)
			var idx: int = start + k
			var frac2: float = float(idx) / float(count)
			var env2: float = minf(1.0, frac2 * 6.0) * minf(1.0, (1.0 - frac2) * 3.0)
			samples[idx] += rng.randf_range(-1.0, 1.0) * amp * decay * env2 * PEAK
	return _pack_wav(samples)

# Coins pouring: many short metallic pings at random pitches.
func _make_coin_shower(duration: float) -> AudioStreamWAV:
	var count: int = int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var length: int = 3000
	for n in 30:
		var start: int = rng.randi_range(0, count - length - 1)
		var f: float = rng.randf_range(1800.0, 3400.0)
		var amp: float = rng.randf_range(0.2, 0.45)
		for k in length:
			var t: float = float(k) / float(MIX_RATE)
			var env: float = pow(1.0 - float(k) / float(length), 2.5)
			samples[start + k] += (sin(TAU * f * t) + 0.5 * sin(TAU * f * 2.7 * t)) * amp * env * PEAK * 0.5
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
