"""Sets for the overlord minigames + the casino back room."""
import math

from lm import LM, hexc, jitter, scale_col
from town import BRASS, CREAM, INK, NEON_CYAN, NEON_GOLD, NEON_PINK, WOOD, WOOD_D, WOOD_L

IRON = hexc("#4a4d58")
IRON_D = hexc("#2f3038")
STEEL = hexc("#c4ccd8")
RED = hexc("#e04a4a")


def soup_pot(out):
    """Giant pot, 29 m inner radius, 40 m tall. Walls face inward; collision is a ring."""
    m = LM("soup_pot", 401)
    R, H, n = 29.5, 40.0, 56
    t = 1.5
    for i in range(n):
        a0, a1 = i * math.tau / n, (i + 1) * math.tau / n
        c = jitter(hexc("#a8693c"), m.rng, 0.06)  # copper-bottomed, so the inside reads
        p = lambda a, r, y: m.P(math.cos(a) * r, y, math.sin(a) * r)
        for k in range(4):  # split so baked AO has somewhere to land
            y0, y1 = -2 + (H + 2) * k / 4, -2 + (H + 2) * (k + 1) / 4
            m.face([p(a0, R, y1), p(a1, R, y1), p(a1, R, y0), p(a0, R, y0)], c)            # inner
            m.face([p(a0, R + t, y0), p(a1, R + t, y0), p(a1, R + t, y1), p(a0, R + t, y1)], scale_col(c, 0.8))  # outer
        m.face([p(a1, R, H), p(a0, R, H), p(a0, R + t, H), p(a1, R + t, H)], STEEL)        # lip
        m.face([p(a0, 0.1, -2), p(a1, 0.1, -2), p(a1, R, -2), p(a0, R, -2)], hexc("#7a5238"))       # base
        am = (a0 + a1) * 0.5
        m.push(0, 0, 0, yaw=-math.degrees(am))
        m.col(R + 0.05, -3, -1.9, R + t, H + 8.0, 1.9)
        m.pop()
    # riveted bands + burnt-on tide marks inside
    for y, c in ((8.0, "#6e4326"), (18.0, "#7f5230"), (28.0, "#6e4326"), (37.0, "#c98a3f")):
        p2 = lambda a, r, yy: m.P(math.cos(a) * r, yy, math.sin(a) * r)
        for i in range(n):
            a0, a1 = i * math.tau / n, (i + 1) * math.tau / n
            m.face([p2(a0, R - 0.06, y + 0.5), p2(a1, R - 0.06, y + 0.5), p2(a1, R - 0.06, y), p2(a0, R - 0.06, y)], hexc(c))
            m.ball(math.cos(a0) * (R - 0.08), y + 0.25, math.sin(a0) * (R - 0.08), 0.16, BRASS, n=5, rings=3)
    # a giant wooden spoon somebody left in the pot
    m.beam((-22, 0, -14), (-30, 46, -20), 0.7, hexc("#b0773f"))
    m.ball(-21.5, -0.5, -13.6, 2.4, hexc("#b0773f"), n=8, rings=5, sy=0.5)
    m.text("SOUP OF THE DAY: YOU", 0, 33.0, -R + 0.1, 3.0, hexc("#ffd257"), font="Bungee-Regular", depth=0.05, res=1)
    # stove below and two great handles
    for side in (-1, 1):
        m.box(side * (R + t), 26, -3, side * (R + t + 7), 29, 3, IRON_D)
    m.cyl(0, -6, 0, R + 5, -2.4, R + 3, IRON_D, n=24, caps=False)
    m.room(-R, -3, -R, R, H, R, level=0.08, col=(1.0, 0.86, 0.7))
    m.finish(out)


