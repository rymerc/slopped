"""Sets for the minigame arenas: Lava Soup, Pocket God, Giant Hunt, Cursed Casino.

Colliders and gameplay stay in the game scripts; these models sit at the same
anchors and only change the look. Sizes noted on each builder match the code.

  soup_raft      toast raft (collider: cylinder r 13, h 1, centred on the anchor)
  game_bits      DYN-only meshes the games place themselves: platform foods, soup
                 floaters, the taste ladle, the god's hand, Giant Hunt pillars,
                 boulders, dirt and mountains
  pg_camp        Pocket God castaway workshop
  gh_fence       one 92 m side of the Giant Hunt palisade (collider 92 x 3 x 0.6)
  gh_hut         little-only hut (colliders in giant_arena.gd)
  gh_rack        spear rack (no collider)
  gh_plaza       worn flagstones round the giant's spawn (walk-on, 4 cm proud)
  cc_gate_big / cc_gate_small   Cursed Casino's locked doors (colliders in code)
  cc_candles     after-hours candelabra
  cc_mess        spilled chips and cards, flat
"""
import math

from lm import LM, hexc, jitter, mix, scale_col
from sets import IRON, RED, RED_D, STEEL, STEEL_D, WHITE, YEL, bolts, lathe, sphere
from town import BRASS, CREAM, INK, WOOD, WOOD_D, WOOD_L

SKIN = hexc("#f1c49a")
GOLD = hexc("#ffc935")
THATCH = hexc("#c9a25a")
PLASTER = hexc("#f0cf9a")
STONE = hexc("#d4c7a6")
STONE_D = hexc("#8d8578")
MOSS = hexc("#6a9a3e")
LEAF = hexc("#4f9a3c")


def _n(a, b, c=0.0):
    """Cheap deterministic lumpiness, the same wherever it is sampled."""
    return math.sin(a * 1.7 + b * 2.3 + c) * math.cos(b * 1.1 - a * 0.6 + c * 0.5)


def polar_slab(m, r0, r1, a0, a1, y0, y1, col, side=None):
    """A ring-sector block (flagstones, raft pieces), top CCW from above."""
    P = m.P
    p = lambda a, r, y: P(math.cos(a) * r, y, math.sin(a) * r)
    m.face([p(a0, r0, y1), p(a1, r0, y1), p(a1, r1, y1), p(a0, r1, y1)], col)
    s = side or scale_col(col, 0.75)
    m.face([p(a0, r1, y0), p(a0, r1, y1), p(a1, r1, y1), p(a1, r1, y0)], s)
    if r0 > 0.01:
        m.face([p(a1, r0, y0), p(a1, r0, y1), p(a0, r0, y1), p(a0, r0, y0)], s)
    m.face([p(a0, r0, y0), p(a0, r0, y1), p(a0, r1, y1), p(a0, r1, y0)], s)
    m.face([p(a1, r1, y0), p(a1, r1, y1), p(a1, r0, y1), p(a1, r0, y0)], s)


def poly_slab(m, pts, y0, y1, col, side=None):
    """Prism from a polygon of (x, z) given CCW seen from above."""
    P = m.P
    m.face([P(x, y1, z) for (x, z) in reversed(pts)], col)
    s = side or scale_col(col, 0.7)
    n = len(pts)
    for i in range(n):
        (ax, az), (bx, bz) = pts[i], pts[(i + 1) % n]
        m.face([P(ax, y0, az), P(ax, y1, az), P(bx, y1, bz), P(bx, y0, bz)], s)


def crate(m, x, z, s, yaw=0.0, y=0.0, col=None):
    """Slatted crate, s wide, sitting at y."""
    c = col or jitter(hexc("#b98a52"), m.rng, 0.08)
    h = s * 0.5
    m.push(x, y, z, yaw=yaw)
    m.box(-h + 0.03, 0.0, -h + 0.03, h - 0.03, s - 0.03, h - 0.03, scale_col(c, 0.7))
    for k in range(3):  # slats on four sides
        y0 = 0.04 + k * (s - 0.08) / 3
        y1 = y0 + (s - 0.08) / 3 - 0.05
        m.box(-h, y0, h - 0.04, h, y1, h, jitter(c, m.rng, 0.06))
        m.box(-h, y0, -h, h, y1, -h + 0.04, jitter(c, m.rng, 0.06))
        m.box(h - 0.04, y0, -h, h, y1, h, jitter(c, m.rng, 0.06))
        m.box(-h, y0, -h, -h + 0.04, y1, h, jitter(c, m.rng, 0.06))
    for sx in (-1, 1):
        for sz in (-1, 1):
            m.box(sx * h - 0.07, 0, sz * h - 0.07, sx * h + 0.07, s, sz * h + 0.07, scale_col(c, 0.82))
    m.box(-h, s - 0.05, -h, h, s, h, jitter(c, m.rng, 0.05))
    m.pop()


def flame(m, x, y, z, s, glow=1.0):
    m.cyl(x, y, z, 0.11 * s, y + 0.32 * s, 0.0, hexc("#ff8a2a"), n=5, glow=glow)
    m.cyl(x, y + 0.02 * s, z, 0.06 * s, y + 0.22 * s, 0.0, hexc("#ffe27a"), n=5, glow=glow)


