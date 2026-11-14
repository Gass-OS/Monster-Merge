#!/usr/bin/env python3
"""Procedural cheerful soundtrack for Monster Merge (v1.3, Worker D).

Generates 5 loopable music tracks as .ogg (STEREO 44100 Hz, 16-bit) using
numpy (vectorised synthesis — fast) + ffmpeg libvorbis encoding. Each
track is ~2 minutes: a cheerful melody + bass + soft drum/hat pattern,
built on exact bar boundaries so the end connects cleanly back to the
start (loopable). The right channel is the left channel delayed ~8 ms
(Haas effect), so the file is genuinely stereo, not dual mono.

Usage:  python3 tools/generate_music.py
Output: assets/music/track1.ogg .. track5.ogg
Requires: numpy, ffmpeg.
"""
import math
import os
import random
import struct
import subprocess
import sys
import wave

import numpy as np

SAMPLE_RATE = 44100
CHANNELS = 2
HAAS_DELAY_SAMPLES = 350  # ~8 ms at 44.1 kHz
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT_DIR = os.path.join(ROOT, "assets", "music")

# Note frequencies (equal temperament, A4 = 440).
def midi_to_freq(m):
    return 440.0 * (2.0 ** ((m - 69) / 12.0))

# Pentatonic-ish cheerful scales (MIDI note numbers).
SCALES = {
    "C": [60, 62, 64, 67, 69, 72, 74, 76, 79, 81],
    "G": [55, 59, 62, 64, 67, 71, 74, 76, 79, 83],
    "F": [53, 57, 60, 62, 65, 69, 72, 74, 77, 81],
    "D": [62, 64, 66, 69, 71, 74, 76, 78, 81, 83],
    "Am": [57, 60, 62, 64, 67, 69, 72, 74, 76, 79],
}

TRACKS = [
    {
        "name": "track1",
        "title": "Sunny Morning",
        "bpm": 116,
        "bars": 58,  # 58 bars @ 116 bpm = 120.0 s
        "scale": "C",
        "chords": [(48, 52, 55), (43, 47, 50), (45, 48, 52), (41, 45, 48)],
        # C, G, Am, F (root positions, MIDI)
        "seed": 11,
    },
    {
        "name": "track2",
        "title": "Bouncy Buddies",
        "bpm": 124,
        "bars": 62,  # 120.0 s
        "scale": "G",
        "chords": [(43, 47, 50), (38, 42, 45), (40, 43, 47), (48, 52, 55)],
        # G, D, Em, C
        "seed": 23,
    },
    {
        "name": "track3",
        "title": "Starlight Parade",
        "bpm": 108,
        "bars": 54,  # 120.0 s
        "scale": "F",
        "chords": [(41, 45, 48), (48, 52, 55), (50, 53, 57), (46, 50, 53)],
        # F, C, Dm, Bb
        "seed": 37,
    },
    {
        "name": "track4",
        "title": "Candy Carnival",
        "bpm": 132,
        "bars": 66,  # 120.0 s
        "scale": "D",
        "chords": [(50, 54, 57), (43, 47, 50), (45, 49, 52), (47, 51, 54)],
        # D, G, A, Bm
        "seed": 51,
    },
    {
        "name": "track5",
        "title": "Dragon Dance Party",
        "bpm": 100,
        "bars": 50,  # 120.0 s
        "scale": "Am",
        "chords": [(45, 48, 52), (41, 45, 48), (48, 52, 55), (43, 47, 50)],
        # Am, F, C, G
        "seed": 67,
    },
]


