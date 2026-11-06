"""Casino district: the Lucky Duck and its machines. Moving parts are DYN_ objects."""
import math

from lm import LM, hexc, jitter, scale_col
from town import BRASS, CREAM, INK, NEON_CYAN, NEON_GOLD, NEON_PINK, WOOD_D, WOOD_L

FELT = hexc("#1f9a68")
FELT_B = hexc("#2a66c4")
CARPET_A = hexc("#6a2a80")
CARPET_B = hexc("#8f2f76")
CARPET_C = hexc("#2f9a96")
DARK = hexc("#3d2a55")
PLUM = hexc("#7a3a8a")
STUCCO = hexc("#ece0c6")
# face order matches CasinoFloorFx.SYMBOL_FACE: 0 cherry, 1 bell, 3 lemon, 4 seven, 7 skull
SYMBOLS = [hexc(c) for c in ("#e8372f", "#f3c62f", "#f6f0e0", "#c8e03f", "#2f6be0", "#e8372f", "#f3c62f", "#9a3fd0")]


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
    m.box(-5.0, 5.6, D + 0.2, 5.0, 21.0, D + 1.3, hexc("#33245a"), sub=3.0)
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
    m.box(-7.5, 5.0, D, 7.5, 5.6, D + 5.2, hexc("#33245a"), sub=3.0)
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
    m.room(-W, 0, -D, W, H, D, level=0.13, col=(1.0, 0.8, 0.85))
    m.finish(out)


def _symbol(p, i):
    """Draws reel symbol i on a face. Frame: +z out of the reel, y up the symbol.
    Face order matches CasinoFloorFx.SYMBOL_FACE."""
    red, gold, green = hexc("#e8272f"), hexc("#f7c531"), hexc("#3fa84a")
    kind = ("cherry", "bell", "bar", "lemon", "seven", "cherry", "bell", "skull")[i]
    if kind == "cherry":
        p.ball(-0.07, -0.05, 0.04, 0.075, red, n=7, rings=4, glow=0.12)
        p.ball(0.07, -0.07, 0.04, 0.075, red, n=7, rings=4, glow=0.12)
        p.beam((-0.07, 0.0, 0.05), (0.02, 0.11, 0.03), 0.009, green)
        p.beam((0.07, -0.02, 0.05), (0.02, 0.11, 0.03), 0.009, green)
        p.ball(0.07, 0.11, 0.03, 0.04, green, n=6, rings=3, sy=0.5)
    elif kind == "bell":
        p.cyl(0, -0.08, 0.03, 0.115, 0.03, 0.065, gold, n=9, glow=0.1)
        p.cyl(0, 0.03, 0.03, 0.065, 0.1, 0.02, gold, n=9, glow=0.1)
        p.ball(0, -0.1, 0.03, 0.028, hexc("#a8701f"), n=6, rings=3)
    elif kind == "bar":
        p.box(-0.125, -0.06, 0.012, 0.125, 0.06, 0.03, hexc("#16121c"))
        p.text("BAR", 0, -0.04, 0.03, 0.105, hexc("#f7c531"), font="Bungee-Regular", depth=0.006, glow=0.2, res=1)
    elif kind == "lemon":
        p.push(0, 0, 0.04, roll=25)
        p.ball(0, 0, 0, 0.1, hexc("#f4e13a"), n=8, rings=5, sy=0.74, glow=0.12)
        p.ball(0, 0.085, 0, 0.022, hexc("#c8a81f"), n=5, rings=3)
        p.pop()
    elif kind == "seven":
        p.text("7", 0, -0.115, 0.016, 0.33, red, font="Bungee-Regular", depth=0.02, glow=0.3, back=hexc("#7a1016"), res=1)
    else:  # skull
        bone = hexc("#f3efe4")
        p.ball(0, 0.025, 0.035, 0.09, bone, n=8, rings=5, glow=0.08)
        p.box(-0.05, -0.095, 0.03, 0.05, -0.045, 0.085, bone)
        for sx in (-1, 1):
            p.ball(sx * 0.038, 0.02, 0.112, 0.024, INK, n=6, rings=3)
        for k in range(3):
            p.box(-0.032 + k * 0.024, -0.095, 0.085, -0.022 + k * 0.024, -0.05, 0.088, INK)


