"""Lobby pieces that were still plain boxes and cylinders in code.

Colliders stay in code; these only change the look and are placed at the same
anchors. Most are DYN parts of `street_bits`, which the game drops into the world
Batch (static) or onto the node it animates (pad tops, the Vault door, the flag).

  street_bits   parts: sign post/cap/plank/bracket, lamp + lamp_glass, chest, coins,
                pad_base/pad_top, landing/landing_top, rope, stake, foam, bubbles,
                pallet, bigbox, vault_door, flag, trophy, sweeper, plate_top, hook,
                pole, umbrella0..3, lounger, flame
  wheel_stand   trestle behind the Big Wheel (no collider, as before)
  start_btn     pedestal (collider in code) + DYN_button
  square_disc   paving under the wheel, r 11.2, top 15 cm
  trampoline    wagon-wheel trampoline (collider in code: cylinder r 2.2, h 0.5)
  summit        Slide Hill summit deck + flagpole (colliders in code)
  y_gate        Chaos Yard entrance arch (column colliders here)
"""
import math

from arenas import poly_slab, polar_slab
from lm import LM, hexc, jitter, mix, scale_col
from sets import IRON, RED, RED_D, STEEL, STEEL_D, WHITE, YEL, bolts, hazard_band, lathe, sphere
from town import BRASS, CREAM, INK, WOOD, WOOD_D, WOOD_L

GOLD = hexc("#ffc935")
PINK = hexc("#ff5fa2")
BLUE = hexc("#3ec1ff")
SIGN_WOOD = hexc("#8f5a35")


def _sign_parts(m):
    p = m.part("post", ao=False)  # unit height, scaled by the game
    c = hexc("#a8703c")
    p.cyl(0, 0.0, 0, 0.095, 1.0, 0.09, c, n=8)
    p.cyl(0, 0.0, 0, 0.1, 0.07, 0.1, scale_col(c, 0.6), n=8, caps=False)
    for k in range(3):  # grain streaks
        a = k * 2.1
        p.box(math.cos(a) * 0.088 - 0.01, 0.15 + k * 0.2, math.sin(a) * 0.088 - 0.01, math.cos(a) * 0.088 + 0.01, 0.75 + k * 0.08, math.sin(a) * 0.088 + 0.01, scale_col(c, 0.75))
    p = m.part("cap", ao=False)
    p.box(-0.12, 0.0, -0.12, 0.12, 0.06, 0.12, scale_col(c, 0.8))
    p.cyl(0, 0.06, 0, 0.15, 0.22, 0.0, scale_col(c, 0.9), n=4)
    p = m.part("plank", ao=False)  # 1 m long (x), 0.3 tall, 0.12 thick; scaled in x and y
    p.box(-0.5, -0.15, -0.06, 0.5, 0.15, 0.06, SIGN_WOOD)
    for sz in (-1, 1):  # chamfered edges and a little grain on both faces
        z = sz * 0.0605
        for (y0, y1, k) in ((-0.15, -0.13, 0.62), (0.13, 0.15, 0.62), (-0.06, -0.055, 0.82), (0.07, 0.074, 0.85)):
            p.face([p.P(-0.5, y0, z), p.P(0.5, y0, z), p.P(0.5, y1, z), p.P(-0.5, y1, z)][::(1 if sz > 0 else -1)], scale_col(SIGN_WOOD, k))
    p = m.part("bracket", ao=False)
    for sz in (-1, 1):
        p.box(-0.16, -0.035, sz * 0.064 - 0.006, 0.0, 0.035, sz * 0.064 + 0.006, IRON)
        p.ball(-0.12, 0.0, sz * 0.072, 0.018, STEEL, n=4, rings=3)


def _lamp_parts(m):
    p = m.part("lamp", ao=True)
    iron, iron_d = hexc("#3d3550"), hexc("#2a2436")
    lathe(p, [(0.0, 0.26, iron_d), (0.12, 0.24, iron), (0.2, 0.16, iron), (0.5, 0.12, iron), (0.55, 0.1, iron), (3.3, 0.075, iron),
              (3.34, 0.12, iron_d), (3.42, 0.12, iron_d), (3.48, 0.2, iron), (3.52, 0.0, iron)], n=8)
    for y in (1.2, 2.4):
        p.cyl(0, y, 0, 0.11, y + 0.06, 0.11, iron_d, n=8)
    for k in range(4):  # scroll brackets under the lantern
        a = k * math.tau / 4 + math.pi / 4
        p.rod((0, 2.95, 0), (math.cos(a) * 0.2, 3.45, math.sin(a) * 0.2), 0.022, iron, n=4)
    for (sx, sz) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):  # lantern frame
        p.box(sx * 0.2 - 0.02, 3.52, sz * 0.2 - 0.02, sx * 0.2 + 0.02, 4.0, sz * 0.2 + 0.02, iron)
    p.box(-0.24, 3.98, -0.24, 0.24, 4.04, 0.24, iron_d)
    p.cyl(0, 4.04, 0, 0.3, 4.24, 0.05, iron, n=4)
    p.ball(0, 4.3, 0, 0.06, iron_d, n=5, rings=3)
    p = m.part("lamp_glass", ao=False)  # white + glow: the game tints it per lamp
    p.box(-0.18, 3.54, -0.18, 0.18, 3.97, 0.18, (0.85, 0.85, 0.85), glow=0.55)
    p.cyl(0, 3.6, 0, 0.05, 3.8, 0.02, (1.0, 1.0, 1.0), n=5, glow=0.9)