def render_track(cfg):
    bpm = cfg["bpm"]
    beat = 60.0 / bpm
    bar = beat * 4
    total = cfg["bars"] * bar
    n = int(total * SAMPLE_RATE)
    buf = np.zeros(n, dtype=np.float64)
    rng = random.Random(cfg["seed"])
    scale = SCALES[cfg["scale"]]

    def add_tone(freq, start, dur, vol, wave="sine", decay=3.0):
        """Add a single note with exponential decay envelope (vectorised)."""
        i0 = int(start * SAMPLE_RATE)
        i1 = min(n, int((start + dur) * SAMPLE_RATE))
        if i1 <= i0:
            return
        t = np.arange(i1 - i0, dtype=np.float64) / SAMPLE_RATE
        frac = t / dur
        env = np.exp(-decay * frac) * np.minimum(1.0, t / 0.01)
        phase = 2.0 * math.pi * freq * t
        if wave == "sine":
            s = np.sin(phase)
        elif wave == "triangle":
            s = 2.0 * np.abs(2.0 * (phase / (2.0 * math.pi)
                             - np.floor(phase / (2.0 * math.pi) + 0.5))) - 1.0
        else:  # soft square (clipped sine mix)
            s = np.tanh(2.0 * np.sin(phase))
        buf[i0:i1] += s * vol * env

    def add_kick(start, dur=0.18, vol=0.5):
        i0 = int(start * SAMPLE_RATE)
        i1 = min(n, int((start + dur) * SAMPLE_RATE))
        if i1 <= i0:
            return
        m = i1 - i0
        frac = np.arange(m, dtype=np.float64) / m
        freq = 150.0 + (40.0 - 150.0) * frac
        phase = np.cumsum(2.0 * math.pi * freq / SAMPLE_RATE)
        env = (1.0 - frac) ** 2
        buf[i0:i1] += np.sin(phase) * vol * env

    def add_hat(start, dur=0.05, vol=0.12):
        i0 = int(start * SAMPLE_RATE)
        i1 = min(n, int((start + dur) * SAMPLE_RATE))
        if i1 <= i0:
            return
        m = i1 - i0
        t = np.arange(m, dtype=np.float64) / SAMPLE_RATE
        env = 1.0 - t / dur
        noise = np.array([rng.random() * 2.0 - 1.0 for _ in range(m)])
        buf[i0:i1] += noise * vol * env * 0.5

    # --- Compose bar by bar -------------------------------------------------
    melody_note = len(scale) // 2
    for b in range(cfg["bars"]):
        bar_start = b * bar
        chord = cfg["chords"][b % len(cfg["chords"])]
        # Bass: root on beats 1 and 3, fifth on beat 2.5-ish, gentle.
        for beat_i, deg in ((0, 0), (2, 0)):
            add_tone(midi_to_freq(chord[deg] - 12), bar_start + beat_i * beat,
                     beat * 0.9, 0.30, "triangle", 2.0)
        add_tone(midi_to_freq(chord[2] - 12), bar_start + 3 * beat,
                 beat * 0.9, 0.22, "triangle", 2.0)
        # Chord pad: soft triad, whole bar, quiet.
        for note in chord:
            add_tone(midi_to_freq(note), bar_start, bar, 0.05, "sine", 0.8)
        # Drums: kick on 1 & 3, hat on every off-beat 8th.
        add_kick(bar_start)
        add_kick(bar_start + 2 * beat)
        for h in range(8):
            add_hat(bar_start + (h + 0.5) * beat * 0.5)
        # Melody: cheerful random walk on the pentatonic scale, 8th notes.
        # Every 4th bar ends on the tonic to keep the loop tidy.
        for e in range(8):
            step_len = beat * 0.5
            start = bar_start + e * step_len
            if rng.random() < 0.18:
                continue  # rest — breathing room
            melody_note += rng.choice((-2, -1, -1, 1, 1, 2))
            melody_note = max(0, min(len(scale) - 1, melody_note))
            if b % 4 == 3 and e == 7:
                melody_note = 4  # land home at phrase ends
            freq = midi_to_freq(scale[melody_note])
            dur = step_len * (2.0 if rng.random() < 0.15 else 1.0)
            add_tone(freq, start, min(dur, bar - e * step_len), 0.26,
                     "triangle", 2.5)
            # Sparkle octave above, very quiet, on phrase starts.
            if e == 0:
                add_tone(freq * 2.0, start, step_len, 0.06, "sine", 3.0)

    # Gentle 0.05 s fade on the very last samples so the loop point is click-free.
    fade = int(0.05 * SAMPLE_RATE)
    buf[-fade:] *= np.linspace(1.0, 0.0, fade)
    # Stereo: right channel = left delayed ~8 ms (Haas effect).
    left = buf
    right = np.concatenate([np.zeros(HAAS_DELAY_SAMPLES), buf[:-HAAS_DELAY_SAMPLES]]) * 0.95
    peak = max(np.max(np.abs(left)), np.max(np.abs(right)), 1e-6)
    gain = 0.85 / peak
    stereo = np.empty((n, 2), dtype=np.int16)
    stereo[:, 0] = np.clip(left * gain * 32767, -32767, 32767).astype(np.int16)
    stereo[:, 1] = np.clip(right * gain * 32767, -32767, 32767).astype(np.int16)
    return stereo.tobytes(), total


def encode_ogg(wav_path, ogg_path):
    try:
        r = subprocess.run(
            ["ffmpeg", "-y", "-v", "error", "-i", wav_path,
             "-c:a", "libvorbis", "-q:a", "3", ogg_path],
            capture_output=True, text=True, timeout=300)
        return r.returncode == 0
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for cfg in TRACKS:
        print(f"Rendering {cfg['title']} ({cfg['name']}) ...", flush=True)
        frames, total = render_track(cfg)
        wav_path = os.path.join(OUT_DIR, cfg["name"] + ".wav")
        with wave.open(wav_path, "wb") as w:
            w.setnchannels(CHANNELS)
            w.setsampwidth(2)
            w.setframerate(SAMPLE_RATE)
            w.writeframes(frames)
        ogg_path = os.path.join(OUT_DIR, cfg["name"] + ".ogg")
        if encode_ogg(wav_path, ogg_path):
            os.remove(wav_path)
            size = os.path.getsize(ogg_path)
            print(f"  -> {ogg_path}  {total:.1f}s  {size} bytes (.ogg)")
        else:
            size = os.path.getsize(wav_path)
            print(f"  -> ffmpeg missing/failed; kept {wav_path}  "
                  f"{total:.1f}s  {size} bytes (.wav)")


if __name__ == "__main__":
    main()
