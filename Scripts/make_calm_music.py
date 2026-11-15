"""Compose the app's calming background loop (original, procedurally generated — no licensing).

Soft detuned pad chords (Cmaj9 → Am9 → Fmaj7#11 → G6sus) with slow swells, a warm low drone and a few
pentatonic bell tones, through a long reverb. Everything is built *circularly* (envelopes wrap around and
the reverb is a circular convolution), so the file loops with no seam.

Usage:  python Scripts/make_calm_music.py out.wav   then encode with ffmpeg (see README).
"""

import sys
import wave

import numpy as np

out = sys.argv[1]
SR = 32000
BAR = 15.0  # seconds per chord
CHORDS = [
    [48, 55, 64, 71, 74],  # Cmaj9   (C3 G3 E4 B4 D5)
    [45, 52, 60, 67, 71],  # Am9     (A2 E3 C4 G4 B4)
    [41, 48, 57, 64, 66],  # Fmaj7#11
    [43, 50, 59, 64, 69],  # G6sus
]
LENGTH = BAR * len(CHORDS) * 2  # two passes, second slightly brighter → 120 s
N = int(SR * LENGTH)
t = np.arange(N) / SR
rng = np.random.default_rng(20261115)


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def circular_window(center, width):
    """Raised-cosine swell centred at `center` seconds, wrapping around the loop."""
    d = (t - center + LENGTH / 2) % LENGTH - LENGTH / 2
    w = np.clip(1 - np.abs(d) / width, 0, 1)
    return 0.5 - 0.5 * np.cos(np.pi * w)


def loop_freq(f):
    """Snap a frequency so it completes a whole number of cycles in the loop (seamless phase)."""
    return round(f * LENGTH) / LENGTH


left = np.zeros(N)
right = np.zeros(N)

# Pads: each chord swells in over ~6 s and overlaps its neighbours.
for pass_no in range(2):
    for i, chord in enumerate(CHORDS):
        center = (pass_no * len(CHORDS) + i) * BAR + BAR / 2
        env = circular_window(center, BAR * 1.15)
        for k, note in enumerate(chord):
            for detune, pan in ((-0.06, 0.25), (0.06, 0.75)):
                f = loop_freq(hz(note + detune))
                tone = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * 2 * f * t) + 0.08 * np.sin(2 * np.pi * 3 * f * t)
                gain = (0.11 if k == 0 else 0.07) * (1.08 if pass_no else 1.0)
                left += tone * env * gain * (1 - pan)
                right += tone * env * gain * pan

# Low drone with a very slow breathing tremolo (2 cycles per loop).
drone_f = loop_freq(hz(36))
breath = 0.75 + 0.25 * np.sin(2 * np.pi * 2 * t / LENGTH)
drone = (np.sin(2 * np.pi * drone_f * t) + 0.3 * np.sin(2 * np.pi * 2 * drone_f * t)) * 0.07 * breath
left += drone
right += drone

# Bells: C major pentatonic, sparse, soft attack, long decay (wrapped).
PENTA = [72, 74, 76, 79, 81, 84, 86]
for _ in range(26):
    start = rng.uniform(0, LENGTH)
    note = rng.choice(PENTA)
    f = loop_freq(hz(note))
    d = (t - start) % LENGTH
    env = (1 - np.exp(-d / 0.02)) * np.exp(-d / 2.8)
    bell = (np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * 2.76 * f * t) * np.exp(-d / 0.6)) * env * 0.05
    pan = rng.uniform(0.2, 0.8)
    left += bell * (1 - pan)
    right += bell * pan

# Long, soft reverb: circular convolution with decaying, low-passed noise (keeps the loop seamless).
ir_len = int(SR * 4.5)
ir = rng.standard_normal(ir_len) * np.exp(-np.arange(ir_len) / (SR * 1.3))
ir = np.convolve(ir, np.ones(24) / 24, mode="same")  # darken
ir /= np.sqrt((ir ** 2).sum())
IR = np.fft.rfft(np.pad(ir, (0, N - ir_len)))


def reverb(x, wet=0.55):
    return (1 - wet) * x + wet * np.fft.irfft(np.fft.rfft(x) * IR, n=N)


left, right = reverb(left), reverb(right)

# Gentle low-pass (one-pole, applied circularly by running twice) for warmth.
def warm(x, a=0.18):
    y = np.empty_like(x)
    prev = 0.0
    for _ in range(2):
        for i in range(len(x)):
            prev += a * (x[i] - prev)
            y[i] = prev
    return y


left, right = warm(left), warm(right)

stereo = np.stack([left, right], axis=1)
stereo *= 0.5 / np.abs(stereo).max()  # peak −6 dBFS; the apps play it quietly anyway
pcm = (stereo * 32767).astype("<i2")

with wave.open(out, "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(pcm.tobytes())
print(f"wrote {out}: {LENGTH:.0f}s @ {SR} Hz")
