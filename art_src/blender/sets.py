"""Detailed replacements for things the game used to build from plain boxes.

Each model is placed by the game at the coordinates its colliders already use, so
gameplay and collision stay in code and only the look changes. Sizes here must match
the collision shapes noted on each builder.

  props        DYN parts for throwable props, each centred like its collision shape
  g_*          the Gauntlet (west chasm)
  y_*          the Chaos Yard
  m_*          the Meadow
"""
import math

from lm import LM, hexc, jitter, scale_col
from town import BRASS, CREAM, INK, WOOD, WOOD_D, WOOD_L

STEEL = hexc("#9aa3b0")
STEEL_D = hexc("#5d6470")
RED = hexc("#d8433c")
RED_D = hexc("#9e2b27")
YEL = hexc("#f2c230")
ORANGE = hexc("#ff7a2e")
WHITE = hexc("#f4f1ea")
STONE = hexc("#aaa2bd")
STONE_D = hexc("#837b9c")
MOSS = hexc("#5f9a3c")
BARK = hexc("#6e4429")
IRON = hexc("#4a4d58")


# --- helpers -----------------------------------------------------------------------
def lathe(m, prof, n=12, x=0.0, z=0.0, glow=0.0):
    """prof: [(y, r, colour)] bottom to top; the colour paints the band above that ring."""
    P = m.P
    ring = lambda y, r: [P(x + math.cos(math.tau * i / n) * r, y, z + math.sin(math.tau * i / n) * r) for i in range(n)]
    rings = [ring(y, r) for (y, r, _) in prof]
    for k in range(len(prof) - 1):
        A, B, col = rings[k], rings[k + 1], prof[k][2]
        for i in range(n):
            j = (i + 1) % n
            m.face([A[j], A[i], B[i], B[j]], col, glow)
    if prof[0][1] > 0.001:
        m.face(rings[0], prof[0][2], glow)
    if prof[-1][1] > 0.001:
        m.face(list(reversed(rings[-1])), prof[-2][2], glow)


def sphere(m, r, colfn, n=16, rings=10, cx=0.0, cy=0.0, cz=0.0, sx=1.0, sy=1.0, sz=1.0, glow=0.0):
    """colfn(ring, seg) -> colour, so balls can carry stripes and panels."""
    P = m.P
    def pt(j, i):
        lat = -math.pi / 2 + math.pi * j / rings
        lon = math.tau * i / n
        return P(cx + math.cos(lat) * math.cos(lon) * r * sx, cy + math.sin(lat) * r * sy, cz + math.cos(lat) * math.sin(lon) * r * sz)
    for j in range(rings):
        for i in range(n):
            a, b, c, d = pt(j, i + 1), pt(j, i), pt(j + 1, i), pt(j + 1, i + 1)
            m.face([a, b, c, d], colfn(j, i), glow)


def bolts(m, pts, col=STEEL_D, r=0.035):
    for (x, y, z) in pts:
        m.box(x - r, y - r, z - r, x + r, y + r, z + r, col)


def hazard_band(m, x0, x1, y0, y1, z, step=0.35, flip=False):
    """Yellow/black diagonal stripes on a +z face (pushed 0.01 proud)."""
    k = 0
    x = x0
    while x < x1 - 0.01:
        xb = min(x + step, x1)
        m.box(x, y0, z, xb, y1, z + 0.012, YEL if (k % 2 == 0) != flip else INK, faces="Z")
        x = xb
        k += 1


def i_beam(m, a, b, w, col, flange=0.06):
    """Vertical I-beam column from y a to y b, w wide (x) by w deep (z)."""
    h = w * 0.5
    m.box(-h, a, -h, h, b, -h + flange, col)
    m.box(-h, a, h - flange, h, b, h, col)
    m.box(-flange * 0.5, a, -h + flange, flange * 0.5, b, h - flange, scale_col(col, 0.8))


def planks(m, x0, x1, y, z0, z1, col, along_x=True, w=0.28, gap=0.03, t=0.06):
    if along_x:
        z = z0
        while z < z1 - 0.01:
            zb = min(z + w, z1)
            m.box(x0, y - t, z, x1, y, zb - gap, jitter(col, m.rng, 0.09))
            z = zb
    else:
        x = x0
        while x < x1 - 0.01:
            xb = min(x + w, x1)
            m.box(x, y - t, z0, xb - gap, y, z1, jitter(col, m.rng, 0.09))
            x = xb


def rock_column(m, top, r_top, depth, col=STONE, cap=MOSS, n=9):
    """Stacked, slightly offset stone drums from `top` down `depth` metres, mossy on top."""
    y = top
    r = r_top
    first = True
    while y > top - depth:
        h = m.rng.uniform(0.7, 1.25)
        ox, oz = m.rng.uniform(-0.07, 0.07), m.rng.uniform(-0.07, 0.07)
        rb = r * m.rng.uniform(1.0, 1.08)
        c = jitter(col if m.rng.random() > 0.3 else STONE_D, m.rng, 0.1)
        m.push(ox, 0, oz, yaw=m.rng.uniform(0, 40))
        m.cyl(0, y - h, 0, rb, y - 0.04, r, c, n=n)
        m.cyl(0, y - 0.04, 0, r, y, r * 0.96, scale_col(c, 1.12), n=n)  # worn top edge
        m.pop()
        if first:  # moss + tufts round the top
            m.cyl(0, top - 0.02, 0, r * 0.98, top + 0.01, r * 0.9, jitter(cap, m.rng, 0.08), n=n, caps=True)
            for i in range(7):
                a = m.rng.uniform(0, math.tau)
                rr = r * m.rng.uniform(0.75, 0.97)
                m.cyl(math.cos(a) * rr, top, math.sin(a) * rr, 0.06, top + m.rng.uniform(0.12, 0.25), 0.0, jitter(MOSS, m.rng, 0.15), n=4)
            first = False
        y -= h
        r = rb


