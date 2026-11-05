"""Casino district: the Lucky Duck and its machines. Moving parts are DYN_ objects."""
import math

from lm import LM, hexc, jitter, scale_col
from town import BRASS, CREAM, INK, NEON_CYAN, NEON_GOLD, NEON_PINK, WOOD_D, WOOD_L

FELT = hexc("#0f7a4f")
FELT_B = hexc("#1b4fa0")
CARPET_A = hexc("#6a2a80")
CARPET_B = hexc("#8f2f76")
CARPET_C = hexc("#2f9a96")
DARK = hexc("#3d2a55")
PLUM = hexc("#7a3a8a")
STUCCO = hexc("#ece0c6")
SYMBOLS = [hexc(c) for c in ("#e8372f", "#f3c62f", "#f6f0e0", "#3fb24a", "#2f6be0", "#e8372f", "#f3c62f", "#9a3fd0")]


def casino(out):
    """Local +z is the entrance (faces west in town). Local x runs along the street."""
    m = LM("casino", 81)
    W, D, F = 19.0, 12.0, 0.0
    H = 8.5
    wallc = STUCCO
    # carpet: a repeating diamond pattern, big enough to read from the camera
    tile = 1.0
    nx, nz = int(2 * W / tile), int(2 * D / tile)
    for i in range(nx):
        for j in range(nz):
            x, z = -W + i * tile, -D + j * tile
            k = (i + j) % 4
            c = CARPET_C if (i % 6 == 0 or j % 6 == 0) else (CARPET_A if k < 2 else CARPET_B)
            if i % 6 == 3 and j % 6 == 3:
                c = BRASS
            m.quad(m.P(x, 0.02, z + tile), m.P(x + tile, 0.02, z + tile), m.P(x + tile, 0.02, z), m.P(x, 0.02, z), c)
    # walls: red-carpet entrance, porthole windows, and a service door out the back
    dw = 7.0
    gl = (*hexc("#7af0ff"), 0.45)
    ops = [(W - dw / 2, dw, 0.0, 5.0)]
    for k in (2.5, 8.0, 27.0, 32.5):
        ops.append((k, 3.2, 2.2, 5.6))
    m.wall((-W, D), (W, D), 0, 11.5, wallc, ops, frame=hexc("#1f6a68"), glass=gl, inner=PLUM, board=0.5, jit=0.04)
    m.wall((W, D), (W, -D), 0, H + 0.5, wallc, inner=PLUM, board=0.5, jit=0.04, frame=BRASS, glass=gl,
           openings=[(9.5, 5.0, 0.0, 4.2)])
    m.wall((W, -D), (-W, -D), 0, H + 0.5, wallc, inner=PLUM, board=0.5, jit=0.04)
    m.wall((-W, -D), (-W, D), 0, H + 0.5, wallc, inner=PLUM, board=0.5, jit=0.04, frame=BRASS, glass=gl,
           openings=[(9.5, 5.0, 0.0, 4.2)])
    # ceiling with gold coffers
    m.box(-W, H, -D, W, H + 0.2, D, DARK, sub=2.5)
    for i in range(-3, 4):
        m.box(i * 5.2 - 0.12, H - 0.25, -D, i * 5.2 + 0.12, H, D, BRASS)
    for j in range(-2, 3):
        m.box(-W, H - 0.25, j * 4.8 - 0.12, W, H, j * 4.8 + 0.12, BRASS)
    m.box(-W - 0.2, H + 0.5, -D - 0.2, W + 0.2, H + 1.0, D + 0.2, hexc("#1f6a68"))
    m.box(-W - 0.4, H + 1.0, -D - 0.4, W + 0.4, H + 1.25, D + 0.4, BRASS)
    m.box(-W, H + 1.25, -D, W, H + 1.3, D, hexc("#7a7f8c"), sub=4.0)
    # art-deco front: stepped pylons flanking a marquee tower
    for sx in (-1, 1):
        for k, (x0, x1, top) in enumerate(((9.0, 12.5, 14.0), (5.2, 8.6, 17.0))):
            xa, xb = sorted((sx * x0, sx * x1))
            m.box(xa, 0, D - 0.3, xb, top, D + 0.9 + k * 0.35, wallc if k else hexc("#1f8a8a"), sub=3.0)
            m.box(xa - 0.2, top, D - 0.5, xb + 0.2, top + 0.4, D + 1.1 + k * 0.35, BRASS)
            xc = (xa + xb) * 0.5
            m.box(xc - 0.22, 5.6, D + 0.9 + k * 0.35, xc + 0.22, top - 0.6, D + 0.98 + k * 0.35, NEON_PINK if k else NEON_CYAN, glow=0.9)
    # central tower: big sign with chase bulbs
    m.box(-5.0, 5.6, D + 0.2, 5.0, 21.0, D + 1.3, hexc("#1b1030"), sub=3.0)
    m.box(-5.2, 20.9, D, 5.2, 21.4, D + 1.5, BRASS)
    for y in range(6, 21):
        for sx in (-1, 1):
            m.ball(sx * 4.75, y, D + 1.32, 0.13, NEON_GOLD, n=6, rings=3, glow=1.0)
    for x in range(-4, 5):
        m.ball(x * 1.05, 20.75, D + 1.32, 0.13, NEON_GOLD, n=6, rings=3, glow=1.0)
        m.ball(x * 1.05, 5.8, D + 1.32, 0.13, NEON_GOLD, n=6, rings=3, glow=1.0)
    m.text("THE", 0, 17.9, D + 1.3, 1.5, CREAM, font="Limelight-Regular", glow=0.5, depth=0.08)
    m.text("LUCKY", 0, 13.7, D + 1.3, 3.0, NEON_GOLD, font="Limelight-Regular", glow=0.85, depth=0.12)
    m.text("DUCK", 0, 9.3, D + 1.3, 3.5, NEON_PINK, font="Limelight-Regular", glow=0.85, depth=0.12)
    m.text("CASINO", 0, 6.6, D + 1.3, 1.7, NEON_CYAN, font="Bungee-Regular", glow=0.85, depth=0.08, res=1)
    # rooftop duck, eleven metres of pure confidence
    m.push(0, 9.9, -2.0, s=1.0)
    yellow = hexc("#ffd23f")
    m.ball(0, 3.2, 0, 4.2, yellow, n=14, rings=8, sy=0.72)
    m.ball(0, 7.0, 2.2, 2.45, yellow, n=12, rings=7)
    m.push(0, 6.8, 4.5)
    m.box(-1.1, -0.3, -0.2, 1.1, 0.3, 1.8, hexc("#ff8a3d"))
    m.pop()
    for sx in (-1, 1):
        m.ball(sx * 1.05, 7.9, 4.2, 0.42, INK, n=8, rings=4)
        m.ball(sx * 1.2, 8.05, 4.53, 0.13, CREAM, n=5, rings=3)
    m.cyl(0, 8.9, 2.2, 1.9, 9.1, 1.9, INK, n=12)
    m.cyl(0, 9.1, 2.2, 1.15, 10.8, 1.25, INK, n=12)
    m.cyl(0, 9.15, 2.2, 1.27, 9.55, 1.27, hexc("#e8372f"), n=12, caps=False)
    m.pop()
    # marquee canopy over the doors
    m.box(-7.5, 5.0, D, 7.5, 5.6, D + 5.2, hexc("#1b1030"), sub=3.0)
    m.box(-7.7, 5.6, D, 7.7, 5.8, D + 5.4, BRASS)
    m.box(-7.7, 4.8, D + 5.2, 7.7, 5.0, D + 5.4, BRASS)
    for x in range(-7, 8):
        m.ball(x * 1.0, 4.7, D + 5.32, 0.12, NEON_GOLD, n=6, rings=3, glow=1.0)
    for z in range(0, 6):
        for sx in (-1, 1):
            m.ball(sx * 7.6, 4.7, D + z, 0.12, NEON_GOLD, n=6, rings=3, glow=1.0)
    for sx in (-1, 1):
        for z in (D + 2.0, D + 5.0):
            m.cyl(sx * 7.1, 0, z, 0.32, 5.0, 0.26, BRASS, n=10)
            m.col(sx * 7.1 - 0.32, 0, z - 0.32, sx * 7.1 + 0.32, 5.0, z + 0.32)
    # red carpet
    m.box(-2.6, 0, D - 0.3, 2.6, 0.05, D + 9.0, hexc("#b5202f"), faces="Y", sub=2.0)
    m.box(-2.8, 0, D - 0.3, -2.6, 0.06, D + 9.0, BRASS, faces="Y")
    m.box(2.6, 0, D - 0.3, 2.8, 0.06, D + 9.0, BRASS, faces="Y")
    # interior pillars and ring chandeliers
    for x in (-10.4, 10.4):
        for z in (-5.0, 5.0):
            m.cyl(x, 0, z, 0.55, H, 0.42, hexc("#7a2336"), n=10, caps=False)
            m.cyl(x, H - 0.8, z, 0.7, H, 0.9, BRASS, n=10, caps=False)
            m.cyl(x, 0, z, 0.8, 0.5, 0.6, BRASS, n=10)
            m.col(x - 0.55, 0, z - 0.55, x + 0.55, H, z + 0.55)
    for cx, cz in ((-5.0, 0.0), (5.0, 0.0)):
        m.cyl(cx, H - 2.2, cz, 2.2, H - 2.0, 2.2, BRASS, n=18, caps=False)
        m.cyl(cx, H - 1.6, cz, 1.2, H - 1.45, 1.2, BRASS, n=14, caps=False)
        for a in range(14):
            ca, sa = math.cos(a * math.tau / 14), math.sin(a * math.tau / 14)
            m.ball(cx + ca * 2.2, H - 2.35, cz + sa * 2.2, 0.14, hexc("#ffe7b0"), n=6, rings=3, glow=1.0)
        for a in range(4):
            ca, sa = math.cos(a * math.tau / 4 + 0.4), math.sin(a * math.tau / 4 + 0.4)
            m.beam((cx + ca * 2.2, H - 2.1, cz + sa * 2.2), (cx, H - 0.1, cz), 0.03, BRASS)
        m.lamp(cx, H - 2.5, cz, radius=14.0, power=0.16, col=(1.0, 0.75, 0.55))
    m.lamp(-14.0, 3.0, 0.0, radius=10.0, power=0.1, col=(1.0, 0.4, 0.75))
    m.lamp(14.0, 3.0, 0.0, radius=10.0, power=0.1, col=(0.4, 0.8, 1.0))
    # stage alcove for the Lil' Wheel + neon back wall lettering
    m.box(2.0, 0, -D + 0.14, 13.5, 0.6, -D + 4.6, hexc("#7a2336"))
    m.box(2.0, 0.6, -D + 0.14, 13.5, 0.63, -D + 4.6, BRASS, faces="Y")
    m.col(2.0, 0, -D + 0.14, 13.5, 0.6, -D + 4.6)
    m.text("HOUSE ALWAYS WINS", -5.0, 5.4, -D + 0.16, 1.0, NEON_PINK, font="Monoton-Regular", glow=0.95, depth=0.03, res=1)
    # crash wall: giant rocket chart behind the machine (screen is a DYN slab)
    p = m.part("crash_screen")
    p.origin = (-9.5, 2.6, -D + 0.2)
    p.box(-3.5, -1.4, 0.0, 3.5, 1.9, 0.04, hexc("#10203a"), glow=0.25)
    for k in range(18):
        x = -3.3 + k * 0.38
        y = -1.2 + 2.8 * (k / 17.0) ** 2.2
        p.box(x, y, 0.04, x + 0.3, y + 0.14, 0.06, hexc("#46e3ff"), glow=0.95)
    m.room(-W, 0, -D, W, H, D, level=0.13, col=(1.0, 0.8, 0.85))
    m.finish(out)