# --- Lava Soup -----------------------------------------------------------------------
def soup_raft(out):
    """Raft of toast. Collider: cylinder r 13, h 1 (y -0.5 .. 0.5 here)."""
    m = LM("soup_raft", 601)
    R, n = 13.0, 48
    crust, crust_l = hexc("#8a4a1f"), hexc("#b4702f")
    m.cyl(0, -0.5, 0, R - 0.25, -0.05, R, crust, n=n, caps=False)
    m.cyl(0, -0.05, 0, R, 0.36, R, jitter(crust, m.rng, 0.04), n=n, caps=False)
    m.cyl(0, 0.36, 0, R, 0.5, R - 0.45, crust_l, n=n, caps=False)
    rings = [0.0, 1.6, 3.2, 4.8, 6.4, 8.0, 9.4, 10.8, 12.0, R - 0.45]
    gold, deep = hexc("#e8b062"), hexc("#c98238")
    for k in range(len(rings) - 1):
        r0, r1 = rings[k], rings[k + 1]
        for i in range(n):
            a0, a1 = i * math.tau / n, (i + 1) * math.tau / n
            t = r1 / R
            c = mix(gold, deep, max(0.0, t - 0.75) * 2.5 + 0.04 * _n(i * 0.5, k))
            if m.rng.random() < 0.025:
                c = scale_col(c, 0.86)  # a darker toasted patch
            c = jitter(c, m.rng, 0.02)
            y = 0.48
            p = lambda a, r: m.P(math.cos(a) * r, y, math.sin(a) * r)
            if r0 < 0.01:
                m.face([p(a0, 0.0), p(a1, r1), p(a0, r1)], c)
            else:
                m.face([p(a0, r0), p(a1, r0), p(a1, r1), p(a0, r1)], c)
    # crumb pores: little dark pits standing a hair proud
    for i in range(70):
        a = m.rng.uniform(0, math.tau)
        r = m.rng.uniform(1.0, 11.8)
        x, z = math.cos(a) * r, math.sin(a) * r
        w = m.rng.uniform(0.08, 0.2)
        m.box(x - w, 0.49, z - w * 0.6, x + w, 0.505, z + w * 0.6, scale_col(gold, 0.72), faces="Y")
    # a melting pat of butter, kept flat so nobody trips on it
    m.push(1.5, 0, -1.0, yaw=22)
    pool = [(math.cos(a) * (2.6 + 0.5 * _n(a * 3, 1)), math.sin(a) * (2.3 + 0.4 * _n(a * 2, 2))) for a in [k * math.tau / 18 for k in range(18)]]
    m.face([m.P(x, 0.505, z) for (x, z) in pool][::-1], hexc("#ffe08a"), glow=0.08)
    m.box(-1.1, 0.505, -1.1, 1.1, 0.62, 1.1, hexc("#fff0a8"))
    m.box(-1.0, 0.62, -1.0, 1.0, 0.64, 1.0, hexc("#fff6c8"))
    m.pop()
    # a cocktail-stick flag claiming the raft
    m.beam((-8.6, 0.0, 7.4), (-8.9, 4.6, 7.8), 0.07, hexc("#e8cf9a"))
    for k, c in enumerate((RED, WHITE, RED)):
        y0 = 3.7 + k * 0.3
        m.box(-8.85, y0, 7.75, -7.2, y0 + 0.3, 7.8, c, faces="zZ")
        m.box(-8.85, y0, 7.68, -7.2, y0 + 0.3, 7.73, scale_col(c, 0.85), faces="z")
    m.finish(out)


def _carrot_coin(p, r, h, y=0.0, x=0.0, z=0.0, n=16):
    p.cyl(x, y - h * 0.5, z, r, y + h * 0.5, r, hexc("#ef7a22"), n=n)
    p.cyl(x, y + h * 0.5, z, r * 0.62, y + h * 0.5 + 0.01 * r, r * 0.62, hexc("#f6a24a"), n=n)
    p.cyl(x, y + h * 0.5 + 0.01 * r, z, r * 0.2, y + h * 0.5 + 0.02 * r, r * 0.2, hexc("#ffc06a"), n=8)


