# Original procedural lo-fi / chill loop. All material generated here (no samples).
import numpy as np, wave
SR = 44100
BPM = 72
BEAT = 60 / BPM
BARS = 32
LENGTH = int(SR * BEAT * 4 * BARS)
rng = np.random.default_rng(20261101)
L = np.zeros(LENGTH); R = np.zeros(LENGTH)

def midi(n): return 440.0 * 2 ** ((n - 69) / 12)

def add(buf, start, sig):
    # circular add so the loop is seamless
    s = int(start) % LENGTH
    n = len(sig)
    end = s + n
    if end <= LENGTH:
        buf[s:end] += sig
    else:
        first = LENGTH - s
        buf[s:] += sig[:first]
        rest = sig[first:]
        while len(rest) > 0:
            k = min(len(rest), LENGTH)
            buf[:k] += rest[:k]
            rest = rest[k:]

def env(n, a, d, sustain_level, r_tail):
    t = np.arange(n) / SR
    e = np.ones(n) * sustain_level
    an = int(a * SR)
    e[:an] = np.linspace(0, 1, an) if an > 0 else e[:an]
    dn = int(d * SR)
    if dn > 0:
        e[an:an + dn] = np.linspace(1, sustain_level, len(e[an:an + dn]))
    rn = int(r_tail * SR)
    if rn > 0:
        e[-rn:] *= np.linspace(1, 0, rn)
    return e

def epiano(freq, dur, vel, detune=0.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = freq * (1 + detune)
    sig = (np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t * 3)
           + 0.12 * np.sin(2 * np.pi * 3 * f * t) * np.exp(-t * 5))
    trem = 1 + 0.06 * np.sin(2 * np.pi * 4.5 * t)
    return sig * trem * env(n, 0.02, 0.6, 0.55, 0.4) * np.exp(-t * 0.35) * vel

def bell(freq, dur, vel):
    n = int(dur * SR)
    t = np.arange(n) / SR
    sig = np.sin(2 * np.pi * freq * t) + 0.25 * np.sin(2 * np.pi * freq * 2.01 * t) * np.exp(-t * 4)
    return sig * np.exp(-t * 2.2) * env(n, 0.005, 0.0, 1, 0.1) * vel

def bass(freq, dur, vel):
    n = int(dur * SR)
    t = np.arange(n) / SR
    sig = np.sin(2 * np.pi * freq * t) + 0.15 * np.sin(2 * np.pi * 2 * freq * t)
    return sig * env(n, 0.01, 0.2, 0.7, 0.15) * vel

def kick(vel):
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    f = 50 + 70 * np.exp(-t * 25)
    phase = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(phase) * np.exp(-t * 9) * vel

def lowpass(x, a):
    y = np.zeros_like(x); acc = 0.0
    for i in range(len(x)):
        acc += a * (x[i] - acc); y[i] = acc
    return y

def noise_hit(dur, decay, vel, cutoff_a):
    n = int(dur * SR)
    t = np.arange(n) / SR
    w = rng.standard_normal(n)
    if cutoff_a < 1:
        w = w - lowpass(w, cutoff_a)  # high-pass
    return w * np.exp(-t * decay) * vel

# Chords (bar-length), voicings as MIDI notes. Progression in F major.
chords = [
    [53, 57, 60, 64],   # Fmaj7
    [57, 60, 64, 67],   # Am7
    [50, 57, 60, 65],   # Dm7
    [46, 53, 57, 62],   # Bbmaj7 (with 9 on top area)
    [53, 57, 60, 64],
    [52, 55, 59, 62],   # Em7(b5)-ish color
    [50, 53, 57, 60],   # Dm7
    [48, 52, 55, 58],   # C7
]
roots = [41, 45, 38, 34, 41, 40, 38, 36]
scale = [65, 67, 69, 72, 74, 77, 79, 81]  # F major pentatonic-ish, melody range
bar_len = BEAT * 4

melody_idx = 3
for bar in range(BARS):
    c = chords[bar % len(chords)]
    start = bar * bar_len * SR
    # e-piano chord, slightly rolled, stereo detune
    for k, note in enumerate(c):
        sigL = epiano(midi(note), bar_len + 0.6, 0.11, -0.0015)
        sigR = epiano(midi(note), bar_len + 0.6, 0.11, 0.0015)
        add(L, start + k * 0.012 * SR, sigL)
        add(R, start + k * 0.016 * SR, sigR)
    # bass on beats 1 and 3 (with a passing note sometimes)
    root = roots[bar % len(roots)]
    for beat, vel in [(0, 0.32), (2, 0.24)]:
        b = bass(midi(root), BEAT * 1.6, vel)
        add(L, start + beat * BEAT * SR, b); add(R, start + beat * BEAT * SR, b)
    # drums enter after bar 4, swing on eighths
    if bar >= 4:
        for beat in range(4):
            t0 = start + beat * BEAT * SR
            if beat in (0, 2):
                k = kick(0.38); add(L, t0, k); add(R, t0, k)
            if beat in (1, 3):
                s = noise_hit(0.25, 18, 0.06, 0.25); add(L, t0, s); add(R, t0, s * 0.9)
            for half, sw in [(0, 0.0), (1, 0.12)]:
                th = t0 + (half * 0.5 + sw * half) * BEAT * SR
                h = noise_hit(0.06, 60, 0.025 if half else 0.035, 0.05)
                add(L, th, h * 0.8); add(R, th, h)
    # melody: sparse, from bar 8, random walk on the scale (original, seeded)
    if bar >= 8 and bar % 8 not in (7,):
        positions = sorted(rng.choice([0, 1, 1.5, 2, 3, 3.5], size=rng.integers(2, 4), replace=False))
        for pos in positions:
            melody_idx = int(np.clip(melody_idx + rng.integers(-2, 3), 0, len(scale) - 1))
            note = scale[melody_idx]
            sig = bell(midi(note), 1.6, 0.09)
            add(L, start + pos * BEAT * SR, sig * 0.9); add(R, start + pos * BEAT * SR + 0.01 * SR, sig)

# vinyl crackle + soft room noise
n_clicks = int(LENGTH / SR * 6)
for _ in range(n_clicks):
    p = rng.integers(0, LENGTH)
    c = noise_hit(0.004, 800, rng.uniform(0.01, 0.04), 0.3)
    add(L, p, c); add(R, p, c * rng.uniform(0.6, 1))
hiss = rng.standard_normal(LENGTH) * 0.003
L += lowpass(hiss, 0.3); R += lowpass(hiss, 0.3)

# warm lo-fi tone: gentle low-pass and normalization
L = lowpass(L, 0.35); R = lowpass(R, 0.35)
peak = max(np.max(np.abs(L)), np.max(np.abs(R)))
L = L / peak * 0.8; R = R / peak * 0.8
st = np.stack([L, R], axis=1)
pcm = (st * 32767).astype(np.int16)
with wave.open('/tmp/music/chill_loop.wav', 'wb') as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
print('seconds', LENGTH / SR)