def _chest_parts(m):
    p = m.part("chest", ao=True)  # collider 1.2 x 0.7 x 0.8, lock on -z
    wd, band = hexc("#a0612f"), hexc("#4a4048")
    for k in range(4):  # planked body
        y0 = 0.02 + k * 0.17
        p.box(-0.6, y0, -0.4, 0.6, y0 + 0.165, 0.4, jitter(wd, p.rng, 0.06))
    p.box(-0.58, 0.0, -0.38, 0.58, 0.04, 0.38, scale_col(wd, 0.6))
    n = 8  # curved lid
    for k in range(n):
        a0, a1 = math.pi * k / n, math.pi * (k + 1) / n
        q = lambda a, x: p.P(x, 0.7 + math.sin(a) * 0.3, -math.cos(a) * 0.42)
        c = jitter(hexc("#7a4520"), p.rng, 0.05)
        p.face([q(a0, -0.62), q(a1, -0.62), q(a1, 0.62), q(a0, 0.62)], c)
    for sx in (-1, 1):
        pts = [(math.cos(math.pi * k / n) * -0.42, 0.7 + math.sin(math.pi * k / n) * 0.3) for k in range(n + 1)]
        p.face([p.P(sx * 0.62, y, z) for (z, y) in pts][::(1 if sx > 0 else -1)], scale_col(hexc("#7a4520"), 0.8))
    for x in (-0.45, 0.0, 0.45):  # iron bands over body and lid
        p.box(x - 0.05, 0.0, -0.415, x + 0.05, 0.7, -0.4, band)
        p.box(x - 0.05, 0.0, 0.4, x + 0.05, 0.7, 0.415, band)
        for k in range(n):
            a0, a1 = math.pi * k / n, math.pi * (k + 1) / n
            q = lambda a, xx: p.P(xx, 0.7 + math.sin(a) * 0.315, -math.cos(a) * 0.435)
            p.face([q(a0, x - 0.05), q(a1, x - 0.05), q(a1, x + 0.05), q(a0, x + 0.05)], band)
    p.box(-0.11, 0.5, -0.46, 0.11, 0.76, -0.41, GOLD, glow=0.4)  # lock plate
    p.box(-0.025, 0.56, -0.47, 0.025, 0.66, -0.46, INK)
    p = m.part("coins", ao=False)
    for i in range(14):
        a = p.rng.uniform(0, math.tau)
        r = p.rng.uniform(0.0, 0.45)
        x, z = math.cos(a) * r * 1.2, math.sin(a) * r * 0.5
        y = 1.0 + (0.45 - r) * 0.12 + i * 0.004
        p.push(x, y, z, pitch=p.rng.uniform(-30, 30), roll=p.rng.uniform(-30, 30))
        p.cyl(0, -0.02, 0, 0.12, 0.02, 0.12, GOLD, n=8, glow=0.6)
        p.pop()


def _pad_parts(m):
    p = m.part("pad_base", ao=True)  # r 1.3 housing, 0.22 tall
    p.cyl(0, 0.0, 0, 1.32, 0.18, 1.24, hexc("#3a3a48"), n=16)
    for i in range(16):
        a0, a1 = i * math.tau / 16, (i + 1) * math.tau / 16
        q = lambda a, r: p.P(math.cos(a) * r, 0.181, math.sin(a) * r)
        p.face([q(a0, 1.02), q(a1, 1.02), q(a1, 1.24), q(a0, 1.24)], YEL if i % 2 else INK)
    for k in range(8):
        a = k * math.tau / 8
        p.ball(math.cos(a) * 1.13, 0.19, math.sin(a) * 1.13, 0.035, STEEL, n=4, rings=3)
    for k in range(6):  # springs peeking out
        a = k * math.tau / 6 + 0.3
        x, z = math.cos(a) * 0.9, math.sin(a) * 0.9
        for j in range(3):
            p.cyl(x, 0.05 + j * 0.055, z, 0.07, 0.08 + j * 0.055, 0.07, STEEL, n=6, caps=False)
    p = m.part("pad_top", ao=False)  # r 1.0, 0.08 thick, centred: the game squashes it
    p.cyl(0, -0.04, 0, 1.0, 0.04, 1.0, PINK, n=16, glow=0.3)
    p.cyl(0, 0.04, 0, 0.82, 0.045, 0.82, hexc("#ff86bd"), n=16, glow=0.35)
    for k in range(5):  # a star, so you know it does something
        a0 = k * math.tau / 5 - math.pi / 2
        pts = [(0, 0), (math.cos(a0 - 0.3) * 0.22, math.sin(a0 - 0.3) * 0.22), (math.cos(a0) * 0.6, math.sin(a0) * 0.6), (math.cos(a0 + 0.3) * 0.22, math.sin(a0 + 0.3) * 0.22)]
        p.face([p.P(x, 0.05, z) for (x, z) in pts][::-1], WHITE, glow=0.4)
    p = m.part("landing", ao=True)  # inflatable target r 7.4, 0.5 tall (membrane is landing_top)
    p.cyl(0, 0.0, 0, 7.4, 0.35, 7.25, hexc("#c0392b"), n=32, caps=False)
    n = 24
    for i in range(n):  # red/white air tube round the rim
        a0, a1 = i * math.tau / n, (i + 1) * math.tau / n
        p.rod((math.cos(a0) * 7.0, 0.42, math.sin(a0) * 7.0), (math.cos(a1) * 7.0, 0.42, math.sin(a1) * 7.0), 0.38, RED if i % 2 else WHITE, n=8, caps=False)
    for k in range(8):  # pegs and guy ropes
        a = k * math.tau / 8 + 0.2
        p.cyl(math.cos(a) * 8.6, 0.0, math.sin(a) * 8.6, 0.06, 0.35, 0.04, WOOD_D, n=5)
        p.rod((math.cos(a) * 8.6, 0.3, math.sin(a) * 8.6), (math.cos(a) * 7.2, 0.6, math.sin(a) * 7.2), 0.02, hexc("#e8dcc0"), n=4)
    p = m.part("landing_top", ao=False)  # bullseye membrane, centred at y 0 (placed 0.5 up)
    for (r0, r1, c) in ((0.0, 1.6, GOLD), (1.6, 3.4, RED), (3.4, 5.2, WHITE), (5.2, 6.75, RED)):
        for i in range(32):
            a0, a1 = i * math.tau / 32, (i + 1) * math.tau / 32
            q = lambda a, r: p.P(math.cos(a) * r, 0.03, math.sin(a) * r)
            if r0 < 0.01:
                p.face([q(a0, 0.0), q(a1, r1), q(a0, r1)], c, glow=0.15)
            else:
                p.face([q(a0, r0), q(a1, r0), q(a1, r1), q(a0, r1)], jitter(c, p.rng, 0.03), glow=0.15)
    p.cyl(0, -0.03, 0, 6.75, 0.03, 6.75, scale_col(RED, 0.8), n=32, caps=False)


