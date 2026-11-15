"""Generate the app's button sounds (original, procedurally synthesised — no licensing).

Each sound has a fixed meaning (no randomness):
  nav        — the bottom navigation bar (soft wood tick)
  today, mealPlan, log, foods, workout, progress, coach — buttons on that tab's screen
  onboarding — buttons during first-run setup

All notes come from the C-major pentatonic scale used by the calm background loop, so sounds never clash.
Each is loudness-matched, ≤ 0.3 s, with a click-free fade.

Usage:  python Scripts/make_click_sounds.py <out_dir> [<out_dir> ...]
"""

import sys
import wave
from pathlib import Path

import numpy as np

SR = 32000
rng = np.random.default_rng(7)


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def env(n, attack=0.004, decay=0.08):
    t = np.arange(n) / SR
    return (1 - np.exp(-t / attack)) * np.exp(-t / decay)


def pluck(f):
    # Karplus–Strong string pluck, softened.
    n = int(SR * 0.30)
    period = int(SR / f)
    buf = rng.uniform(-1, 1, period) * 0.6
    out = np.empty(n)
    for i in range(n):
        out[i] = buf[i % period]
        buf[i % period] = 0.498 * (buf[i % period] + buf[(i + 1) % period])
    return out * env(n, 0.002, 0.09)


def bubble(f):
    n = int(SR * 0.16)
    t = np.arange(n) / SR
    sweep = f * 0.75 * (1 + 0.6 * (1 - np.exp(-t / 0.03)))  # quick upward glide
    phase = 2 * np.pi * np.cumsum(sweep) / SR
    return np.sin(phase) * env(n, 0.003, 0.045)


def chime(f):
    n = int(SR * 0.30)
    t = np.arange(n) / SR
    tone = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t / 0.04)
    return tone * env(n, 0.002, 0.11)


def wood(f):
    n = int(SR * 0.12)
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    # Resonant "knock": noise through a damped resonator at a low multiple of the note.
    fr = f / 2
    r = np.exp(-2 * np.pi * 180 / SR)
    a1, a2 = -2 * r * np.cos(2 * np.pi * fr / SR), r * r
    y = np.zeros(n)
    for i in range(n):
        y[i] = noise[i] * (1 if i < 60 else 0) - a1 * (y[i - 1] if i else 0) - a2 * (y[i - 2] if i > 1 else 0)
    y /= np.abs(y).max() + 1e-9
    return (0.7 * y + 0.3 * np.sin(2 * np.pi * fr * t)) * env(n, 0.001, 0.03)


C5, D5, E5, G5, A5 = 72, 74, 76, 79, 81

# name → (timbre, note). Chosen so neighbouring tabs sound clearly different.
SOUNDS = {
    "nav": ("wood", C5),
    "today": ("chime", E5),
    "mealPlan": ("bubble", G5),
    "log": ("pluck", D5),
    "foods": ("bubble", C5),
    "workout": ("pluck", A5),
    "progress": ("chime", G5),
    "coach": ("chime", C5),
    "onboarding": ("pluck", E5),
}
TIMBRES = {"pluck": pluck, "bubble": bubble, "chime": chime, "wood": wood}


def finish(x):
    fade = int(SR * 0.012)
    x[-fade:] *= np.linspace(1, 0, fade)
    x = x / (np.sqrt((x ** 2).mean()) + 1e-9) * 0.12  # match loudness (RMS)
    peak = np.abs(x).max()
    if peak > 0.6:
        x *= 0.6 / peak
    return (x * 32767).astype("<i2")


def main():
    outs = [Path(p) for p in sys.argv[1:]]
    for o in outs:
        o.mkdir(parents=True, exist_ok=True)
    for name, (timbre, note) in SOUNDS.items():
        pcm = finish(TIMBRES[timbre](hz(note)))
        for o in outs:
            with wave.open(str(o / f"{name}.wav"), "wb") as w:
                w.setnchannels(1)
                w.setsampwidth(2)
                w.setframerate(SR)
                w.writeframes(pcm.tobytes())
    print(f"wrote {len(SOUNDS)} sounds to {', '.join(map(str, outs))}")


if __name__ == "__main__":
    main()
