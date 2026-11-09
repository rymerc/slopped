"""Western furniture for the saloon, hotel lobby, casino and jail (replaces the
plain KayKit pieces). DYN parts of `furn`, origin at floor centre, front +z.
Sizes match what the KayKit pieces were scaled to, so colliders stay the same.

  table     round saloon table, top at 1.0 m, r 0.62
  chair     spindle-back chair, seat 0.55, back to 1.2 at -z
  armchair  upholstered hotel chair
  stool     bar stool, seat top 0.48
  settee    hotel settee, 3.9 x 1.6 x 2.0
  lamp      brass floor lamp with a fringed shade, 3.1 tall
"""
import math

from lm import LM, hexc, jitter, scale_col
from sets import STEEL, lathe
from town import BRASS, INK, WOOD, WOOD_D, WOOD_L

OAK = hexc("#8a5530")
OAK_D = hexc("#5e3a22")
VELVET = hexc("#8a2337")
GREEN = hexc("#2f5d43")


def _table(m):
    p = m.part("table", ao=True)
    lathe(p, [(0.0, 0.0, OAK_D), (0.0, 0.08, OAK_D), (0.1, 0.07, OAK), (0.3, 0.06, OAK), (0.42, 0.1, OAK), (0.55, 0.06, OAK), (0.8, 0.07, OAK),
              (0.86, 0.12, OAK_D), (0.9, 0.12, OAK_D), (0.9, 0.0, OAK_D)], n=10)
    for k in range(4):  # splayed feet
        a = k * math.tau / 4 + math.pi / 4
        p.rod((0, 0.14, 0), (math.cos(a) * 0.48, 0.03, math.sin(a) * 0.48), 0.05, OAK_D, n=5)
        p.ball(math.cos(a) * 0.48, 0.04, math.sin(a) * 0.48, 0.06, BRASS, n=5, rings=3)
    p.cyl(0, 0.9, 0, 0.5, 0.94, 0.5, OAK_D, n=16)
    p.cyl(0, 0.94, 0, 0.62, 1.0, 0.62, jitter(OAK, p.rng, 0.04), n=20)
    p.cyl(0, 1.0, 0, 0.48, 1.002, 0.48, scale_col(OAK, 1.08), n=20)  # worn ring on the top


def _chair(m, name, seat_col, back_slats=True):
    p = m.part(name, ao=True)
    for (sx, sz) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        top = 1.2 if sz < 0 else 0.55
        p.cyl(sx * 0.27, 0.0, sz * 0.27, 0.035, top, 0.03, OAK_D, n=6)
    p.box(-0.32, 0.5, -0.32, 0.32, 0.58, 0.34, seat_col)
    for sx in (-1, 1):  # stretchers
        p.rod((sx * 0.27, 0.18, -0.27), (sx * 0.27, 0.18, 0.27), 0.018, OAK_D, n=4)
    p.rod((-0.27, 0.22, 0.27), (0.27, 0.22, 0.27), 0.018, OAK_D, n=4)
    p.box(-0.3, 1.05, -0.31, 0.3, 1.2, -0.23, OAK)  # top rail
    if back_slats:
        for k in range(5):
            x = -0.2 + k * 0.1
            p.cyl(x, 0.58, -0.27, 0.014, 1.05, 0.014, OAK_L, n=4)
    else:  # upholstered back
        p.box(-0.27, 0.62, -0.3, 0.27, 1.05, -0.22, seat_col)
        for x in (-0.15, 0.0, 0.15):
            p.ball(x, 0.85, -0.215, 0.018, BRASS, n=4, rings=3)


OAK_L = hexc("#b07a48")


def _stool(m):
    p = m.part("stool", ao=True)
    for k in range(4):
        a = k * math.tau / 4 + math.pi / 4
        p.rod((math.cos(a) * 0.25, 0.0, math.sin(a) * 0.25), (math.cos(a) * 0.15, 0.42, math.sin(a) * 0.15), 0.025, OAK_D, n=5)
    p.cyl(0, 0.16, 0, 0.21, 0.19, 0.21, BRASS, n=10, caps=False)  # foot ring
    p.cyl(0, 0.42, 0, 0.27, 0.45, 0.28, OAK_D, n=12)
    p.cyl(0, 0.45, 0, 0.29, 0.48, 0.27, VELVET, n=12)


