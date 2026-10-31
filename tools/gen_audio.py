#!/usr/bin/env python3
"""Synthesize the Summit Trick SFX and fallback music into audio/*.wav.

The shipped menu, race and Trick Attack tracks are CC0 music from OpenGameArt;
see THIRD_PARTY_AUDIO.md. music.wav is the fallback if those files are missing.
Run with: python3 tools/gen_audio.py
"""
import math
import os
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "audio")
os.makedirs(OUT, exist_ok=True)


def save(name, data, stereo=False):
    data = np.asarray(data, dtype=np.float64)
    if data.ndim == 1:
        peak = np.max(np.abs(data)) or 1.0
        data = data / peak * 0.72
        pcm = np.int16(np.clip(data, -1, 1) * 32767)
        channels = 1
    else:
        peak = np.max(np.abs(data)) or 1.0
        data = data / peak * 0.72
        pcm = np.int16(np.clip(data, -1, 1) * 32767)
        channels = 2
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(f"wrote {path}")


def t_axis(seconds):
    return np.arange(int(seconds * SR)) / SR


def env(n, attack=0.005, release=0.2):
    a = max(1, int(attack * SR))
    r = max(1, int(release * SR))
    e = np.ones(n)
    a = min(a, n)
    r = min(r, n)
    e[:a] = np.linspace(0, 1, a)
    e[-r:] *= np.linspace(1, 0, r)
    return e


def sine(freq, dur, amp=1.0, phase=0.0):
    t = t_axis(dur)
    return amp * np.sin(2 * np.pi * freq * t + phase)


def add_wrapped(buf, sig, start):
    """Add sig into a circular buffer at start (for seamless music loops)."""
    n = len(buf)
    start = int(start) % n
    i = 0
    while i < len(sig):
        room = min(len(sig) - i, n - start)
        buf[start:start + room] += sig[i:i + room]
        i += room
        start = (start + room) % n


def kick(dur=0.22):
    n = int(dur * SR)
    t = np.arange(n) / SR
    freq = 150 * np.exp(-t * 28) + 44
    body = np.sin(2 * np.pi * np.cumsum(freq) / SR)
    click = np.random.default_rng(1).normal(0, 0.25, n) * np.exp(-t * 90)
    return (body * np.exp(-t * 13) + click) * 0.85


def snare(dur=0.2):
    n = int(dur * SR)
    t = np.arange(n) / SR
    rng = np.random.default_rng(2)
    noise = rng.normal(0, 1, n)
    tone = np.sin(2 * np.pi * 185 * t) * 0.5
    return (noise * 0.6 + tone) * np.exp(-t * 24) * 0.5


def hat(dur=0.06):
    n = int(dur * SR)
    t = np.arange(n) / SR
    rng = np.random.default_rng(3)
    noise = rng.normal(0, 1, n)
    # cheap high pass
    noise = np.diff(np.concatenate(([0.0], noise)))
    return noise * np.exp(-t * 80) * 0.16


def saw(freq, dur, amp=1.0):
    t = t_axis(dur)
    out = np.zeros_like(t)
    for k in range(1, 6):
        out += np.sin(2 * np.pi * freq * k * t) / k
    return out * amp


def make_wind():
    n = int(9.0 * SR)
    rng = np.random.default_rng(7)
    white = rng.normal(0, 1, n)
    brown = np.cumsum(white)
    brown -= brown.mean()
    brown /= max(np.max(np.abs(brown)), 1e-9)
    lp = np.empty(n)
    acc = 0.0
    for i in range(n):
        acc += 0.045 * (brown[i] - acc)
        lp[i] = acc
    t = np.arange(n) / SR
    mod = 0.7 + 0.22 * np.sin(2 * np.pi * 0.055 * t) + 0.12 * np.sin(2 * np.pi * 0.013 * t + 1.3)
    hiss = white * 0.05
    wind = lp * mod * 2.4 + hiss * mod
    fade = int(0.7 * SR)
    fade_in = np.linspace(0, 1, fade)
    fade_out = np.linspace(1, 0, fade)
    wind[:fade] = wind[:fade] * fade_in + wind[-fade:] * fade_out
    wind = wind[:-fade]
    return wind


