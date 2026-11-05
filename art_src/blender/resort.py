"""Beach district: bilge bar, tiki huts, boardwalk dock, diving tower, lighthouse."""
import math

from mathutils import Vector

from lm import LM, hexc, jitter, scale_col
from town import BRASS, CREAM, INK, NEON_CYAN, NEON_GOLD, NEON_PINK, WOOD, WOOD_D, WOOD_L

THATCH = hexc("#c9a35a")
THATCH_D = hexc("#a37f3f")
BAMBOO = hexc("#c9b06a")
SEA_TEAL = hexc("#2fb0a8")
CORAL = hexc("#ff7a5c")


def thatch_cone(m, x, y, z, r, h, rows=5, n=14, col=THATCH):
    """Shaggy layered roof: each ring overhangs the one above."""
    for k in range(rows):
        t0, t1 = k / rows, (k + 1) / rows
        r0 = r * (1 - t0) + 0.08
        r1 = r * (1 - t1) * 0.92 + 0.02
        y0 = y + h * t0 - 0.16
        y1 = y + h * t1
        for i in range(n):
            a0 = i * math.tau / n
            a1 = (i + 1) * math.tau / n
            c = jitter(col, m.rng, 0.13)
            d = m.rng.uniform(-0.06, 0.1)
            A = m.P(x + math.cos(a0) * (r0 + d), y0, z + math.sin(a0) * (r0 + d))
            B = m.P(x + math.cos(a1) * (r0 + d), y0, z + math.sin(a1) * (r0 + d))
            C = m.P(x + math.cos(a1) * r1, y1, z + math.sin(a1) * r1)
            D = m.P(x + math.cos(a0) * r1, y1, z + math.sin(a0) * r1)
            m.face([D, C, B, A], c)
            drop = Vector((0.0, -0.16, 0.0))
            m.face([A + drop, B + drop, C + drop, D + drop], scale_col(THATCH_D, 0.6))


def bamboo_post(m, x, y0, z, y1, r=0.14):
    m.cyl(x, y0, z, r, y1, r * 0.9, BAMBOO, n=7, caps=False)
    y = y0 + 0.9
    while y < y1:
        m.cyl(x, y, z, r * 1.2, y + 0.06, r * 1.2, THATCH_D, n=7, caps=False)
        y += 0.9


