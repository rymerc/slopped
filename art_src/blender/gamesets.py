"""Sets for the overlord minigames + the casino back room."""
import math

from lm import LM, hexc, jitter, scale_col
from town import BRASS, CREAM, INK, NEON_CYAN, NEON_GOLD, NEON_PINK, WOOD, WOOD_D, WOOD_L
from sets import bolts, lathe, sphere, hazard_band

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
    # on the sun-facing wall: on a wall the sun rakes across, its shadow read as a second line
    m.push(0, 0, 0, yaw=-90)
    m.text("SOUP OF THE DAY: YOU", 0, 33.0, -R + 0.06, 3.0, hexc("#ffd257"), font="Bungee-Regular", depth=0.05, glow=0.35, res=1, bend=R - 0.06)
    m.pop()
    # vertical seams with rivet columns, and scorch where the soup has been
    for i in range(3, n, 7):
        if i <= 6 or i >= 50:
            continue  # keep the lettering clear
        a0 = i * math.tau / n
        m.push(math.cos(a0) * (R - 0.1), 0, math.sin(a0) * (R - 0.1), yaw=-math.degrees(a0) - 90)
        m.box(-0.35, -2.0, -0.06, 0.35, H - 0.4, 0.1, hexc("#8a5530"))
        for y in range(0, int(H) - 1, 2):
            m.ball(-0.18, y + 0.5, 0.12, 0.13, BRASS, n=5, rings=3)
            m.ball(0.18, y + 1.5, 0.12, 0.13, BRASS, n=5, rings=3)
        m.pop()
    for i in range(n):
        a0, a1 = i * math.tau / n, (i + 1) * math.tau / n
        p3 = lambda a, yy: m.P(math.cos(a) * (R - 0.04), yy, math.sin(a) * (R - 0.04))
        top = 1.2 + 1.1 * math.sin(i * 1.3) ** 2
        m.face([p3(a0, top), p3(a1, top), p3(a1, -2.0), p3(a0, -2.0)], jitter(hexc("#4a2a18"), m.rng, 0.1))
    # rolled rim
    m.cyl(0, H - 0.5, 0, R + t + 0.35, H + 0.35, R + t + 0.35, scale_col(STEEL, 0.85), n=n, caps=False)
    m.cyl(0, H + 0.35, 0, R + t + 0.35, H + 0.5, R + t + 0.1, STEEL, n=n, caps=False)
    # a ladle left leaning in the pot, and a thermometer clipped to the rim
    m.rod((math.cos(2.4) * (R - 4.0), 27.0, math.sin(2.4) * (R - 4.0)), (math.cos(2.4) * (R + 4.5), H + 7.0, math.sin(2.4) * (R + 4.5)), 0.55, STEEL, n=10)
    m.ball(math.cos(2.4) * (R - 4.4), 26.0, math.sin(2.4) * (R - 4.4), 3.2, STEEL, n=10, rings=6, sy=0.55)
    ta = 0.9
    tx, tz = math.cos(ta), math.sin(ta)
    m.beam((tx * (R - 1.2), 28.0, tz * (R - 1.2)), (tx * (R - 1.2), H + 3.2, tz * (R - 1.2)), 0.18, STEEL)
    m.beam((tx * (R - 1.2), H + 1.0, tz * (R - 1.2)), (tx * (R + t + 0.4), H + 1.0, tz * (R + t + 0.4)), 0.15, STEEL)
    m.push(tx * (R - 1.4), H + 3.6, tz * (R - 1.4), yaw=-math.degrees(ta) - 90)
    m.push(0, 0, 0, pitch=90)
    m.cyl(0, -0.25, 0, 1.6, 0.05, 1.6, scale_col(STEEL, 0.7), n=16)
    m.cyl(0, 0.05, 0, 1.4, 0.07, 1.4, hexc("#f4f1ea"), n=16)
    m.pop()
    for k in range(12):  # dial bands: green, yellow, the red you're in
        a0 = math.pi * 0.15 + k * math.pi * 0.7 / 12
        a1 = a0 + math.pi * 0.7 / 12
        c = hexc("#4fbf5a") if k < 5 else (hexc("#ffd257") if k < 9 else hexc("#ff4a3a"))
        pp = lambda aa, rr: m.P(math.cos(aa) * rr, math.sin(aa) * rr, 0.09)
        m.face([pp(a1, 1.0), pp(a0, 1.0), pp(a0, 1.3), pp(a1, 1.3)], c, glow=0.2)
    m.beam((0, 0, 0.1), (math.cos(math.pi * 0.22) * 1.2, math.sin(math.pi * 0.22) * 1.2, 0.1), 0.05, RED)
    m.text("HOT", 0, -0.75, 0.08, 0.38, INK, font="Bungee-Regular", depth=0.02, res=1)
    m.pop()
    # leek and celery sticking out over the rim (out of reach)
    for (aa, c0, c1, r0) in ((-2.2, hexc("#f2f0dc"), hexc("#4f9a3c"), 1.3), (-1.9, hexc("#a8d86a"), hexc("#6fb83f"), 0.9)):
        ax, az = math.cos(aa), math.sin(aa)
        a3 = (ax * (R - 3.0), 30.0, az * (R - 3.0))
        b3 = (ax * (R + 6.0), H + 14.0, az * (R + 6.0))
        mid = tuple(a3[k] + (b3[k] - a3[k]) * 0.55 for k in range(3))
        m.rod(a3, mid, r0, c0, n=12)
        m.rod(mid, b3, r0, c1, r1=r0 * 0.85, n=12)
        for k in range(3):
            m.rod(b3, (b3[0] + (k - 1) * 2.0 * az, b3[1] + 3.5, b3[2] - (k - 1) * 2.0 * ax), r0 * 0.5, c1, r1=r0 * 0.15, n=8)
    # the burners: a ring of blue flames under the pot
    for i in range(36):
        a0 = i * math.tau / 36
        x, z = math.cos(a0) * (R + 2.5), math.sin(a0) * (R + 2.5)
        m.cyl(x, -6.0, z, 0.9, -3.4, 0.0, hexc("#3e8bff"), n=5, glow=1.0)
        m.cyl(x, -6.0, z, 0.5, -4.4, 0.0, hexc("#bfe6ff"), n=5, glow=1.0)
    # stove below and two great handles
    for side in (-1, 1):
        m.box(side * (R + t), 26, -3, side * (R + t + 7), 29, 3, IRON_D)
    m.cyl(0, -6, 0, R + 5, -2.4, R + 3, IRON_D, n=24, caps=False)
    m.room(-R, -3, -R, R, H, R, level=0.08, col=(1.0, 0.86, 0.7))
    m.finish(out)