def make_music():
    bpm = 124.0
    beat = 60.0 / bpm
    bars = 8
    loop_len = int(round(bars * 4 * beat * SR))
    buf = np.zeros(loop_len)

    chords = [
        [220.00, 261.63, 329.63],  # Am
        [174.61, 220.00, 261.63],  # F
        [261.63, 329.63, 392.00],  # C
        [196.00, 246.94, 293.66],  # G
    ]
    roots = [55.0, 43.65, 65.41, 49.0]
    arp_notes = [
        [440.0, 523.25, 659.25, 523.25],
        [349.23, 440.0, 523.25, 440.0],
        [523.25, 659.25, 783.99, 659.25],
        [392.0, 493.88, 587.33, 493.88],
    ]

    for bar in range(bars):
        chord = chords[bar % 4]
        root = roots[bar % 4]
        arp = arp_notes[bar % 4]
        bar_start = bar * 4 * beat * SR
        for b in range(4):
            at = bar_start + b * beat * SR
            add_wrapped(buf, kick(), at)
            if b in (1, 3):
                add_wrapped(buf, snare(), at)
            add_wrapped(buf, hat(), at + beat * 0.5 * SR)
            add_wrapped(buf, hat(), at + beat * 0.75 * SR)
            # bass eighth notes
            for e in (0.0, 0.5):
                if (b == 0 and e == 0.0) or True:
                    note = saw(root, beat * 0.44, 0.32)
                    note *= env(len(note), 0.01, 0.12)
                    add_wrapped(buf, note, at + e * beat * SR)
        # pad across the bar
        pad_len = int(4 * beat * SR)
        t = np.arange(pad_len) / SR
        pad = np.zeros(pad_len)
        for f in chord:
            pad += np.sin(2 * np.pi * f * t) * 0.11
            pad += np.sin(2 * np.pi * f * 2.0 * t + 0.4) * 0.03
        pad *= np.minimum(1.0, t * 3.0) * np.minimum(1.0, (pad_len / SR - t) * 3.0)
        add_wrapped(buf, pad, bar_start)
        # 16th-note arp
        for step in range(16):
            note_freq = arp[step % 4] * (2.0 if step % 8 >= 4 else 1.0)
            note = sine(note_freq, beat * 0.22, 0.10)
            note *= env(len(note), 0.004, 0.1)
            add_wrapped(buf, note, bar_start + step * beat * 0.25 * SR)

    # Gentle stereo width with delayed right channel.
    left = buf.copy()
    delay = int(0.011 * SR)
    right = np.concatenate((np.zeros(delay), buf[:-delay]))
    stereo = np.stack([left, right], axis=1)
    return stereo


def make_sfx():
    trick = np.zeros(int(0.55 * SR))
    for i, freq in enumerate([880, 1174.7, 1568]):
        tone = sine(freq, 0.4, 0.35)
        tone *= np.exp(-np.arange(len(tone)) / SR * 7)
        start = int(i * 0.06 * SR)
        trick[start:start + len(tone)] += tone[:len(trick) - start]
    save("trick.wav", trick)

    land = np.zeros(int(0.4 * SR))
    n = len(land)
    t = np.arange(n) / SR
    thud = np.sin(2 * np.pi * (95 * np.exp(-t * 9) + 40) * t) * np.exp(-t * 9)
    nz = np.random.default_rng(11).normal(0, 1, n) * np.exp(-t * 30) * 0.4
    land += thud * 0.8 + nz
    save("land.wav", land)

    n = int(0.3 * SR)
    t = np.arange(n) / SR
    rng = np.random.default_rng(12)
    whoosh = rng.normal(0, 1, n) * np.linspace(0.05, 0.8, n) * np.exp(-t * 6)
    save("jump.wav", whoosh)

    dur = 0.7
    n = int(dur * SR)
    t = np.arange(n) / SR
    freq = 180 * np.exp(t * 1.7)
    boost = np.sin(2 * np.pi * np.cumsum(freq) / SR) * 0.4
    boost += np.random.default_rng(13).normal(0, 1, n) * 0.08
    boost *= env(n, 0.02, 0.25)
    save("boost.wav", boost)

    n = int(0.85 * SR)
    t = np.arange(n) / SR
    rng = np.random.default_rng(14)
    crash = rng.normal(0, 1, n) * np.exp(-t * 5) * 0.6
    crash += np.sin(2 * np.pi * (70 * np.exp(-t * 3) + 35) * t) * np.exp(-t * 4)
    save("crash.wav", crash)

    n = int(0.45 * SR)
    t = np.arange(n) / SR
    rail = (np.sin(2 * np.pi * 1240 * t) + np.sin(2 * np.pi * 1860 * t) * 0.5) * np.exp(-t * 9) * 0.35
    save("rail.wav", rail)

    beep = sine(660, 0.14, 0.5) * env(int(0.14 * SR), 0.005, 0.05)
    save("beep.wav", beep)

    go = (sine(880, 0.35, 0.4) + sine(1320, 0.35, 0.25)) * env(int(0.35 * SR), 0.005, 0.2)
    save("go.wav", go)

    n = int(1.8 * SR)
    t = np.arange(n) / SR
    finish = np.zeros(n)
    for i, freq in enumerate([523.25, 659.25, 783.99, 1046.5]):
        tone = np.sin(2 * np.pi * freq * t) * np.exp(-t * 2.2) * 0.22
        finish += np.roll(tone, int(i * 0.1 * SR))
    save("finish.wav", finish)


if __name__ == "__main__":
    save("wind.wav", make_wind())
    save("music.wav", make_music(), stereo=True)
    make_sfx()