def slot_machine(out):
    m = LM("slot_machine", 91)
    red = hexc("#c4284f")
    # cabinet: faces +z, 1.5 wide
    m.box(-0.75, 0, -0.55, 0.75, 1.05, 0.55, red)
    m.box(-0.8, 0, -0.6, 0.8, 0.14, 0.6, BRASS)
    m.box(-0.75, 1.05, -0.55, 0.75, 2.5, 0.28, red)
    m.quad(m.P(-0.75, 1.05, 0.55), m.P(0.75, 1.05, 0.55), m.P(0.75, 1.3, 0.28), m.P(-0.75, 1.3, 0.28), scale_col(red, 0.8))
    m.box(-0.8, 2.5, -0.6, 0.8, 2.66, 0.34, BRASS)
    m.box(-0.62, 1.42, 0.28, 0.62, 2.28, 0.31, DARK)
    m.box(-0.7, 1.34, 0.26, 0.7, 1.42, 0.33, BRASS)
    m.box(-0.7, 2.28, 0.26, 0.7, 2.36, 0.33, BRASS)
    m.box(-0.7, 1.34, 0.26, -0.62, 2.36, 0.33, BRASS)
    m.box(0.62, 1.34, 0.26, 0.7, 2.36, 0.33, BRASS)
    # marquee top
    m.box(-0.68, 2.66, -0.5, 0.68, 3.34, 0.25, DARK)
    m.text("777", 0, 2.76, 0.25, 0.55, NEON_GOLD, font="Bungee-Regular", glow=0.95, depth=0.03, res=1)
    for x in (-0.6, -0.3, 0.0, 0.3, 0.6):
        m.ball(x, 3.42, 0.2, 0.07, NEON_PINK, n=5, rings=3, glow=1.0)
    # coin tray + buttons
    m.box(-0.5, 0.42, 0.55, 0.5, 0.66, 0.68, hexc("#3a3a48"))
    m.box(-0.45, 0.48, 0.56, 0.45, 0.64, 0.685, DARK)
    for i, x in enumerate((-0.4, 0.0, 0.4)):
        m.cyl(x, 1.16, 0.46, 0.09, 1.2, 0.09, [NEON_GOLD, NEON_CYAN, NEON_PINK][i], n=8, glow=0.6)
    m.col(-0.8, 0, -0.6, 0.8, 3.3, 0.6)
    # three independently spinning reels (axis = local x)
    for r, x in enumerate((-0.39, 0.0, 0.39)):
        p = m.part(f"reel{r}")
        p.origin = (x, 1.85, 0.14)
        n = 8
        R = 0.3
        w = 0.17
        for i in range(n):
            a0, a1 = i * math.tau / n, (i + 1) * math.tau / n
            A = (0.0, math.cos(a0) * R, math.sin(a0) * R)
            B = (0.0, math.cos(a1) * R, math.sin(a1) * R)
            p.face([p.P(-w, A[1], A[2]), p.P(-w, B[1], B[2]), p.P(w, B[1], B[2]), p.P(w, A[1], A[2])], hexc("#f6efe0"), 0.12)
            am = (a0 + a1) * 0.5
            # symbol: a chunky gem on each face
            ym, zm = math.cos(am) * (R + 0.012), math.sin(am) * (R + 0.012)
            ty, tz = -math.sin(am), math.cos(am)
            s = 0.075
            p.face([p.P(-s, ym - ty * s, zm - tz * s), p.P(-s, ym + ty * s, zm + tz * s),
                    p.P(s, ym + ty * s, zm + tz * s), p.P(s, ym - ty * s, zm - tz * s)], SYMBOLS[i], 0.3)
    # the arm
    p = m.part("lever")
    p.origin = (0.86, 1.25, 0.05)
    p.cyl(0, -0.08, 0, 0.09, 0.08, 0.09, hexc("#5a6068"), n=8)
    p.beam((0, 0, 0), (0.06, 0.82, 0), 0.03, hexc("#c0c6d0"))
    p.ball(0.06, 0.9, 0, 0.1, hexc("#e8372f"), n=8, rings=5)
    m.finish(out)