def rocket(out):
    """The escape rocket, built up in eight visible stages (DYN_s0..s7) on a pad.
    Collider: the pad only (r 6.4). Stage radii and heights are fixed by the game."""
    m = LM("rocket", 411)
    m.cyl(0, -0.5, 0, 6.8, 0.1, 6.8, hexc("#6a6e78"), n=24)
    for i in range(24):  # hazard chevrons round the pad edge
        a0, a1 = i * math.tau / 24, (i + 1) * math.tau / 24
        pp = lambda a, r: m.P(math.cos(a) * r, 0.12, math.sin(a) * r)
        m.face([pp(a0, 5.4), pp(a1, 5.4), pp(a1, 6.6), pp(a0, 6.6)], hexc("#ffc935") if i % 2 else INK)
    m.cyl(0, 0.1, 0, 5.2, 0.14, 5.2, hexc("#8a8e98"), n=24)
    m.cyl(0, 0.1, 0, 4.6, 0.16, 4.6, hexc("#3a3a48"), n=20)
    for k in range(8):  # flame-trench grate
        x = -3.5 + k
        m.box(x - 0.08, 0.16, -3.2, x + 0.08, 0.19, 3.2, hexc("#55586a"))
    # two lattice masts with an arm across, umbilicals hanging
    for sx in (-1, 1):
        cx, cz = sx * 5.0, -5.0
        for (dx, dz) in ((-0.35, -0.35), (0.35, -0.35), (0.35, 0.35), (-0.35, 0.35)):
            m.box(cx + dx - 0.08, 0, cz + dz - 0.08, cx + dx + 0.08, 16.4, cz + dz + 0.08, RED)
        for y in range(0, 16, 2):
            for (a, b) in (((-0.35, -0.35), (0.35, -0.35)), ((0.35, -0.35), (0.35, 0.35)), ((0.35, 0.35), (-0.35, 0.35)), ((-0.35, 0.35), (-0.35, -0.35))):
                m.beam((cx + a[0], y, cz + a[1]), (cx + b[0], y + 2, cz + b[1]), 0.04, scale_col(RED, 0.8))
            m.box(cx - 0.45, y + 1.95, cz - 0.45, cx + 0.45, y + 2.05, cz + 0.45, CREAM)
        m.box(cx - 0.6, 16.4, cz - 0.6, cx + 0.6, 16.6, cz + 0.6, IRON)
        m.cyl(cx, 16.6, cz, 0.12, 17.4, 0.05, IRON, n=5)
        m.ball(cx, 17.5, cz, 0.16, hexc("#ff4a3a"), n=6, rings=4, glow=1.0)
        m.box(min(cx, cx - 1.6 * sx), 11.3, cz + 0.4, max(cx, cx - 1.6 * sx), 11.6, cz + 0.7, RED)  # swing arm, folded back
        m.rod((cx, 0.3, cz + 0.45), (cx, 11.3, cz + 0.45), 0.08, hexc("#2a2a32"), n=6)  # fuel line
    # fuel tanks at the back of the pad
    for (x, z) in ((-2.6, -6.0), (-1.2, -6.3)):
        m.cyl(x, 0.1, z, 0.55, 2.4, 0.55, hexc("#e8e2d0"), n=10)
        m.ball(x, 2.4, z, 0.55, hexc("#e8e2d0"), n=10, rings=4, sy=0.5)
        m.cyl(x, 1.0, z, 0.57, 1.2, 0.57, RED, n=10)
    m.col(-6.4, -1, -6.4, 6.4, 0.14, 6.4)
    sections = [
        (0.6, 2.4, 2.5, 2.4, hexc("#e8e2d0")), (2.4, 4.4, 2.5, 2.6, RED), (4.4, 6.4, 2.6, 2.6, hexc("#e8e2d0")),
        (6.4, 8.4, 2.6, 2.5, hexc("#3ec1ff")), (8.4, 10.4, 2.5, 2.3, hexc("#e8e2d0")), (10.4, 12.2, 2.3, 1.9, RED),
        (12.2, 14.2, 1.9, 1.1, hexc("#e8e2d0")), (14.2, 16.4, 1.1, 0.0, RED)]
    patch_cols = [hexc("#b9c2d0"), hexc("#c98a3f"), hexc("#7fa7c0"), hexc("#d6d2c4")]
    for i, (y0, y1, r0, r1, c) in enumerate(sections):
        p = m.part(f"s{i}")
        p.cyl(0, y0, 0, r0, y1, r1, c, n=18)
        p.cyl(0, y0, 0, r0 + 0.04, y0 + 0.14, r0 + 0.04 - (r0 - r1) * 0.07, scale_col(c, 0.78), n=18, caps=False)  # seam band
        if r1 > 0.5:
            for k in range(14):  # rivets round the top seam
                a = k * math.tau / 14
                rr = r1 + 0.03
                p.ball(math.cos(a) * rr, y1 - 0.12, math.sin(a) * rr, 0.06, STEEL, n=4, rings=3)
        # a mismatched patch panel or two: it was built from scrap
        for k in range(1 + i % 2):
            a0 = p.rng.uniform(0, math.tau)
            a1 = a0 + p.rng.uniform(0.35, 0.6)
            pc = patch_cols[(i + k) % len(patch_cols)]
            ya, yb = y0 + 0.35, y1 - 0.35
            rr = lambda y: r0 + (r1 - r0) * (y - y0) / (y1 - y0) + 0.05
            if yb - ya > 0.4 and r1 > 0.6:
                q = lambda a, y: p.P(math.cos(a) * rr(y), y, math.sin(a) * rr(y))
                p.face([q(a1, ya), q(a0, ya), q(a0, yb), q(a1, yb)], pc)
                for (aa, yy) in ((a0 + 0.05, ya + 0.12), (a1 - 0.05, ya + 0.12), (a0 + 0.05, yb - 0.12), (a1 - 0.05, yb - 0.12)):
                    p.ball(math.cos(aa) * (rr(yy) + 0.02), yy, math.sin(aa) * (rr(yy) + 0.02), 0.05, IRON_D, n=4, rings=3)
        if i == 0:
            for k in range(3):  # fins + engine
                a = k * math.tau / 3
                x, z = math.cos(a), math.sin(a)
                p.beam((x * 2.5, 2.0, z * 2.5), (x * 4.2, 0.2, z * 4.2), 0.32, RED)
                p.beam((x * 2.4, 0.9, z * 2.4), (x * 4.2, 0.2, z * 4.2), 0.2, scale_col(RED, 0.7))
            lathe(p, [(0.2, 1.7, hexc("#3a3a48")), (0.45, 1.45, hexc("#3a3a48")), (0.8, 1.0, IRON), (0.85, 0.0, IRON)], n=14)
            p.cyl(0, 0.22, 0, 1.2, 0.25, 1.2, hexc("#ff8a2a"), n=12, glow=0.6)
        if i == 2:
            p.text("SLOP-1", 0, 5.0, 2.62, 0.6, INK, font="Bungee-Regular", depth=0.04, res=1)
        if i == 3:
            p.push(0, 7.4, 2.62)
            p.disc(0, 0, 0, 0.95, hexc("#ffd257"), n=12)
            p.disc(0, 0, 0.02, 0.72, hexc("#7fd0e0"), n=12, glow=0.3)
            p.pop()
        if i == 5:  # a bin lid, bolted on
            p.push(0, 11.3, 2.2, pitch=90)
            p.cyl(0, 0, 0, 0.6, 0.08, 0.6, hexc("#8d93a0"), n=10)
            p.box(-0.25, 0.08, -0.05, 0.25, 0.16, 0.05, hexc("#8d93a0"))
            p.pop()
        if i == 7:
            p.cyl(0, 16.4, 0, 0.06, 17.2, 0.02, IRON, n=4)
            p.ball(0, 17.25, 0, 0.1, hexc("#ff4a3a"), n=5, rings=3, glow=1.0)
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
    """Prayer circle (r 4) ringed by six carved stones (colliders 0.7 x 3 x 0.7), an
    altar (collider 2.4 x 1.5 x 2.4) and a rubber duck that has seen things."""
    m = LM("shrine", 421)
    stone, stone_d = hexc("#a79fb0"), hexc("#7f7790")
    R = 4.0
    n = 36
    for i in range(n):
        a0, a1 = i * math.tau / n, (i + 1) * math.tau / n
        p = lambda a, r, y=0.1: m.P(math.cos(a) * r, y, math.sin(a) * r)
        m.face([p(a0, R - 0.3), p(a1, R - 0.3), p(a1, R), p(a0, R)], hexc("#ffd257"), 0.5)
        if i % 2 == 0:  # a ring of flat paving inside the glow line
            m.face([p(a0 + 0.02, 1.9, 0.06), p(a1 + 0.12, 1.9, 0.06), p(a1 + 0.12, 3.55, 0.06), p(a0 + 0.02, 3.55, 0.06)], jitter(stone, m.rng, 0.08))
    for k in range(6):
        a = k * math.tau / 6
        x, z = math.cos(a) * (R + 0.4), math.sin(a) * (R + 0.4)
        h = 2.2 + (k % 2) * 0.8
        m.push(x, 0, z, yaw=-math.degrees(a) + 90)
        c = jitter(stone, m.rng, 0.08)
        m.box(-0.38, 0, -0.38, 0.38, 0.3, 0.38, stone_d)
        m.box(-0.33, 0.3, -0.33, 0.33, h - 0.35, 0.33, c, sub=0.8)
        m.box(-0.38, h - 0.35, -0.38, 0.38, h - 0.2, 0.38, scale_col(c, 1.1))
        m.cyl(0, h - 0.2, 0, 0.36, h, 0.0, scale_col(c, 0.95), n=4)
        for j in range(3):  # carved rings with a duck glyph between them
            y = 0.8 + j * (h - 1.3) / 2
            m.box(-0.35, y, -0.35, 0.35, y + 0.08, 0.35, stone_d)
        m.ball(0, h * 0.55, -0.34, 0.12, hexc("#ffd23f"), n=6, rings=4, glow=0.25)
        m.pop()
        m.col(x - 0.35, 0, z - 0.35, x + 0.35, 3.0, z + 0.35)
        m.cyl(x, h, z, 0.05, h + 0.4, 0.05, BRASS, n=5)
        m.ball(x, h + 0.55, z, 0.15, NEON_GOLD, n=6, rings=4, glow=1.0)
        for j in range(3):  # tufts at the foot
            aa = a + (j - 1) * 0.3
            m.cyl(math.cos(aa) * (R + 0.95), 0, math.sin(aa) * (R + 0.95), 0.12, 0.35, 0.0, jitter(hexc("#5f9a3c"), m.rng, 0.15), n=4)
    # stepped altar, offerings, candles
    m.box(-1.2, 0, -1.2, 1.2, 0.55, 1.2, stone_d, sub=0.8)
    m.box(-1.05, 0.55, -1.05, 1.05, 1.0, 1.05, stone, sub=0.8)
    m.box(-0.9, 1.0, -0.9, 0.9, 1.5, 0.9, jitter(stone, m.rng, 0.1))
    m.box(-0.95, 1.42, -0.95, 0.95, 1.5, 0.95, hexc("#7a1f3a"))
    for (x, z) in ((-0.75, 0.75), (0.75, 0.75), (-0.75, -0.75), (0.75, -0.75)):
        m.cyl(x, 1.5, z, 0.06, 1.75, 0.06, CREAM, n=6)
        m.cyl(x, 1.75, z, 0.05, 1.92, 0.0, hexc("#ffb347"), n=5, glow=1.0)
    for (x, z, c) in ((0.0, 1.3, hexc("#ff8a3d")), (-1.25, 0.2, hexc("#c0392b")), (1.25, -0.1, hexc("#7ccf4e"))):
        m.cyl(x, 0.55, z, 0.22, 0.68, 0.3, hexc("#b0773f"), n=8)
        m.ball(x, 0.75, z, 0.13, c, n=6, rings=4)
        m.ball(x + 0.1, 0.72, z + 0.06, 0.1, hexc("#ffd23f"), n=6, rings=4)
    # the idol
    m.ball(0, 2.0, 0, 0.6, hexc("#ffd23f"), n=10, rings=6, sy=0.75)
    m.ball(0, 2.7, -0.3, 0.38, hexc("#ffd23f"), n=9, rings=6)
    m.box(-0.14, 2.58, -0.88, 0.14, 2.7, -0.6, hexc("#ff8a3d"))
    m.box(-0.12, 2.52, -0.84, 0.12, 2.58, -0.62, hexc("#e8641a"))
    for sx in (-1, 1):
        m.ball(sx * 0.17, 2.82, -0.6, 0.08, INK, n=6, rings=4)
        m.ball(sx * 0.19, 2.85, -0.66, 0.025, hexc("#ffffff"), n=4, rings=3, glow=0.6)
        m.ball(sx * 0.5, 1.98, 0.05, 0.22, hexc("#f2c22a"), n=6, rings=4, sy=0.6)
    m.cyl(0, 3.1, -0.3, 0.42, 3.14, 0.42, NEON_GOLD, n=12, glow=0.8)  # halo
    m.col(-1.2, 0, -1.2, 1.2, 1.5, 1.2)
    m.lamp(0, 2.2, 0, radius=4.0, power=0.18, col=(1.0, 0.8, 0.45))
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