def beach_bar(out):
    """THE BILGE BAR: open-sided tiki bar. Round counter you can walk behind."""
    m = LM("beach_bar", 201)
    F = 0.3
    R = 7.5
    # octagonal deck
    n = 16
    for k in range(int(R / 0.45)):
        r0, r1 = k * 0.45, (k + 1) * 0.45
        for i in range(n):
            a0, a1 = i * math.tau / n, (i + 1) * math.tau / n
            c = jitter(WOOD_L, m.rng, 0.1)
            m.face([m.P(math.cos(a0) * r1, F, math.sin(a0) * r1), m.P(math.cos(a1) * r1, F, math.sin(a1) * r1),
                    m.P(math.cos(a1) * r0, F, math.sin(a1) * r0), m.P(math.cos(a0) * r0, F, math.sin(a0) * r0)][::-1], c)
    m.col(-4.9, -0.3, -4.9, 4.9, F, 4.9)
    # the deck rim slopes to the sand all the way round: walk on from any side
    m.cyl(0, 0, 0, R + 1.5, F, R, WOOD_D, n=n, caps=False)
    for i in range(8):
        a = i * math.tau / 8
        x, z = math.sin(a), math.cos(a)
        m.col_ramp((x * (R + 1.6), -0.05, z * (R + 1.6)), (x * (R - 1.2), F, z * (R - 1.2)), 7.2)
        m.push(0, 0, 0, yaw=math.degrees(a))
        m.col(-3.6, F - 0.3, 4.6, 3.6, F, R - 1.15)   # octagon of flat deck
        m.pop()
    # roof on bamboo posts
    for i in range(8):
        a = (i + 0.5) * math.tau / 8
        x, z = math.cos(a) * (R - 0.7), math.sin(a) * (R - 0.7)
        bamboo_post(m, x, F, z, 5.0, r=0.2)
        m.col(x - 0.2, F, z - 0.2, x + 0.2, 5.0, z + 0.2)
    thatch_cone(m, 0, 4.9, 0, R + 1.0, 4.2, rows=6, n=18)
    m.cyl(0, 4.8, 0, 0.3, 8.6, 0.08, WOOD_D, n=6, caps=False)
    # ring bar
    Rb0, Rb1 = 3.0, 4.0
    gap = 0.55  # radians of walk-through at the back
    nb = 22
    for i in range(nb):
        a0 = gap + (math.tau - 2 * gap) * i / nb - math.pi / 2 + math.pi
        a1 = gap + (math.tau - 2 * gap) * (i + 1) / nb - math.pi / 2 + math.pi
        c = jitter(hexc("#a56b3b"), m.rng, 0.1)
        for r, flip in ((Rb1, False), (Rb0, True)):
            pts = [m.P(math.cos(a0) * r, F, math.sin(a0) * r), m.P(math.cos(a1) * r, F, math.sin(a1) * r),
                   m.P(math.cos(a1) * r, F + 1.15, math.sin(a1) * r), m.P(math.cos(a0) * r, F + 1.15, math.sin(a0) * r)]
            m.face(pts if flip else pts[::-1], c)
        top = [m.P(math.cos(a0) * (Rb1 + 0.15), F + 1.2, math.sin(a0) * (Rb1 + 0.15)), m.P(math.cos(a1) * (Rb1 + 0.15), F + 1.2, math.sin(a1) * (Rb1 + 0.15)),
               m.P(math.cos(a1) * (Rb0 - 0.1), F + 1.2, math.sin(a1) * (Rb0 - 0.1)), m.P(math.cos(a0) * (Rb0 - 0.1), F + 1.2, math.sin(a0) * (Rb0 - 0.1))]
        m.face(top[::-1], hexc("#7fd0c8"))
        am = (a0 + a1) * 0.5
        cx, cz = math.cos(am) * (Rb0 + Rb1) * 0.5, math.sin(am) * (Rb0 + Rb1) * 0.5
        m.col(cx - 0.62, F, cz - 0.62, cx + 0.62, F + 1.2, cz + 0.62)
    # bottle pyramid in the middle
    for lvl, (r, y) in enumerate(((1.1, F), (0.8, F + 1.1), (0.5, F + 2.1))):
        m.cyl(0, y, 0, r, y + 1.0, r * 0.95, WOOD, n=10)
        for i in range(10 - lvl * 2):
            a = i * math.tau / (10 - lvl * 2)
            c = m.rng.choice([hexc(h) for h in ("#3f8f55", "#d99b2b", "#b23a55", "#3a7fbe")])
            bx, bz = math.cos(a) * (r + 0.07), math.sin(a) * (r + 0.07)
            m.cyl(bx, y + 0.1, bz, 0.06, y + 0.55, 0.06, c, n=5, glow=0.12, caps=False)
            m.cyl(bx, y + 0.55, bz, 0.06, y + 0.8, 0.025, c, n=5, glow=0.12)
    # neon + signboard + fairy lights
    m.push(0, 0, R + 0.15)
    m.box(-4.4, 3.9, -0.1, 4.4, 5.3, 0.04, hexc("#2d6a70"))
    m.box(-4.5, 3.8, -0.12, 4.5, 3.9, 0.08, BAMBOO)
    m.box(-4.5, 5.3, -0.12, 4.5, 5.4, 0.08, BAMBOO)
    m.text("THE BILGE BAR", 0, 4.17, 0.04, 1.0, NEON_PINK, font="Bungee-Regular", glow=0.9, depth=0.05, res=1)
    m.pop()
    for i in range(8):
        a0, a1 = (i + 0.5) * math.tau / 8, (i + 1.5) * math.tau / 8
        A = (math.cos(a0) * (R - 0.7), 4.5, math.sin(a0) * (R - 0.7))
        B = (math.cos(a1) * (R - 0.7), 4.5, math.sin(a1) * (R - 0.7))
        for k in range(7):
            t = (k + 0.5) / 7
            x, z = A[0] + (B[0] - A[0]) * t, A[2] + (B[2] - A[2]) * t
            y = 4.5 - math.sin(t * math.pi) * 0.55
            m.ball(x, y, z, 0.09, [NEON_GOLD, NEON_PINK, NEON_CYAN][k % 3], n=5, rings=3, glow=1.0)
    m.lamp(0, 3.5, 0, radius=11.0, power=0.1, col=(1.0, 0.7, 0.45))
    m.finish(out)