def table_base(m, w, d, felt, rail=hexc("#5a2f1e"), oval=True):
    """Oval (or kidney-ish) casino table with padded rail, felt and a pedestal."""
    n = 26
    rim = [(math.cos(i * math.tau / n) * w, math.sin(i * math.tau / n) * d) for i in range(n)]
    h = 0.92
    for i in range(n):
        ax, az = rim[i]
        bx, bz = rim[(i + 1) % n]
        for (y0, y1, s0, s1, c) in ((h - 0.18, h, 1.0, 1.0, rail), (h, h + 0.09, 1.0, 0.86, hexc("#2a1c28"))):
            m.face([m.P(ax * s1, y1, az * s1), m.P(bx * s1, y1, bz * s1), m.P(bx * s0, y0, bz * s0), m.P(ax * s0, y0, az * s0)][::-1], c)
    m.face([m.P(x * 0.86, h + 0.05, z * 0.86) for (x, z) in rim][::-1], felt)
    m.cyl(0, 0, 0, w * 0.45, 0.06, w * 0.45, INK, n=10)
    m.cyl(0, 0.06, 0, w * 0.2, h - 0.15, w * 0.3, WOOD_D, n=10)
    m.col(-w * 0.86, 0, -d * 0.86, w * 0.86, h + 0.1, d * 0.86)