def _yard_parts(m):
    p = m.part("rope", ao=False)  # 1 m along +z, scaled
    p.rod((0, 0, 0), (0, 0, 1.0), 0.035, hexc("#d9c08a"), n=5, caps=False)
    p = m.part("stake", ao=False)  # bridge stake, 1 m, rope lashing near the deck
    p.cyl(0, 0.0, 0, 0.06, 0.95, 0.05, hexc("#8a5a32"), n=6)
    p.cyl(0, 0.95, 0, 0.05, 1.05, 0.0, hexc("#8a5a32"), n=6)
    for k in range(3):
        p.cyl(0, 0.05 + k * 0.05, 0, 0.068, 0.09 + k * 0.05, 0.068, hexc("#d9c08a"), n=6, caps=False)
    p = m.part("foam", ao=False)  # pink goo froth, ~1.6 m across
    for i in range(9):
        a = p.rng.uniform(0, math.tau)
        r = p.rng.uniform(0.0, 0.6)
        p.ball(math.cos(a) * r, 0.0, math.sin(a) * r, p.rng.uniform(0.14, 0.34), mix(hexc("#ffc2e4"), hexc("#ff8fcb"), p.rng.random()), n=6, rings=3, sy=0.45)
    p = m.part("bubbles", ao=False)
    for i in range(4):
        a = p.rng.uniform(0, math.tau)
        r = p.rng.uniform(0.0, 0.8)
        p.ball(math.cos(a) * r, 0.0, math.sin(a) * r, p.rng.uniform(0.15, 0.45), hexc("#ffb8e4"), n=8, rings=4, sy=0.7, glow=0.3)
    p = m.part("pallet", ao=True)  # 1.8 x 0.27 x 1.8, weathered pine
    pine = hexc("#c9a06a")
    for k in range(7):
        z = -0.9 + k * 0.3
        p.box(-0.9, 0.21, z, 0.9, 0.27, z + 0.22, jitter(pine, p.rng, 0.1))
    for x in (-0.82, 0.0, 0.82):
        p.box(x - 0.08, 0.06, -0.9, x + 0.08, 0.21, 0.9, jitter(scale_col(pine, 0.8), p.rng, 0.05))
    for k in range(3):
        z = -0.9 + k * 0.8
        p.box(-0.9, 0.0, z, 0.9, 0.06, z + 0.2, jitter(pine, p.rng, 0.1))
    p = m.part("bigbox", ao=True)  # 0.4 x 0.4 x 0.8 tool crate, stencilled
    olive = hexc("#5f6b3a")
    p.box(-0.2, 0.0, -0.4, 0.2, 0.36, 0.4, olive)
    p.box(-0.21, 0.36, -0.41, 0.21, 0.4, 0.41, scale_col(olive, 0.8))
    for sz in (-1, 1):
        p.box(-0.21, 0.08, sz * 0.4 - 0.01, 0.21, 0.3, sz * 0.4 + 0.01, scale_col(olive, 0.7))
        p.box(-0.08, 0.38, sz * 0.25 - 0.03, 0.08, 0.44, sz * 0.25 + 0.03, STEEL_D)  # handles
    p.box(0.201, 0.12, -0.25, 0.205, 0.26, 0.25, hexc("#e8dcb0"))
    p = m.part("hook", ao=True)  # crane block + hook, centred like the old 0.8 box
    p.box(-0.4, -0.3, -0.3, 0.4, 0.3, 0.3, YEL)
    hazard_band(p, -0.4, 0.4, -0.3, -0.12, 0.3, step=0.16)
    for sx in (-1, 1):
        p.cyl(sx * 0.4, 0.0, 0, 0.22, 0.04, 0.22, STEEL_D, n=8)
    p.cyl(0, -0.55, 0, 0.06, -0.3, 0.06, STEEL, n=6)
    for k in range(7):  # the hook itself
        a0, a1 = math.pi * 0.1 + k * math.pi * 1.2 / 7, math.pi * 0.1 + (k + 1) * math.pi * 1.2 / 7
        p.rod((math.cos(a0) * 0.22, -0.8 + math.sin(a0) * -0.22, 0), (math.cos(a1) * 0.22, -0.8 + math.sin(a1) * -0.22, 0), 0.05, STEEL, n=6)


