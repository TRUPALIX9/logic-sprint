"""Composes LogicSprint's in-game music: one original, seamless loop per game.

    python3 tool/compose_music.py            # writes assets/audio/<game>.m4a
    python3 tool/compose_music.py memoryLane # just one

Everything is synthesised here (no samples, no licences). Each track suits its
game and stays quiet and soft (no drums, nothing harsh above ~6 kHz):

  rocketLaunch  continuous space ambience: drifting pads, low drone, twinkles
  memoryLane    soft piano, broken chords
  quickMath     marimba ostinato, steady and light
  guessColor    warm electric-piano bells, playful
  angleSense    music box / celesta in 3/4
  lineSplit     kalimba plucks over a soft pad

Needs numpy, scipy and ffmpeg.
"""
import subprocess
import sys
from pathlib import Path

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, fftconvolve, sosfilt

SR = 44100
OUT = Path(__file__).resolve().parent.parent / 'assets' / 'audio'


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


class Track:
    """A stereo buffer with a seamless loop of [loop] seconds plus a tail."""

    def __init__(self, loop, seed, tail=6.0):
        self.loop = loop
        self.n = int((loop + tail) * SR)
        self.L = np.zeros(self.n)
        self.R = np.zeros(self.n)
        self.rng = np.random.default_rng(seed)

    def add(self, sig, start, pan=0.0, gain=1.0):
        i = int(start * SR)
        if i >= self.n:
            return
        j = min(self.n, i + len(sig))
        lg, rg = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
        self.L[i:j] += sig[: j - i] * gain * lg
        self.R[i:j] += sig[: j - i] * gain * rg

    def reverb(self, seconds, decay, mix):
        irn = int(seconds * SR)
        t = np.arange(irn) / SR
        out = []
        for ch in (self.L, self.R):
            ir = self.rng.normal(0, 1, irn) * np.exp(-t / decay)
            ir = sosfilt(butter(2, 4500, fs=SR, output='sos'), ir)
            ir /= np.sqrt((ir ** 2).sum())
            out.append((1 - mix * .4) * ch + mix * fftconvolve(ch, ir)[: self.n])
        self.L, self.R = out

    def master(self, path, rms_db=-21.0):
        lp = butter(2, 6000, fs=SR, output='sos')
        hp = butter(2, 35, btype='high', fs=SR, output='sos')
        L = sosfilt(hp, sosfilt(lp, self.L))
        R = sosfilt(hp, sosfilt(lp, self.R))
        n = int(self.loop * SR)
        l, r = L[:n].copy(), R[:n].copy()
        l[: self.n - n] += L[n:]   # fold the tail back: seamless loop
        r[: self.n - n] += R[n:]
        st = np.stack([l, r], 1)
        st *= 10 ** (rms_db / 20) / np.sqrt((st ** 2).mean())
        peak = np.abs(st).max()
        if peak > 10 ** (-3 / 20):
            st *= 10 ** (-3 / 20) / peak
        wav = path.with_suffix('.wav')
        wavfile.write(wav, SR, (st * 32767).astype(np.int16))
        subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', str(wav),
                        '-c:a', 'aac', '-b:a', '112k', str(path)], check=True)
        if '--keep-wav' not in sys.argv:
            wav.unlink()
        print(f'{path.name}: {n / SR:.1f}s')


def env(n, attack, decay_rate):
    t = np.arange(n) / SR
    return (1 - np.exp(-t / max(attack, 1e-4))) * np.exp(-t * decay_rate)


def pad_note(tr, m, start, dur, gain, pan=0.0, bright=.3, detune=.003):
    """Soft detuned pad with a slow swell and release."""
    n = int((dur + 3) * SR)
    t = np.arange(n) / SR
    sig = np.zeros(n)
    for d in (-detune, 0, detune):
        for k, a in enumerate((1, bright, bright * .4, bright * .15), 1):
            sig += a * np.sin(2 * np.pi * hz(m) * k * (1 + d) * t + tr.rng.uniform(0, 6.28))
    a = np.clip(t / 1.6, 0, 1) ** 1.5
    r = np.clip((dur + 2.5 - t) / 2.5, 0, 1)
    tr.add(sig / 3 * a * r, start, pan, gain)