def game_bits(out):
    m = LM("game_bits", 611)
    m.box(0, 0, 0, 0.01, 0.01, 0.01, INK)  # the static part must not be empty

    # platform foods: top is placed exactly on the step height by the game
    p = m.part("cracker", ao=True)
    W = 2.1
    cr = hexc("#e9bf72")
    p.box(-W, -0.24, -W, W, 0.12, W, cr, sub=0.7)
    for sx in (-1, 1):  # baked darker edges, scalloped
        for k in range(9):
            t = -W + 0.25 + k * (2 * W - 0.5) / 8
            p.box(sx * W - 0.12, -0.24, t - 0.2, sx * W + 0.04, 0.14, t + 0.2, scale_col(cr, 0.8))
            p.box(t - 0.2, -0.24, sx * W - 0.12, t + 0.2, 0.14, sx * W + 0.04, scale_col(cr, 0.8))
    for i in range(4):
        for j in range(4):
            x, z = -1.35 + i * 0.9, -1.35 + j * 0.9
            p.box(x - 0.08, 0.12, z - 0.08, x + 0.08, 0.135, z + 0.08, scale_col(cr, 0.62), faces="Y")
    for k in range(14):
        x, z = p.rng.uniform(-1.8, 1.8), p.rng.uniform(-1.8, 1.8)
        p.box(x - 0.05, 0.12, z - 0.05, x + 0.05, 0.17, z + 0.05, WHITE)

    p = m.part("carrot", ao=True)
    _carrot_coin(p, 2.2, 0.5, n=22)
    for k in range(10):  # growth rings
        a = k * math.tau / 10
        p.box(math.cos(a) * 1.6 - 0.04, 0.25, math.sin(a) * 1.6 - 0.04, math.cos(a) * 1.6 + 0.04, 0.262, math.sin(a) * 1.6 + 0.04, hexc("#d86a1c"), faces="Y")

    p = m.part("mushroom", ao=True)
    lathe(p, [(-0.9, 0.55, hexc("#efe6d6")), (-0.35, 0.62, hexc("#efe6d6")), (-0.3, 2.3, hexc("#c99a72")), (0.05, 2.45, hexc("#b5835c")),
              (0.36, 2.35, hexc("#a87550")), (0.42, 2.0, hexc("#a87550")), (0.42, 0.0, hexc("#a87550"))], n=18)
    for k in range(7):
        a = k * math.tau / 7 + 0.3
        r = 1.2 + 0.4 * (k % 2)
        p.box(math.cos(a) * r - 0.14, 0.41, math.sin(a) * r - 0.14, math.cos(a) * r + 0.14, 0.45, math.sin(a) * r + 0.14, hexc("#efe2c8"))

    # floaters ride the soup surface (y 0 = surface); r 14..28, clear of the raft
    p = m.part("floaters")
    rng = p.rng
    for i in range(150):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(14.2, 28.0)
        x, z = math.cos(a) * r, math.sin(a) * r
        kind = rng.random()
        p.push(x, 0, z, yaw=rng.uniform(0, 360))
        if kind < 0.3:
            _carrot_coin(p, rng.uniform(0.35, 0.6), 0.14, y=0.02, n=10)
        elif kind < 0.5:
            p.ball(0, 0.05, 0, rng.uniform(0.18, 0.28), jitter(hexc("#69c24a"), rng, 0.1), n=6, rings=4)
        elif kind < 0.65:  # celery crescent
            p.box(-0.5, -0.04, -0.12, 0.5, 0.1, 0.12, hexc("#a8d86a"))
            p.box(-0.45, 0.1, -0.1, 0.45, 0.12, 0.0, hexc("#c8ec92"))
        elif kind < 0.78:  # onion ring
            for k in range(8):
                b0 = k * math.tau / 8
                p.beam((math.cos(b0) * 0.45, 0.04, math.sin(b0) * 0.45), (math.cos(b0 + math.tau / 8) * 0.45, 0.04, math.sin(b0 + math.tau / 8) * 0.45), 0.07, hexc("#f4ead2"))
        elif kind < 0.88:  # herb leaf
            p.face([p.P(0, 0.06, -0.35), p.P(-0.18, 0.06, 0), p.P(0, 0.06, 0.3), p.P(0.18, 0.06, 0)], hexc("#3f8f3a"))
        else:  # a bubble
            p.ball(0, 0.0, 0, rng.uniform(0.2, 0.45), hexc("#ffb15a"), n=7, rings=4, sy=0.6, glow=0.25)
        p.pop()

    # the chef's tasting ladle (falls from the sky; centre of the bowl at 0)
    p = m.part("ladle")
    st, st_d = hexc("#c4ccd8"), hexc("#8d96a6")
    lathe(p, [(-2.4, 0.0, st), (-2.25, 1.8, st), (-1.6, 3.4, st), (-0.6, 4.4, st), (0.3, 4.7, st_d), (0.35, 4.45, st_d),
              (-0.4, 4.1, st_d), (-1.3, 3.1, st_d), (-1.9, 1.6, scale_col(st_d, 0.8)), (-2.0, 0.0, st_d)], n=20)
    p.rod((4.3, 0.2, 0), (5.4, 33.0, 0), 0.42, st, n=10)
    p.rod((5.4, 33.0, 0), (5.2, 35.0, 0), 0.42, st, n=10)
    p.cyl(5.3, 34.0, 0, 0.62, 35.2, 0.62, hexc("#2a2a32"), n=8)  # grip
    p.ball(4.3, 0.25, 0, 0.6, st_d, n=6, rings=4)

    # the god's hand: palm down, fingers toward +z, thumb at +x
    p = m.part("hand")
    sk, sk_d, nail = SKIN, scale_col(SKIN, 0.82), hexc("#ffe2d2")
    sphere(p, 1.0, lambda j, i: sk if j > 2 else sk_d, n=14, rings=8, cy=0.0, sx=2.15, sy=0.78, sz=2.55)
    for k in range(4):
        x = -1.5 + k * 1.0
        ln = (2.6, 3.2, 3.0, 2.3)[k]
        p.rod((x, -0.05, 1.4), (x, -0.1, 1.6 + ln), 0.42, sk, n=10)
        p.ball(x, -0.1, 1.6 + ln, 0.42, sk, n=8, rings=5)
        p.box(x - 0.24, 0.15, 1.6 + ln - 0.3, x + 0.24, 0.3, 1.6 + ln + 0.25, nail)
        p.box(x - 0.4, 0.3, 2.4, x + 0.4, 0.36, 2.48, sk_d)  # knuckle crease
    p.rod((1.6, -0.1, 0.2), (3.4, -0.1, 1.7), 0.45, sk, n=10)
    p.ball(3.4, -0.1, 1.7, 0.45, sk, n=8, rings=5)
    p.push(0, 0, -1.4, pitch=-90)  # a robe sleeve with a gold cuff
    p.cyl(0, -0.6, 0, 1.75, 2.6, 2.1, hexc("#f4f1ea"), n=14)
    p.cyl(0, -0.75, 0, 1.8, -0.45, 1.8, hexc("#e2b23a"), n=14, caps=False)
    p.pop()

    # Giant Hunt: ruined columns (collider cylinder r 0.8; scaled in y by the game)
    for k, H in enumerate((2.0, 3.5, 5.0)):
        p = m.part("pillar%d" % k, seed=700 + k, ao=True)
        p.cyl(0, 0.0, 0, 0.9, 0.18, 0.88, STONE_D, n=8)
        p.cyl(0, 0.18, 0, 0.86, 0.38, 0.82, STONE, n=8)
        nf = 20
        top = H - 0.35
        ring = lambda y, rr, jag=0.0: [p.P(math.cos(math.tau * i / nf) * (rr if i % 2 == 0 else rr * 0.9), y + (jag * (0.5 + 0.5 * math.sin(i * 2.7 + k)) if jag else 0.0),
                                           math.sin(math.tau * i / nf) * (rr if i % 2 == 0 else rr * 0.9)) for i in range(nf)]
        levels = [0.38, 0.38 + (top - 0.38) * 0.5, top]
        rads = [0.8, 0.76, 0.72]
        rr = [ring(levels[0], rads[0]), ring(levels[1], rads[1]), ring(levels[2], rads[2], jag=-0.4)]
        for L in range(2):
            A, B = rr[L], rr[L + 1]
            for i in range(nf):
                j = (i + 1) % nf
                c = jitter(STONE if i % 2 == 0 else scale_col(STONE, 0.86), p.rng, 0.05)
                if L == 0 and p.rng.random() < 0.25:
                    c = mix(c, MOSS, 0.5)
                p.face([A[j], A[i], B[i], B[j]], c)
        p.face(list(reversed(rr[2])), scale_col(STONE, 1.08))
        for i in range(5):  # moss creeping up from the base and ivy leaves
            a = p.rng.uniform(0, math.tau)
            y = p.rng.uniform(0.4, min(1.6, top - 0.2))
            p.push(math.cos(a) * 0.8, y, math.sin(a) * 0.8, yaw=-math.degrees(a) + 90)
            p.box(-0.18, 0, -0.02, 0.18, 0.28, 0.03, jitter(LEAF, p.rng, 0.12))
            p.pop()
        for i in range(4):  # rubble
            a = p.rng.uniform(0, math.tau)
            p.ball(math.cos(a) * 1.15, 0.08, math.sin(a) * 1.15, p.rng.uniform(0.1, 0.2), STONE_D, n=5, rings=3)

    # boulders (unit radius; game scales 1.25 x 0.75 x 1.0 like the old rocks)
    for k in range(3):
        p = m.part("rock%d" % k, seed=720 + k, ao=True)
        nr, ns = 6, 9
        pts = []
        for j in range(nr + 1):
            lat = -math.pi / 2 + math.pi * j / nr
            row = []
            for i in range(ns):
                lon = math.tau * i / ns
                f = 1.0 + 0.16 * _n(i + k * 3, j, k)
                if j in (0, nr):
                    f = 1.0
                row.append(p.P(math.cos(lat) * math.cos(lon) * f, math.sin(lat) * f, math.cos(lat) * math.sin(lon) * f))
            pts.append(row)
        base = mix(hexc("#a39cb3"), hexc("#7b7390"), k * 0.3)
        for j in range(nr):
            for i in range(ns):
                q = (i + 1) % ns
                c = jitter(base, p.rng, 0.07)
                if j >= nr - 2 and p.rng.random() < 0.6:
                    c = jitter(MOSS, p.rng, 0.1)
                p.face([pts[j][q], pts[j][i], pts[j + 1][i], pts[j + 1][q]], c)

    # dirt patch: unit radius, game stretches it
    p = m.part("dirt", ao=False)
    nd = 16
    edge = [(math.cos(math.tau * i / nd) * (1.0 + 0.16 * _n(i, 1)), math.sin(math.tau * i / nd) * (1.0 + 0.16 * _n(i, 2))) for i in range(nd)]
    inner = [(x * 0.62, z * 0.62) for (x, z) in edge]
    for i in range(nd):
        j = (i + 1) % nd
        P = p.P
        p.face([P(edge[i][0], 0.0, edge[i][1]), P(inner[i][0], 0.012, inner[i][1]), P(inner[j][0], 0.012, inner[j][1]), P(edge[j][0], 0.0, edge[j][1])], hexc("#a88e6c"))
    p.face([p.P(x, 0.012, z) for (x, z) in inner][::-1], hexc("#9a7f5e"))

    # far mountain: authored 70 m tall, r 45; the game scales its height
    p = m.part("mountain", seed=740)
    nr, ns = 7, 11
    rows = []
    for j in range(nr + 1):
        t = j / nr
        y = 70.0 * t
        row = []
        for i in range(ns):
            a = math.tau * i / ns
            rr = 45.0 * (1.0 - t) ** 0.85 * (1.0 + 0.22 * _n(i, j, 3)) if j < nr else 0.0
            row.append(p.P(math.cos(a) * rr, y - 6.0 + (4.0 * _n(i, 9) if j == 0 else 0.0), math.sin(a) * rr))
        rows.append(row)
    for j in range(nr):
        for i in range(ns):
            q = (i + 1) % ns
            t = (j + 0.5) / nr
            c = hexc("#f4f6fa") if t > 0.68 + 0.08 * _n(i, j) else mix(hexc("#6f9fb0"), hexc("#557f96"), 0.5 + 0.5 * _n(i, j, 1))
            if j == nr - 1:
                p.face([rows[j][q], rows[j][i], rows[j + 1][i]], c)
            else:
                p.face([rows[j][q], rows[j][i], rows[j + 1][i], rows[j + 1][q]], c)
    m.finish(out)