def _misc_parts(m):
    p = m.part("vault_door", ao=True)  # slab 3 x 4 x 0.4, round door on -z
    st, st_d = hexc("#8d96a6"), hexc("#5d6470")
    p.box(-1.5, -2.0, -0.2, 1.5, 2.0, 0.2, st_d, sub=0.8)
    p.push(0, 0.1, -0.2, pitch=-90)
    lathe(p, [(0.0, 1.6, scale_col(GOLD, 0.75)), (0.18, 1.6, GOLD), (0.22, 1.5, GOLD), (0.3, 1.15, scale_col(GOLD, 0.85)), (0.34, 0.0, scale_col(GOLD, 0.85))], n=24)
    for k in range(12):  # locking bolts round the rim
        a = k * math.tau / 12
        p.cyl(math.cos(a) * 1.38, 0.2, math.sin(a) * 1.38, 0.07, 0.3, 0.07, STEEL, n=6)
    p.cyl(0, 0.34, 0, 0.32, 0.5, 0.28, STEEL, n=10)
    p.pop()
    for k in range(3):  # spoked handle wheel
        a = k * math.pi / 3
        p.rod((math.cos(a) * -0.95, 0.1 + math.sin(a) * -0.95, -0.66), (math.cos(a) * 0.95, 0.1 + math.sin(a) * 0.95, -0.66), 0.06, STEEL, n=6)
    for k in range(6):
        a = k * math.tau / 6
        p.ball(math.cos(a) * 0.95, 0.1 + math.sin(a) * 0.95, -0.66, 0.1, STEEL_D, n=6, rings=4)
    for sy in (-1, 1):  # hinges
        p.cyl(1.55, sy * 1.2 - 0.3, -0.25, 0.12, sy * 1.2 + 0.3, 0.12, st, n=8)
    p.box(-1.1, 1.55, -0.24, 1.1, 1.85, -0.2, BRASS)
    p.text("FIRST BANK OF SLOP", 0, 1.62, -0.24, 0.15, INK, font="Bungee-Regular", depth=0.02, res=1, yaw=180)

    p = m.part("flag", ao=False)  # cloth runs +x from the pole, 2.6 x 1.6
    for k in range(6):
        x0, x1 = k * 2.6 / 6, (k + 1) * 2.6 / 6
        z0, z1 = math.sin(k * 1.1) * 0.12, math.sin((k + 1) * 1.1) * 0.12
        for sz, c in ((0.03, PINK), (-0.03, scale_col(PINK, 0.85))):
            q = [p.P(x0, -0.8, z0 + sz), p.P(x1, -0.8, z1 + sz), p.P(x1, 0.8, z1 + sz), p.P(x0, 0.8, z0 + sz)]
            p.face(q if sz > 0 else q[::-1], c)
    for sz in (0.045, -0.045):  # a duck, both sides
        sg = 1 if sz > 0 else -1
        p.push(1.3, 0.0, math.sin(3 * 1.1) * 0.12 + sz)
        pts = [(math.cos(a) * 0.36, math.sin(a) * 0.28 - 0.1) for a in [k * math.tau / 10 for k in range(10)]]
        p.face([p.P(x, y, 0) for (x, y) in pts][::sg], YEL, glow=0.3)
        pts = [(0.18 + math.cos(a) * 0.18, 0.22 + math.sin(a) * 0.18) for a in [k * math.tau / 8 for k in range(8)]]
        p.face([p.P(x, y, 0.002 * sg) for (x, y) in pts][::sg], YEL, glow=0.3)
        p.face([p.P(x, y, 0.004 * sg) for (x, y) in ((0.34, 0.2), (0.52, 0.16), (0.34, 0.12))][::-sg], hexc("#ff8a3d"))
        p.pop()

    p = m.part("trophy", ao=False)  # origin at the node: base 0..0.08, bowl to 1.1
    lathe(p, [(0.0, 0.32, hexc("#3a2a20")), (0.12, 0.3, hexc("#3a2a20")), (0.14, 0.2, GOLD), (0.22, 0.08, GOLD), (0.5, 0.07, GOLD), (0.58, 0.14, GOLD),
              (0.7, 0.32, GOLD), (0.95, 0.46, GOLD), (1.1, 0.48, GOLD), (1.1, 0.42, scale_col(GOLD, 0.7)), (0.75, 0.0, scale_col(GOLD, 0.7))], n=14, glow=0.5)
    for sx in (-1, 1):
        for k in range(5):
            a0, a1 = -math.pi / 2 + k * math.pi / 5, -math.pi / 2 + (k + 1) * math.pi / 5
            p.rod((sx * (0.46 + math.cos(a0) * 0.18), 0.88 + math.sin(a0) * 0.16, 0), (sx * (0.46 + math.cos(a1) * 0.18), 0.88 + math.sin(a1) * 0.16, 0), 0.035, GOLD, n=5, glow=0.5)

    p = m.part("sweeper", ao=True)  # hub r 0.5 x 1.5 tall, arm 9.6 x 0.5 x 0.5, centred
    p.cyl(0, -0.75, 0, 0.5, 0.75, 0.4, INK, n=10)
    p.cyl(0, 0.75, 0, 0.42, 0.85, 0.3, STEEL_D, n=10)
    for k in range(12):
        x0, x1 = -4.0 + k * 8.0 / 12, -4.0 + (k + 1) * 8.0 / 12
        p.box(x0, -0.24, -0.24, x1, 0.24, 0.24, RED if k % 2 else WHITE)
    for sx in (-1, 1):
        p.box(sx * 4.0 - (0.0 if sx > 0 else 0.8), -0.27, -0.27, sx * 4.0 + (0.8 if sx > 0 else 0.0), 0.27, 0.27, hexc("#f4f1ea"))
        p.box(sx * 4.75 - 0.06, -0.29, -0.29, sx * 4.75 + 0.06, 0.29, 0.29, hexc("#3a3a48"))
    p = m.part("plate_top", ao=False)  # r 1.4, 0.12 thick, centred
    p.cyl(0, -0.06, 0, 1.4, 0.06, 1.4, hexc("#c0392b"), n=18, glow=0.4)
    for k in range(5):
        x = -0.8 + k * 0.4
        p.box(x - 0.08, 0.06, -0.9, x + 0.08, 0.075, 0.9, hexc("#e8574a"), glow=0.5)
    for i in range(18):
        a0, a1 = i * math.tau / 18, (i + 1) * math.tau / 18
        q = lambda a, r: p.P(math.cos(a) * r, 0.062, math.sin(a) * r)
        p.face([q(a0, 1.18), q(a1, 1.18), q(a1, 1.38), q(a0, 1.38)], YEL if i % 2 else INK)

    p = m.part("pole", ao=False)  # carnival pole r 0.14, 7 m, gold finial
    for k in range(14):
        y0, y1 = k * 0.5, (k + 1) * 0.5
        r0, r1 = 0.14 - k * 0.003, 0.14 - (k + 1) * 0.003
        p.cyl(0, y0, 0, r0, y1, r1, RED if k % 2 else WHITE, n=8, caps=False)
    p.cyl(0, 0.0, 0, 0.26, 0.3, 0.2, hexc("#3a3a48"), n=8)
    p.ball(0, 7.0, 0, 0.16, GOLD, n=8, rings=4, glow=0.4)
    p.cyl(0, 7.05, 0, 0.3, 7.55, 0.0, GOLD, n=8, glow=0.3)
    cols = [hexc("#ee4b4b"), BLUE, GOLD, PINK]
    for v in range(4):
        p = m.part("umbrella%d" % v, ao=False)
        p.cyl(0, 0.0, 0, 0.05, 3.3, 0.05, WHITE, n=6)
        p.cyl(0, 0.0, 0, 0.18, 0.12, 0.2, hexc("#d9c8a0"), n=8)
        n = 12
        for i in range(n):  # panels, alternating with white
            a0, a1 = i * math.tau / n, (i + 1) * math.tau / n
            c = cols[v] if i % 2 == 0 else WHITE
            p.face([p.P(0, 3.62, 0), p.P(math.cos(a1) * 2.15, 2.86, math.sin(a1) * 2.15), p.P(math.cos(a0) * 2.15, 2.86, math.sin(a0) * 2.15)], c)
            p.face([p.P(0, 3.5, 0), p.P(math.cos(a0) * 2.1, 2.8, math.sin(a0) * 2.1), p.P(math.cos(a1) * 2.1, 2.8, math.sin(a1) * 2.1)], scale_col(c, 0.75))
            am = (a0 + a1) * 0.5  # scalloped valance
            tri = [p.P(math.cos(a0) * 2.15, 2.86, math.sin(a0) * 2.15), p.P(math.cos(a1) * 2.15, 2.86, math.sin(a1) * 2.15), p.P(math.cos(am) * 2.17, 2.62, math.sin(am) * 2.17)]
            p.face(tri, c)
            p.face(tri[::-1], scale_col(c, 0.8))
        p.ball(0, 3.66, 0, 0.07, WHITE, n=5, rings=3)
    p = m.part("lounger", ao=True)  # 0.75 x 2.0 along z, back raised at -z
    tk = hexc("#c9965a")
    for sx in (-1, 1):
        p.box(sx * 0.36 - 0.04, 0.22, -1.0, sx * 0.36 + 0.04, 0.3, 1.0, scale_col(tk, 0.8))
        for z in (-0.9, 0.9):
            p.box(sx * 0.33 - 0.04, 0.0, z - 0.04, sx * 0.33 + 0.04, 0.22, z + 0.04, scale_col(tk, 0.7))
    for k in range(8):
        z = -0.25 + k * 0.155
        p.box(-0.34, 0.3, z, 0.34, 0.34, z + 0.12, jitter(tk, p.rng, 0.06))
    p.push(0, 0.3, -0.3, pitch=-55)
    for k in range(5):
        z = -0.75 + k * 0.155
        p.box(-0.34, 0.0, z, 0.34, 0.04, z + 0.12, jitter(tk, p.rng, 0.06))
    p.pop()
    p.box(-0.3, 0.34, -0.2, 0.3, 0.4, 0.95, hexc("#3ec1ff"))  # towel
    p.box(-0.3, 0.341, 0.2, 0.3, 0.401, 0.3, WHITE)
    p = m.part("flame", ao=False)  # campfire flames, centred on the old cone
    for (x, z, s, c) in ((0, 0, 1.0, hexc("#ff7a2a")), (0.18, 0.1, 0.7, hexc("#ff9a3a")), (-0.15, -0.12, 0.75, hexc("#ff8a2a")), (0.0, 0.0, 0.62, hexc("#ffe27a"))):
        p.cyl(x, -0.55, z, 0.42 * s, -0.55 + 1.1 * s, 0.0, c, n=6, glow=1.0)
    for k in range(5):
        a = k * math.tau / 5
        p.cyl(math.cos(a) * 0.3, -0.5, math.sin(a) * 0.3, 0.1, -0.05, 0.0, hexc("#ffb347"), n=4, glow=1.0)


