#!/usr/bin/env python3
"""Regenerates the metronome beep.wav and boop.wav tones.

Uses only the standard library; run (from anywhere): python3 assets/sounds/update_sounds.py
"""

import math
import pathlib
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


def main():
    peak = 32767 * 10 ** (PEAK_DBFS / 20)
    for name, freq in TONES.items():
        frames = int(RATE * DURATION)
        samples = [round(peak * envelope(i / RATE) * math.sin(2 * math.pi * freq * i / RATE))
                   for i in range(frames)]
        path = SOUNDS_DIR / f'{name}.wav'
        with wave.open(str(path), 'wb') as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(struct.pack(f'<{frames}h', *samples))
        print(f'Wrote {path} ({freq} Hz)')


if __name__ == '__main__':
    main()
