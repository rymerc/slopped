"""Chaos / activity district: fairground, cannon, big duck, spiral slide, yard landmarks."""
import math

from lm import LM, hexc, jitter, scale_col
from town import BRASS, CREAM, INK, NEON_CYAN, NEON_GOLD, NEON_PINK, WOOD, WOOD_D, WOOD_L

RED = hexc("#e04a4a")
BLUE = hexc("#3ec1ff")
YEL = hexc("#ffd23f")
PINK = hexc("#ff5fa2")
PURP = hexc("#8b5cf6")
GRN = hexc("#7ccf4e")
STEEL = hexc("#b9c2d0")


def ferris_wheel(out):
    """DYN_rotor spins about local z; DYN_car* are counter-rotated gondolas."""
    m = LM("ferris_wheel", 301)
    R = 13.0
    hub = R + 3.0
    for sz in (-1.6, 1.6):
        for sx in (-1, 1):
            m.beam((sx * 6.0, 0, sz * 1.6), (0, hub, sz), 0.26, STEEL)
            m.col(sx * 6.0 - 0.4, 0, sz * 1.6 - 0.4, sx * 6.0 + 0.4, 3.0, sz * 1.6 + 0.4)
    m.box(-7.5, 0, -3.4, 7.5, 0.4, 3.4, hexc("#6a5c90"), sub=3.0)
    m.col(-7.5, 0, -3.4, 7.5, 0.4, 3.4)
    m.beam((0, hub, -2.2), (0, hub, 2.2), 0.3, INK)
    r = m.part("rotor")
    r.origin = (0, hub, 0)
    n = 12
    for side in (-1.0, 1.0):
        for i in range(n * 2):
            a0, a1 = i * math.tau / (n * 2), (i + 1) * math.tau / (n * 2)
            p0, p1 = (math.cos(a0) * R, math.sin(a0) * R, side), (math.cos(a1) * R, math.sin(a1) * R, side)
            r.beam(p0, p1, 0.11, PINK if i % 2 else YEL)
            r.ball(p0[0], p0[1], side * 1.08, 0.14, NEON_GOLD if i % 2 else NEON_CYAN, n=5, rings=3, glow=1.0)
        for i in range(n):
            a = i * math.tau / n
            r.beam((0, 0, side * 0.6), (math.cos(a) * R, math.sin(a) * R, side), 0.07, STEEL)
    for i in range(n):
        a = i * math.tau / n
        r.beam((math.cos(a) * R, math.sin(a) * R, -1.0), (math.cos(a) * R, math.sin(a) * R, 1.0), 0.06, STEEL)
    cols = [RED, BLUE, YEL, PINK, GRN, PURP]
    for i in range(n):
        c = m.part(f"car{i}")
        a = i * math.tau / n
        c.origin = (math.cos(a) * R, hub + math.sin(a) * R, 0)
        col = cols[i % len(cols)]
        c.box(-0.8, -2.0, -0.7, 0.8, -1.3, 0.7, col)
        c.box(-0.86, -1.32, -0.76, 0.86, -1.22, 0.76, CREAM)
        for sx in (-1, 1):
            for sz in (-1, 1):
                c.beam((sx * 0.7, -1.25, sz * 0.6), (0, 0, sz * 0.4), 0.03, STEEL)
        c.box(-0.95, -0.25, -0.85, 0.95, -0.15, 0.85, scale_col(col, 0.8))
    m.finish(out)