def rocket(out):
    """The escape rocket, built up in eight visible stages (DYN_s0..s7) on a pad."""
    m = LM("rocket", 411)
    m.cyl(0, -0.5, 0, 6.8, 0.1, 6.8, hexc("#6a6e78"), n=20)
    m.cyl(0, 0.1, 0, 5.2, 0.14, 5.2, hexc("#ffc935"), n=20)
    m.cyl(0, 0.1, 0, 4.6, 0.16, 4.6, hexc("#3a3a48"), n=20)
    for sx, sz in ((-5.0, -5.0), (5.0, -5.0)):
        m.box(sx - 0.2, 0, sz - 0.2, sx + 0.2, 16, sz + 0.2, RED)
        for y in range(2, 16, 3):
            m.box(sx - 0.25, y, sz - 0.25, sx + 0.25, y + 0.2, sz + 0.25, CREAM)
    m.col(-6.4, -1, -6.4, 6.4, 0.14, 6.4)
    sections = [
        (0.6, 2.4, 2.5, 2.4, hexc("#e8e2d0")), (2.4, 4.4, 2.5, 2.6, RED), (4.4, 6.4, 2.6, 2.6, hexc("#e8e2d0")),
        (6.4, 8.4, 2.6, 2.5, hexc("#3ec1ff")), (8.4, 10.4, 2.5, 2.3, hexc("#e8e2d0")), (10.4, 12.2, 2.3, 1.9, RED),
        (12.2, 14.2, 1.9, 1.1, hexc("#e8e2d0")), (14.2, 16.4, 1.1, 0.0, RED)]
    for i, (y0, y1, r0, r1, c) in enumerate(sections):
        p = m.part(f"s{i}")
        p.cyl(0, y0, 0, r0, y1, r1, c, n=14)
        if i == 0:
            for k in range(3):  # fins + engine
                a = k * math.tau / 3
                x, z = math.cos(a), math.sin(a)
                p.beam((x * 2.5, 2.0, z * 2.5), (x * 4.2, 0.2, z * 4.2), 0.32, RED)
            p.cyl(0, 0.2, 0, 1.6, 0.8, 1.0, hexc("#3a3a48"), n=10)
        if i == 3:
            p.push(0, 7.4, 2.62)
            p.disc(0, 0, 0, 0.95, hexc("#ffd257"), n=12)
            p.disc(0, 0, 0.02, 0.72, hexc("#7fd0e0"), n=12, glow=0.3)
            p.pop()
    m.finish(out)


def scrap(out):
    """Rocket parts for Pocket God: things that shouldn't be on a rocket."""
    m = LM("scrap", 415)
    tin = hexc("#b9c2d0")
    a = m.part("fin")
    a.face([a.P(-0.45, -0.3, 0), a.P(0.45, -0.3, 0), a.P(0.0, 0.42, 0)], RED)
    a.face([a.P(0.45, -0.3, 0), a.P(-0.45, -0.3, 0), a.P(0.0, 0.42, 0)], scale_col(RED, 0.75))
    a.box(-0.48, -0.36, -0.08, 0.48, -0.3, 0.08, tin)
    b = m.part("bin")
    b.cyl(0, -0.45, 0, 0.3, 0.45, 0.36, tin, n=8)
    b.cyl(0, 0.45, 0, 0.38, 0.5, 0.38, hexc("#8d93a0"), n=8)
    c = m.part("nose")
    c.cyl(0, -0.2, 0, 0.3, 0.45, 0.0, hexc("#e8e2d0"), n=8)
    c.cyl(0, -0.3, 0, 0.32, -0.2, 0.32, RED, n=8)
    m.box(0, 0, 0, 0.01, 0.01, 0.01, tin)
    m.finish(out)