def tiki_hut(out):
    m = LM("tiki_hut", 211)
    F = 0.8
    R = 3.4
    for i in range(6):
        a = i * math.tau / 6 + 0.26
        x, z = math.cos(a) * R, math.sin(a) * R
        bamboo_post(m, x, 0, z, 3.5, r=0.16)
        m.col(x - 0.16, 0, z - 0.16, x + 0.16, 3.5, z + 0.16)
    m.floor_boards(-3.0, -3.0, 3.0, 3.0, F, WOOD_L)
    m.col(-3.0, -0.2, -3.0, 3.0, F, 3.0)
    m.col_ramp((0, 0, 5.0), (0, F, 3.0), 2.4)
    for i in range(6):
        z0, z1 = 3.0 + 2.0 * i / 6, 3.0 + 2.0 * (i + 1) / 6
        y0, y1 = F * (1 - i / 6), F * (1 - (i + 1) / 6)
        m.quad(m.P(-1.2, y1, z1), m.P(1.2, y1, z1), m.P(1.2, y0, z0), m.P(-1.2, y0, z0), jitter(WOOD_L, m.rng, 0.1))
    thatch_cone(m, 0, 3.4, 0, R + 1.2, 3.2, rows=5, n=12)
    # hammock
    a = (-2.4, F + 1.6, -1.4)
    for k in range(10):
        t0, t1 = k / 10, (k + 1) / 10
        y0 = a[1] - math.sin(t0 * math.pi) * 0.9
        y1 = a[1] - math.sin(t1 * math.pi) * 0.9
        c = [CORAL, CREAM, SEA_TEAL][k % 3]
        m.quad(m.P(-2.4 + 4.8 * t0, y0, -1.9), m.P(-2.4 + 4.8 * t1, y1, -1.9), m.P(-2.4 + 4.8 * t1, y1, -0.9), m.P(-2.4 + 4.8 * t0, y0, -0.9), c)
        m.quad(m.P(-2.4 + 4.8 * t1, y1 - 0.02, -1.9), m.P(-2.4 + 4.8 * t0, y0 - 0.02, -1.9), m.P(-2.4 + 4.8 * t0, y0 - 0.02, -0.9), m.P(-2.4 + 4.8 * t1, y1 - 0.02, -0.9), c)
    m.finish(out)


def dock_section(out):
    """12 m pier piece, -z to +z, walkway at y=1.6. Instanced along the shoreline."""
    m = LM("dock_section", 221)
    w, L, y = 2.6, 6.0, 1.6
    m.floor_boards(-w, -L, w, L, y, hexc("#b0845a"), along_x=True, depth=0.2)
    m.box(-w, y - 0.5, -L, -w + 0.3, y - 0.2, L, WOOD_D)
    m.box(w - 0.3, y - 0.5, -L, w, y - 0.2, L, WOOD_D)
    m.col(-w, y - 0.4, -L, w, y, L)
    for z in (-L + 0.6, L - 0.6):
        for sx in (-1, 1):
            m.cyl(sx * (w - 0.1), -8.0, z, 0.22, y + 1.05, 0.2, WOOD_D, n=7)
            m.col(sx * (w - 0.1) - 0.2, y, z - 0.2, sx * (w - 0.1) + 0.2, y + 1.05, z + 0.2)
            m.cyl(sx * (w - 0.1), y + 0.62, z, 0.25, y + 0.72, 0.25, CREAM, n=7, caps=False)
    # rope rail
    for sx in (-1, 1):
        x = sx * (w - 0.1)
        for k in range(8):
            t0, t1 = k / 8, (k + 1) / 8
            z0, z1 = -L + 0.6 + (2 * L - 1.2) * t0, -L + 0.6 + (2 * L - 1.2) * t1
            m.beam((x, y + 0.75 - math.sin(t0 * math.pi) * 0.3, z0), (x, y + 0.75 - math.sin(t1 * math.pi) * 0.3, z1), 0.03, hexc("#d9c49a"))
    m.finish(out)