def carousel(out):
    """DYN_top spins: canopy + galloping rubber ducks on poles."""
    m = LM("carousel", 311)
    R = 7.0
    m.cyl(0, 0, 0, R + 0.5, 0.45, R + 0.5, hexc("#6a5c90"), n=20)
    m.col(-R, 0, -R, R, 0.45, R)
    m.col_ramp((0, 0, R + 2.4), (0, 0.45, R + 0.2), 3.0)
    m.cyl(0, 0.45, 0, 1.6, 6.0, 1.3, hexc("#c4284f"), n=12)
    m.col(-1.5, 0.45, -1.5, 1.5, 6.0, 1.5)
    t = m.part("top")
    t.origin = (0, 0, 0)
    n = 16
    for i in range(n):
        a0, a1 = i * math.tau / n, (i + 1) * math.tau / n
        c = RED if i % 2 else CREAM
        A = t.P(math.cos(a0) * (R + 0.6), 5.6, math.sin(a0) * (R + 0.6))
        B = t.P(math.cos(a1) * (R + 0.6), 5.6, math.sin(a1) * (R + 0.6))
        C = t.P(0, 8.4, 0)
        t.face([C, B, A], c)
        t.face([A, B, C], scale_col(c, 0.7))
        hang = [t.P(math.cos(a0) * (R + 0.6), 5.6, math.sin(a0) * (R + 0.6)), t.P(math.cos(a1) * (R + 0.6), 5.6, math.sin(a1) * (R + 0.6)),
                t.P(math.cos(a1) * (R + 0.6), 5.0, math.sin(a1) * (R + 0.6)), t.P(math.cos(a0) * (R + 0.6), 5.0, math.sin(a0) * (R + 0.6))]
        t.face(hang[::-1], YEL if i % 2 else PINK)
        t.face(hang, YEL if i % 2 else PINK)
        am = (a0 + a1) * 0.5
        t.ball(math.cos(am) * (R + 0.65), 4.95, math.sin(am) * (R + 0.65), 0.12, NEON_GOLD, n=5, rings=3, glow=1.0)
    t.cyl(0, 8.3, 0, 0.1, 9.6, 0.04, BRASS, n=6)
    t.ball(0, 9.7, 0, 0.3, YEL, n=8, rings=4, glow=0.3)
    cols = [YEL, PINK, BLUE, GRN]
    for i in range(8):
        a = i * math.tau / 8
        x, z = math.cos(a) * 5.0, math.sin(a) * 5.0
        c = cols[i % 4]
        t.cyl(x, 0.45, z, 0.05, 5.6, 0.05, BRASS, n=5, caps=False)
        t.push(x, 1.5 + (i % 2) * 0.5, z, yaw=-math.degrees(a))
        t.ball(0, 0, 0, 0.75, c, n=8, rings=5, sy=0.7)
        t.ball(0, 0.75, 0.42, 0.42, c, n=7, rings=4)
        t.box(-0.16, 0.65, 0.78, 0.16, 0.77, 1.05, hexc("#ff8a3d"))
        t.ball(-0.2, 0.9, 0.7, 0.06, INK, n=4, rings=3)
        t.ball(0.2, 0.9, 0.7, 0.06, INK, n=4, rings=3)
        t.pop()
    m.finish(out)


