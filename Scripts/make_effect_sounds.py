"""Generate the Workout Complete sound effects (original, procedurally synthesised — no licensing).

  celebration — "Workout Complete!" screen: bright rising arpeggio with sparkles and a confetti pop
  whoosh      — the progress / baseline review screen sliding in
  fire        — the streak screen when the flame ignites and the streak goes up by one

Usage:  python3 Scripts/make_effect_sounds.py <out_dir> [<out_dir> ...]
"""

import sys
import wave
from pathlib import Path

import numpy as np

SR = 32000
rng = np.random.default_rng(11)


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def adsr(n, attack, decay):
    t = np.arange(n) / SR
    return (1 - np.exp(-t / attack)) * np.exp(-t / decay)


def biquad(x, b, a):
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    b0, b1, b2 = b
    _, a1, a2 = a
    for i, xi in enumerate(x):
        yi = b0 * xi + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, xi, y1, yi
        y[i] = yi
    return y


def bandpass_sweep(x, f_start, f_end, q):
    """Time-varying band-pass (coefficients recomputed per sample) — the heart of a whoosh."""
    n = len(x)
    freqs = f_start * (f_end / f_start) ** (np.linspace(0, 1, n) ** 0.8)
    y = np.zeros(n)
    x1 = x2 = y1 = y2 = 0.0
    for i in range(n):
        w = 2 * np.pi * freqs[i] / SR
        alpha = np.sin(w) / (2 * q)
        a0 = 1 + alpha
        b0, b2 = alpha / a0, -alpha / a0
        a1, a2 = -2 * np.cos(w) / a0, (1 - alpha) / a0
        yi = b0 * x[i] + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, x[i], y1, yi
        y[i] = yi
    return y


def lowpass(x, fc):
    w = 2 * np.pi * fc / SR
    alpha = np.sin(w) / (2 * 0.707)
    a0 = 1 + alpha
    c = np.cos(w)
    return biquad(x, ((1 - c) / 2 / a0, (1 - c) / a0, (1 - c) / 2 / a0), (1, -2 * c / a0, (1 - alpha) / a0))


def bell(f, dur, decay):
    n = int(SR * dur)
    t = np.arange(n) / SR
    tone = (
        np.sin(2 * np.pi * f * t)
        + 0.5 * np.sin(2 * np.pi * f * 2 * t) * np.exp(-t / (decay * 0.6))
        + 0.25 * np.sin(2 * np.pi * f * 3.01 * t) * np.exp(-t / (decay * 0.3))
    )
    return tone * adsr(n, 0.003, decay)


def place(buf, snd, at):
    i = int(at * SR)
    end = min(len(buf), i + len(snd))
    buf[i:end] += snd[: end - i]


def celebration():
    buf = np.zeros(int(SR * 1.9))
    # Rising major arpeggio C5 E5 G5 C6, then a sustained C6+E6 shimmer.
    for k, m in enumerate([72, 76, 79, 84]):
        place(buf, 0.55 * bell(hz(m), 1.0, 0.35), 0.0 + k * 0.085)
    place(buf, 0.45 * (bell(hz(84), 1.5, 0.6) + 0.7 * bell(hz(88), 1.5, 0.55)), 0.38)
    # Sparkles: tiny high pings at fixed times (not random per play — the file is fixed).
    for k in range(14):
        f = hz(rng.choice([91, 93, 96, 98, 100]))
        place(buf, 0.12 * bell(f, 0.25, 0.05), 0.42 + k * 0.07 + rng.uniform(0, 0.03))
    # Confetti pop: short filtered noise burst.
    pop = lowpass(rng.standard_normal(int(SR * 0.12)), 2500) * adsr(int(SR * 0.12), 0.001, 0.025)
    place(buf, 0.9 * pop, 0.36)
    return buf


def whoosh():
    n = int(SR * 0.75)
    noise = rng.standard_normal(n)
    y = bandpass_sweep(noise, 250, 3800, 1.6)
    t = np.linspace(0, 1, n)
    swell = np.sin(np.pi * np.clip(t / 0.9, 0, 1)) ** 1.6  # rises, peaks around 45%, falls away
    out = y * swell
    # A soft airy shimmer on top so it feels "magical" rather than windy.
    shimmer = bandpass_sweep(rng.standard_normal(n), 3000, 7000, 4) * swell**2 * 0.35
    return out + shimmer


def fire():
    n = int(SR * 1.7)
    t = np.arange(n) / SR
    # Ignition "fwoomp": low noise through an opening low-pass with a pitch-dropping body.
    burst_env = (1 - np.exp(-t / 0.03)) * np.exp(-t / 0.35)
    body = lowpass(rng.standard_normal(n), 700) * burst_env * 2.2
    thump = np.sin(2 * np.pi * np.cumsum(120 * np.exp(-t / 0.15) + 45) / SR) * np.exp(-t / 0.18) * 0.6
    # Steady flame roar (soft band noise) that fades out.
    roar = bandpass_sweep(rng.standard_normal(n), 400, 900, 0.9) * (1 - np.exp(-t / 0.15)) * np.exp(-t / 0.7) * 0.6
    out = body + thump + roar
    # Crackles: sharp tiny clicks at fixed pseudo-random times.
    for _ in range(38):
        at = rng.uniform(0.08, 1.45)
        m = int(SR * rng.uniform(0.002, 0.008))
        click = rng.standard_normal(m) * np.exp(-np.arange(m) / (m / 3))
        place(out, click * rng.uniform(0.3, 0.9) * np.exp(-at / 0.9), at)
    # A rising "level up" ping for the +1.
    ping_n = int(SR * 0.6)
    pt = np.arange(ping_n) / SR
    f = hz(84) * (1 + 0.5 * (1 - np.exp(-pt / 0.05)))
    ping = np.sin(2 * np.pi * np.cumsum(f) / SR) * adsr(ping_n, 0.004, 0.18) * 0.35
    place(out, ping, 0.25)
    return out


def finish(x, peak=0.8):
    x = x - x.mean()
    fade = int(SR * 0.02)
    x[:64] *= np.linspace(0, 1, 64)
    x[-fade:] *= np.linspace(1, 0, fade)
    return x / (np.abs(x).max() + 1e-9) * peak


def write(path, x):
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


EFFECTS = {"celebration": (celebration, 0.8), "whoosh": (whoosh, 0.7), "fire": (fire, 0.85)}


def main():
    outs = [Path(p) for p in sys.argv[1:]] or [Path("web/public/audio/effects")]
    rendered = {name: finish(fn(), peak) for name, (fn, peak) in EFFECTS.items()}
    for out in outs:
        out.mkdir(parents=True, exist_ok=True)
        for name, x in rendered.items():
            write(out / f"{name}.wav", x)
            print(f"{out / name}.wav  {len(x) / SR:.2f}s")


if __name__ == "__main__":
    main()