# ---------------------------------------------------------------- tracks --

def memory_lane():
    """Soft piano: Am9 – Fmaj7 – Cmaj7 – G6, broken chords, 72 BPM."""
    bpm = 72
    beat = 60 / bpm
    bars = 16
    tr = Track(bars * 4 * beat, seed=1)

    def piano(m, start, vel=1.0, pan=0.0):
        f = hz(m)
        n = int(5 * SR)
        t = np.arange(n) / SR
        sig = np.zeros(n)
        for k in range(1, 9):
            fk = f * k * np.sqrt(1 + 0.0004 * k * k)  # string inharmonicity
            sig += (1 / k ** 1.3) * np.sin(2 * np.pi * fk * t) * np.exp(-t * (0.9 + 0.55 * k) * (f / 400) ** .3)
        hammer = tr.rng.normal(0, 1, n) * np.exp(-t * 90) * .03
        sig = (sig + hammer) * (1 - np.exp(-t / .004))
        tr.add(sig, start, pan, .16 * vel)

    chords = [(45, [57, 60, 64, 67, 71]), (41, [57, 60, 64, 65, 69]),
              (36, [55, 60, 64, 67, 71]), (43, [55, 59, 62, 64, 67])]
    for bar in range(bars):
        root, tones = chords[(bar // 2) % 4]
        t0 = bar * 4 * beat
        if bar % 2 == 0:
            piano(root, t0, .9, -.2)
            piano(root + 12, t0, .5, -.2)
        order = [0, 2, 1, 3, 4, 3, 2, 1]
        for i, k in enumerate(order):
            piano(tones[k] + (12 if (bar % 4 == 3 and i > 4) else 0),
                  t0 + i * beat / 2, .55 + .15 * tr.rng.random(), -.4 + .8 * k / 4)
        if bar % 4 in (1, 3):  # a quiet melody note on top
            piano(tones[-1] + 12, t0 + 2 * beat, .45, .3)
    tr.reverb(2.6, .7, .35)
    tr.master(OUT / 'memoryLane.m4a')


def rocket_launch():
    """Continuous space ambience: no beat, drifting pads, drone, twinkles."""
    loop = 64.0
    tr = Track(loop, seed=2, tail=8)
    t = np.arange(tr.n) / SR
    # low drone with a slow wobble
    drone = (np.sin(2 * np.pi * hz(38) * t) + .5 * np.sin(2 * np.pi * hz(45) * t * 1.001)) \
        * (.8 + .2 * np.sin(2 * np.pi * t / 16))
    tr.add(drone, 0, 0, .06)
    # pads: Dmaj9 – Bm9 – Gmaj9 – Asus2, 16 s each, long overlaps
    chords = [[50, 57, 61, 64, 66], [47, 54, 57, 61, 62], [43, 54, 57, 59, 62], [45, 52, 57, 59, 64]]
    for i, tones in enumerate(chords):
        for v, m in enumerate(tones):
            pad_note(tr, m, i * 16, 17, .05, pan=-.7 + 1.4 * v / 4, bright=.45, detune=.004)
    # slow-moving filtered "solar wind"
    noise = tr.rng.normal(0, 1, tr.n)
    wind = sosfilt(butter(2, [500, 1800], btype='band', fs=SR, output='sos'), noise)
    tr.add(wind * (.5 + .5 * np.sin(2 * np.pi * t / 32)) * .012, 0, 0, 1)
    # twinkles: high soft bells, random but sparse
    for s in np.arange(1.5, loop, 2.7):
        if tr.rng.random() < .55:
            m = int(tr.rng.choice([78, 81, 83, 85, 86, 88, 90]))
            n = int(4 * SR)
            tt = np.arange(n) / SR
            bell = (np.sin(2 * np.pi * hz(m) * tt) + .3 * np.sin(2 * np.pi * hz(m) * 2.76 * tt)) * env(n, .003, 1.1)
            tr.add(bell, s + tr.rng.uniform(0, 1), tr.rng.uniform(-.8, .8), .03)
    tr.reverb(4.5, 1.4, .55)
    tr.master(OUT / 'rocketLaunch.m4a', rms_db=-22)


def quick_math():
    """Marimba ostinato over soft bass, 96 BPM, light and steady."""
    bpm = 96
    beat = 60 / bpm
    bars = 16
    tr = Track(bars * 4 * beat, seed=3)

    def marimba(m, start, gain, pan):
        n = int(1.6 * SR)
        t = np.arange(n) / SR
        f = hz(m)
        sig = np.sin(2 * np.pi * f * t) * env(n, .002, 4.5) + .25 * np.sin(2 * np.pi * f * 3.93 * t) * env(n, .001, 16)
        tr.add(sig, start, pan, gain)

    chords = [(48, [60, 64, 67, 72]), (45, [60, 64, 69, 72]), (41, [60, 65, 69, 72]), (43, [59, 62, 67, 71])]
    pattern = [0, 2, 1, 3, 2, 1, 3, 2]
    for bar in range(bars):
        root, tones = chords[bar % 4]
        t0 = bar * 4 * beat
        for i, k in enumerate(pattern):
            marimba(tones[k] + (12 if bar % 8 >= 4 and i % 4 == 3 else 0), t0 + i * beat / 2,
                    .11 if i % 2 == 0 else .07, -.3 + .2 * k)
        n = int(4 * beat * SR)
        tt = np.arange(n) / SR
        tr.add(np.sin(2 * np.pi * hz(root - 12) * tt) * env(n, .02, .6), t0, 0, .14)
    for bar in range(0, bars, 4):
        pad_note(tr, 64 if bar % 8 == 0 else 67, bar * 4 * beat, 8 * beat, .025)
    tr.reverb(1.8, .45, .25)
    tr.master(OUT / 'quickMath.m4a')


def guess_color():
    """Warm electric-piano bells (FM), playful syncopation, 84 BPM."""
    bpm = 84
    beat = 60 / bpm
    bars = 16
    tr = Track(bars * 4 * beat, seed=4)

    def ep(m, start, gain, pan, dur=2.5):
        n = int(dur * SR)
        t = np.arange(n) / SR
        f = hz(m)
        index = 1.6 * np.exp(-t * 3)
        sig = np.sin(2 * np.pi * f * t + index * np.sin(2 * np.pi * f * t)) * env(n, .004, 1.4)
        sig += .08 * np.sin(2 * np.pi * f * 14 * t) * env(n, .001, 30)  # tine ping
        tr.add(sig, start, pan, gain)

    chords = [(41, [57, 60, 64, 67]), (38, [57, 60, 62, 65]), (46, [58, 62, 65, 69]), (48, [58, 60, 64, 67])]
    comp = [0, 1.5, 2.5, 3.5]
    melody = [72, 74, 76, 79, 77, 76, 74, 72]
    for bar in range(bars):
        root, tones = chords[(bar // 2) % 4]
        t0 = bar * 4 * beat
        for c in comp:
            for v, m in enumerate(tones):
                ep(m, t0 + c * beat, .045, -.4 + .27 * v, 1.6)
        n = int(4 * beat * SR)
        tt = np.arange(n) / SR
        tr.add(np.sin(2 * np.pi * hz(root - 12) * tt) * env(n, .01, .7), t0, 0, .15)
        if bar % 2 == 1:
            for i in range(3):
                ep(melody[(bar + i * 3) % len(melody)], t0 + (i * 1.25) * beat, .07, .35)
    tr.reverb(2.2, .6, .3)
    tr.master(OUT / 'guessColor.m4a')


def angle_sense():
    """Music box / celesta in 3/4, calm, 70 BPM."""
    bpm = 70
    beat = 60 / bpm
    bars = 24
    tr = Track(bars * 3 * beat, seed=5)

    def box(m, start, gain, pan):
        n = int(3 * SR)
        t = np.arange(n) / SR
        f = hz(m)
        sig = (np.sin(2 * np.pi * f * t) + .35 * np.sin(2 * np.pi * f * 3 * t) * np.exp(-t * 6)
               + .12 * np.sin(2 * np.pi * f * 5.4 * t) * np.exp(-t * 12)) * env(n, .001, 1.8)
        tr.add(sig, start, pan, gain)

    chords = [(43, [67, 71, 74]), (40, [67, 71, 76]), (36, [67, 72, 76]), (38, [66, 69, 74])]
    tune = [79, 78, 76, 74, 76, 78, 79, 83, 81, 79, 78, 76]
    for bar in range(bars):
        root, tones = chords[(bar // 2) % 4]
        t0 = bar * 3 * beat
        n = int(3 * beat * SR)
        tt = np.arange(n) / SR
        tr.add(np.sin(2 * np.pi * hz(root) * tt) * env(n, .01, 1.0), t0, 0, .1)
        for b in (1, 2):
            for v, m in enumerate(tones):
                box(m - 12, t0 + b * beat, .03, -.3 + .3 * v)
        if bar % 3 != 2:
            box(tune[bar % len(tune)], t0, .09, .25)
            box(tune[(bar + 5) % len(tune)], t0 + 1.5 * beat, .06, .4)
    tr.reverb(2.4, .75, .35)
    tr.master(OUT / 'angleSense.m4a')


def line_split():
    """Kalimba plucks over a soft pad, D pentatonic, 78 BPM."""
    bpm = 78
    beat = 60 / bpm
    bars = 16
    tr = Track(bars * 4 * beat, seed=6)

    def kalimba(m, start, gain, pan):
        n = int(2.2 * SR)
        t = np.arange(n) / SR
        f = hz(m) * (1 + .004 * np.exp(-t * 40))  # tiny pitch settle
        ph = 2 * np.pi * np.cumsum(f) / SR
        sig = np.sin(ph) * env(n, .002, 2.6) + .18 * np.sin(5.9 * ph) * env(n, .001, 22)
        tr.add(sig, start, pan, gain)

    pent = [62, 64, 66, 69, 71, 74, 76, 78]
    chords = [[50, 57, 62, 66], [47, 54, 59, 62], [43, 50, 59, 62], [45, 52, 57, 61]]
    for i, tones in enumerate(chords * (bars // 8)):
        for v, m in enumerate(tones):
            pad_note(tr, m, i * 8 * beat, 8 * beat, .03, pan=-.5 + .33 * v, bright=.2)
    for bar in range(bars):
        t0 = bar * 4 * beat
        steps = [0, 1, 1.5, 2.5, 3] if bar % 2 == 0 else [0, .5, 2, 3, 3.5]
        for s in steps:
            m = int(tr.rng.choice(pent[2:] if bar % 4 == 3 else pent[:6]))
            kalimba(m, t0 + s * beat, .1, tr.rng.uniform(-.5, .5))
    tr.reverb(2.0, .55, .3)
    tr.master(OUT / 'lineSplit.m4a')


TRACKS = {
    'rocketLaunch': rocket_launch,
    'memoryLane': memory_lane,
    'quickMath': quick_math,
    'guessColor': guess_color,
    'angleSense': angle_sense,
    'lineSplit': line_split,
}

if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    for name in [a for a in sys.argv[1:] if not a.startswith('--')] or TRACKS:
        TRACKS[name]()