def chips(m, x, z, y=1.0, n=4, col=None):
    cols = [hexc("#e8372f"), hexc("#2f6be0"), hexc("#f3c62f"), hexc("#111118"), hexc("#3fb24a")]
    c = col or m.rng.choice(cols)
    m.cyl(x, y, z, 0.07, y + n * 0.022, 0.07, c, n=7)


def roulette_table(out):
    m = LM("roulette_table", 101)
    table_base(m, 2.1, 1.2, FELT)
    F = 0.98
    # betting grid
    cols = (hexc("#b5202f"), hexc("#1a1a22"))
    for i in range(12):
        for j in range(3):
            x = -0.4 + i * 0.16
            z = -0.36 + j * 0.24
            m.box(x, F, z, x + 0.15, F + 0.004, z + 0.23, cols[(i + j) % 2], faces="Y")
    m.box(-0.52, F, -0.36, -0.42, F + 0.004, 0.36, FELT, faces="Y")
    for i in range(7):
        chips(m, m.rng.uniform(-0.3, 1.4), m.rng.uniform(-0.3, 0.3), y=F + 0.005, n=m.rng.randint(2, 7))
    # wooden bowl (static) + wheel (spins)
    wx = -1.05
    m.cyl(wx, 0.95, 0, 0.66, 1.12, 0.66, hexc("#4a2415"), n=20)
    m.cyl(wx, 1.12, 0, 0.66, 1.15, 0.56, BRASS, n=20)
    p = m.part("rotor")
    p.origin = (wx, 1.16, 0)
    n = 18
    for i in range(n):
        a0, a1 = i * math.tau / n, (i + 1) * math.tau / n
        c = hexc("#0f7a4f") if i == 0 else (hexc("#b5202f") if i % 2 else hexc("#1a1a22"))
        pts = [p.P(math.cos(a) * r, 0.02, math.sin(a) * r) for (a, r) in ((a1, 0.54), (a0, 0.54), (a0, 0.2), (a1, 0.2))]
        p.face(pts[::-1], c, 0.05)
    p.cyl(0, 0.0, 0, 0.2, 0.1, 0.09, BRASS, n=10)
    p.cyl(0, 0.1, 0, 0.03, 0.26, 0.03, BRASS, n=6)
    p.ball(0, 0.27, 0, 0.05, BRASS, n=6, rings=3)
    m.part("ball").ball(0.45, 0.0, 0, 0.035, CREAM, n=6, rings=3)
    m.dyn["ball"].origin = (wx, 1.2, 0)
    m.finish(out)