# --- Pocket God ------------------------------------------------------------------------
def pg_camp(out):
    """Castaway workshop, front (+z) toward the pad. About 14 x 11 m."""
    m = LM("pg_camp", 621)
    sand = hexc("#d9bf86")
    pts = [(math.cos(a) * (7.4 + 0.8 * _n(a * 3, 1)), math.sin(a) * (5.8 + 0.6 * _n(a * 2, 2))) for a in [k * math.tau / 20 for k in range(20)]]
    poly_slab(m, pts, -0.3, 0.03, sand, side=scale_col(sand, 0.8))
    # lean-to: high at the front, roofed in planks and fronds
    for (x, z, h) in ((-3.2, -0.6, 2.7), (3.2, -0.6, 2.7), (-3.2, -3.4, 1.5), (3.2, -3.4, 1.5)):
        m.box(x - 0.12, 0, z - 0.12, x + 0.12, h, z + 0.12, jitter(BARK_C, m.rng, 0.08))
        m.col(x - 0.12, 0, z - 0.12, x + 0.12, h, z + 0.12)
    slope = lambda z: 2.75 + (z + 0.3) * (1.23 / 3.4)
    rows = 5
    for row in range(rows):  # dried fronds, rows abutting (overlaps bake black)
        z0 = -3.75 + row * 3.6 / rows
        z1 = z0 + 3.6 / rows
        for k in range(10):
            x0 = -3.75 + k * 0.75
            c = jitter(mix(hexc("#b8a35a"), LEAF, 0.12 + 0.12 * (k % 2)), m.rng, 0.05)
            m.face([m.P(x0, slope(z1), z1), m.P(x0 + 0.75, slope(z1), z1),
                    m.P(x0 + 0.75, slope(z0) - 0.07, z0), m.P(x0, slope(z0) - 0.07, z0)], c)
        m.box(-3.75, slope(z1) - 0.12, z1 - 0.04, 3.75, slope(z1) + 0.01, z1, scale_col(hexc("#b8a35a"), 0.7), faces="Z")
    for k in range(9):  # plank undersides, seen from inside
        x0 = -3.6 + k * 0.8
        c = jitter(hexc("#d9b27c"), m.rng, 0.1)
        m.face([m.P(x0, slope(-3.75) - 0.14, -3.75), m.P(x0 + 0.76, slope(-3.75) - 0.14, -3.75),
                m.P(x0 + 0.76, slope(-0.15) - 0.14, -0.15), m.P(x0, slope(-0.15) - 0.14, -0.15)], c)
    # bed roll and a hammock of sacking under the roof
    m.box(-2.6, 0.03, -3.1, -0.6, 0.25, -1.1, hexc("#7a8fb0"))
    m.box(-2.6, 0.25, -3.1, -2.1, 0.42, -1.1, hexc("#e8e2d0"))
    m.room(-3.8, 0, -3.9, 3.8, 2.8, -0.1, level=0.16)
    # workbench + tools + a half-built fin
    m.push(4.2, 0, 1.4, yaw=-12)
    m.box(-1.3, 0.92, -0.55, 1.3, 1.04, 0.55, jitter(WOOD, m.rng, 0.05))
    for sx in (-1, 1):
        for sz in (-1, 1):
            m.box(sx * 1.15 - 0.07, 0, sz * 0.42 - 0.07, sx * 1.15 + 0.07, 0.92, sz * 0.42 + 0.07, WOOD_D)
    m.box(-1.15, 0.3, -0.45, 1.15, 0.36, 0.45, WOOD_D)
    m.col(-1.3, 0, -0.55, 1.3, 1.04, 0.55)
    m.box(-0.9, 1.04, -0.1, -0.2, 1.08, 0.12, STEEL)              # saw blade
    m.box(-0.25, 1.04, -0.08, 0.0, 1.14, 0.1, hexc("#c0392b"))     # saw handle
    m.box(0.3, 1.04, 0.15, 0.75, 1.1, 0.23, WOOD_L)                # hammer
    m.box(0.62, 1.04, 0.05, 0.82, 1.18, 0.33, IRON)
    m.face([m.P(0.2, 1.06, -0.45), m.P(1.15, 1.06, -0.45), m.P(0.7, 1.06, -0.05)][::-1], RED)  # fin
    m.cyl(-0.6, 1.04, 0.3, 0.12, 1.16, 0.12, hexc("#e8e2d0"), n=6)  # tape roll
    m.pop()
    # blueprint easel: the plan is very confident
    m.push(-4.6, 0, 1.6, yaw=20)
    for sx in (-0.7, 0.7):
        m.beam((sx, 0, -0.3), (sx * 0.8, 2.6, 0.0), 0.05, WOOD_D)
    m.beam((0, 0, -0.9), (0, 2.4, -0.05), 0.05, WOOD_D)
    m.box(-1.1, 0.9, -0.08, 1.1, 2.4, 0.0, hexc("#2d5fa8"))
    m.box(-1.15, 0.85, -0.02, 1.15, 0.92, 0.12, WOOD_D)
    wl = hexc("#dfeaff")
    m.box(-0.12, 1.15, 0.0, 0.12, 2.0, 0.02, wl, glow=0.05, faces="xXyYZ")   # rocket outline
    m.face([m.P(-0.12, 2.0, 0.021), m.P(0.12, 2.0, 0.021), m.P(0.0, 2.25, 0.021)], wl)
    m.face([m.P(-0.12, 1.15, 0.021), m.P(-0.12, 1.45, 0.021), m.P(-0.32, 1.12, 0.021)], wl)
    m.face([m.P(0.12, 1.45, 0.021), m.P(0.12, 1.15, 0.021), m.P(0.32, 1.12, 0.021)], wl)
    m.text("v14", 0.65, 1.95, 0.0, 0.26, wl, font="Bungee-Regular", depth=0.02, res=1)
    m.text("it will fly", 0.62, 1.2, 0.0, 0.13, wl, font="Bungee-Regular", depth=0.02, res=1)
    m.pop()
    # crates and fuel drums
    crate(m, -5.2, -1.6, 1.1, yaw=8)
    crate(m, -5.0, -1.5, 0.8, yaw=-20, y=1.1)
    crate(m, -4.1, -2.8, 0.9, yaw=30)
    m.col(-5.8, 0, -2.2, -4.6, 1.9, -1.0)
    m.col(-4.6, 0, -3.3, -3.6, 0.9, -2.3)
    for (x, z, c) in ((5.6, -1.6, hexc("#c0392b")), (6.2, -0.8, hexc("#2d6fb0"))):
        m.cyl(x, 0, z, 0.42, 1.2, 0.42, c, n=10)
        for y in (0.3, 0.9):
            m.cyl(x, y - 0.04, z, 0.44, y + 0.04, 0.44, scale_col(c, 0.7), n=10)
        m.col(x - 0.42, 0, z - 0.42, x + 0.42, 1.2, z + 0.42)
    # fire pit: ring of stones, logs, flames, a fish on a stick
    fx, fz = 0.0, 3.3
    for k in range(10):
        a = k * math.tau / 10
        m.ball(fx + math.cos(a) * 0.9, 0.12, fz + math.sin(a) * 0.9, 0.22, jitter(STONE_D, m.rng, 0.12), n=5, rings=3)
    for k in range(3):
        a = k * math.tau / 3 + 0.4
        m.beam((fx + math.cos(a) * 0.6, 0.12, fz + math.sin(a) * 0.6), (fx + math.cos(a) * 0.05, 0.38, fz + math.sin(a) * 0.05), 0.08, BARK_C)
    m.ball(fx, 0.1, fz, 0.45, hexc("#3a2620"), n=6, rings=3, sy=0.3, glow=0.2)
    flame(m, fx, 0.2, fz, 2.0)
    flame(m, fx + 0.18, 0.18, fz - 0.1, 1.3)
    flame(m, fx - 0.15, 0.18, fz + 0.12, 1.4)
    m.lamp(fx, 0.8, fz, radius=4.5, power=0.25, col=(1.0, 0.65, 0.35))
    for sx in (-1, 1):
        m.beam((fx + sx * 1.1, 0, fz), (fx + sx * 1.1, 1.2, fz), 0.04, WOOD_D)
    m.beam((fx - 1.2, 1.2, fz), (fx + 1.2, 1.2, fz), 0.03, WOOD_D)
    m.ball(fx, 1.05, fz, 0.22, hexc("#7fa7c0"), n=6, rings=4, sy=0.6)
    m.face([m.P(fx + 0.2, 1.05, fz), m.P(fx + 0.42, 1.2, fz), m.P(fx + 0.42, 0.9, fz)][::-1], hexc("#7fa7c0"))
    for k in range(3):  # stump stools
        a = k * 1.4 + 2.4
        x, z = fx + math.cos(a) * 2.0, fz + math.sin(a) * 2.0
        m.cyl(x, 0, z, 0.32, 0.45, 0.3, BARK_C, n=7)
        m.cyl(x, 0.45, z, 0.3, 0.47, 0.28, hexc("#d9b27c"), n=7)
    # washing line from the lean-to to a pole: the island has standards
    m.box(5.9, 0, -3.2, 6.1, 2.4, -3.0, WOOD_D)
    m.col(5.9, 0, -3.2, 6.1, 2.4, -3.0)
    for k in range(9):
        t0, t1 = k / 9, (k + 1) / 9
        sag = lambda t: 2.35 - math.sin(t * math.pi) * 0.25
        m.beam((3.2 + 2.8 * t0, sag(t0), -0.6 - 2.5 * t0), (3.2 + 2.8 * t1, sag(t1), -0.6 - 2.5 * t1), 0.012, WHITE)
    for (t, c) in ((0.3, hexc("#ff8a3d")), (0.55, hexc("#3ec1ff")), (0.8, WHITE)):
        x, z, y = 3.2 + 2.8 * t, -0.6 - 2.5 * t, 2.35 - math.sin(t * math.pi) * 0.25
        m.push(x, y, z, yaw=42)
        m.box(-0.3, -0.7, -0.02, 0.3, 0.0, 0.02, c)
        m.box(-0.45, -0.25, -0.02, 0.45, 0.0, 0.02, c)
        m.pop()
    # sign: this way to the launch
    m.push(6.6, 0, 4.0, yaw=-90)
    m.box(-0.08, 0, -0.08, 0.08, 2.1, 0.08, WOOD_D)
    m.col(-0.12, 0, -0.12, 0.12, 2.1, 0.12)
    sb = hexc("#e8d6ae")
    m.box(-0.9, 1.45, 0.08, 0.7, 1.9, 0.16, sb)
    m.face([m.P(0.7, 1.4, 0.16), m.P(1.05, 1.675, 0.16), m.P(0.7, 1.95, 0.16)], sb)
    m.face([m.P(0.7, 1.4, 0.08), m.P(0.7, 1.95, 0.08), m.P(1.05, 1.675, 0.08)], scale_col(sb, 0.7))
    m.text("LAUNCH", -0.1, 1.58, 0.16, 0.24, hexc("#7a2a1c"), font="Rye-Regular", depth=0.02, res=1)
    m.pop()
    m.finish(out)


