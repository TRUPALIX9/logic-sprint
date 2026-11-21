"""LogicSprint ambient loop: original, procedurally composed, seamless."""
import numpy as np
from scipy.signal import fftconvolve, butter, sosfilt
from scipy.io import wavfile
import sys
SR = 44100
BPM = 66
BEAT = 60 / BPM
BAR = 4 * BEAT
BARS = 16
LOOP = BARS * BAR
TAIL = 6.0
N = int((LOOP + TAIL) * SR)
rng = np.random.default_rng(42)
t_all = np.arange(N) / SR

def hz(m):  # MIDI to Hz
    return 440.0 * 2 ** ((m - 69) / 12)

def env_adsr(n, a, d, s, r, sustain_len):
    """attack, decay, sustain level, release (seconds); sustain_len seconds before release"""
    e = np.zeros(n)
    ia, id_ = int(a * SR), int(d * SR)
    isus = int(sustain_len * SR)
    ir = int(r * SR)
    seg = []
    seg.append(np.linspace(0, 1, max(ia, 1), endpoint=False) ** 1.6)
    seg.append(np.linspace(1, s, max(id_, 1), endpoint=False))
    hold = max(isus - ia - id_, 0)
    seg.append(np.full(hold, s))
    seg.append(np.linspace(s, 0, max(ir, 1)) ** 1.2 * s if s > 0 else np.zeros(max(ir, 1)))
    x = np.concatenate(seg)[:n]
    e[: len(x)] = x
    return e

def warm_tone(freq, n, harmonics=(1, .32, .14, .06, .03), detune=0.0):
    t = np.arange(n) / SR
    out = np.zeros(n)
    for k, amp in enumerate(harmonics, start=1):
        ph = rng.uniform(0, 2 * np.pi)
        out += amp * np.sin(2 * np.pi * freq * k * (1 + detune) * t + ph)
    return out

L = np.zeros(N); R = np.zeros(N)
def add(sig, start, pan=0.0, gain=1.0):
    i = int(start * SR)
    j = min(N, i + len(sig))
    lg = np.cos((pan + 1) * np.pi / 4); rg = np.sin((pan + 1) * np.pi / 4)
    L[i:j] += sig[: j - i] * gain * lg
    R[i:j] += sig[: j - i] * gain * rg

