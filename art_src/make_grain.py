"""Writes assets/textures/paint_grain.png: a 256x256 tileable grey noise made of
integer-frequency sines, sampled in world space by toon.gdshader so large flat
faces look hand-painted. python art_src/make_grain.py"""
import math
import os
import random
import struct
import zlib

N = 256
rng = random.Random(7)
waves = []
for _ in range(90):
    fx = rng.randint(-40, 40)
    fy = rng.randint(-40, 40)
    if fx == 0 and fy == 0:
        continue
    amp = 1.0 / (1.0 + (fx * fx + fy * fy) ** 0.5 * 0.12)
    waves.append((fx, fy, rng.uniform(0, math.tau), amp))
vals = []
for y in range(N):
    for x in range(N):
        v = 0.0
        for fx, fy, ph, amp in waves:
            v += amp * math.sin(math.tau * (fx * x + fy * y) / N + ph)
        vals.append(v)
lo, hi = min(vals), max(vals)
rows = bytearray()
for y in range(N):
    rows.append(0)
    for x in range(N):
        rows.append(int(255 * (vals[y * N + x] - lo) / (hi - lo)))


def chunk(tag, data):
    c = struct.pack(">I", len(data)) + tag + data
    return c + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)


png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", N, N, 8, 0, 0, 0, 0)) + \
    chunk(b"IDAT", zlib.compress(bytes(rows), 9)) + chunk(b"IEND", b"")
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "textures", "paint_grain.png")
os.makedirs(os.path.dirname(out), exist_ok=True)
with open(out, "wb") as f:
    f.write(png)
print(len(png))