def big_cannon(out):
    """HUMAN CANNON. Fires you at the beach. No refunds, see saloon."""
    m = LM("big_cannon", 321)
    m.box(-2.6, 0, -3.2, 2.6, 0.7, 3.2, hexc("#6e4326"))
    m.col(-2.6, 0, -3.2, 2.6, 0.7, 3.2)
    for sx in (-1, 1):
        m.push(sx * 2.7, 1.5, -0.2)
        for k in range(12):
            a0, a1 = k * math.tau / 12, (k + 1) * math.tau / 12
            m.beam((0, math.cos(a0) * 1.45, math.sin(a0) * 1.45), (0, math.cos(a1) * 1.45, math.sin(a1) * 1.45), 0.13, RED)
        for k in range(6):
            a = k * math.tau / 6
            m.beam((0, 0, 0), (0, math.cos(a) * 1.45, math.sin(a) * 1.45), 0.07, YEL)
        m.pop()
    m.push(0, 1.9, 0, pitch=-42.0)
    n = 14
    # barrel: runs along local +z
    ring = lambda z, r: [m.P(math.cos(i * math.tau / n) * r, math.sin(i * math.tau / n) * r, z) for i in range(n)]
    prof = [(-2.8, 1.25), (-1.2, 1.35), (2.6, 1.0), (4.6, 0.95), (4.7, 1.25), (5.3, 1.25)]
    for k in range(len(prof) - 1):
        A, B = ring(*prof[k]), ring(*prof[k + 1])
        col = hexc("#3a3a48") if k != 3 else BRASS
        for i in range(n):
            j = (i + 1) % n
            m.face([A[i], A[j], B[j], B[i]][::-1], col)
    m.face(ring(*prof[0])[::-1], hexc("#3a3a48"))
    m.face(ring(5.3, 0.95), INK)
    for z in (-1.8, 0.5, 2.4):
        A, B = ring(z, 1.42), ring(z + 0.35, 1.42)
        for i in range(n):
            j = (i + 1) % n
            m.face([A[i], A[j], B[j], B[i]][::-1], YEL)
    m.pop()
    m.box(-2.2, 0.7, 2.2, 2.2, 3.2, 2.5, hexc("#6e4326"))
    m.text("HUMAN CANNON", 0, 1.1, 2.5, 0.52, YEL, font="Bungee-Regular", depth=0.05, res=1)
    # step up to the breech
    m.col_ramp((0, 0, -6.4), (0, 0.7, -3.2), 3.0)
    for i in range(6):
        z0, z1 = -6.4 + 3.2 * i / 6, -6.4 + 3.2 * (i + 1) / 6
        y0, y1 = 0.7 * i / 6, 0.7 * (i + 1) / 6
        m.quad(m.P(-1.5, y0, z0), m.P(-1.5, y1, z1), m.P(1.5, y1, z1), m.P(1.5, y0, z0), jitter(WOOD, m.rng, 0.1))
    m.finish(out)


def giant_duck(out):
    """Summit landmark, 11 m tall, visible from the whole island."""
    m = LM("giant_duck", 331)
    yellow = hexc("#ffd23f")
    m.ball(0, 3.6, 0, 5.2, yellow, n=18, rings=11, sy=0.7)
    m.ball(0, 3.2, -4.4, 2.0, yellow, n=10, rings=6, sy=0.8)   # tail
    m.ball(0, 8.6, 2.8, 3.1, yellow, n=16, rings=9)
    m.box(-1.4, 7.9, 5.4, 1.4, 8.8, 7.8, hexc("#ff8a3d"))
    m.box(-1.2, 7.55, 5.4, 1.2, 7.9, 7.3, hexc("#e8702a"))
    for sx in (-1, 1):
        m.ball(sx * 1.45, 9.9, 5.2, 0.62, CREAM, n=10, rings=6)
        m.ball(sx * 1.6, 10.0, 5.72, 0.3, INK, n=8, rings=5)
        m.ball(sx * 5.0, 4.1, 0.2, 1.7, yellow, n=10, rings=6, sy=0.75)
    # party hat: it earned it
    m.cyl(0, 11.2, 2.4, 1.3, 13.9, 0.0, hexc("#ff5fa2"), n=10)
    m.ball(0, 14.0, 2.4, 0.34, NEON_CYAN, n=7, rings=4, glow=0.5)
    m.col(-4.0, 0, -4.0, 4.0, 7.0, 4.0)
    m.finish(out)