def poker_table(out):
    m = LM("poker_table", 111)
    table_base(m, 2.0, 1.15, FELT_B)
    F = 0.98
    for i in range(5):
        x = -0.6 + i * 0.3
        m.box(x - 0.09, F, -0.12, x + 0.09, F + 0.006, 0.13, CREAM, faces="Yz")
    for a in range(6):
        ca, sa = math.cos(a * math.tau / 6), math.sin(a * math.tau / 6)
        x, z = ca * 1.3, sa * 0.72
        chips(m, x, z, y=F, n=m.rng.randint(3, 9))
        chips(m, x + 0.17, z, y=F, n=m.rng.randint(2, 6))
        m.box(x - 0.14, F, z - 0.16 + sa * 0.2, x + 0.14, F + 0.006, z + 0.16 + sa * 0.2, hexc("#b5202f"), faces="Y")
    # pot in the middle: a stupid pile
    for i in range(14):
        chips(m, m.rng.uniform(-0.3, 0.3), m.rng.uniform(0.2, 0.42), y=F, n=m.rng.randint(1, 6))
    m.finish(out)


def blackjack_table(out):
    m = LM("blackjack_table", 121)
    table_base(m, 2.0, 1.0, FELT)
    F = 0.98
    for a in range(5):
        ang = math.radians(25 + a * 32)
        x, z = math.cos(ang) * 1.3, math.sin(ang) * 0.66 - 0.05
        m.cyl(x, F, z, 0.16, F + 0.004, 0.16, CREAM, n=12, caps=True)
        m.cyl(x, F + 0.004, z, 0.13, F + 0.006, 0.13, FELT, n=12)
        chips(m, x, z, y=F + 0.006, n=m.rng.randint(2, 5))
    m.box(-0.5, F, -0.6, 0.5, F + 0.2, -0.3, hexc("#2a1c28"))
    m.box(-0.45, F + 0.2, -0.56, 0.45, F + 0.22, -0.34, hexc("#b5202f"))
    m.text("BLACKJACK PAYS 3 TO 2", 0, F + 0.003, 0.28, 0.13, BRASS, font="Bungee-Regular", depth=0.004, res=1, yaw=0)
    m.finish(out)