BARK_C = hexc("#6e4429")


# --- Giant Hunt ------------------------------------------------------------------------
def gh_fence(out):
    """One side of the palisade, 92 m along x, inside face +z. Collider in code."""
    m = LM("gh_fence", 631)
    L = 46.0
    x = -L
    k = 0
    while x < L:
        h = 3.0 + m.rng.uniform(0.0, 0.55)
        r = m.rng.uniform(0.17, 0.21)
        lean = m.rng.uniform(-0.04, 0.04)
        c = jitter(hexc("#9a6a3e") if k % 7 else hexc("#7d5532"), m.rng, 0.09)
        m.push(x + r, 0, 0, roll=math.degrees(lean))
        m.cyl(0, -0.3, 0, r, h, r * 0.95, c, n=6, caps=False)
        m.cyl(0, h, 0, r * 0.95, h + 0.5, 0.0, scale_col(c, 1.12), n=6, caps=False)
        m.pop()
        x += r * 2 - 0.02
        k += 1
    for y in (0.75, 2.35):  # rails, lashed every few metres
        m.box(-L, y - 0.09, 0.2, L, y + 0.09, 0.3, jitter(hexc("#7d5532"), m.rng, 0.05))
        for i in range(24):
            xx = -L + 2.0 + i * 3.83
            m.box(xx - 0.07, y - 0.13, 0.17, xx + 0.07, y + 0.13, 0.32, hexc("#d8c08a"))
    for i in range(4):  # round shields and torches on the inside
        xx = -34.5 + i * 23.0
        m.push(xx, 1.75, 0.3, pitch=90)
        m.cyl(0, 0.0, 0, 0.55, 0.08, 0.55, [RED, hexc("#2d6fb0"), YEL, hexc("#3f8f3a")][i], n=12)
        m.cyl(0, 0.08, 0, 0.16, 0.16, 0.16, BRASS, n=8)
        m.pop()
        tx = xx + 11.5
        if tx < L - 1:
            m.box(tx - 0.06, 2.55, 0.2, tx + 0.06, 2.65, 0.55, IRON)
            m.cyl(tx, 2.6, 0.55, 0.08, 3.2, 0.1, BARK_C, n=6)
            m.cyl(tx, 3.2, 0.55, 0.14, 3.35, 0.14, hexc("#3a2620"), n=6)
            flame(m, tx, 3.3, 0.55, 1.6)
    m.finish(out)