def spiral_slide(out):
    """Helter-skelter tower: walk up the ramp inside... or get launched to the top."""
    m = LM("spiral_slide", 341)
    R0, R1 = 3.0, 5.6
    H = 14.0
    turns = 2.5
    n = int(turns * 16)
    cols = [PINK, YEL, BLUE, GRN]
    m.cyl(0, 0, 0, R0 + 0.2, H + 0.4, R0 - 0.3, hexc("#f2dfb8"), n=14, caps=False)
    for k in range(8):
        y = k * 2.0
        m.cyl(0, y, 0, R0 + 0.26 - k * 0.05, y + 1.0, R0 + 0.21 - k * 0.05, RED, n=14, caps=False)
    m.col(-R0, 0, -R0, R0, H, R0)
    for i in range(n):
        t0, t1 = i / n, (i + 1) / n
        a0, a1 = t0 * turns * math.tau, t1 * turns * math.tau
        y0, y1 = H * (1 - t0) + 0.2, H * (1 - t1) + 0.2
        c = cols[(i // 4) % 4]
        p = lambda a, r, y: m.P(math.cos(a) * r, y, math.sin(a) * r)
        m.face([p(a0, R0, y0), p(a1, R0, y1), p(a1, R1, y1), p(a0, R1, y0)][::-1], c)
        m.face([p(a0, R0, y0 - 0.1), p(a1, R0, y1 - 0.1), p(a1, R1, y1 - 0.1), p(a0, R1, y0 - 0.1)], scale_col(c, 0.6))
        m.face([p(a0, R1, y0), p(a1, R1, y1), p(a1, R1, y1 + 0.5), p(a0, R1, y0 + 0.5)][::-1], scale_col(c, 0.85))
        m.face([p(a0, R1 - 0.05, y0 + 0.5), p(a1, R1 - 0.05, y1 + 0.5), p(a1, R1 - 0.05, y1), p(a0, R1 - 0.05, y0)][::-1], scale_col(c, 0.85))
        # collision: a tilted slab per step
        amid = (a0 + a1) * 0.5
        mid_r = (R0 + R1) * 0.5
        am = (math.cos(a0) * mid_r, y0, math.sin(a0) * mid_r)
        bm = (math.cos(a1) * mid_r, y1, math.sin(a1) * mid_r)
        m.col_ramp(am, bm, R1 - R0 + 0.2, t=0.25)
        if i % 2 == 0:
            m.cyl(math.cos(amid) * (R1 - 0.2), 0, math.sin(amid) * (R1 - 0.2), 0.1, (y0 + y1) * 0.5, 0.1, WOOD_L, n=5, caps=False)
    # top platform + flag
    m.cyl(0, H + 0.4, 0, R0 + 0.8, H + 0.7, R0 + 0.8, hexc("#6a5c90"), n=14)
    m.col(-R0 - 0.5, H + 0.4, -R0 - 0.5, R0 + 0.5, H + 0.7, R0 + 0.5)
    m.cyl(0, H + 0.7, 0, R0 + 1.2, H + 3.4, 0.08, RED, n=14)
    m.finish(out)


def ticket_booth(out):
    m = LM("ticket_booth", 351)
    m.box(-1.8, 0, -1.6, 1.8, 2.8, 1.6, hexc("#ff7a5c"))
    m.box(-1.2, 1.1, 1.6, 1.2, 2.3, 1.63, hexc("#ffe0a8"), glow=0.3)
    m.box(-1.95, 2.8, -1.75, 1.95, 3.0, 1.75, CREAM)
    for i in range(10):
        c = RED if i % 2 else CREAM
        x0, x1 = -2.2 + i * 0.44, -2.2 + (i + 1) * 0.44
        m.quad(m.P(x0, 2.8, 2.5), m.P(x1, 2.8, 2.5), m.P(x1, 3.6, 1.4), m.P(x0, 3.6, 1.4), c)
        m.quad(m.P(x1, 2.78, 2.5), m.P(x0, 2.78, 2.5), m.P(x0, 3.58, 1.4), m.P(x1, 3.58, 1.4), scale_col(c, 0.7))
    m.box(-1.5, 3.0, -0.8, 1.5, 4.3, -0.65, hexc("#3d2a55"))
    m.text("TICKETS", 0, 3.3, -0.65, 0.62, NEON_GOLD, font="Bungee-Regular", glow=0.8, depth=0.04, res=1)
    m.col(-1.95, 0, -1.75, 1.95, 3.0, 1.75)
    m.finish(out)


ALL = ["ferris_wheel", "carousel", "big_cannon", "giant_duck", "spiral_slide", "ticket_booth"]