def _settee(m):
    p = m.part("settee", ao=True)  # 3.9 wide, seat 0.6, back 1.5 at -z
    W, D = 1.95, 0.8
    p.box(-W + 0.2, 0.18, -D, W - 0.2, 0.42, D - 0.1, OAK_D)
    for k in range(3):  # seat cushions
        x0 = -W + 0.25 + k * (2 * W - 0.5) / 3
        p.box(x0 + 0.02, 0.42, -D + 0.25, x0 + (2 * W - 0.5) / 3 - 0.02, 0.62, D - 0.1, jitter(VELVET, p.rng, 0.04))
    p.box(-W + 0.2, 0.42, -D, W - 0.2, 1.4, -D + 0.25, VELVET, sub=0.6)
    for k in range(7):  # buttoned back
        p.ball(-W + 0.6 + k * (2 * W - 1.2) / 6, 1.0, -D + 0.255, 0.03, BRASS, n=4, rings=3)
    n = 8  # carved crest along the top
    for k in range(n):
        x0, x1 = -W + 0.2 + k * (2 * W - 0.4) / n, -W + 0.2 + (k + 1) * (2 * W - 0.4) / n
        y0 = 1.4 + math.sin(math.pi * k / n) * 0.18
        y1 = 1.4 + math.sin(math.pi * (k + 1) / n) * 0.18
        p.face([p.P(x0, 1.38, -D + 0.26), p.P(x1, 1.38, -D + 0.26), p.P(x1, y1, -D + 0.26), p.P(x0, y0, -D + 0.26)], OAK)
        p.face([p.P(x1, 1.38, -D - 0.01), p.P(x0, 1.38, -D - 0.01), p.P(x0, y0, -D - 0.01), p.P(x1, y1, -D - 0.01)], OAK)
        p.face([p.P(x0, y0, -D - 0.01), p.P(x0, y0, -D + 0.26), p.P(x1, y1, -D + 0.26), p.P(x1, y1, -D - 0.01)], OAK)
    for sx in (-1, 1):  # rolled arms + turned legs
        x0, x1 = (W - 0.22, W) if sx > 0 else (-W, -W + 0.22)
        p.box(x0, 0.42, -D, x1, 0.82, D - 0.1, VELVET)
        p.push(sx * (W - 0.11), 0.86, -D, pitch=90)
        p.cyl(0, 0.0, 0, 0.13, 1.7, 0.13, VELVET, n=10)
        p.pop()
        for sz in (-1, 1):
            p.cyl(sx * (W - 0.15), 0.0, sz * (D - 0.2), 0.05, 0.18, 0.07, OAK_D, n=6)


def _lamp(m):
    p = m.part("lamp", ao=False)
    lathe(p, [(0.0, 0.32, BRASS), (0.05, 0.3, BRASS), (0.1, 0.12, BRASS), (2.4, 0.04, BRASS), (2.45, 0.08, BRASS), (2.5, 0.0, BRASS)], n=10)
    shade = hexc("#e8c98a")
    p.cyl(0, 2.4, 0, 0.55, 2.95, 0.3, shade, n=12, caps=False, glow=0.5)
    p.cyl(0, 2.95, 0, 0.3, 2.97, 0.0, scale_col(shade, 0.8), n=12)
    for k in range(24):  # fringe
        a = k * math.tau / 24
        p.box(math.cos(a) * 0.55 - 0.012, 2.28, math.sin(a) * 0.55 - 0.012, math.cos(a) * 0.55 + 0.012, 2.42, math.sin(a) * 0.55 + 0.012, VELVET)
    p.ball(0, 2.55, 0, 0.1, hexc("#fff1b8"), n=6, rings=4, glow=1.0)


def furn(out):
    m = LM("furn", 901)
    m.box(0, 0, 0, 0.01, 0.01, 0.01, INK)
    _table(m)
    _chair(m, "chair", OAK)
    _chair(m, "armchair", GREEN, back_slats=False)
    _stool(m)
    _settee(m)
    _lamp(m)
    m.finish(out)


ALL = ["furn"]