def gh_hut(out):
    """Little-only hut, 6 x 6 m, doorway 1.6 x 1.4 on +z. Colliders in code."""
    m = LM("gh_hut", 641)
    timber = hexc("#8a5e38")
    pl = PLASTER
    walls = ((-3.2, -3.2, 3.2, -2.8, "xXyYzZ"), (-3.2, -2.8, -2.8, 2.8, "xXyY"), (2.8, -2.8, 3.2, 2.8, "xXyY"),
             (-3.2, 2.8, -0.8, 3.2, "xXyYzZ"), (0.8, 2.8, 3.2, 3.2, "xXyYzZ"))
    for (x0, z0, x1, z1, f) in walls:
        m.box(x0 - 0.06, 0, z0 - 0.06, x1 + 0.06, 0.45, z1 + 0.06, jitter(STONE_D, m.rng, 0.05), faces=f.replace("y", ""))  # stone footing
        m.box(x0, 0.45, z0, x1, 3.0, z1, jitter(pl, m.rng, 0.04), sub=1.0, faces=f.replace("y", ""))
    m.box(-0.8, 1.4, 2.8, 0.8, 3.0, 3.2, jitter(pl, m.rng, 0.04), sub=1.0, faces="yYzZ")
    # timber frame, proud of the plaster: corner posts, mid rail, braces
    for cx in (-3.2, 3.2):
        for cz in (-3.2, 3.2):
            m.box(cx - 0.16, 0.45, cz - 0.16, cx + 0.16, 3.0, cz + 0.16, timber)
    for (a, b) in (((-3.25, -3.0), (3.25, -3.0)), ((-3.0, 3.25), (-3.0, -3.25)), ((3.0, -3.25), (3.0, 3.25))):
        m.beam((a[0], 1.75, a[1]), (b[0], 1.75, b[1]), 0.08, timber)
        m.beam((a[0], 2.95, a[1]), (b[0], 2.95, b[1]), 0.09, timber)
    m.beam((-3.25, 2.95, 3.25), (3.25, 2.95, 3.25), 0.09, timber)
    for (p0, p1) in (((-3.25, 0.5, -1.0), (-3.25, 1.7, 1.0)), ((3.25, 0.5, 1.0), (3.25, 1.7, -1.0)), ((-1.0, 0.5, -3.25), (1.0, 1.7, -3.25))):
        m.beam(p0, p1, 0.07, timber)
    m.box(-0.97, 0.0, 2.74, -0.76, 1.55, 3.33, timber)  # door frame
    m.box(0.76, 0.0, 2.74, 0.97, 1.55, 3.33, timber)
    m.box(-0.97, 1.4, 2.74, 0.97, 1.58, 3.33, timber)
    m.box(-0.76, 0.0, 2.8, 0.76, 0.05, 3.3, scale_col(timber, 0.8))  # step
    # little windows (shuttered: nothing to see)
    for (x, z, yaw) in ((-3.22, 0.0, -90), (3.22, 0.0, 90)):
        m.push(x, 2.0, z, yaw=yaw)
        m.box(-0.45, -0.35, 0.0, 0.45, 0.35, 0.06, hexc("#3a2a20"))
        m.box(-0.55, -0.42, 0.0, -0.02, 0.42, 0.1, jitter(hexc("#4f8a6a"), m.rng, 0.08))
        m.box(0.02, -0.42, 0.0, 0.55, 0.42, 0.1, jitter(hexc("#4f8a6a"), m.rng, 0.08))
        m.pop()
    # thatched pyramid roof: eaves overhang past the walls, peak at 5.7
    E, ye, yp = 3.75, 2.9, 5.7
    rows = 6
    for side in range(4):
        m.push(0, 0, 0, yaw=side * 90)
        for r in range(rows):
            t0, t1 = r / rows, (r + 1) / rows
            e0, e1 = E * (1 - t0), E * (1 - t1)
            y0, y1 = ye + (yp - ye) * t0, ye + (yp - ye) * t1
            c = jitter(THATCH, m.rng, 0.1)
            lip = 0.1
            m.face([m.P(-e0, y0 - lip, e0), m.P(e0, y0 - lip, e0), m.P(e1, y1, e1), m.P(-e1, y1, e1)], c)
            m.face([m.P(e0, y0 - lip - 0.14, e0), m.P(-e0, y0 - lip - 0.14, e0), m.P(-e1, y1 - 0.14, e1), m.P(e1, y1 - 0.14, e1)], scale_col(c, 0.45))
        for k in range(16):  # ragged fringe
            x = -E + (k + 0.5) * 2 * E / 16
            m.box(x - 0.1, ye - 0.32 - m.rng.uniform(0, 0.12), E - 0.04, x + 0.1, ye - 0.05, E + 0.08, jitter(scale_col(THATCH, 0.85), m.rng, 0.1))
        m.pop()
    m.cyl(0, yp - 0.2, 0, 0.35, yp + 0.4, 0.05, scale_col(THATCH, 0.8), n=6)
    m.beam((0, yp + 0.2, 0), (0.1, yp + 1.0, 0.05), 0.04, timber)
    # inside: straw bed, a cook pot, a stool
    m.box(-2.6, 0.0, -2.6, -0.6, 0.35, -1.0, jitter(THATCH, m.rng, 0.05))
    m.box(-2.6, 0.35, -2.6, -1.9, 0.5, -1.0, hexc("#c8b8a0"))
    m.cyl(1.8, 0.0, -1.6, 0.45, 0.6, 0.5, IRON, n=10)
    m.cyl(1.8, 0.6, -1.6, 0.52, 0.66, 0.52, scale_col(IRON, 0.8), n=10)
    m.cyl(1.5, 0, 1.4, 0.25, 0.45, 0.25, WOOD, n=7)
    m.room(-2.8, 0, -2.8, 2.8, 3.0, 2.8, level=0.1)
    m.finish(out)