def prize_wheel(out):
    """Lil' Wheel: upright 2.6 m radius wheel on a pedestal, 8 segments."""
    m = LM("prize_wheel", 131)
    R = 2.6
    m.box(-1.0, 0, -0.5, 1.0, 0.6, 0.5, hexc("#7a2336"))
    m.box(-0.28, 0.6, -0.28, 0.28, 3.3, 0.28, BRASS)
    m.col(-1.0, 0, -0.5, 1.0, 3.3, 0.5)
    m.cyl(0, 6.0 + 0.0, 0.5, 0.0, 6.0, 0.0, BRASS, n=4, caps=False)
    ptr = [m.P(-0.25, 6.45, 0.35), m.P(0.25, 6.45, 0.35), m.P(0.0, 5.8, 0.35)]
    m.face(ptr, hexc("#e8372f"), 0.4)
    m.face(ptr[::-1], hexc("#e8372f"), 0.4)
    p = m.part("rotor")
    p.origin = (0, 3.3, 0.3)
    segs = [hexc(c) for c in ("#2f9e6b", "#b5202f", "#e6b23c", "#6a2fa0", "#20142a", "#2f9e6b", "#7a1020", "#ffd257")]
    sub = 5
    for i in range(8):
        for k in range(sub):
            a0 = (i + k / sub) * math.tau / 8
            a1 = (i + (k + 1) / sub) * math.tau / 8
            A = p.P(math.sin(a0) * R, math.cos(a0) * R, 0.06)
            B = p.P(math.sin(a1) * R, math.cos(a1) * R, 0.06)
            p.face([p.P(0, 0, 0.06), A, B][::-1], segs[i], 0.14)
    p.cyl(0, -0.06, 0, 0, 0, 0, BRASS, n=4, caps=False)
    # rim + pegs + hub, facing +z
    n = 40
    for i in range(n):
        a0, a1 = i * math.tau / n, (i + 1) * math.tau / n
        for (r0, r1, z0, z1, c) in ((R, R + 0.2, 0.1, 0.1, BRASS), (R + 0.2, R + 0.2, 0.1, -0.1, scale_col(BRASS, 0.75))):
            p.face([p.P(math.sin(a0) * r0, math.cos(a0) * r0, z0), p.P(math.sin(a0) * r1, math.cos(a0) * r1, z1),
                    p.P(math.sin(a1) * r1, math.cos(a1) * r1, z1), p.P(math.sin(a1) * r0, math.cos(a1) * r0, z0)], c)
    for i in range(16):
        a = i * math.tau / 16
        p.ball(math.sin(a) * (R + 0.1), math.cos(a) * (R + 0.1), 0.14, 0.09, NEON_GOLD, n=5, rings=3, glow=1.0 if i % 2 else 0.2)
    p.push(0, 0, 0.12)
    p.disc(0, 0, 0, 0.42, BRASS, n=14)
    p.pop()
    m.finish(out)