# Chords (MIDI): two bars each. Cmaj9, Am9, Fmaj9, G6sus(add9)
CHORDS = [
    (36, [52, 55, 59, 62, 67]),   # C:  E G B D G
    (33, [52, 55, 60, 64, 71]),   # Am: E G C E B(9)
    (29, [53, 57, 60, 64, 67]),   # F:  F A C E G(9)
    (31, [50, 55, 59, 62, 64]),   # G6sus-ish: D G B D E
]
CH_LEN = 2 * BAR
for rep in range(BARS // 8):
    for ci, (root, tones) in enumerate(CHORDS):
        start = (rep * 4 + ci) * CH_LEN
        dur = CH_LEN + 1.8  # overlap into next chord
        n = int((dur + 2.5) * SR)
        # pad voices: two slightly detuned layers, slow swell, gentle tremolo
        for v, m in enumerate(tones):
            e = env_adsr(n, 1.8, 1.0, .75, 2.5, dur)
            lfo = 1 + .08 * np.sin(2 * np.pi * (.13 + .02 * v) * np.arange(n) / SR + v)
            sig = (warm_tone(hz(m), n, detune=+.0025) + warm_tone(hz(m), n, detune=-.0025)) * .5
            add(sig * e * lfo, start, pan=(-.6 + 1.2 * v / (len(tones) - 1)), gain=.055)
        # sub bass: soft sine root, swells
        e = env_adsr(n, 1.2, .8, .8, 2.0, dur)
        add(np.sin(2 * np.pi * hz(root) * np.arange(n) / SR) * e, start, gain=.16)
        add(np.sin(2 * np.pi * hz(root + 12) * np.arange(n) / SR) * e, start, gain=.04)

# Sparse pentatonic pluck melody (C major pentatonic, upper register)
PENT = [72, 74, 76, 79, 81, 84]
pattern_beats = [0, 1.5, 3, 5, 6.5, 8, 10, 11.5, 13, 14.5]  # within each 16-beat phrase
for phrase in range(BARS // 4):
    chord_tones = CHORDS[(phrase * 2) % 4][1]
    for k, b in enumerate(pattern_beats):
        if rng.random() < .25:
            continue
        cands = [p for p in PENT if (p % 12) in {(c % 12) for c in chord_tones}] or PENT
        m = cands[rng.integers(len(cands))] if rng.random() < .7 else PENT[rng.integers(len(PENT))]
        start = phrase * 4 * BAR + b * BEAT
        n = int(3.0 * SR)
        tt = np.arange(n) / SR
        e = np.exp(-tt * 2.2) * (1 - np.exp(-tt * 300))
        sig = (np.sin(2 * np.pi * hz(m) * tt) + .25 * np.sin(2 * np.pi * hz(m) * 2 * tt) + .08 * np.sin(2 * np.pi * hz(m) * 3 * tt)) * e
        pan = rng.uniform(-.4, .4)
        add(sig, start, pan=pan, gain=.075)
        # soft dotted-eighth echoes
        for d in range(1, 4):
            add(sig * (.42 ** d), start + d * .75 * BEAT, pan=-pan * (1 if d % 2 else -1), gain=.075)

# Very soft "air": filtered noise swell, barely audible
noise = rng.normal(0, 1, N)
sos = butter(2, [300, 2200], btype='band', fs=SR, output='sos')
air = sosfilt(sos, noise) * (.5 + .5 * np.sin(2 * np.pi * t_all / LOOP * 2 - np.pi / 2)) * .006
L += air; R += air[::-1] if False else air

# Reverb: exponentially decaying stereo noise impulse
irn = int(2.8 * SR)
tt = np.arange(irn) / SR
ir_l = rng.normal(0, 1, irn) * np.exp(-tt / .55)
ir_r = rng.normal(0, 1, irn) * np.exp(-tt / .55)
lp = butter(2, 4500, fs=SR, output='sos')
ir_l = sosfilt(lp, ir_l); ir_r = sosfilt(lp, ir_r)
ir_l /= np.sqrt((ir_l ** 2).sum()); ir_r /= np.sqrt((ir_r ** 2).sum())
wetL = fftconvolve(L, ir_l)[:N]; wetR = fftconvolve(R, ir_r)[:N]
L = .78 * L + .32 * wetL; R = .78 * R + .32 * wetR

# Gentle tone: roll off highs and rumble
sos_lp = butter(2, 6000, fs=SR, output='sos'); sos_hp = butter(2, 35, btype='high', fs=SR, output='sos')
L = sosfilt(sos_hp, sosfilt(sos_lp, L)); R = sosfilt(sos_hp, sosfilt(sos_lp, R))

# Seamless loop: fold the tail back onto the start
n_loop = int(LOOP * SR)
outL = L[:n_loop].copy(); outR = R[:n_loop].copy()
tail = N - n_loop
outL[:tail] += L[n_loop:]; outR[:tail] += R[n_loop:]

# Master: target quiet RMS, safe peak
st = np.stack([outL, outR], axis=1)
rms = np.sqrt((st ** 2).mean())
st *= (10 ** (-20 / 20)) / rms          # ~ -20 dBFS RMS
peak = np.abs(st).max()
if peak > 10 ** (-3 / 20):
    st *= (10 ** (-3 / 20)) / peak
print('len %.2fs rms %.1f dBFS peak %.1f dBFS' % (n_loop / SR, 20*np.log10(np.sqrt((st**2).mean())), 20*np.log10(np.abs(st).max())))
wavfile.write(sys.argv[1], SR, (st * 32767).astype(np.int16))