def gh_rack(out):
    """Spear rack: posts at x +-0.8, crossbar at 1.45, spears leaning back."""
    m = LM("gh_rack", 651)
    w = hexc("#8a5a32")
    for sx in (-1, 1):
        m.box(sx * 0.8 - 0.08, 0, -0.08, sx * 0.8 + 0.08, 1.62, 0.08, jitter(w, m.rng, 0.06))
        m.beam((sx * 0.8, 0.0, -0.55), (sx * 0.8, 0.9, 0.0), 0.05, w)  # strut
        m.cyl(sx * 0.8, 1.62, 0, 0.1, 1.72, 0.04, w, n=6)
    m.box(-0.95, 1.38, -0.08, 0.95, 1.52, 0.08, scale_col(w, 0.9))
    m.box(-0.95, 0.3, -0.08, 0.95, 0.4, 0.08, scale_col(w, 0.9))
    for i in range(3):  # spears: shaft, binding, iron point
        x = -0.5 + i * 0.5
        m.push(x, 0.05, 0.25, pitch=-15)
        m.cyl(0, 0, 0, 0.04, 2.0, 0.04, hexc("#d9b27c"), n=5)
        m.cyl(0, 1.75, 0, 0.055, 1.9, 0.055, hexc("#c0392b"), n=5)
        m.cyl(0, 2.0, 0, 0.09, 2.32, 0.0, hexc("#c0c6d0"), n=5)
        m.pop()
    m.cyl(1.25, 0, 0.1, 0.3, 0.6, 0.34, hexc("#b8925a"), n=9)  # basket of spares
    for i in range(3):
        m.beam((1.25 + (i - 1) * 0.1, 0.3, 0.1), (1.25 + (i - 1) * 0.25, 1.5, 0.1 + i * 0.05), 0.03, hexc("#d9b27c"))
    m.finish(out)


def gh_plaza(out):
    """Worn flagstones round the giant's spawn, r 7.5, top 4 cm above the ground."""
    m = LM("gh_plaza", 661)
    radii = [0.0, 1.6, 3.2, 4.8, 6.3, 7.6]
    for k in range(len(radii) - 1):
        r0, r1 = radii[k] + 0.06, radii[k + 1] - 0.06
        n = max(5, int(r1 * 2.2))
        for i in range(n):
            if k == len(radii) - 2 and m.rng.random() < 0.3:
                continue  # the outer ring is missing stones
            a0 = i * math.tau / n + 0.05 / max(r1, 1.0) + k * 0.3
            a1 = (i + 1) * math.tau / n - 0.05 / max(r1, 1.0) + k * 0.3
            c = jitter(STONE if m.rng.random() > 0.25 else STONE_D, m.rng, 0.07)
            polar_slab(m, max(r0, 0.0), r1, a0, a1, -0.1, 0.04 + m.rng.uniform(-0.01, 0.0), c)
    m.finish(out)