def crash_cabinet(out):
    m = LM("crash_cabinet", 141)
    m.box(-1.3, 0, -0.5, 1.3, 1.0, 0.7, hexc("#20142a"))
    m.box(-1.35, 1.0, -0.55, 1.35, 1.1, 0.75, BRASS)
    for x in (-0.7, 0.0, 0.7):
        m.cyl(x, 1.1, 0.3, 0.2, 1.2, 0.17, [hexc("#3fb24a"), hexc("#f3c62f"), hexc("#e8372f")][int((x + 0.7) / 0.7)], n=10, glow=0.5)
    m.text("CASH OUT!", 0, 0.42, 0.7, 0.33, NEON_GOLD, font="Bungee-Regular", glow=0.7, depth=0.02, res=1)
    # little rocket on a stalk, ready to disappoint you
    m.cyl(-1.0, 1.1, -0.1, 0.05, 2.2, 0.05, hexc("#5a6068"), n=6, caps=False)
    m.col(-1.35, 0, -0.55, 1.35, 1.2, 0.75)
    m.finish(out)


def duck_track(out):
    """Four-lane mechanical duck derby, 9 m long, ducks are DYN parts."""
    m = LM("duck_track", 151)
    L, W = 4.6, 1.5
    m.box(-L - 0.3, 0, -W - 0.3, L + 0.3, 0.9, W + 0.3, hexc("#5a2f1e"))
    m.box(-L - 0.35, 0.9, -W - 0.35, L + 0.35, 1.02, W + 0.35, BRASS)
    m.box(-L, 1.0, -W, L, 1.03, W, hexc("#2f9fd8"), glow=0.1, sub=1.5)
    for k in range(5):
        z = -W + k * (2 * W / 4)
        m.box(-L, 1.03, z - 0.02, L, 1.1, z + 0.02, CREAM)
    for i in range(10):
        c = CREAM if i % 2 == 0 else INK
        m.box(L - 0.5, 1.03, -W + i * 0.3, L - 0.2, 1.04, -W + (i + 1) * 0.3, c, faces="Y")
    m.col(-L - 0.35, 0, -W - 0.35, L + 0.35, 1.02, W + 0.35)
    ducks = [hexc("#ffd23f"), hexc("#ff7ab6"), hexc("#7bdcff"), hexc("#9ae66e")]
    for i in range(4):
        p = m.part(f"duck{i}")
        p.origin = (-L + 0.7, 1.05, -W + 0.375 + i * 0.75)
        c = ducks[i]
        p.ball(0, 0.16, 0, 0.26, c, n=8, rings=5, sy=0.72)
        p.ball(0.16, 0.42, 0, 0.16, c, n=7, rings=4)
        p.box(0.28, 0.36, -0.06, 0.42, 0.42, 0.06, hexc("#ff8a3d"))
        p.ball(0.22, 0.5, 0.1, 0.03, INK, n=4, rings=3)
        p.ball(0.22, 0.5, -0.1, 0.03, INK, n=4, rings=3)
    m.finish(out)


ALL = ["casino", "slot_machine", "roulette_table", "poker_table", "blackjack_table", "prize_wheel", "crash_cabinet", "duck_track"]
