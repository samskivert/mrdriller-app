#!/usr/bin/env python3
"""Regenerates the metronome's click sounds: each a high one (on the beat) and a low one (between).

- beep.wav, boop.wav: the classic pure tones (800 and 400Hz). Calibration listens for exactly
  these, so keep them as they are.
- woodblock_high.wav, woodblock_low.wav, cowbell_high.wav, cowbell_low.wav: percussive clicks,
  bright (most of their energy from 1 to 5kHz, where the ear is most sensitive and drums have
  least) with a sharp attack and a short ring, to be heard over drums: see synth() below.

Uses only the standard library; run (from anywhere): python3 assets/sounds/update_sounds.py
"""

import math
import pathlib
import random
import struct
import wave

SOUNDS_DIR = pathlib.Path(__file__).resolve().parent

RATE = 44100
DURATION = 0.100  # seconds
ATTACK = 0.002  # short ramp up to avoid a click at the start
HOLD = 0.035  # time at full level before decaying, so the tone has some body
DECAY = 0.015  # exponential decay time constant after the hold
RELEASE = 0.005  # final linear fade so the tail ends exactly at zero
PEAK_DBFS = -1.0  # a little headroom below full scale to avoid inter-sample clipping

TONES = {'beep': 800, 'boop': 400}


def envelope(t):
    if t < ATTACK:
        level = t / ATTACK
    elif t < ATTACK + HOLD:
        level = 1.0
    else:
        level = math.exp(-(t - ATTACK - HOLD) / DECAY)
    remaining = DURATION - t
    if remaining < RELEASE:
        level *= remaining / RELEASE
    return level


def write(name, samples, normalize=True):
    """Writes [samples] (floats) as 16-bit mono, with 1 (or if [normalize], the loudest sample) at
    PEAK_DBFS."""
    peak = 32767 * 10 ** (PEAK_DBFS / 20)
    loudest = max(abs(s) for s in samples) if normalize else 1.0
    ints = [round(peak * s / loudest) for s in samples]
    path = SOUNDS_DIR / f'{name}.wav'
    with wave.open(str(path), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(struct.pack(f'<{len(ints)}h', *ints))
    print(f'Wrote {path}')


# A struck object rings at a few partials (not, as a string or pipe does, at whole multiples of
# one), each dying away at its own rate, the higher ones faster. Each partial is (frequency ratio,
# level, decay time constant in seconds), from a fundamental. A burst of noise at the start, the
# strike itself, gives it a sharp attack.
WOODBLOCK = [(1.0, 1.0, 0.025), (2.57, 0.5, 0.012), (4.15, 0.25, 0.006)]
COWBELL = [(1.0, 0.6, 0.060), (1.504, 1.0, 0.050), (2.03, 0.6, 0.035), (2.72, 0.5, 0.025),
           (3.61, 0.3, 0.016)]

CLICKS = {
    # (Partials, fundamental in Hz, duration in seconds, strike.) Fundamentals chosen so that most
    # of each one's energy falls between 1 and 5kHz, the low ones about a fifth below the high.
    'woodblock_high': (WOODBLOCK, 1650, 0.10, 0.35),
    'woodblock_low': (WOODBLOCK, 1100, 0.10, 0.35),
    'cowbell_high': (COWBELL, 1050, 0.20, 0.25),
    'cowbell_low': (COWBELL, 700, 0.20, 0.25),
}


def synth(partials, fundamental, duration, strike, seed):
    """[partials] at [fundamental], for [duration] seconds, with a strike of noise [strike] as loud
    as the partials together."""
    rng = random.Random(seed)
    frames = int(RATE * duration)
    out = []
    for i in range(frames):
        t = i / RATE
        # A fraction of a millisecond to rise, so it starts sharply but without a pop.
        rise = min(1.0, t / 0.0004)
        v = sum(level * math.exp(-t / decay) * math.sin(2 * math.pi * fundamental * ratio * t)
                for ratio, level, decay in partials)
        v += strike * math.exp(-t / 0.0015) * (rng.random() * 2 - 1)
        remaining = duration - t
        fade = min(1.0, remaining / RELEASE)
        out.append(v * rise * fade)
    return out


def main():
    for name, freq in TONES.items():
        frames = int(RATE * DURATION)
        write(name, [envelope(i / RATE) * math.sin(2 * math.pi * freq * i / RATE)
                     for i in range(frames)], normalize=False)
    for seed, (name, (partials, fundamental, duration, strike)) in enumerate(CLICKS.items()):
        write(name, synth(partials, fundamental, duration, strike, seed))


if __name__ == '__main__':
    main()