def _slot(out, name, seed, body, trim, title, tag, title_col, tag_col):
    """A full slot cabinet with modelled reel symbols. Faces +z, 1.7 m wide."""
    m = LM(name, seed)
    dark = hexc("#241a2e")
    W = 0.85
    # base, kick plate, belly, angled deck
    m.box(-W, 0, -0.6, W, 0.16, 0.62, hexc("#16121c"))
    m.box(-W + 0.02, 0.16, -0.58, W - 0.02, 1.08, 0.58, body)
    m.box(-W, 1.08, -0.6, W, 1.14, 0.64, trim)
    m.quad(m.P(-W, 1.14, 0.64), m.P(W, 1.14, 0.64), m.P(W, 1.42, 0.3), m.P(-W, 1.42, 0.3), scale_col(body, 0.75))
    # belly glass with the pay table
    m.box(-0.66, 0.34, 0.58, 0.66, 0.98, 0.6, dark)
    m.box(-0.7, 0.3, 0.57, 0.7, 0.34, 0.62, trim)
    m.box(-0.7, 0.98, 0.57, 0.7, 1.02, 0.62, trim)
    for i, (t, c) in enumerate((("7 7 7   JACKPOT", NEON_GOLD), ("BAR BAR BAR   20", NEON_PINK), ("ANY PAIR   15", NEON_CYAN))):
        m.text(t, 0, 0.81 - i * 0.19, 0.6, 0.125, c, font="Bungee-Regular", depth=0.006, glow=0.75, res=1)
    # upper cabinet + reel window, deep bezel so the reels sit inside it
    m.box(-W + 0.02, 1.42, -0.58, W - 0.02, 2.5, 0.26, body)
    m.box(-0.74, 1.4, 0.2, 0.74, 2.42, 0.24, hexc("#0c0910"))
    for (x0, y0, x1, y1) in ((-0.8, 1.32, 0.8, 1.42), (-0.8, 2.36, 0.8, 2.48), (-0.8, 1.32, -0.7, 2.48), (0.7, 1.32, 0.8, 2.48)):
        m.box(x0, y0, 0.2, x1, y1, 0.5, trim)
    for x in (-0.205, 0.205):
        m.box(x - 0.012, 1.42, 0.24, x + 0.012, 2.36, 0.46, hexc("#16121c"))
    m.box(-0.7, 1.84, 0.46, 0.7, 1.858, 0.47, hexc("#ff3b3b"), glow=0.8)  # pay line
    # credit meter, buttons, coin tray
    m.box(-0.6, 1.2, 0.5, -0.1, 1.31, 0.53, hexc("#0a200f"))
    m.text("CREDIT", -0.35, 1.215, 0.53, 0.08, hexc("#5dff7a"), font="Bungee-Regular", depth=0.004, glow=0.9, res=1)
    for i, x in enumerate((0.1, 0.32, 0.54)):
        m.cyl(x, 1.27, 0.46, 0.08, 1.31, 0.08, [NEON_GOLD, NEON_CYAN, NEON_PINK][i], n=9, glow=0.8)
    m.box(-0.5, 0.1, 0.58, 0.5, 0.28, 0.76, hexc("#8d93a0"))
    m.box(-0.45, 0.16, 0.6, 0.45, 0.28, 0.72, hexc("#16121c"))
    for k in range(7):
        x = -0.34 + k * 0.11
        m.cyl(x, 0.16 + (k % 2) * 0.02, 0.66, 0.05, 0.18 + (k % 2) * 0.02, 0.05, hexc("#ffd257"), n=7)
    # LED edge strips
    for sx in (-1, 1):
        for k in range(12):
            m.ball(sx * (W + 0.005), 0.25 + k * 0.19, 0.46, 0.035, title_col if k % 2 else tag_col, n=5, rings=3, glow=1.0)
    # topper: backlit sign and a dome
    m.box(-W, 2.5, -0.6, W, 2.58, 0.3, trim)
    m.box(-0.8, 2.58, -0.5, 0.8, 3.38, 0.24, hexc("#33245a"))
    m.box(-0.84, 3.38, -0.54, 0.84, 3.46, 0.28, trim)
    m.text(title, 0, 2.86, 0.24, 0.34, title_col, font="Limelight-Regular", glow=0.95, depth=0.03)
    m.text(tag, 0, 2.64, 0.24, 0.15, tag_col, font="Bungee-Regular", glow=0.9, depth=0.02, res=1)
    m.cyl(0, 3.46, -0.1, 0.42, 3.56, 0.42, trim, n=12)
    m.ball(0, 3.56, -0.1, 0.36, title_col, n=10, rings=5, sy=0.75, glow=0.65)
    m.col(-W, 0, -0.6, W, 3.46, 0.64)
    # three reels, every symbol a real shape
    for r, x in enumerate((-0.41, 0.0, 0.41)):
        p = m.part(f"reel{r}")
        p.origin = (x, 1.85, 0.02)
        n = 8
        RR, w = 0.37, 0.19
        for i in range(n):
            a0, a1 = i * math.tau / n, (i + 1) * math.tau / n
            A = (math.cos(a0) * RR, math.sin(a0) * RR)
            B = (math.cos(a1) * RR, math.sin(a1) * RR)
            p.face([p.P(-w, A[0], A[1]), p.P(-w, B[0], B[1]), p.P(w, B[0], B[1]), p.P(w, A[0], A[1])], hexc("#f6efe0"), 0.05)
            am = (a0 + a1) * 0.5
            ap = RR * math.cos(math.pi / n)
            p.push(0, math.cos(am) * ap, math.sin(am) * ap, pitch=math.degrees(am) - 90.0)
            _symbol(p, i)
            p.pop()
    p = m.part("lever")
    p.origin = (0.95, 1.3, 0.05)
    p.cyl(0, -0.09, 0, 0.1, 0.09, 0.1, hexc("#8d93a0"), n=8)
    p.beam((0, 0, 0), (0.06, 0.95, 0), 0.032, hexc("#d5dae3"))
    p.ball(0.06, 1.03, 0, 0.12, hexc("#e8272f"), n=9, rings=5)
    m.finish(out)


