"""Writes assets/audio/*.wav: original, fully synthesised diegetic loops (22 kHz mono).
Nothing is sampled, so there is nothing to license. python art_src/make_audio.py
Every track is rendered into a circular buffer, so note tails wrap and loops are seamless."""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
NOTE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def freq(n):
    """'C4', 'F#3', 'Bb2' -> Hz"""
    s = NOTE[n[0]]
    i = 1
    if n[1] == "#":
        s += 1
        i = 2
    elif n[1] == "b":
        s -= 1
        i = 2
    return 440.0 * 2 ** ((s + 12 * (int(n[i:]) + 1) - 69) / 12.0)


class Track:
    def __init__(self, seconds):
        self.n = int(seconds * RATE)
        self.b = [0.0] * self.n

    def tone(self, t, f, dur, vol, harm, decay, attack=0.004, detune=0.0):
        """Additive voice. harm = [(multiple, amplitude)...]."""
        start = int(t * RATE)
        count = min(int(dur * RATE), self.n)
        tau = math.tau / RATE
        parts = []
        for m, a in harm:
            parts.append((f * m * tau, a))
            if detune:
                parts.append((f * m * (1.0 + detune) * tau, a * 0.8))
        b, n = self.b, self.n
        for i in range(count):
            ts = i / RATE
            env = min(1.0, ts / attack) * math.exp(-ts * decay) * min(1.0, (count - i) / 300.0)
            s = 0.0
            for w, a in parts:
                s += math.sin(w * i) * a
            b[(start + i) % n] += s * env * vol

    def noise(self, t, dur, vol, decay, lp=0.5, rng=random):
        start = int(t * RATE)
        y = 0.0
        for i in range(int(dur * RATE)):
            y += (rng.uniform(-1, 1) - y) * lp
            self.b[(start + i) % self.n] += y * math.exp(-i / RATE * decay) * vol

    def write(self, name, gain=0.85):
        peak = max(abs(x) for x in self.b) or 1.0
        os.makedirs(OUT, exist_ok=True)
        with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(b"".join(struct.pack("<h", int(x / peak * gain * 32000)) for x in self.b))
        print(name, self.n // RATE, "s")


PIANO = [(1, 1.0), (2, 0.5), (3, 0.28), (4, 0.12), (6, 0.05)]
VIBES = [(1, 1.0), (4, 0.28), (10, 0.05)]
ORGAN = [(1, 1.0), (2, 0.7), (3, 0.45), (4, 0.3), (6, 0.18), (8, 0.1)]
PLUCK = [(1, 1.0), (2, 0.6), (3, 0.3), (5, 0.1)]
BASS = [(1, 1.0), (2, 0.35), (3, 0.1)]


def saloon_piano():
    """Out-of-tune ragtime stride in C, 16 bars."""
    bpm = 132
    beat = 60.0 / bpm
    bars = [("C2", "E3 G3 C4"), ("G1", "D3 F3 B3"), ("C2", "E3 G3 C4"), ("C2", "E3 Bb3 C4"),
            ("F2", "F3 A3 C4"), ("F2", "F3 Ab3 C4"), ("C2", "E3 G3 C4"), ("A1", "E3 A3 C4"),
            ("D2", "F#3 A3 C4"), ("G1", "D3 F3 B3"), ("C2", "E3 G3 C4"), ("A1", "C3 E3 A3"),
            ("D2", "F3 A3 D4"), ("G1", "F3 G3 B3"), ("C2", "E3 G3 C4"), ("G1", "F3 G3 B3")]
    t = Track(len(bars) * 4 * beat)
    rng = random.Random(3)
    scale = "C5 D5 E5 G5 A5 C6 D6 E6".split()
    for b, (bass, chord) in enumerate(bars):
        t0 = b * 4 * beat
        for i in range(4):
            bt = t0 + i * beat
            if i % 2 == 0:
                t.tone(bt, freq(bass), 0.7, 0.55, PIANO, 3.5, detune=0.004)
                t.tone(bt, freq(bass) * 2, 0.7, 0.3, PIANO, 3.5)
            else:
                for n in chord.split():
                    t.tone(bt, freq(n), 0.42, 0.28, PIANO, 5.0, detune=0.006)
        # syncopated melody built on chord tones + the pentatonic
        pat = [0, 1.5, 2, 3, 3.5] if b % 2 == 0 else [0, 0.5, 1, 2.5, 3]
        idx = rng.randrange(len(scale))
        for off in pat:
            idx = max(0, min(len(scale) - 1, idx + rng.choice([-2, -1, 1, 2])))
            t.tone(t0 + off * beat, freq(scale[idx]), 0.7, 0.42, PIANO, 3.2, detune=0.007)
    t.write("saloon_piano")


def casino_lounge():
    """Slow bossa on vibraphone + upright bass + brushes. Expensive-sounding regret."""
    bpm = 108
    beat = 60.0 / bpm
    bars = [("D2", "F3 A3 C4 E4"), ("G1", "F3 A3 B3 E4"), ("C2", "E3 G3 B3 D4"), ("A1", "E3 G3 C#4 F4"),
            ("D2", "F3 A3 C4 E4"), ("G1", "F3 B3 D4 E4"), ("C2", "G3 B3 D4 E4"), ("Bb1", "Ab3 D4 F4 A4")]
    t = Track(len(bars) * 4 * beat)
    rng = random.Random(9)
    for b, (bass, chord) in enumerate(bars):
        t0 = b * 4 * beat
        for off, nn in ((0, bass), (1.5, bass), (2, bass), (3.5, bass)):
            f = freq(nn) * (1.5 if off == 2 else 1.0)
            t.tone(t0 + off * beat, f, 0.8, 0.55, BASS, 3.0, attack=0.012)
        for off in (0.5, 1.5, 3.0):
            for n in chord.split():
                t.tone(t0 + off * beat, freq(n), 1.6, 0.17, VIBES, 2.2, attack=0.006)
        for k in range(8):
            t.noise(t0 + k * 0.5 * beat, 0.09, 0.05 if k % 2 else 0.09, 40.0, lp=0.7, rng=rng)
        note = chord.split()[rng.randrange(4)]
        f = freq(note) * 2
        t.tone(t0 + rng.choice([1, 2, 2.5]) * beat, f, 1.4, 0.22, VIBES, 2.5)
    t.write("casino_lounge")


def carnival_organ():
    """Oom-pah-pah calliope waltz in G."""
    bpm = 168
    beat = 60.0 / bpm
    bars = "G2 G2 D2 D2 G2 G2 C2 D2 G2 G2 D2 D2 C2 D2 G2 G2".split()
    chords = {"G2": "B3 D4 G4", "D2": "A3 D4 F#4", "C2": "C4 E4 G4"}
    mel = "G5 B5 D6 B5 A5 F#5 D5 F#5 G5 B5 D6 G6 E6 C6 A5 F#5 G5 B5 D6 B5 A5 F#5 D5 A5 E6 C6 B5 A5 G5 D5 G5 G5".split()
    t = Track(len(bars) * 3 * beat)
    for b, bass in enumerate(bars):
        t0 = b * 3 * beat
        t.tone(t0, freq(bass), 0.34, 0.5, ORGAN, 2.0, attack=0.01)
        for k in (1, 2):
            for n in chords[bass].split():
                t.tone(t0 + k * beat, freq(n), 0.24, 0.16, ORGAN, 3.0, attack=0.008)
        t.tone(t0, freq(mel[b * 2]), beat * 1.9, 0.26, ORGAN, 0.9, attack=0.01, detune=0.003)
        t.tone(t0 + 2 * beat, freq(mel[b * 2 + 1]), beat * 0.95, 0.26, ORGAN, 1.4, attack=0.01, detune=0.003)
    t.write("carnival_organ")


def beach_ukulele():
    """Lazy plucked loop for the Bilge Bar."""
    bpm = 96
    beat = 60.0 / bpm
    bars = ["C4 E4 G4 C5", "A3 E4 A4 C5", "F3 A4 C5 F5", "G3 D4 B4 D5"] * 2
    t = Track(len(bars) * 4 * beat)
    rng = random.Random(5)
    for b, ch in enumerate(bars):
        t0 = b * 4 * beat
        nn = ch.split()
        for k, off in enumerate((0, 0.75, 1.5, 2, 2.75, 3.5)):
            t.tone(t0 + off * beat, freq(nn[(k * 2 + b) % 4]), 0.9, 0.34, PLUCK, 4.5, attack=0.003)
        t.tone(t0, freq(nn[0]) / 2, 1.2, 0.3, PLUCK, 2.8)
        t.noise(t0 + 2 * beat, 0.04, 0.04, 60.0, lp=0.8, rng=rng)
    t.write("beach_ukulele")


def surf():
    """Seamless shore loop: three overlapping swells of low-passed noise."""
    secs = 13.0
    t = Track(secs)
    rng = random.Random(21)
    n = t.n
    for w in range(3):
        start = int(n * w / 3)
        length = int(n * 0.72)
        lp1 = lp2 = 0.0
        for i in range(length):
            p = i / length
            k = 0.04 + 0.18 * math.sin(math.pi * p) ** 2
            lp1 += (rng.uniform(-1, 1) - lp1) * k
            lp2 += (lp1 - lp2) * 0.5
            t.b[(start + i) % n] += lp2 * math.sin(math.pi * p) ** 1.6
    t.write("surf", gain=0.7)


for f in (saloon_piano, casino_lounge, carnival_organ, beach_ukulele, surf):
    f()