# --- throwable props (DYN parts) --------------------------------------------------------
def props(out):
    m = LM("props", 501)

    # TNT: cyl r 0.38 h 0.95. A bundle of seven sticks, taped, with a lit fuse.
    p = m.part("tnt")
    for (x, z) in [(0, 0)] + [(math.cos(a) * 0.245, math.sin(a) * 0.245) for a in [k * math.tau / 6 for k in range(6)]]:
        c = jitter(RED, p.rng, 0.06)
        p.cyl(x, -0.46, z, 0.125, 0.43, 0.125, c, n=8)
        p.cyl(x, 0.43, z, 0.125, 0.46, 0.1, hexc("#e8d9b8"), n=8)   # paper end
    for y in (-0.28, 0.24):
        p.cyl(0, y - 0.05, 0, 0.385, y + 0.05, 0.385, hexc("#3a3330"), n=14)   # tape
    p.box(-0.16, -0.12, 0.33, 0.16, 0.12, 0.39, CREAM)
    p.text("TNT", 0, -0.075, 0.39, 0.16, RED_D, font="Bungee-Regular", depth=0.02, res=1)
    p.beam((0, 0.46, 0), (0.06, 0.62, 0.04), 0.018, INK)
    p.beam((0.06, 0.62, 0.04), (0.14, 0.7, 0.02), 0.016, INK)
    p.ball(0.15, 0.71, 0.02, 0.04, hexc("#ffd257"), n=5, rings=3, glow=1.0)

    # playground balls: sphere r 0.45, four colourways, two-tone with a seam band
    for k, (a, b) in enumerate([(RED, WHITE), (hexc("#3a8ee6"), YEL), (hexc("#41b85a"), WHITE), (ORANGE, hexc("#7b4bd6"))]):
        p = m.part("ball%d" % k)
        sphere(p, 0.45, lambda j, i, a=a, b=b: (WHITE if j in (4, 5) else (a if (i // 4) % 2 == 0 else b)), n=16, rings=10)

    # beach balls: r 0.6, six gores + white caps
    gore_sets = [[RED, WHITE, hexc("#3a8ee6"), YEL, hexc("#41b85a"), WHITE],
                 [hexc("#ff5fa2"), WHITE, YEL, hexc("#3ec1ff"), ORANGE, WHITE]]
    for k in range(4):
        p = m.part("beachball%d" % k)
        g = gore_sets[k % 2]
        off = k
        sphere(p, 0.6, lambda j, i, g=g, off=off: WHITE if j in (0, 11) else g[((i // 3) + off) % 6], n=18, rings=12)

    # big ball: r 1.3, pink with a yellow equator and a few dents of colour
    p = m.part("big_ball")
    sphere(p, 1.3, lambda j, i: YEL if j in (6, 7) else (hexc("#ff7ab8") if (i + j) % 7 else hexc("#ffd0e6")), n=22, rings=14)

    # traffic cone: cyl r 0.24 h 0.7, centred. Square base, reflective bands, hollow tip.
    p = m.part("cone")
    p.box(-0.26, -0.35, -0.26, 0.26, -0.3, 0.26, hexc("#d9531c"))
    p.box(-0.24, -0.3, -0.24, 0.24, -0.29, 0.24, hexc("#b8441a"))
    lathe(p, [(-0.29, 0.21, ORANGE), (-0.12, 0.175, WHITE), (-0.04, 0.16, ORANGE), (0.08, 0.13, WHITE),
              (0.15, 0.115, ORANGE), (0.33, 0.045, hexc("#2a2020")), (0.35, 0.04, ORANGE)], n=12)

    # plank: box 3.0 x 0.15 x 0.45. Three boards nailed to two cleats.
    p = m.part("plank")
    for k, z0 in enumerate((-0.225, -0.072, 0.081)):
        c = jitter(hexc("#d2a06a"), p.rng, 0.08)
        p.box(-1.5, -0.01, z0, 1.5, 0.075, z0 + 0.144, c)
        p.box(-1.5, -0.01, z0, -1.49, 0.075, z0 + 0.144, scale_col(c, 0.7))  # end grain
        p.box(1.49, -0.01, z0, 1.5, 0.075, z0 + 0.144, scale_col(c, 0.7))
    for x in (-1.1, 1.1):
        p.box(x - 0.1, -0.075, -0.225, x + 0.1, -0.01, 0.225, hexc("#a8774a"))
        bolts(p, [(x, 0.08, -0.15), (x, 0.08, 0.0), (x, 0.08, 0.15)], hexc("#3a3a40"), 0.015)

    # bowling pin: cyl r 0.17 h 0.9
    p = m.part("pin")
    lathe(p, [(-0.45, 0.1, WHITE), (-0.38, 0.15, WHITE), (-0.2, 0.17, WHITE), (-0.02, 0.14, WHITE), (0.1, 0.075, RED),
              (0.13, 0.07, WHITE), (0.16, 0.068, RED), (0.19, 0.07, WHITE), (0.3, 0.11, WHITE), (0.4, 0.09, WHITE), (0.45, 0.0, WHITE)], n=12)

    # rubber duck: sphere r 0.32 (faces -z)
    p = m.part("duck")
    duck = hexc("#ffd23f")
    sphere(p, 0.3, lambda j, i: jitter(duck, p.rng, 0.03), n=14, rings=8, cy=-0.07, sx=1.15, sy=0.78, sz=1.05)
    sphere(p, 0.2, lambda j, i: duck, n=12, rings=8, cy=0.2, cz=-0.12)
    p.box(-0.09, 0.15, -0.42, 0.09, 0.19, -0.28, ORANGE)   # beak
    p.box(-0.08, 0.12, -0.39, 0.08, 0.15, -0.28, hexc("#e8641a"))
    for sx in (-1, 1):
        p.ball(0.09 * sx, 0.26, -0.29, 0.045, INK, n=6, rings=4)
        p.ball(0.1 * sx, 0.275, -0.32, 0.014, WHITE, n=4, rings=3)
        p.ball(0.24 * sx, -0.04, 0.0, 0.1, scale_col(duck, 0.9), n=6, rings=4, sy=0.6)  # wings
    p.cyl(0, 0.0, 0.3, 0.08, 0.12, 0.02, duck, n=6)  # tail

    # steel beam: box 4 x 0.3 x 0.3. Painted I-section with bolt holes and a lifting eye.
    p = m.part("beam")
    for y0, y1 in ((-0.15, -0.11), (0.11, 0.15)):
        p.box(-2.0, y0, -0.15, 2.0, y1, 0.15, RED_D)
    p.box(-2.0, -0.11, -0.03, 2.0, 0.11, 0.03, scale_col(RED_D, 0.85))
    for x in (-1.6, -0.8, 0.0, 0.8, 1.6):
        p.box(x - 0.05, -0.05, -0.035, x + 0.05, 0.05, 0.035, INK)
    for x in (-2.0, 1.97):
        p.box(x, -0.15, -0.15, x + 0.03, 0.15, 0.15, STEEL_D)

    # log: cyl r 0.38 h 2.4 (on its axis). Bark with rings at the ends.
    p = m.part("log")
    for k in range(8):
        y0, y1 = -1.2 + k * 0.3, -1.2 + (k + 1) * 0.3
        p.cyl(0, y0, 0, 0.38 * p.rng.uniform(0.97, 1.03), y1, 0.38 * p.rng.uniform(0.97, 1.03), jitter(BARK, p.rng, 0.12), n=10, caps=False)
    for y, s in ((-1.2, -1), (1.2, 1)):
        for r, c in ((0.37, hexc("#c99a62")), (0.24, hexc("#b5864f")), (0.1, hexc("#a87a45"))):
            p.cyl(0, y, 0, r, y + 0.005 * s, r, c, n=10)
    p.beam((0.36, 0.3, 0), (0.62, 0.55, 0.05), 0.04, BARK)   # a stub of branch

    # mixer drum: cyl r 1.4 -> 0.9 h 3.6 along y, with spiral fins and stripes
    p = m.part("drum")
    n = 14
    for k in range(6):
        y0, y1 = -1.8 + k * 0.6, -1.8 + (k + 1) * 0.6
        r0, r1 = 1.4 - (0.5 * k / 6), 1.4 - (0.5 * (k + 1) / 6)
        p.cyl(0, y0, 0, r0, y1, r1, ORANGE if k % 2 == 0 else WHITE, n=n, caps=False)
    p.cyl(0, -1.9, 0, 1.2, -1.8, 1.4, STEEL_D, n=n)
    p.cyl(0, 1.8, 0, 0.9, 2.1, 0.55, STEEL_D, n=n)
    for i in range(16):
        a = i * 0.7
        y = -1.6 + i * 0.21
        r = 1.42 - 0.5 * (y + 1.8) / 3.6
        p.box(math.cos(a) * r - 0.06, y, math.sin(a) * r - 0.06, math.cos(a) * r + 0.06, y + 0.18, math.sin(a) * r + 0.06, STEEL_D)

    # wrecking ball: r 1.0 (the game scales it), banded iron with a lifting eye
    p = m.part("wreck")
    iron = hexc("#3d3f4a")
    sphere(p, 1.0, lambda j, i: hexc("#55586a") if j in (5, 6) else jitter(iron, p.rng, 0.06), n=18, rings=12)
    p.push(0, 0, 0, roll=90)
    p.cyl(0, -0.08, 0, 1.03, 0.08, 1.03, hexc("#55586a"), n=18)
    p.pop()
    p.cyl(0, 0.9, 0, 0.32, 1.12, 0.28, hexc("#55586a"), n=10)
    p.push(0, 1.25, 0, roll=90)
    for k in range(10):
        a0, a1 = k * math.tau / 10, (k + 1) * math.tau / 10
        p.beam((math.cos(a0) * 0.2, 0, math.sin(a0) * 0.2), (math.cos(a1) * 0.2, 0, math.sin(a1) * 0.2), 0.05, STEEL_D)
    p.pop()
    for k in range(8):  # scuffs
        a, b = p.rng.uniform(0, math.tau), p.rng.uniform(-0.6, 0.6)
        x, y, z = math.cos(a) * math.cos(b), math.sin(b), math.sin(a) * math.cos(b)
        p.box(x * 1.0 - 0.08, y * 1.0 - 0.08, z * 1.0 - 0.08, x * 1.0 + 0.08, y * 1.0 + 0.08, z * 1.0 + 0.08, hexc("#8a8c96"))

    # crate: unit cube (the game scales it). Planked sides, a frame, a diagonal brace.
    p = m.part("crate")
    pine = hexc("#c9925a")
    for side in range(4):
        p.push(0, 0, 0, yaw=90 * side)
        for k in range(4):
            y0 = -0.5 + k * 0.25
            p.box(-0.46, y0 + 0.01, 0.44, 0.46, y0 + 0.24, 0.48, jitter(pine, p.rng, 0.08))
        p.beam((-0.38, -0.38, 0.49), (0.38, 0.38, 0.49), 0.04, scale_col(pine, 0.8))
        p.pop()
    for (x, z) in ((-0.46, -0.46), (0.46, -0.46), (-0.46, 0.46), (0.46, 0.46)):
        p.box(x - 0.05, -0.5, z - 0.05, x + 0.05, 0.5, z + 0.05, scale_col(pine, 0.75))
    for y in (-0.5, 0.45):
        for k in range(4):
            x0 = -0.46 + k * 0.23
            p.box(x0 + 0.01, y, -0.46, x0 + 0.22, y + 0.05, 0.46, jitter(pine, p.rng, 0.08))
    p.box(-0.44, -0.46, -0.44, 0.44, 0.46, 0.44, scale_col(pine, 0.4))   # dark inside the gaps
    p.text("THIS SIDE UP", 0, -0.08, 0.49, 0.1, hexc("#3a2a20"), font="Bungee-Regular", depth=0.005, res=1)

    m.box(0, 0, 0, 0.01, 0.01, 0.01, STEEL)
    m.finish(out)


# --- the Gauntlet ---------------------------------------------------------------------
def g_pad(out):
    """Start pad: collider box 6 x 0.6 x 6 centred on the origin (top at 0.3)."""
    m = LM("g_pad", 511)
    for (x0, z0, x1, z1) in ((-3, -3, 3, -2.4), (-3, 2.4, 3, 3), (-3, -2.4, -2.4, 2.4), (2.4, -2.4, 3, 2.4)):
        x = x0
        while x < x1 - 0.01:
            xb = min(x + m.rng.uniform(0.6, 1.0), x1)
            z = z0
            while z < z1 - 0.01:
                zb = min(z + m.rng.uniform(0.6, 1.0), z1)
                m.box(x + 0.02, -0.6, z + 0.02, xb - 0.02, 0.3, zb - 0.02, jitter(STONE, m.rng, 0.12))
                z = zb
            x = xb
    planks(m, -2.4, 2.4, 0.3, -2.4, 2.4, hexc("#b88a5a"), along_x=False)
    m.box(-2.4, -0.3, -2.4, 2.4, 0.24, 2.4, WOOD_D, faces="Y")
    m.finish(out)


def g_arch(out):
    """Start arch: posts at z +-2.6 (0.6 square, 5 tall), crossbar at y 5.2 (0.9 tall, 6.2 long)."""
    m = LM("g_arch", 512)
    for sz in (-1, 1):
        z = 2.6 * sz
        m.box(-0.42, 0, z - 0.42, 0.42, 0.5, z + 0.42, STONE_D)   # plinth
        for k in range(9):
            y0, y1 = 0.5 + k * 0.5, 0.5 + (k + 1) * 0.5
            c = RED if k % 2 == 0 else WHITE
            m.box(-0.3, y0, z - 0.3, 0.3, y1, z + 0.3, c)
        for y in (0.5, 2.5, 4.6):
            m.box(-0.34, y, z - 0.34, 0.34, y + 0.1, z + 0.34, BRASS)
        m.ball(0, 6.0, z, 0.22, BRASS, n=8, rings=5)
        m.cyl(0, 5.65, z, 0.06, 6.0, 0.06, BRASS, n=6)
        # pennant
        m.face([m.P(0.0, 7.1, z), m.P(0.0, 6.6, z), m.P(0.0, 6.85, z + 0.9 * sz)], RED if sz > 0 else YEL)
        m.face([m.P(0.0, 6.6, z), m.P(0.0, 7.1, z), m.P(0.0, 6.85, z + 0.9 * sz)], RED_D if sz > 0 else scale_col(YEL, 0.8))
        m.cyl(0, 5.6, z, 0.03, 7.15, 0.03, INK, n=4)
    m.box(-0.45, 4.75, -3.1, 0.45, 5.65, 3.1, YEL)
    m.box(-0.47, 4.72, -3.15, 0.47, 4.82, 3.15, RED_D)
    m.box(-0.47, 5.58, -3.15, 0.47, 5.68, 3.15, RED_D)
    for k in range(12):  # marquee bulbs both faces
        z = -2.85 + k * 0.52
        for sx in (-1, 1):
            m.ball(0.47 * sx, 5.2, z, 0.06, hexc("#fff1b8"), n=5, rings=3, glow=1.0)
    m.finish(out)


def g_pillar(out):
    """Stepping stone: collider cylinder r 1.25, top at the origin; drawn 12 m down."""
    m = LM("g_pillar", 513)
    rock_column(m, 0.0, 1.18, 12.0)
    m.finish(out)


def g_drum(out):
    """Sweeper platform: collider cylinder r 5, top at the origin; drawn 14 m down."""
    m = LM("g_drum", 514)
    rock_column(m, -0.2, 5.0, 14.0, n=16)
    # riveted steel deck plate under the hazard ring the game draws
    for i in range(16):
        a0, a1 = i * math.tau / 16, (i + 1) * math.tau / 16
        c = jitter(STEEL, m.rng, 0.05)
        m.face([m.P(0, 0.0, 0), m.P(math.cos(a1) * 4.98, 0.0, math.sin(a1) * 4.98), m.P(math.cos(a0) * 4.98, 0.0, math.sin(a0) * 4.98)], c)
        x, z = math.cos(a0) * 4.6, math.sin(a0) * 4.6
        bolts(m, [(x, 0.02, z), (x * 0.55, 0.02, z * 0.55)])
    m.cyl(0, -0.25, 0, 5.05, 0.0, 5.05, STEEL_D, n=24, caps=False)
    m.finish(out)


def g_beam(out):
    """Balance beam (collider 9.5 x 0.4 x 0.6 centred at origin) on two posts (r 0.5,
    tops at 0, 14 m deep) at x +-4.75, and the pendulum gantry: legs at z +-3 from
    y -4.5 to 9.5, crossbar at y 9.5."""
    m = LM("g_beam", 515)
    # the beam is a squared log, lashed at both ends
    for k in range(10):
        x0, x1 = -4.75 + k * 0.95, -4.75 + (k + 1) * 0.95
        m.box(x0, -0.2, -0.3, x1, 0.2, 0.3, jitter(hexc("#c99a62"), m.rng, 0.07), top=jitter(hexc("#d9a865"), m.rng, 0.05))
    for x in (-4.75, 4.75):
        m.push(x, 0, 0)
        rock_column(m, -0.2, 0.55, 13.8, n=8)
        for y in (-0.15, 0.0, 0.15):
            m.box(-0.12, y - 0.03, -0.33, 0.12, y + 0.03, 0.33, hexc("#c9b48a"))  # rope
        m.pop()
    # pendulum gantry: timber legs with braces and an iron head block
    for sz in (-1, 1):
        z = 3.0 * sz
        m.box(-0.22, -4.5, z - 0.22, 0.22, 9.6, z + 0.22, WOOD_D)
        for y in (-1.0, 3.0, 7.0):
            m.box(-0.25, y, z - 0.25, 0.25, y + 0.12, z + 0.25, IRON)
        m.beam((0, 6.5, z), (0, 9.2, z - 1.4 * sz), 0.09, WOOD)
    m.box(-0.28, 9.3, -3.3, 0.28, 9.8, 3.3, WOOD_D)
    m.box(-0.32, 9.2, -0.4, 0.32, 9.85, 0.4, IRON)
    m.finish(out)



def g_tower(out):
    """Bounce tower: deck collider 4 x 0.5 x 4 centred at origin, post r 0.6 down to -12."""
    m = LM("g_tower", 516)
    rock_column(m, -0.25, 0.8, 11.8, n=8)
    m.box(-2.0, -0.25, -2.0, 2.0, -0.05, 2.0, STONE_D)
    planks(m, -2.0, 2.0, 0.25, -2.0, 2.0, hexc("#b88a5a"))
    for (x, z) in ((-1.6, -1.6), (1.6, -1.6), (-1.6, 1.6), (1.6, 1.6)):
        m.beam((x, -0.25, z), (x * 0.3, -2.4, z * 0.3), 0.08, WOOD_D)
    m.finish(out)


def g_plinth(out):
    """Trophy plinth: collider cylinder r 1.2 from 0 to 1.2."""
    m = LM("g_plinth", 517)
    marble = hexc("#e6dfcc")
    lathe(m, [(0.0, 1.2, scale_col(marble, 0.9)), (0.18, 1.2, marble), (0.22, 1.05, marble), (0.95, 0.98, marble),
              (1.0, 1.1, BRASS), (1.08, 1.2, marble), (1.2, 1.2, marble)], n=20)
    for i in range(10):  # fluting
        a = i * math.tau / 10
        m.box(math.cos(a) * 1.0 - 0.04, 0.3, math.sin(a) * 1.0 - 0.04, math.cos(a) * 1.0 + 0.04, 0.9, math.sin(a) * 1.0 + 0.04, scale_col(marble, 0.82))
    m.text("CHAMPION", 0, 0.5, 1.03, 0.2, BRASS, depth=0.02, res=1)
    m.finish(out)


# --- the Chaos Yard -----------------------------------------------------------------------
def y_gantry(out):
    """Wrecking-ball gantry: posts (0.8 square) at z +-4 from 0 to 16.5, crossbar at 16.2."""
    m = LM("y_gantry", 521)
    for sz in (-1, 1):
        z = 4.0 * sz
        m.push(0, 0, z)
        i_beam(m, 0.0, 16.5, 0.8, RED)
        m.box(-0.7, 0, -0.7, 0.7, 0.12, 0.7, STEEL_D)   # base plate
        bolts(m, [(x, 0.14, zz) for x in (-0.55, 0.55) for zz in (-0.55, 0.55)])
        for k in range(6):  # hazard stripes at the foot
            y0 = 0.12 + k * 0.3
            m.box(-0.41, y0, -0.41, 0.41, y0 + 0.3, -0.39, YEL if k % 2 == 0 else INK)
            m.box(-0.41, y0, 0.39, 0.41, y0 + 0.3, 0.41, YEL if k % 2 == 0 else INK)
        for y in range(2, 16, 1):  # ladder on the outside face
            m.box(-0.25, y, 0.48 * sz - 0.02, 0.25, y + 0.05, 0.48 * sz + 0.02, STEEL)
        m.box(-0.28, 1.5, 0.46 * sz - 0.03, -0.24, 16.0, 0.46 * sz + 0.03, STEEL)
        m.box(0.24, 1.5, 0.46 * sz - 0.03, 0.28, 16.0, 0.46 * sz + 0.03, STEEL)
        m.pop()
        m.beam((0, 13.8, z), (0, 15.8, z - 2.0 * sz), 0.12, RED_D)   # knee brace
    m.box(-0.4, 15.8, -4.4, 0.4, 16.6, 4.4, RED)
    m.box(-0.45, 15.8, -4.4, 0.45, 15.86, 4.4, RED_D)
    m.box(-0.45, 16.54, -4.4, 0.45, 16.6, 4.4, RED_D)
    m.box(-0.35, 15.2, -0.3, 0.35, 15.8, 0.3, STEEL_D)   # pulley block
    m.cyl(0, 15.3, -0.32, 0.22, 15.7, 0.22, STEEL, n=10)
    hazard_band(m, -0.4, 0.4, 16.0, 16.4, 4.4)
    m.finish(out)


def y_scaffold(out):
    """Scaffold tower: decks (6 x 0.35 x 6) centred at y 3, 6, 9; tubes at +-2.8."""
    m = LM("y_scaffold", 522)
    tube = hexc("#b8c0cc")
    for cx in (-2.8, 2.8):
        for cz in (-2.8, 2.8):
            m.cyl(cx, 0.0, cz, 0.06, 9.9, 0.06, tube, n=8)
            m.box(cx - 0.2, 0, cz - 0.2, cx + 0.2, 0.06, cz + 0.2, STEEL_D)   # base jack
            for y in (2.82, 5.82, 8.82):  # couplers
                m.box(cx - 0.09, y - 0.08, cz - 0.09, cx + 0.09, y + 0.08, cz + 0.09, STEEL_D)
    for lvl in range(3):
        y = 3.0 * (lvl + 1)
        planks(m, -3.0, 3.0, y + 0.175, -3.0, 3.0, hexc("#c9a26a"), along_x=(lvl % 2 == 0), w=0.32)
        for (a, b) in (((-2.8, -2.8), (2.8, -2.8)), ((2.8, 2.8), (-2.8, 2.8))):
            m.beam((a[0], y - 0.25, a[1]), (b[0], y - 0.25, b[1]), 0.04, tube)   # ledgers
        # toe boards on the z sides only: the x sides are where the ramps land
        for sz in (-1, 1):
            m.box(-3.0, y + 0.175, 2.94 * sz - 0.03, 3.0, y + 0.33, 2.94 * sz + 0.03, YEL)
        # X bracing under each deck on the z faces
        for sz in (-1, 1):
            m.beam((-2.8, y - 2.9, 2.8 * sz), (2.8, y - 0.3, 2.8 * sz), 0.035, tube)
            m.beam((2.8, y - 2.9, 2.8 * sz), (-2.8, y - 0.3, 2.8 * sz), 0.035, tube)
    m.finish(out)


def y_frame(out):
    """Steel frame tower: posts (0.5) at +-3 from 0 to 10, decks (6.6 x 0.35) at 5 and 10."""
    m = LM("y_frame", 523)
    for cx in (-3, 3):
        for cz in (-3, 3):
            m.push(cx, 0, cz)
            i_beam(m, 0.0, 10.0, 0.5, RED)
            m.box(-0.4, 0, -0.4, 0.4, 0.1, 0.4, STEEL_D)
            m.pop()
    for y in (5.0, 10.0):
        m.box(-3.3, y - 0.175, -3.3, 3.3, y + 0.175, 3.3, hexc("#a4aab4"))
        for k in range(12):  # grating lines
            x = -3.2 + k * 0.55
            m.box(x, y + 0.175, -3.3, x + 0.05, y + 0.19, 3.3, hexc("#5a5f6a"))
        for sz in (-1, 1):
            m.box(-3.3, y - 0.5, 3.3 * sz - 0.1, 3.3, y - 0.17, 3.3 * sz + 0.1, RED)   # perimeter beams
        hazard_band(m, -3.3, 3.3, y - 0.17, y + 0.17, 3.31)
    for sz in (-1, 1):
        for (y0, y1) in ((0.3, 4.7), (5.3, 9.7)):
            m.beam((-3, y0, 3 * sz), (3, y1, 3 * sz), 0.06, RED)
    m.finish(out)


def y_mixer(out):
    """Cement truck faces -z. Colliders: body 3 x 2.2 x 7 centred at y 1.5, cab 3 x 1.6 x 2
    centred at (0, 3.3, -2.6). The drum is a live node the game spins."""
    m = LM("y_mixer", 524)
    body = hexc("#e8e2d0")
    # chassis + wheels
    m.box(-1.2, 0.6, -3.5, 1.2, 1.0, 3.5, INK)
    for z in (-2.6, 0.9, 2.5):
        for sx in (-1, 1):
            m.push(1.35 * sx, 0.6, z, roll=90)
            m.cyl(0, -0.22, 0, 0.6, 0.22, 0.6, hexc("#26262c"), n=14)
            m.cyl(0, -0.24, 0, 0.32, 0.24, 0.32, STEEL, n=10)
            m.pop()
            m.box(min(1.2 * sx, 1.5 * sx), 1.25, z - 0.8, max(1.2 * sx, 1.5 * sx), 1.35, z + 0.8, IRON)  # fender
    # drum cradle + deck
    m.box(-1.5, 1.0, -1.6, 1.5, 2.6, 3.5, body)
    for sx in (-1, 1):
        m.box(1.45 * sx - 0.05, 1.3, -1.4, 1.45 * sx + 0.05, 1.5, 3.3, BRASS)
    hazard_band(m, -1.5, 1.5, 1.0, 1.4, 3.5)
    m.box(-1.0, 2.6, 2.6, 1.0, 3.3, 3.2, STEEL_D)     # chute support
    m.beam((0, 3.0, 3.2), (0, 2.2, 4.2), 0.18, STEEL)
    # cab
    cab = hexc("#2f6be0")
    m.box(-1.5, 1.0, -3.6, 1.5, 4.1, -1.6, cab)
    m.box(-1.35, 2.7, -3.62, 1.35, 3.9, -3.6, hexc("#9fd4ea"), glow=0.15)   # windscreen
    for sx in (-1, 1):
        m.box(1.5 * sx - 0.01 * sx, 2.7, -3.3, 1.5 * sx + 0.01 * sx, 3.8, -2.2, hexc("#9fd4ea"))
        m.box(1.55 * sx - 0.05, 2.9, -3.7, 1.55 * sx + 0.05, 3.5, -3.55, INK)   # mirrors
        m.box(0.95 * sx - 0.25, 1.5, -3.63, 0.95 * sx + 0.25, 1.8, -3.6, hexc("#fff1b8"), glow=0.8)   # lamps
    m.box(-0.8, 1.2, -3.63, 0.8, 2.3, -3.6, STEEL_D)   # grille
    for k in range(5):
        m.box(-0.75, 1.3 + k * 0.2, -3.65, 0.75, 1.36 + k * 0.2, -3.62, STEEL)
    m.box(-1.6, 0.7, -3.85, 1.6, 1.05, -3.55, STEEL)   # bumper
    m.box(-1.5, 4.1, -3.4, 1.5, 4.2, -1.8, hexc("#244fa8"))
    m.text("SLOP CONCRETE", 0, 1.6, 3.52, 0.28, INK, font="Bungee-Regular", depth=0.02, res=1, yaw=0)
    m.finish(out)


def y_potty(out):
    """Port-a-potty: collider 1.4 x 2.4 x 1.4 centred at y 1.2; door faces -z."""
    m = LM("y_potty", 525)
    blue = hexc("#2f7fd8")
    m.box(-0.72, 0, -0.72, 0.72, 0.12, 0.72, hexc("#1f4f8a"))
    for k in range(9):  # ribbed walls
        x = -0.7 + k * 0.175
        c = blue if k % 2 == 0 else scale_col(blue, 0.85)
        m.box(x, 0.12, 0.64, x + 0.175, 2.3, 0.72, c)
        if k in (0, 1, 7, 8):  # front wall either side of the door
            m.box(x, 0.12, -0.72, x + 0.175, 2.3, -0.64, c)
        z = -0.7 + k * 0.175
        m.box(0.64, 0.12, z, 0.72, 2.3, z + 0.175, c)
        m.box(-0.72, 0.12, z, -0.64, 2.3, z + 0.175, c)
    m.box(-0.36, 0.14, -0.74, 0.36, 2.2, -0.68, scale_col(blue, 1.1))   # door
    m.box(0.22, 1.05, -0.78, 0.3, 1.25, -0.74, STEEL)    # handle
    m.box(-0.18, 1.7, -0.75, 0.18, 1.85, -0.74, hexc("#c43b3b"))   # OCCUPIED
    m.text("OCCUPIED", 0, 1.73, -0.745, 0.07, WHITE, font="Bungee-Regular", depth=0.005, res=1, yaw=180)
    m.ball(0, 2.0, -0.75, 0.08, hexc("#1f4f8a"), n=8, rings=3, sy=0.2)   # moon vent
    lathe(m, [(2.3, 0.75, hexc("#e8eef6")), (2.42, 0.7, hexc("#e8eef6")), (2.5, 0.5, hexc("#e8eef6")), (2.55, 0.0, hexc("#e8eef6"))], n=8)
    m.cyl(0.45, 2.3, 0.45, 0.06, 2.85, 0.06, INK, n=6)
    m.finish(out)


# --- the Meadow -------------------------------------------------------------------------
def _kicker(name, paint):
    def build(out):
        """Kicker ramp: deck from (0, 0, 0) to (0, 2.3, 7), 4 wide. Back wall at z 7."""
        m = LM(name, 531)
        L, H = 7.0, 2.3
        ang = math.atan2(H, L)
        # deck: planks running across, painted lane down the middle
        n = 22
        for i in range(n):
            t0, t1 = i / n, (i + 1) / n - 0.004
            z0, z1 = L * t0, L * t1
            y0, y1 = H * t0, H * t1
            for (xa, xb, c) in ((-2.0, -0.9, hexc("#c99a62")), (-0.9, 0.9, paint), (0.9, 2.0, hexc("#c99a62"))):
                c = jitter(c, m.rng, 0.06)
                m.quad(m.P(xa, y1, z1), m.P(xb, y1, z1), m.P(xb, y0, z0), m.P(xa, y0, z0), c)  # faces up the slope
        # side frames: triangles with vertical posts
        for sx in (-1, 1):
            x = 2.0 * sx
            # side panel: two faces held apart, never coincident (that bakes black)
            for off, flip in ((0.04, sx > 0), (-0.04, sx < 0)):
                pts = [m.P(x + off, 0, 0), m.P(x + off, 0, L), m.P(x + off, H, L)]
                m.face(pts if flip else list(reversed(pts)), jitter(WOOD, m.rng, 0.05))
            for k in range(1, 4):
                z = L * k / 4
                m.box(x - 0.08, 0, z - 0.08, x + 0.08, H * z / L, z + 0.08, WOOD)
            m.beam((x, 0.05, 0.2), (x, H - 0.1, L - 0.1), 0.06, WOOD)
        # back wall + coping pipe at the lip
        m.box(-2.0, 0, L, 2.0, H, L + 0.4, WOOD_D)
        for k in range(5):
            m.box(-2.0, 0.2 + k * 0.42, L + 0.4, 2.0, 0.24 + k * 0.42, L + 0.42, WOOD)
        m.push(0, H, L, roll=90)
        m.cyl(0, -2.05, 0, 0.08, 2.05, 0.08, STEEL, n=8)
        m.pop()
        m.box(-2.05, 0, -0.02, 2.05, 0.03, 0.15, STEEL_D)   # steel kick plate at the foot
        m.finish(out)
    return build


m_kicker_pink = _kicker("m_kicker_pink", hexc("#ff5fa2"))
m_kicker_blue = _kicker("m_kicker_blue", hexc("#3ec1ff"))
m_kicker_gold = _kicker("m_kicker_gold", hexc("#ffc935"))


def m_lane(out):
    """Bowling lane: 4 wide, z 0 to 32, surface at y 0.08; gutters at x +-2.1."""
    m = LM("m_lane", 541)
    maple = hexc("#e3b57e")
    for k in range(20):
        x0, x1 = -1.8 + k * 0.18, -1.8 + (k + 1) * 0.18
        c = jitter(maple, m.rng, 0.04)
        m.box(x0, 0.0, 0.0, x1 - 0.004, 0.08, 26.5, c, sub=4.0)
        m.box(x0, 0.0, 26.5, x1 - 0.004, 0.08, 32.0, scale_col(c, 1.08), sub=4.0)   # pin deck
    m.box(-1.8, 0.081, 0.0, 1.8, 0.083, 0.08, INK)   # foul line
    for k in range(7):  # target arrows
        x = -1.35 + k * 0.45
        z = 4.5 + abs(k - 3) * 0.35
        m.face([m.P(x - 0.07, 0.085, z), m.P(x + 0.07, 0.085, z), m.P(x, 0.085, z + 0.35)], hexc("#7a2336"))
    for k in range(10):  # pin spots
        r = 0
        cnt = 0
        while cnt + r + 1 <= k:
            cnt += r + 1
            r += 1
        i = k - cnt
        m.cyl((i - r * 0.5) * 0.7, 0.081, 28 + r * 0.6, 0.06, 0.084, 0.06, hexc("#7a2336"), n=6)
    for sx in (-1, 1):  # gutters: rounded channels with caps
        x = 1.95 * sx
        for k in range(6):
            a0, a1 = math.pi * k / 6, math.pi * (k + 1) / 6
            pa = m.P(x + math.cos(a0) * 0.15, 0.08 - math.sin(a0) * 0.12, 0)
            pb = m.P(x + math.cos(a1) * 0.15, 0.08 - math.sin(a1) * 0.12, 0)
            pc = m.P(x + math.cos(a1) * 0.15, 0.08 - math.sin(a1) * 0.12, 32)
            pd = m.P(x + math.cos(a0) * 0.15, 0.08 - math.sin(a0) * 0.12, 32)
            m.face([pa, pb, pc, pd] if sx > 0 else [pb, pa, pd, pc], STEEL_D)
        m.box(2.1 * sx - 0.1, 0.0, 0.0, 2.1 * sx + 0.1, 0.2, 32.0, hexc("#7a4520"), sub=4.0)
        m.box(2.1 * sx - 0.11, 0.2, 0.0, 2.1 * sx + 0.11, 0.24, 32.0, BRASS)
    # back pit: kickback walls, curtain and a lit header
    m.box(-2.3, 0.0, 32.0, 2.3, 0.05, 33.6, INK)
    for sx in (-1, 1):
        m.box(2.2 * sx - 0.1, 0.0, 26.5, 2.2 * sx + 0.1, 1.6, 33.6, hexc("#2a1c28"))
    for k in range(12):
        x = -2.1 + k * 0.36
        m.box(x, 0.05, 33.4, x + 0.36, 2.2, 33.55 + (k % 2) * 0.06, hexc("#3a1e40") if k % 2 else hexc("#2a1530"))
    m.box(-2.3, 2.2, 32.0, 2.3, 3.0, 33.6, hexc("#7a2336"))
    m.text("SLOPSVILLE LANES", 0, 2.35, 31.98, 0.38, hexc("#ffcc5c"), font="Bungee-Regular", glow=0.6, depth=0.02, res=1, yaw=180)
    # ball return at the approach
    m.box(2.5, 0.0, -1.6, 3.1, 0.8, 1.4, hexc("#3a3e4a"))
    m.box(2.45, 0.8, -1.6, 3.15, 0.95, 1.4, hexc("#5a5f6a"))
    for k, c in enumerate((hexc("#e04a4a"), hexc("#3a8ee6"), hexc("#41b85a"))):
        m.ball(2.8, 1.12, -1.0 + k * 0.6, 0.18, c, n=10, rings=6)
    m.finish(out)


def m_ledge(out):
    """Friend Ledge: collider 3 x 3 x 3 from y 0 to 3, centred on x/z."""
    m = LM("m_ledge", 551)
    brick = hexc("#b7a99a")
    for r in range(10):
        y0, y1 = r * 0.3, (r + 1) * 0.3
        off = 0.25 if r % 2 else 0.0
        for side in range(4):
            m.push(0, 0, 0, yaw=90 * side)
            x = -1.5 - off
            while x < 1.5:
                xa, xb = max(x, -1.5), min(x + 0.5, 1.5)
                if xb - xa > 0.02:
                    m.box(xa + 0.01, y0 + 0.01, 1.48, xb - 0.01, y1 - 0.01, 1.52, jitter(brick, m.rng, 0.1))
                x += 0.5
            m.pop()
    m.box(-1.48, 0, -1.48, 1.48, 2.9, 1.48, hexc("#6e6460"))   # mortar
    m.box(-1.58, 2.9, -1.58, 1.58, 3.0, 1.58, hexc("#d8cfba"))   # capstone
    for i in range(10):
        a = m.rng.uniform(0, math.tau)
        rr = m.rng.uniform(0.6, 1.4)
        m.cyl(math.cos(a) * rr, 3.0, math.sin(a) * rr, 0.06, 3.0 + m.rng.uniform(0.1, 0.22), 0.0, jitter(MOSS, m.rng, 0.15), n=4)
    for side in range(4):
        m.push(0, 0, 0, yaw=90 * side)
        m.box(-1.5, 0, 1.52, 1.5, 0.15, 1.6, MOSS)
        m.pop()
    m.finish(out)


def m_plate(out):
    """Pressure-plate housing round the live top (r 1.4, y 0.19 to 0.31)."""
    m = LM("m_plate", 552)
    n = 24
    for i in range(n):
        a0, a1 = i * math.tau / n, (i + 1) * math.tau / n
        def p(a, r, y):
            return m.P(math.cos(a) * r, y, math.sin(a) * r)
        c = YEL if (i // 2) % 2 == 0 else INK
        m.face([p(a0, 1.8, 0.2), p(a0, 1.45, 0.2), p(a1, 1.45, 0.2), p(a1, 1.8, 0.2)], c)
        m.face([p(a1, 1.8, 0.0), p(a0, 1.8, 0.0), p(a0, 1.8, 0.2), p(a1, 1.8, 0.2)], STEEL_D)
        if i % 3 == 0:
            bolts(m, [(math.cos(a0) * 1.62, 0.22, math.sin(a0) * 1.62)], STEEL, 0.04)
    m.cyl(0, 0.0, 0, 1.45, 0.19, 1.45, IRON, n=n, caps=False)
    m.finish(out)


ALL = ["props", "g_pad", "g_arch", "g_pillar", "g_drum", "g_beam", "g_tower", "g_plinth",
       "y_gantry", "y_scaffold", "y_frame", "y_mixer", "y_potty",
       "m_kicker_pink", "m_kicker_blue", "m_kicker_gold", "m_lane", "m_ledge", "m_plate"]


# --- second pass: town square, yard, carnival -------------------------------------------
def plaza_ring(out):
    """Packed cobble ring round the wheel plaza, r 11.4 to 14, centred on the origin."""
    m = LM("plaza_ring", 561)
    cob = hexc("#a9a096")
    r = 11.5
    row = 0
    while r < 14.0:
        n = int(math.tau * r / 0.46)
        off = (row % 2) * 0.5
        for i in range(n):
            a = math.tau * (i + off) / n
            c = jitter(cob, m.rng, 0.14)
            h = m.rng.uniform(0.04, 0.085)
            w, d = m.rng.uniform(0.17, 0.2), m.rng.uniform(0.17, 0.2)
            m.push(math.cos(a) * r, 0, math.sin(a) * r, yaw=-math.degrees(a) + m.rng.uniform(-6, 6))
            m.box(-w, -0.02, -d, w, h - 0.02, d, scale_col(c, 0.82), faces="xXzZ")
            m.box(-w + 0.03, h - 0.02, -d + 0.03, w - 0.03, h, d - 0.03, c, faces="xXzZY")
            m.pop()
        r += 0.44
        row += 1
    m.finish(out)


def pebble(out):
    """A rounded loose stone, unit radius: the game scatters and scales it."""
    m = LM("pebble", 562)
    for k in range(3):
        m.ball(m.rng.uniform(-0.3, 0.3), 0.0, m.rng.uniform(-0.3, 0.3), m.rng.uniform(0.55, 0.85), jitter(hexc("#a39a90"), m.rng, 0.1), n=7, rings=4, sy=0.35)
    m.finish(out)


def trough(out):
    """Water trough: collider 3.2 x 0.9 x 1.0 centred at (0, 0.45, 0)."""
    m = LM("trough", 563)
    for k in range(6):  # staves along the sides
        y0 = 0.15 + k * 0.125
        for sz in (-1, 1):
            m.box(-1.55, y0, 0.44 * sz - 0.05, 1.55, y0 + 0.12, 0.44 * sz + 0.05, jitter(WOOD_L, m.rng, 0.08))
    for sx in (-1, 1):
        m.box(1.55 * sx - 0.06, 0.15, -0.5, 1.55 * sx + 0.06, 0.9, 0.5, WOOD_D)
        m.box(1.25 * sx - 0.08, 0.0, -0.45, 1.25 * sx + 0.08, 0.2, 0.45, WOOD_D)   # legs
    for x in (-0.9, 0.0, 0.9):
        m.box(x - 0.04, 0.2, -0.51, x + 0.04, 0.92, 0.51, IRON)   # bands
    m.box(-1.5, 0.15, -0.4, 1.5, 0.2, 0.4, WOOD_D)
    m.box(-1.5, 0.76, -0.4, 1.5, 0.8, 0.4, hexc("#3f9fc2"), glow=0.1)   # water
    # a hand pump at one end
    m.box(1.7, 0.0, -0.15, 2.0, 1.4, 0.15, IRON)
    m.cyl(1.85, 1.4, 0, 0.12, 1.6, 0.12, IRON, n=8)
    m.beam((1.85, 1.0, 0), (1.5, 1.0, 0), 0.05, IRON)
    m.beam((1.85, 1.6, 0), (2.4, 1.85, 0), 0.04, IRON)
    m.room(-2.6, -0.5, -1.0, 2.6, 2.0, 1.0, level=0.14, col=(1.0, 0.95, 0.88))  # it sits in porch shade
    m.finish(out)


def y_barrier(out):
    """Jersey barrier: collider 0.3 x 1.0 x 2.8 centred at (0, 0.5, 0)."""
    m = LM("y_barrier", 564)
    conc = hexc("#d6d0c4")
    prof = [(-0.3, 0.0), (0.3, 0.0), (0.3, 0.08), (0.2, 0.3), (0.12, 1.0), (-0.12, 1.0), (-0.2, 0.3), (-0.3, 0.08)]
    for i in range(len(prof)):
        (x0, y0), (x1, y1) = prof[i], prof[(i + 1) % len(prof)]
        c = conc if y0 < 0.32 or y1 < 0.32 else hexc("#e8e2d6")
        m.quad(m.P(x0, y0, -1.4), m.P(x1, y1, -1.4), m.P(x1, y1, 1.4), m.P(x0, y0, 1.4), jitter(c, m.rng, 0.03))
    for z in (-1.4, 1.4):
        pts = [m.P(x, y, z) for (x, y) in prof]
        m.face(pts if z > 0 else list(reversed(pts)), conc)
    for k in range(7):  # red/white panels on both faces
        z0 = -1.4 + k * 0.4
        for sx in (-1, 1):
            m.box(0.15 * sx - 0.01, 0.55, z0 + 0.02, 0.15 * sx + 0.01, 0.85, z0 + 0.38, RED if k % 2 else WHITE)
    for sx in (-1, 1):
        m.box(0.14 * sx - 0.01, 0.9, -0.08, 0.14 * sx + 0.01, 0.96, 0.08, hexc("#ffcf3a"), glow=0.6)   # reflector
    m.finish(out)


def y_crane(out):
    """Tower crane: base 4 x 1 x 4 (0 to 1), mast 1.6 square to 38.5. The jib is a live part."""
    m = LM("y_crane", 565)
    conc = hexc("#9a958c")
    m.box(-2.0, 0, -2.0, 2.0, 1.0, 2.0, conc)
    for k in range(4):
        m.box(-1.9 + k * 1.0, 1.0, -1.9, -1.2 + k * 1.0, 1.6, -1.2, hexc("#7c776e"))   # ballast blocks
    h = 0.8
    for (x, z) in ((-h, -h), (h, -h), (-h, h), (h, h)):
        m.box(x - 0.08, 1.0, z - 0.08, x + 0.08, 38.5, z + 0.08, YEL)
    for k in range(13):
        y0, y1 = 1.0 + k * 2.9, 1.0 + (k + 1) * 2.9
        for side in range(4):
            m.push(0, 0, 0, yaw=90 * side)
            m.beam((-h, y0, h), (h, y1, h), 0.05, YEL)
            m.beam((-h, y1, h), (h, y1, h), 0.05, YEL)
            m.pop()
    for y in range(2, 38):  # ladder inside
        m.box(-0.25, y, -0.05, 0.25, y + 0.04, 0.05, STEEL_D)
    m.text("SLOP AND SONS", 0, 4.0, 0.9, 0.3, INK, font="Bungee-Regular", depth=0.02, res=1)
    # jib (DYN, the game turns it about the mast head)
    p = m.part("jib")
    p.box(-1.2, -1.0, -1.2, 1.2, 0.4, 1.2, YEL)   # slewing unit
    p.box(1.2, -1.6, -1.0, 2.6, 0.2, 0.6, hexc("#e8e2d0"))   # operator cab
    p.box(2.58, -1.3, -0.9, 2.62, -0.1, 0.5, hexc("#9fd4ea"), glow=0.1)
    for (x0, x1) in ((-0.6, -0.5), (0.5, 0.6)):   # jib chords
        p.box(x0, 0.4, -30.0, x1, 0.5, 2.0, YEL)
    p.box(-0.05, 1.5, -30.0, 0.05, 1.6, 2.0, YEL)
    for k in range(16):
        z0, z1 = 2.0 - k * 2.0, 2.0 - (k + 1) * 2.0
        p.beam((-0.55, 0.45, z0), (0.0, 1.55, z1), 0.04, YEL)
        p.beam((0.55, 0.45, z0), (0.0, 1.55, z1), 0.04, YEL)
        p.beam((-0.55, 0.45, z1), (0.55, 0.45, z1), 0.04, YEL)
    p.box(-0.5, 0.4, 2.0, 0.5, 0.9, 9.0, YEL)   # counter-jib
    p.box(-1.0, -0.6, 6.2, 1.0, 1.4, 8.6, hexc("#7c776e"))   # counterweights
    p.box(-0.3, 0.4, -0.3, 0.3, 5.5, 0.3, YEL)   # A-frame apex
    p.beam((0, 5.5, 0), (0, 1.6, -22.0), 0.03, INK)
    p.beam((0, 5.5, 0), (0, 0.9, 8.0), 0.03, INK)
    p.box(-0.7, -0.1, -26.6, 0.7, 0.4, -25.4, STEEL_D)   # trolley
    p.ball(0, 5.7, 0, 0.25, RED, n=6, rings=4, glow=1.5)
    hazard_band(p, -1.2, 1.2, -0.9, 0.3, 1.2)
    m.finish(out)


def _stall(name, title, awning, body, goods):
    def build(out):
        """Carnival stall, faces +z. Colliders: the booth, and the counter at the front."""
        m = LM(name, 571)
        W, D = 2.0, 1.5
        m.box(-W, 0, -D, W, 0.15, D, WOOD_D)
        for k in range(10):   # striped back + sides
            x0, x1 = -W + k * 0.4, -W + (k + 1) * 0.4
            m.box(x0, 0.15, -D, x1, 2.7, -D + 0.08, body if k % 2 else scale_col(body, 0.85))
        for sx in (-1, 1):
            for k in range(7):
                z0, z1 = -D + k * 0.43, -D + (k + 1) * 0.43
                m.box(W * sx - 0.04, 0.15, z0, W * sx + 0.04, 2.7, z1, body if k % 2 else scale_col(body, 0.85))
        m.box(-W, 0.15, D - 0.5, W, 1.1, D - 0.4, WOOD)   # counter front
        m.box(-W - 0.05, 1.1, D - 0.6, W + 0.05, 1.18, D + 0.05, hexc("#f2e2c0"))   # counter top
        for k in range(8):
            m.box(-W + 0.1 + k * 0.5, 0.25, D - 0.39, -W + 0.4 + k * 0.5, 1.0, D - 0.38, scale_col(WOOD, 0.85))
        for sx in (-1, 1):   # posts
            m.box(W * sx - 0.08, 0.15, D - 0.08, W * sx + 0.08, 3.0, D + 0.08, BRASS)
        # striped awning with a scalloped edge
        for k in range(10):
            x0, x1 = -W - 0.1 + k * 0.42, -W - 0.1 + (k + 1) * 0.42
            c = awning if k % 2 == 0 else WHITE
            m.quad(m.P(x0, 3.0, D + 0.7), m.P(x1, 3.0, D + 0.7), m.P(x1, 3.5, -D), m.P(x0, 3.5, -D), c)
            m.quad(m.P(x1, 2.9, D + 0.7), m.P(x0, 2.9, D + 0.7), m.P(x0, 3.4, -D), m.P(x1, 3.4, -D), scale_col(c, 0.7))
            m.face([m.P(x0, 3.0, D + 0.71), m.P((x0 + x1) / 2, 2.72, D + 0.71), m.P(x1, 3.0, D + 0.71)], c)
            m.face([m.P(x1, 3.0, D + 0.69), m.P((x0 + x1) / 2, 2.72, D + 0.69), m.P(x0, 3.0, D + 0.69)], scale_col(c, 0.7))
        for k in range(9):
            m.ball(-W + k * 0.5, 2.95, D + 0.72, 0.06, hexc("#fff1b8"), n=5, rings=3, glow=1.0)
        # sign board on top
        m.box(-1.7, 3.5, -D - 0.05, 1.7, 4.4, -D + 0.08, hexc("#2d1f3a"))
        m.box(-1.75, 3.45, -D - 0.06, 1.75, 3.52, -D + 0.09, BRASS)
        m.box(-1.75, 4.38, -D - 0.06, 1.75, 4.45, -D + 0.09, BRASS)
        m.text(title, 0, 3.66, -D + 0.09, 0.62 if len(title) < 11 else 0.46, hexc("#ffcc5c"), font="Bungee-Regular", glow=0.7, depth=0.03, res=1)
        goods(m, W, D)
        m.room(-W, 0, -D, W, 3.0, D, level=0.12, col=(1.0, 0.9, 0.75))
        m.col(-W, 0, -D, W, 2.7, D - 0.4)
        m.col(-W, 0, D - 0.6, W, 1.18, D + 0.05)
        m.finish(out)
    return build


def _goods_food(m, W, D):
    for k in range(5):   # corn dogs on the counter
        x = -1.4 + k * 0.6
        m.cyl(x, 1.18, D - 0.25, 0.012, 1.45, 0.012, CREAM, n=4)
        m.ball(x, 1.55, D - 0.25, 0.09, hexc("#c9862f"), n=6, rings=4, sy=1.6)
    m.box(-1.6, 1.2, -1.2, -0.6, 2.0, -0.6, STEEL)   # fryer
    m.box(-1.5, 2.0, -1.1, -0.7, 2.05, -0.7, hexc("#d9a43a"), glow=0.2)


def _goods_drinks(m, W, D):
    for k in range(6):
        x = -1.5 + k * 0.6
        m.cyl(x, 1.18, D - 0.25, 0.08, 1.42, 0.09, [RED, hexc("#3ec1ff"), hexc("#7ccf4e")][k % 3], n=7)
        m.cyl(x + 0.03, 1.42, D - 0.25, 0.01, 1.62, 0.01, WHITE, n=3)
    for k, x in enumerate((-1.0, 0.0, 1.0)):   # slushie machines
        m.box(x - 0.3, 1.18, -1.3, x + 0.3, 2.2, -0.8, STEEL)
        m.box(x - 0.25, 1.5, -0.81, x + 0.25, 2.1, -0.79, [hexc("#ff5fa2"), hexc("#3ec1ff"), hexc("#ffd23f")][k], glow=0.4)


def _goods_info(m, W, D):
    m.box(-1.6, 1.3, -1.42, 1.6, 2.5, -1.4, hexc("#e8dcc0"))   # map board
    for k in range(6):
        m.box(-1.4 + k * 0.5, 1.5 + (k % 2) * 0.4, -1.39, -1.1 + k * 0.5, 1.8 + (k % 2) * 0.4, -1.38, [RED, hexc("#3ec1ff"), YEL][k % 3])
    for k in range(4):   # lost property
        m.ball(-1.2 + k * 0.8, 1.32, D - 0.3, 0.14, [hexc("#ff5fa2"), YEL, hexc("#7ccf4e"), WHITE][k], n=7, rings=4)


def _goods_toilets(m, W, D):
    for x in (-1.0, 1.0):
        m.box(x - 0.75, 0.15, -1.3, x + 0.75, 2.4, -1.25, hexc("#e8eef6"))
        m.box(x - 0.6, 0.2, -1.24, x + 0.6, 2.2, -1.22, hexc("#2f7fd8"))
        m.ball(x, 1.9, -1.21, 0.14, WHITE, n=8, rings=3, sy=0.2)
    m.box(-0.4, 1.18, D - 0.4, 0.4, 1.3, D - 0.1, WHITE)   # a sad roll of tickets


c_stall_food = _stall("c_stall_food", "CORN DOGS", RED, hexc("#ffcf5a"), _goods_food)
c_stall_drinks = _stall("c_stall_drinks", "SLOP SODA", hexc("#3ec1ff"), hexc("#ff9ac1"), _goods_drinks)
c_stall_info = _stall("c_stall_info", "LOST AND FOUND", hexc("#7ccf4e"), hexc("#ffe7a8"), _goods_info)
c_stall_toilets = _stall("c_stall_toilets", "RESTROOMS", hexc("#2f7fd8"), hexc("#e8eef6"), _goods_toilets)

ALL += ["plaza_ring", "trough", "y_barrier", "y_crane", "c_stall_food", "c_stall_drinks", "c_stall_info", "c_stall_toilets"]