def slot_duck(out):
    _slot(out, "slot_duck", 91, hexc("#c4284f"), BRASS, "LUCKY DUCK", "quack for cash", NEON_GOLD, NEON_CYAN)


def slot_skull(out):
    _slot(out, "slot_skull", 92, hexc("#3a2a6a"), hexc("#c0c6d0"), "BONE ZONE", "dead certain", NEON_CYAN, NEON_PINK)


def slot_soup(out):
    _slot(out, "slot_soup", 93, hexc("#1f8a6a"), BRASS, "HOT SOUP", "extra ladle", NEON_PINK, NEON_GOLD)


def table_base(m, w, d, felt, rail=hexc("#5a2f1e"), half=False):
    """Casino table: padded rail, felt, pedestal. half=True is the blackjack shape:
    an arc on the players' side (-z) and a straight dealer edge at z=+1."""
    n = 30
    if half:
        rim = [(math.cos(math.pi * i / n) * w, -math.sin(math.pi * i / n) * d) for i in range(n + 1)]
        rim = [(w, 1.0)] + rim + [(-w, 1.0)]
        rim = rim[::-1]
    else:
        rim = [(math.cos(i * math.tau / n) * w, math.sin(i * math.tau / n) * d) for i in range(n)]
    h = 0.92
    k = len(rim)
    for i in range(k):
        ax, az = rim[i]
        bx, bz = rim[(i + 1) % k]
        for (y0, y1, s0, s1, c) in ((h - 0.2, h, 1.0, 1.0, rail), (h, h + 0.1, 1.0, 0.9, hexc("#3a2030"))):
            m.face([m.P(ax * s1, y1, az * s1), m.P(bx * s1, y1, bz * s1), m.P(bx * s0, y0, bz * s0), m.P(ax * s0, y0, az * s0)][::-1], c)
    # felt in rings, so the bake darkens the edge under the rail and not the whole cloth
    ring = (0.9, 0.84, 0.6, 0.3, 0.02)
    for j in range(len(ring) - 1):
        s0, s1 = ring[j], ring[j + 1]
        for i in range(k):
            ax, az = rim[i]
            bx, bz = rim[(i + 1) % k]
            m.face([m.P(ax * s0, h + 0.06, az * s0), m.P(ax * s1, h + 0.06, az * s1),
                    m.P(bx * s1, h + 0.06, bz * s1), m.P(bx * s0, h + 0.06, bz * s0)], felt, 0.05)
    m.face([m.P(x, h - 0.2, z) for (x, z) in rim], rail)
    if half:
        m.box(-w * 0.45, 0, -d * 0.5, w * 0.45, h - 0.2, 0.7, WOOD_D)
        m.col(-w * 0.9, 0, -d * 0.72, w * 0.9, h + 0.1, 1.0)
        m.col(-w * 0.5, 0, -d * 0.96, w * 0.5, h + 0.1, -d * 0.7)
    else:
        m.cyl(0, 0, 0, w * 0.45, 0.06, w * 0.45, INK, n=10)
        m.cyl(0, 0.06, 0, w * 0.2, h - 0.15, w * 0.3, WOOD_D, n=10)
        m.col(-w * 0.86, 0, -d * 0.86, w * 0.86, h + 0.1, d * 0.86)


def chips(m, x, z, y=1.0, n=4, col=None):
    cols = [hexc("#e8372f"), hexc("#2f6be0"), hexc("#f3c62f"), hexc("#111118"), hexc("#3fb24a")]
    c = col or m.rng.choice(cols)
    m.cyl(x, y, z, 0.07, y + n * 0.022, 0.07, c, n=7)