def shrine(out):
    m = LM("shrine", 421)
    stone = hexc("#a79fb0")
    R = 4.0
    n = 18
    for i in range(n):
        a0, a1 = i * math.tau / n, (i + 1) * math.tau / n
        for r0, r1, c in ((R - 0.3, R, hexc("#ffd257")),):
            p = lambda a, r: m.P(math.cos(a) * r, 0.1, math.sin(a) * r)
            m.face([p(a0, r1), p(a1, r1), p(a1, r0), p(a0, r0)], c, 0.5)
    for k in range(6):
        a = k * math.tau / 6
        x, z = math.cos(a) * (R + 0.4), math.sin(a) * (R + 0.4)
        m.box(x - 0.35, 0, z - 0.35, x + 0.35, 2.2 + (k % 2) * 0.8, z + 0.35, jitter(stone, m.rng, 0.1))
        m.col(x - 0.35, 0, z - 0.35, x + 0.35, 3.0, z + 0.35)
        m.cyl(x, 2.2 + (k % 2) * 0.8, z, 0.1, 2.6 + (k % 2) * 0.8, 0.1, CREAM, n=5)
        m.ball(x, 2.75 + (k % 2) * 0.8, z, 0.11, NEON_GOLD, n=5, rings=3, glow=1.0)
    m.box(-1.2, 0, -1.2, 1.2, 1.0, 1.2, stone)
    m.box(-0.9, 1.0, -0.9, 0.9, 1.5, 0.9, jitter(stone, m.rng, 0.1))
    # the idol: a rubber duck that has seen things
    m.ball(0, 2.0, 0, 0.6, hexc("#ffd23f"), n=8, sy=0.75)
    m.ball(0, 2.7, -0.3, 0.38, hexc("#ffd23f"), n=7)
    m.box(-0.12, 2.6, -0.85, 0.12, 2.72, -0.6, hexc("#ff8a3d"))
    m.col(-1.2, 0, -1.2, 1.2, 1.5, 1.2)
    m.finish(out)


def back_room(out):
    """Dirty Deeds Dept.: curtained booth, faces +z."""
    m = LM("back_room", 431)
    W, D, H = 3.2, 2.0, 4.6
    velvet = hexc("#6a1a3a")
    for i in range(int(2 * W / 0.4)):  # pleated curtains
        x = -W + i * 0.4
        c = velvet if i % 2 == 0 else scale_col(velvet, 0.72)
        m.box(x, 0, -D, x + 0.4, H, -D + 0.14 + (i % 2) * 0.08, c, faces="zZxX")
    m.box(-W - 0.1, H, -D - 0.1, W + 0.1, H + 0.4, D + 0.1, hexc("#2a1c28"))
    m.box(-W - 0.2, H + 0.4, -D - 0.2, W + 0.2, H + 0.55, D + 0.2, BRASS)
    for sx in (-1, 1):
        m.box(sx * W - 0.15, 0, -D, sx * W + 0.15, H, -D + 0.4, WOOD_D)
        m.box(sx * W - 0.15, 0, D - 0.3, sx * W + 0.15, H, D, WOOD_D)
    m.box(-W, 0, 0.1, W, 1.2, 1.0, WOOD_D)
    m.box(-W - 0.1, 1.2, 0.0, W + 0.1, 1.32, 1.1, hexc("#c98a3f"))
    m.col(-W - 0.1, 0, 0.0, W + 0.1, 1.32, 1.1)
    m.col(-W, 0, -D, W, H, -D + 0.3)
    m.box(-2.9, H + 0.75, D - 0.1, 2.9, H + 2.05, D + 0.02, hexc("#33245a"))
    m.text("DIRTY DEEDS", 0, H + 1.28, D + 0.02, 0.72, NEON_PINK, font="Bungee-Regular", glow=0.95, depth=0.04, res=1)
    m.text("DEPT.", 0, H + 0.82, D + 0.02, 0.36, NEON_CYAN, font="Bungee-Regular", glow=0.9, depth=0.03, res=1)
    m.box(-2.9, H + 0.55, D - 0.1, -2.75, H + 0.75, D, BRASS)
    m.box(2.75, H + 0.55, D - 0.1, 2.9, H + 0.75, D, BRASS)
    # merchandise you shouldn't look at directly
    for x, c in ((-2.2, hexc("#ffe27a")), (-1.2, hexc("#46e3ff")), (1.6, hexc("#ff4f9a"))):
        m.cyl(x, 1.32, 0.5, 0.16, 1.8, 0.16, c, n=7, glow=0.5)
    m.box(0.3, 1.32, 0.3, 0.9, 1.5, 0.75, INK)
    m.room(-W, 0, -D, W, H, D, level=0.26, col=(1.0, 0.6, 0.8))
    m.lamp(0, 3.4, 0.2, radius=6.0, power=0.3, col=(1.0, 0.65, 0.8))
    m.finish(out)


ALL = ["soup_pot", "rocket", "shrine", "back_room", "scrap"]