def _ride_parts(m):
    """Coaster cars: origin at the seat frame the game moves (0.42 above the rail)."""
    cols = [hexc("#ee4b4b"), GOLD, BLUE]
    for i in range(3):
        p = m.part("car%d" % i, ao=True)
        c = cols[i]
        p.box(-0.95, -0.25, -1.35, 0.95, 0.35, 1.35, c)  # tub
        for (x0, z0, x1, z1) in ((-1.0, -1.4, -0.8, 1.4), (0.8, -1.4, 1.0, 1.4), (-0.8, -1.4, 0.8, -0.8), (-0.8, 1.0, 0.8, 1.4)):
            p.box(x0, 0.3, z0, x1, 0.45, z1, scale_col(c, 0.8))  # rolled rim
        p.box(-0.8, 0.35, -0.8, 0.8, 0.36, 1.0, INK, faces="Y")  # seat well floor
        p.box(-0.75, 0.36, -0.7, 0.75, 0.5, 0.9, hexc("#3a3a48"))  # cushion
        p.box(-0.85, 0.45, 0.95, 0.85, 0.95, 1.25, WHITE)  # backrest
        p.box(-0.8, 0.95, 0.98, 0.8, 1.0, 1.22, scale_col(WHITE, 0.85))
        p.rod((-0.75, 0.55, -0.55), (0.75, 0.55, -0.55), 0.04, STEEL, n=6)  # lap bar
        for sx in (-1, 1):
            p.rod((sx * 0.75, 0.3, -0.55), (sx * 0.75, 0.55, -0.55), 0.04, STEEL, n=6)
            for z in (-0.95, 0.95):  # wheels under the tub
                p.push(sx * 0.62, -0.32, z, roll=90)
                p.cyl(0, -0.08, 0, 0.13, 0.08, 0.13, hexc("#2a2a32"), n=8)
                p.pop()
        p.box(-0.95, -0.12, -1.38, 0.95, 0.02, -1.35, WHITE)  # stripe
        p.box(-0.95, -0.12, 1.35, 0.95, 0.02, 1.38, WHITE)
        if i == 0:  # the lead car is a duck, obviously
            p.ball(0, 0.85, -1.25, 0.5, YEL, n=10, rings=6)
            p.box(-0.16, 0.74, -1.95, 0.16, 0.86, -1.6, hexc("#ff8a3d"))
            for sx in (-1, 1):
                p.ball(sx * 0.2, 1.0, -1.66, 0.07, INK, n=6, rings=4)
        else:  # couplers and a headlight
            p.box(-0.08, -0.1, -1.6, 0.08, 0.04, -1.35, STEEL_D)
            p.ball(0, 0.18, -1.38, 0.1, hexc("#ffe27a"), n=6, rings=4, glow=0.8)


def c_station(out):
    """Coaster station: deck top at 0 (collider 26 x 0.4 x 6 in code), posts at
    x -12/0/12, z +-2.4 (colliders in code), canopy at 5.1, front (+z) toward the queue."""
    m = LM("c_station", 871)
    deck = hexc("#a8703c")
    for k in range(13):
        z = -3.0 + k * 0.46
        m.box(-13.0, -0.4, z, 13.0, 0.0, z + 0.43, jitter(deck, m.rng, 0.07), sub=2.5, faces="yYzZ" if k in (0, 12) else "yY")
    m.box(-13.05, -0.4, -3.0, -13.0, 0.0, 3.0, scale_col(deck, 0.7))
    m.box(13.0, -0.4, -3.0, 13.05, 0.0, 3.0, scale_col(deck, 0.7))
    for k in range(26):  # yellow edge line along the track side
        x = -13.0 + k
        m.box(x, 0.0, -3.0, x + 0.5, 0.012, -2.8, YEL, faces="Y")
    for x in (-12.0, 0.0, 12.0):
        for z in (-2.4, 2.4):
            m.cyl(x, 0.0, z, 0.2, 5.0, 0.17, hexc("#b5402f"), n=8)
            m.cyl(x, 0.0, z, 0.28, 0.25, 0.26, IRON, n=8)
            m.cyl(x, 4.8, z, 0.22, 4.95, 0.22, GOLD, n=8, glow=0.2)
    n = 26  # striped awning, scalloped front and back
    for k in range(n):
        x0, x1 = -13.0 + k, -12.0 + k
        c = hexc("#ee4b4b") if k % 2 == 0 else hexc("#fff3dc")
        for (za, zb, ya, yb) in ((-3.3, 0.0, 5.0, 5.7), (0.0, 3.3, 5.7, 5.0)):
            q = [m.P(x0, ya, za), m.P(x1, ya, za), m.P(x1, yb, zb), m.P(x0, yb, zb)]
            m.face(q[::-1], c)
            m.face([m.P(x, y - 0.12, z) for (x, y, z) in ((x0, ya, za), (x1, ya, za), (x1, yb, zb), (x0, yb, zb))], scale_col(c, 0.6))
        for (z, sg) in ((3.3, 1), (-3.3, -1)):
            tri = [m.P(x0, 5.0, z), m.P(x1, 5.0, z), m.P((x0 + x1) * 0.5, 4.72, z + 0.02 * sg)]
            m.face(tri if sg > 0 else tri[::-1], c)
            m.face(tri[::-1] if sg > 0 else tri, scale_col(c, 0.7))
    m.bulbs((-12.8, 4.9, 3.25), (12.8, 4.9, 3.25), 26, 0.06, hexc("#ffe6a8"), glow=1.0)
    m.room(-13.0, 0.0, -3.0, 13.0, 5.0, 3.0, level=0.08)
    m.finish(out)