def roulette_table(out):
    m = LM("roulette_table", 101)
    table_base(m, 2.7, 1.5, FELT)
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
    table_base(m, 2.6, 1.5, FELT_B)
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
    """Five seats on the arc (-z); the dealer works the straight edge (+z)."""
    m = LM("blackjack_table", 121)
    table_base(m, 3.3, 2.5, FELT, half=True)
    F = 0.985
    for a in (-60, -30, 0, 30, 60):
        r = math.radians(a)
        x, z = math.sin(r) * 2.15, -math.cos(r) * 1.65
        m.cyl(x, F, z, 0.28, F + 0.004, 0.28, CREAM, n=16)
        m.cyl(x, F + 0.004, z, 0.25, F + 0.006, 0.25, FELT, n=16)
    # printed flat on the felt, reading from the players' side
    m.push(0, F + 0.004, -0.42, yaw=180, pitch=-90)
    m.text("BLACKJACK PAYS 3 TO 2", 0, 0, 0, 0.3, BRASS, font="Bungee-Regular", depth=0.004, res=2)
    m.pop()
    m.push(0, F + 0.004, -0.14, yaw=180, pitch=-90)
    m.text("DEALER STANDS ON 17", 0, 0, 0, 0.2, CREAM, font="Bungee-Regular", depth=0.004, res=1)
    m.pop()
    # chip tray along the dealer edge
    m.box(-1.3, F, 0.58, 1.1, F + 0.05, 0.82, hexc("#2a1c28"))
    cols = [hexc("#e8372f"), hexc("#2f6be0"), hexc("#3fb24a"), hexc("#111118"), hexc("#f3c62f")]
    for i in range(10):
        x = -1.2 + i * 0.24
        for k in range(2):
            m.cyl(x, F + 0.05, 0.64 + k * 0.12, 0.05, F + 0.1, 0.05, cols[i % 5], n=7)
    # the shoe
    m.push(2.0, F, 0.5, yaw=-20)
    m.box(-0.2, 0, -0.42, 0.2, 0.26, 0.42, hexc("#16121c"))
    m.box(-0.17, 0.03, -0.46, 0.17, 0.2, -0.42, hexc("#b5202f"))
    m.pop()
    m.finish(out)


def cards(out):
    """Suit pips + card back. The game builds cards from these parts."""
    m = LM("cards", 125)
    red, blk = hexc("#d3202f"), hexc("#16121c")
    def lobe(p, x, z, r, c):
        p.disc(x, 0.0, z, r, c, n=10, axis="y")
    def tri(p, a, b, c, col):
        p.face([p.P(*a), p.P(*b), p.P(*c)], col)
    h = m.part("s0")  # hearts
    lobe(h, -0.05, -0.04, 0.056, red)
    lobe(h, 0.05, -0.04, 0.056, red)
    tri(h, (-0.102, 0, -0.02), (0.102, 0, -0.02), (0, 0, 0.12), red)
    t = m.part("s1")  # spades
    lobe(t, -0.05, 0.03, 0.056, blk)
    lobe(t, 0.05, 0.03, 0.056, blk)
    tri(t, (0.102, 0, 0.01), (-0.102, 0, 0.01), (0, 0, -0.12), blk)
    tri(t, (0.03, 0, 0.12), (-0.03, 0, 0.12), (0, 0, 0.02), blk)
    d = m.part("s2")  # diamonds
    tri(d, (-0.085, 0, 0), (0.085, 0, 0), (0, 0, 0.12), red)
    tri(d, (0.085, 0, 0), (-0.085, 0, 0), (0, 0, -0.12), red)
    c = m.part("s3")  # clubs
    lobe(c, 0, -0.055, 0.052, blk)
    lobe(c, -0.058, 0.03, 0.052, blk)
    lobe(c, 0.058, 0.03, 0.052, blk)
    tri(c, (0.028, 0, 0.12), (-0.028, 0, 0.12), (0, 0, -0.02), blk)
    b = m.part("back")
    b.box(-0.21, 0, -0.3, 0.21, 0.002, 0.3, hexc("#b5202f"), faces="Y")
    for i in range(5):
        for j in range(7):
            b.ball(-0.16 + i * 0.08, 0.003, -0.24 + j * 0.08, 0.018, hexc("#ffd257"), n=4, rings=2)
    m.box(-0.1, 0, -0.1, 0.1, 0.01, 0.1, hexc("#ffffff"))
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


ALL = ["casino", "slot_duck", "slot_skull", "slot_soup", "roulette_table", "poker_table", "blackjack_table", "cards",
       "prize_wheel", "crash_cabinet", "duck_track"]