# --- Cursed Casino ------------------------------------------------------------------------
def _gate(m, W, H, sign):
    """Barred, chained door, W along x, H tall, 0.6 thick, inside face +z."""
    iron, iron_d = hexc("#6a6278"), hexc("#4a4458")
    blood = hexc("#a8302c")
    m.box(-W * 0.5, 0, -0.3, -W * 0.5 + 0.22, H, 0.3, iron_d)
    m.box(W * 0.5 - 0.22, 0, -0.3, W * 0.5, H, 0.3, iron_d)
    m.box(-W * 0.5, H - 0.25, -0.3, W * 0.5, H, 0.3, iron_d)
    x = -W * 0.5 + 0.4
    while x < W * 0.5 - 0.3:
        m.box(x - 0.045, 0, -0.05, x + 0.045, H - 0.2, 0.05, iron)
        m.cyl(x, H - 0.25, 0, 0.07, H + 0.15, 0.0, iron, n=4)
        x += 0.36
    for y in (0.6, H * 0.5, H - 0.6):
        m.box(-W * 0.5, y - 0.07, -0.08, W * 0.5, y + 0.07, 0.08, iron_d)
        bolts(m, [(-W * 0.5 + 0.11, y, 0.1), (W * 0.5 - 0.11, y, 0.1)], STEEL_D, 0.05)
    # boards nailed across in a hurry
    for bi, (a, b) in enumerate((((-W * 0.5 + 0.1, 0.8), (W * 0.5 - 0.1, H - 1.1)), ((-W * 0.5 + 0.1, H - 1.0), (W * 0.5 - 0.1, 0.9)))):
        m.push(0, 0, 0.16 + 0.06 * bi)
        d = math.hypot(b[0] - a[0], b[1] - a[1])
        ang = math.degrees(math.atan2(b[1] - a[1], b[0] - a[0]))
        m.push((a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5, 0.0, roll=ang)
        m.box(-d * 0.5, -0.16, -0.04, d * 0.5, 0.16, 0.06, jitter(blood, m.rng, 0.1))
        m.pop()
        m.pop()
    # chain loops and a fat padlock in the middle
    cy = H * 0.5
    for k in range(9):
        t = k / 8
        px = -0.9 + 1.8 * t
        py = cy + 0.15 - math.sin(t * math.pi) * 0.45
        m.push(px, py, 0.3, roll=90 if k % 2 else 0)
        m.box(-0.12, -0.05, -0.03, 0.12, 0.05, 0.03, STEEL)
        m.pop()
    m.box(-0.28, cy - 0.85, 0.28, 0.28, cy - 0.35, 0.44, BRASS)
    m.cyl(0, cy - 0.35, 0.36, 0.18, cy - 0.12, 0.18, STEEL, n=8, caps=False)
    m.box(-0.05, cy - 0.68, 0.44, 0.05, cy - 0.52, 0.45, INK)
    if sign:
        size = 0.78
        sw = len(sign) * size * 0.2 + 0.35
        m.box(-sw, cy + 0.55, 0.3, sw, cy + 1.6, 0.36, hexc("#1a1018"))
        m.box(-sw - 0.06, cy + 0.49, 0.28, sw + 0.06, cy + 1.66, 0.3, BRASS)
        m.text(sign, 0, cy + 0.78, 0.36, size, hexc("#ff4a5c"), font="Bungee-Regular", depth=0.03, glow=1.0, res=1)
    m.room(-W * 0.5, 0, -0.4, W * 0.5, H, 0.8, level=0.12, col=(1.0, 0.7, 0.9))


def cc_gate_big(out):
    """Front doors: collider 0.6 x 5.2 x 7.4 (here 7.4 along x)."""
    m = LM("cc_gate_big", 671)
    _gate(m, 7.4, 5.2, "NOBODY LEAVES")
    m.finish(out)


def cc_gate_small(out):
    """Side doors: collider 5.4 x 4.4 x 0.6."""
    m = LM("cc_gate_small", 672)
    _gate(m, 5.4, 4.4, "LOCKED")
    m.finish(out)


def cc_candles(out):
    """Floor candelabra with purple flames, 2 m tall. Collider in code (r 0.35)."""
    m = LM("cc_candles", 681)
    lathe(m, [(0.0, 0.42, IRON), (0.08, 0.38, IRON), (0.16, 0.12, BRASS), (1.5, 0.07, IRON), (1.55, 0.13, BRASS), (1.62, 0.06, IRON)], n=10)
    for k in range(5):
        a = k * math.tau / 5
        x, z = (math.cos(a) * 0.38, math.sin(a) * 0.38) if k else (0.0, 0.0)
        y = 1.62 if k == 0 else 1.6
        if k:
            m.beam((0, 1.58, 0), (x, 1.62, z), 0.025, IRON)
        m.cyl(x, y, z, 0.07, y + 0.05, 0.08, BRASS, n=6)
        hh = 0.22 + 0.1 * (k % 2)
        m.cyl(x, y + 0.05, z, 0.045, y + 0.05 + hh, 0.045, hexc("#e8e2d0"), n=6)
        m.cyl(x, y + 0.05 + hh, z, 0.05, y + 0.25 + hh, 0.0, hexc("#c46bff"), n=5, glow=1.0)
        m.cyl(x, y + 0.06 + hh, z, 0.025, y + 0.16 + hh, 0.0, hexc("#f4dcff"), n=4, glow=1.0)
    # cobweb from the top to one arm
    for k in range(4):
        m.beam((0, 1.95, 0), (math.cos(k * 0.5) * 0.38, 1.7 - k * 0.05, math.sin(k * 0.5) * 0.38), 0.004, hexc("#d8d0e0"))
    m.lamp(0, 2.0, 0, radius=2.0, power=0.3, col=(0.8, 0.5, 1.0))
    m.finish(out)


def cc_mess(out):
    """Spilled chips and dropped cards over ~2 m: flat, nothing to trip on."""
    m = LM("cc_mess", 691)
    chip_cols = [RED, hexc("#2d6fb0"), hexc("#3f8f3a"), INK, WHITE, GOLD]
    for i in range(40):
        a = m.rng.uniform(0, math.tau)
        r = abs(m.rng.gauss(0, 0.7))
        x, z = math.cos(a) * r, math.sin(a) * r
        c = m.rng.choice(chip_cols)
        if i < 6:  # a toppled stack
            for k in range(m.rng.randint(2, 5)):
                m.cyl(x + k * 0.012, k * 0.03, z, 0.11, k * 0.03 + 0.03, 0.11, c if k % 2 else WHITE, n=8)
        else:
            m.cyl(x, 0.0, z, 0.11, 0.025, 0.11, c, n=8)
            m.cyl(x, 0.025, z, 0.05, 0.028, 0.05, WHITE, n=6)
    for i in range(7):
        x, z = m.rng.uniform(-1.2, 1.2), m.rng.uniform(-1.2, 1.2)
        m.push(x, 0.0, z, yaw=m.rng.uniform(0, 360))
        m.box(-0.16, 0.0, -0.23, 0.16, 0.012, 0.23, hexc("#f4f1ea") if i % 3 else hexc("#7a1020"), faces="Y")
        if i % 3:
            m.box(-0.04, 0.012, -0.05, 0.04, 0.016, 0.05, RED if i % 2 else INK, faces="Y")
        m.pop()
    m.finish(out, ao=False)


ALL = ["soup_raft", "game_bits", "pg_camp", "gh_fence", "gh_hut", "gh_rack", "gh_plaza", "cc_gate_big", "cc_gate_small", "cc_candles", "cc_mess"]