def wardrobe(out):
    """Hotel lobby wardrobe pieces as parts: paint bench (collider 1.8 x 0.5 x 1.8),
    hat stand (r 0.1, 2.8), body-swap booth (back 2.2 x 3.2 x 0.3), Hall of Fame board,
    VIP rope (authored along x)."""
    m = LM("wardrobe", 881)
    m.box(0, 0, 0, 0.01, 0.01, 0.01, INK)
    p = m.part("paint", ao=True)  # origin at PAINT (bench centred at z +0.1)
    p.box(-0.9, 0.0, -0.8, 0.9, 0.46, 1.0, hexc("#8a5a32"))
    p.box(-0.95, 0.46, -0.85, 0.95, 0.5, 1.05, hexc("#a8703c"))
    swatch = [hexc("#ff5fa2"), hexc("#3ec1ff"), hexc("#7ccf4e"), hexc("#ffd23f")]
    for i in range(4):
        x, z = -0.42 + (i % 2) * 0.84, -0.32 + (i // 2) * 0.84
        p.cyl(x, 0.5, z, 0.3, 1.1, 0.33, STEEL, n=12)
        p.cyl(x, 1.1, z, 0.33, 1.13, 0.33, scale_col(STEEL, 0.8), n=12)
        p.cyl(x, 1.06, z, 0.29, 1.1, 0.29, swatch[i], n=12, glow=0.15)
        for k in range(3):  # drips down the side
            a = k * 2.1 + i
            p.box(x + math.cos(a) * 0.31 - 0.04, 0.75 + k * 0.08, z + math.sin(a) * 0.31 - 0.04, x + math.cos(a) * 0.31 + 0.04, 1.11, z + math.sin(a) * 0.31 + 0.04, swatch[i])
    p.rod((0.6, 1.1, 0.75), (0.95, 1.75, 0.95), 0.03, WOOD_L, n=5)  # brush
    p.box(0.55, 1.0, 0.7, 0.68, 1.15, 0.82, hexc("#ff5fa2"))
    p = m.part("hats", ao=True)  # coat stand, origin at the floor
    p.cyl(0, 0.0, 0, 0.35, 0.08, 0.3, WOOD_D, n=10)
    for k in range(3):
        a = k * math.tau / 3
        p.rod((0, 0.25, 0), (math.cos(a) * 0.5, 0.0, math.sin(a) * 0.5), 0.04, WOOD_D, n=5)
    p.cyl(0, 0.08, 0, 0.09, 2.8, 0.07, WOOD, n=8)
    p.ball(0, 2.85, 0, 0.11, BRASS, n=8, rings=4)
    for i in range(6):
        a = i * math.tau / 6
        p.rod((math.cos(a) * 0.05, 2.0 + (i % 3) * 0.4, math.sin(a) * 0.05), (math.cos(a) * 0.32, 2.15 + (i % 3) * 0.4, math.sin(a) * 0.32), 0.025, BRASS, n=4)
    p = m.part("booth", ao=True)  # back panel at z -0.2, roof over z -0.3..1.3, open to +z
    vio, vio_d = hexc("#b388ff"), hexc("#7a52c9")
    p.box(-1.1, 0.0, -0.35, 1.1, 3.2, -0.05, vio, sub=0.8)
    for k in range(9):  # starry backdrop
        x, y = -0.8 + (k % 3) * 0.8, 0.9 + (k // 3) * 0.75
        p.box(x - 0.06, y - 0.06, -0.05, x + 0.06, y + 0.06, -0.03, hexc("#ffe27a"), glow=0.6)
    p.box(-1.2, 3.15, -0.3, 1.2, 3.45, 1.3, vio_d)
    p.box(-1.25, 3.05, 1.25, 1.25, 3.2, 1.35, GOLD, glow=0.2)
    for sx in (-1, 1):
        p.box(sx * 1.1 - 0.06, 0.0, -0.3, sx * 1.1 + 0.06, 3.15, 1.3, scale_col(vio_d, 0.8))
        for k in range(4):  # curtain pleats on the sides
            z = -0.1 + k * 0.32
            p.box(sx * 1.05 - 0.05, 0.1, z, sx * 1.05 + 0.05, 3.05, z + 0.26, hexc("#6a1a3a") if k % 2 else hexc("#8a2a50"))
    p.cyl(0, 0.0, 0.5, 0.55, 0.12, 0.55, GOLD, n=12, glow=0.2)  # swap pad
    p.cyl(0, 0.12, 0.5, 0.45, 0.14, 0.45, hexc("#ff5fa2"), n=12, glow=0.5)
    p = m.part("fame", ao=True)  # board 5 x 3, writing face at z -0.02, header plate above
    frame = hexc("#6e4429")
    p.box(-2.5, -1.5, -0.1, 2.5, 1.5, -0.03, hexc("#2e2a28"), sub=1.0)
    for (x0, y0, x1, y1) in ((-2.62, -1.62, 2.62, -1.5), (-2.62, 1.5, 2.62, 1.62), (-2.62, -1.5, -2.5, 1.5), (2.5, -1.5, 2.62, 1.5)):
        p.box(x0, y0, -0.12, x1, y1, -0.01, frame)
    p.box(-2.2, 1.6, -0.1, 2.2, 2.08, -0.03, frame)
    p.box(-2.1, 1.66, -0.03, 2.1, 2.02, -0.025, scale_col(frame, 0.75))
    for sx in (-1, 1):
        p.ball(sx * 2.56, 1.56, 0.0, 0.06, BRASS, n=6, rings=4)
        p.ball(sx * 2.56, -1.56, 0.0, 0.06, BRASS, n=6, rings=4)
    p = m.part("vip", ao=False)  # brass stanchions + velvet ropes along x, 4.4 wide
    for x in (-2.1, 0.0, 2.1):
        p.cyl(x, 0.0, 0, 0.2, 0.06, 0.18, BRASS, n=10, glow=0.15)
        p.cyl(x, 0.06, 0, 0.045, 1.0, 0.045, BRASS, n=8, glow=0.15)
        p.ball(x, 1.04, 0, 0.08, BRASS, n=8, rings=4, glow=0.2)
    for (xa, xb) in ((-2.1, 0.0), (0.0, 2.1)):
        for k in range(6):
            t0, t1 = k / 6, (k + 1) / 6
            sag = lambda t: 0.95 - math.sin(t * math.pi) * 0.25
            p.rod((xa + (xb - xa) * t0, sag(t0), 0), (xa + (xb - xa) * t1, sag(t1), 0), 0.045, hexc("#a3122c"), n=6)
    m.finish(out)


def street_bits(out):
    m = LM("street_bits", 801)
    m.box(0, 0, 0, 0.01, 0.01, 0.01, INK)
    _sign_parts(m)
    _lamp_parts(m)
    _chest_parts(m)
    _pad_parts(m)
    _yard_parts(m)
    _misc_parts(m)
    _ride_parts(m)
    m.finish(out)


def wheel_stand(out):
    """Trestle behind the Big Wheel (disc at y 6.2, z 0, r 4.75). Stays behind z -0.3."""
    m = LM("wheel_stand", 811)
    red, cream = hexc("#b8322c"), hexc("#f2e2bc")
    for sx in (-1, 1):  # splayed legs, gold-capped
        m.rod((sx * 2.25, 0.0, -0.65), (sx * 0.55, 6.05, -0.65), 0.26, red, n=8)
        for t in (0.25, 0.55):
            x = sx * (2.25 - 1.7 * t)
            m.cyl(x, 6.05 * t - 0.08, -0.65, 0.29, 6.05 * t + 0.08, 0.29, GOLD, n=8, glow=0.15)
        m.box(sx * 2.25 - 0.45, 0.0, -1.15, sx * 2.25 + 0.45, 0.14, -0.15, IRON)
        m.rod((sx * 2.0, 0.0, -2.6), (sx * 0.7, 5.6, -0.8), 0.13, scale_col(red, 0.8), n=6)  # back strut
        m.box(sx * 2.0 - 0.25, 0.0, -2.85, sx * 2.0 + 0.25, 0.1, -2.35, IRON)
    m.rod((-1.7, 2.0, -0.65), (1.7, 2.0, -0.65), 0.1, cream, n=6)
    m.rod((-1.25, 3.6, -0.7), (1.25, 3.6, -0.7), 0.09, cream, n=6)
    m.rod((-1.7, 2.0, -0.7), (1.0, 3.6, -0.75), 0.06, cream, n=6)
    m.rod((1.7, 2.0, -0.7), (-1.0, 3.6, -0.75), 0.06, cream, n=6)
    m.box(-0.75, 5.75, -1.05, 0.75, 6.65, -0.35, IRON)  # bearing housing
    m.push(0, 6.2, -0.35, pitch=-90)
    m.cyl(0, 0.0, 0, 0.32, 0.1, 0.32, BRASS, n=10)
    m.pop()
    bolts(m, [(-0.6, 5.85, -0.34), (0.6, 5.85, -0.34), (-0.6, 6.55, -0.34), (0.6, 6.55, -0.34)], STEEL, 0.05)
    m.box(-2.9, 0.0, -3.0, 2.9, 0.08, -0.3, hexc("#6e4429"))  # low deck behind
    for k in range(10):
        x = -2.9 + k * 0.58
        m.box(x, 0.08, -3.0, x + 0.54, 0.1, -0.3, jitter(WOOD, m.rng, 0.08))
    m.finish(out)


def start_btn(out):
    """Pedestal: collider cylinder r 1.4, h 1. DYN_button pivot at y 1.15."""
    m = LM("start_btn", 821)
    iron, iron_d = hexc("#4a4e69"), hexc("#34374c")
    m.cyl(0, 0.0, 0, 1.55, 0.18, 1.55, GOLD, n=16, glow=0.15)
    lathe(m, [(0.18, 1.4, iron_d), (0.3, 1.32, iron), (0.85, 1.32, iron), (0.92, 1.42, iron_d), (1.0, 1.42, iron_d), (1.0, 0.0, iron_d)], n=16)
    for y in (0.4, 0.75):
        m.cyl(0, y - 0.03, 0, 1.335, y + 0.03, 1.335, BRASS, n=16, caps=False)
    for i in range(16):
        a0, a1 = i * math.tau / 16, (i + 1) * math.tau / 16
        q = lambda a, r: m.P(math.cos(a) * r, 1.001, math.sin(a) * r)
        m.face([q(a0, 1.05), q(a1, 1.05), q(a1, 1.4), q(a0, 1.4)], YEL if i % 2 else INK)
    for k in range(4):  # rivets
        a = k * math.tau / 4 + math.pi / 4
        m.ball(math.cos(a) * 1.33, 0.57, math.sin(a) * 1.33, 0.05, STEEL, n=5, rings=3)
    p = m.part("button")
    p.origin = (0.0, 1.15, 0.0)
    lathe(p, [(-0.17, 1.0, hexc("#c62a36")), (0.08, 0.95, hexc("#e63946")), (0.14, 0.85, hexc("#ef5a63")), (0.18, 0.55, hexc("#f47a80")), (0.2, 0.0, hexc("#f47a80"))], n=18, glow=0.35)
    p.ball(-0.35, 0.16, -0.3, 0.12, hexc("#ffd4d6"), n=6, rings=3, sy=0.3, glow=0.5)
    m.finish(out)


def square_disc(out):
    """Paving under the Big Wheel, centred on (0, 0, -1.5). Tops 12-15 cm, as before."""
    m = LM("square_disc", 831)
    stone, cream, brick = hexc("#b8ad9f"), hexc("#d3c5ae"), hexc("#a33a2c")
    n = 40
    for i in range(n):
        a0, a1 = i * math.tau / n + 0.004, (i + 1) * math.tau / n - 0.004
        polar_slab(m, 9.85, 11.2, a0, a1, -0.05, 0.12, jitter(stone, m.rng, 0.07))
    for i in range(32):
        a0, a1 = i * math.tau / 32 + 0.005, (i + 1) * math.tau / 32 - 0.005
        polar_slab(m, 8.15, 9.8, a0, a1, -0.05, 0.135, jitter(cream, m.rng, 0.05))
        polar_slab(m, 6.45, 8.1, a0 + math.tau / 64, a1 + math.tau / 64, -0.05, 0.135, jitter(cream, m.rng, 0.05))
    for k in range(4):  # brick rings inside, a gold star in the middle
        r0, r1 = 1.6 + k * 1.2, 1.6 + (k + 1) * 1.2 - 0.04
        nb = 12 + k * 8
        for i in range(nb):
            a0, a1 = i * math.tau / nb + 0.01, (i + 1) * math.tau / nb - 0.01
            polar_slab(m, r0, min(r1, 6.4), a0, a1, -0.05, 0.15, jitter(brick, m.rng, 0.08))
    for i in range(16):
        a0, a1 = i * math.tau / 16, (i + 1) * math.tau / 16
        polar_slab(m, 0.0, 1.56, a0, a1, -0.05, 0.15, scale_col(brick, 0.8))
    for k in range(8):
        a = k * math.tau / 8
        tip = 1.5 if k % 2 == 0 else 1.0
        pts = [(0, 0), (math.cos(a - 0.22) * 0.45, math.sin(a - 0.22) * 0.45), (math.cos(a) * tip, math.sin(a) * tip), (math.cos(a + 0.22) * 0.45, math.sin(a + 0.22) * 0.45)]
        m.face([m.P(x, 0.152, z) for (x, z) in pts][::-1], GOLD, glow=0.1)
    m.finish(out)


def trampoline(out):
    """A wagon wheel laid flat. Collider: cylinder r 2.2, h 0.5 (y 0..0.5)."""
    m = LM("trampoline", 841)
    wd = hexc("#6e4326")
    m.cyl(0, 0.0, 0, 2.3, 0.5, 2.3, hexc("#3a3440"), n=24, caps=False)  # iron tyre
    m.cyl(0, 0.0, 0, 2.1, 0.5, 2.1, wd, n=24, caps=False)
    for i in range(24):
        a0, a1 = i * math.tau / 24, (i + 1) * math.tau / 24
        q = lambda a, r: m.P(math.cos(a) * r, 0.5, math.sin(a) * r)
        m.face([q(a0, 1.9), q(a1, 1.9), q(a1, 2.3), q(a0, 2.3)], jitter(wd if i % 3 else scale_col(wd, 1.2), m.rng, 0.05))
        if i % 2 == 0:
            m.ball(math.cos(a0) * 2.2, 0.5, math.sin(a0) * 2.2, 0.04, STEEL, n=4, rings=3)
    m.cyl(0, 0.0, 0, 1.9, 0.48, 1.9, scale_col(wd, 0.6), n=24, caps=False)
    for i in range(24):  # the bouncy cloth, blue and lit
        a0, a1 = i * math.tau / 24, (i + 1) * math.tau / 24
        q = lambda a, r: m.P(math.cos(a) * r, 0.52, math.sin(a) * r)
        m.face([q(a0, 0.0), q(a1, 1.9), q(a0, 1.9)], BLUE if i % 2 else hexc("#62d0ff"), glow=0.3)
    for k in range(12):  # spokes over the cloth edge
        a = k * math.tau / 12
        m.rod((math.cos(a) * 0.35, 0.53, math.sin(a) * 0.35), (math.cos(a) * 1.95, 0.51, math.sin(a) * 1.95), 0.07, scale_col(wd, 1.15), n=5)
    m.cyl(0, 0.5, 0, 0.38, 0.62, 0.34, wd, n=12)
    m.cyl(0, 0.62, 0, 0.2, 0.66, 0.2, IRON, n=10)
    m.finish(out)


def summit(out):
    """Slide Hill summit: deck 14 x 14 (collider top at +0.05), flagpole at (-4, 0, 3)."""
    m = LM("summit", 851)
    deck = hexc("#c9a46e")
    for k in range(28):
        x = -7.0 + k * 0.5
        m.box(x, -0.2, -7.0, x + 0.48, 0.05, 7.0, jitter(deck, m.rng, 0.08), sub=2.0, faces="xXY")
    for s in (-1, 1):
        m.box(-7.1, -0.55, s * 7.0 - 0.12, 7.1, 0.07, s * 7.0 + 0.12, scale_col(deck, 0.7))
        m.box(s * 7.0 - 0.12, -0.55, -7.1, s * 7.0 + 0.12, 0.07, 7.1, scale_col(deck, 0.7))
        for t in (-1, 1):
            m.cyl(s * 6.9, -0.6, t * 6.9, 0.18, 0.55, 0.16, WOOD_D, n=6)
            m.cyl(s * 6.9, 0.55, t * 6.9, 0.2, 0.68, 0.0, WOOD_D, n=6)
    m.cyl(-4, 0.05, 3, 0.4, 0.25, 0.35, hexc("#55586a"), n=8)
    m.cyl(-4, 0.25, 3, 0.12, 9.0, 0.09, hexc("#c4ccd8"), n=8)
    m.ball(-4, 9.1, 3, 0.18, GOLD, n=8, rings=4, glow=0.3)
    m.finish(out)


def y_gate(out):
    """Chaos Yard entrance: columns at x +-8.2 (colliders here), sign under the beam.
    Front (+z) faces back toward town."""
    m = LM("y_gate", 861)
    for sx in (-1, 1):
        cx = sx * 8.2
        for (dx, dz) in ((-0.35, -0.35), (0.35, -0.35), (0.35, 0.35), (-0.35, 0.35)):
            m.box(cx + dx - 0.07, 0, dz - 0.07, cx + dx + 0.07, 7.2, dz + 0.07, YEL)
        for y in range(0, 7):
            m.rod((cx - 0.35, y, 0.36), (cx + 0.35, y + 1, 0.36), 0.03, scale_col(YEL, 0.8), n=4)
            m.rod((cx - 0.35, y, -0.36), (cx + 0.35, y + 1, -0.36), 0.03, scale_col(YEL, 0.8), n=4)
            m.box(cx - 0.42, y + 0.97, -0.42, cx + 0.42, y + 1.03, 0.42, scale_col(YEL, 0.85))
        m.box(cx - 0.6, 0.0, -0.6, cx + 0.6, 0.3, 0.6, hexc("#9a9aa6"))
        m.col(cx - 0.45, 0, -0.45, cx + 0.45, 7.2, 0.45)
        m.cyl(cx, 7.5, 0, 0.18, 7.8, 0.1, hexc("#3a3a48"), n=6)
        m.ball(cx, 7.95, 0, 0.2, hexc("#ff8a2a"), n=6, rings=4, glow=1.0)  # warning beacons
    m.box(-8.8, 6.9, -0.3, 8.8, 7.5, 0.3, hexc("#5d6470"))  # I-beam across
    m.box(-8.8, 6.85, -0.36, 8.8, 6.95, 0.36, hexc("#4a4f5a"))
    m.box(-8.8, 7.45, -0.36, 8.8, 7.55, 0.36, hexc("#4a4f5a"))
    hazard_band(m, -8.8, 8.8, 6.95, 7.45, 0.3, step=0.5)
    m.push(0, 0, 0, yaw=180)
    hazard_band(m, -8.8, 8.8, 6.95, 7.45, 0.3, step=0.5)
    m.pop()
    for sx in (-1, 1):  # chains down to the sign
        for k in range(6):
            m.push(sx * 3.2, 6.85 - k * 0.15, 0, yaw=90 * (k % 2))
            m.box(-0.06, -0.08, -0.02, 0.06, 0.0, 0.02, STEEL)
            m.pop()
    m.box(-3.3, 4.5, -0.06, 3.3, 6.2, 0.06, hexc("#2a2a32"))
    m.box(-3.4, 4.42, -0.08, 3.4, 4.52, 0.08, YEL)
    m.box(-3.4, 6.18, -0.08, 3.4, 6.28, 0.08, YEL)
    m.text("CHAOS YARD", 0, 4.86, 0.06, 1.55, YEL, font="Bungee-Regular", depth=0.03, glow=0.4, res=1)
    m.text("NO REFUNDS", 0, 4.95, -0.06, 1.3, hexc("#ff8a2a"), font="Bungee-Regular", depth=0.03, glow=0.4, res=1, yaw=180)
    m.finish(out)


ALL = ["street_bits", "wheel_stand", "start_btn", "square_disc", "trampoline", "summit", "y_gate", "c_station", "wardrobe"]