def dive_tower(out):
    """Three platforms over the deep end. Pure bragging rights."""
    m = LM("dive_tower", 231)
    legs = [(-2.4, -2.4), (2.4, -2.4), (2.4, 2.4), (-2.4, 2.4)]
    col = hexc("#e8e2d0")
    for (x, z) in legs:
        m.box(x - 0.22, -9, z - 0.22, x + 0.22, 15.5, z + 0.22, col)
        m.col(x - 0.22, -9, z - 0.22, x + 0.22, 15.5, z + 0.22)
    for (y, ext, c) in ((5.0, 3.0, SEA_TEAL), (10.0, 4.0, CORAL), (15.0, 5.5, hexc("#ffd23f"))):
        m.box(-2.8, y - 0.25, -2.8, 2.8, y, 2.8, c, sub=2.0)
        m.col(-2.8, y - 0.25, -2.8, 2.8, y, 2.8)
        m.box(-1.0, y - 0.18, 2.8, 1.0, y, 2.8 + ext, c)
        m.col(-1.0, y - 0.18, 2.8, 1.0, y, 2.8 + ext)
        m.box(-1.0, y, 2.8 + ext - 0.1, 1.0, y + 0.06, 2.8 + ext, CREAM)
    # the climb: switchback ramp is a pain to model, so: bounce pads are placed in-game
    m.text("DIVE", 0, 15.4, -2.6, 1.3, CORAL, font="Bungee-Regular", depth=0.1, yaw=180, res=1)
    # rails on top three sides
    for y in (5.0, 10.0, 15.0):
        m.box(-2.8, y + 1.0, -2.85, 2.8, y + 1.1, -2.75, CREAM)
        for sx in (-1, 1):
            m.box(sx * 2.8 - 0.05, y + 1.0, -2.8, sx * 2.8 + 0.05, y + 1.1, 2.8, CREAM)
        for k in range(8):
            x = -2.8 + k * 0.8
            m.box(x - 0.03, y, -2.84, x + 0.03, y + 1.0, -2.78, CREAM)
    m.finish(out)


def lighthouse(out):
    m = LM("lighthouse", 241)
    red = hexc("#d6443a")
    white = hexc("#f6efe0")
    n = 14
    base = hexc("#8d8791")
    m.cyl(0, -2, 0, 7.5, 1.2, 6.5, base, n=12)
    m.col(-5.0, -2, -5.0, 5.0, 1.2, 5.0)
    y = 1.2
    h = 4.0
    for k in range(6):
        r0, r1 = 3.8 - k * 0.32, 3.8 - (k + 1) * 0.32
        m.cyl(0, y, 0, r0, y + h, r1, red if k % 2 else white, n=n, caps=False)
        y += h
    m.col(-2.6, 1.2, -2.6, 2.6, y, 2.6)
    # gallery + lantern room
    m.cyl(0, y, 0, 2.9, y + 0.3, 2.9, INK, n=n)
    for i in range(n):
        a = i * math.tau / n
        m.cyl(math.cos(a) * 2.7, y + 0.3, math.sin(a) * 2.7, 0.04, y + 1.2, 0.04, CREAM, n=4, caps=False)
    m.cyl(0, y + 1.15, 0, 2.75, y + 1.25, 2.75, CREAM, n=n, caps=False)
    m.cyl(0, y + 0.3, 0, 1.5, y + 3.0, 1.5, hexc("#ffe27a"), n=10, glow=1.0, caps=False)
    m.cyl(0, y + 3.0, 0, 2.0, y + 4.4, 0.05, red, n=10)
    m.ball(0, y + 4.55, 0, 0.18, BRASS, n=6, rings=4)
    # door + round windows
    m.box(-0.8, 1.2, 3.55, 0.8, 3.5, 3.8, WOOD_D)
    m.disc(0, 7.0, 3.5, 0.45, hexc("#ffd79a"), n=10, glow=0.4)
    m.disc(0, 14.0, 2.9, 0.4, hexc("#ffd79a"), n=10, glow=0.4)
    m.finish(out)


ALL = ["beach_bar", "tiki_hut", "dock_section", "dive_tower", "lighthouse"]
