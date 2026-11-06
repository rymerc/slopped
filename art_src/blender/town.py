"""Western district landmarks. Every number is metres in Godot axes, front door = +z."""
import math

from lm import LM, hexc, jitter, mix, scale_col

WOOD = hexc("#9c6238")
WOOD_D = hexc("#6e4326")
WOOD_L = hexc("#c08a55")
CREAM = hexc("#f2dfb8")
INK = hexc("#2a1c28")
BRASS = hexc("#e6b23c")
ROOF = hexc("#5a3b33")
GLASS = (*hexc("#ffcf86"), 0.36)
NEON_PINK = hexc("#ff4f9a")
NEON_CYAN = hexc("#46e3ff")
NEON_GOLD = hexc("#ffd257")
BOTTLES = [hexc(c) for c in ("#3f8f55", "#b5502d", "#d99b2b", "#7a3fa0", "#3a7fbe", "#b23a55")]


def porch(m, x0, x1, z0, z1, y, deck=WOOD, posts=5, roof_y=4.6, roof_col=None, ramp_x=None, ramp_w=7.0, ramp_len=2.6):
    """Raised boardwalk + awning + ramp. Runs along the front of a building."""
    m.floor_boards(x0, z0, x1, z1, y, deck, along_x=True)
    m.box(x0, 0, z1 - 0.1, x1, y, z1, scale_col(deck, 0.55))
    m.col(x0, -0.2, z0, x1, y, z1)
    if roof_y:
        m.posts(x0 + 0.2, x1 - 0.2, posts, y, roof_y, z1 - 0.2, WOOD_L)
        rc = roof_col or ROOF
        rows = int((z1 - z0 + 0.6) / 0.45)
        for i in range(rows):
            a = z0 + (z1 + 0.6 - z0) * i / rows
            b = z0 + (z1 + 0.6 - z0) * (i + 1) / rows
            ya = roof_y + 0.65 - 0.65 * i / rows
            yb = roof_y + 0.65 - 0.65 * (i + 1) / rows
            c = jitter(rc, m.rng, 0.1)
            m.quad(m.P(x0 - 0.3, yb, b), m.P(x1 + 0.3, yb, b), m.P(x1 + 0.3, ya, a), m.P(x0 - 0.3, ya, a), c)
            m.quad(m.P(x1 + 0.3, yb - 0.16, b), m.P(x0 - 0.3, yb - 0.16, b), m.P(x0 - 0.3, ya - 0.16, a), m.P(x1 + 0.3, ya - 0.16, a), WOOD)
        m.box(x0 - 0.3, roof_y - 0.18, z1 - 0.28, x1 + 0.3, roof_y, z1 - 0.12, WOOD_D)
    # Boardwalks must never stop a running player: the whole front and both ends
    # are ramps, dressed as two broad steps.
    if ramp_x is not None:
        run = 1.3
        for (za, zb, ya, yb) in ((z1, z1 + run * 0.5, y, y * 0.5), (z1 + run * 0.5, z1 + run, y * 0.5, 0.0)):
            m.box(x0, 0, za, x1, ya, zb, jitter(deck, m.rng, 0.06), faces="YZ")
        m.col_ramp((0.5 * (x0 + x1), 0.0, z1 + run), (0.5 * (x0 + x1), y, z1), x1 - x0 + 2.0 * run)
        for (x_edge, sgn) in ((x0, -1), (x1, 1)):
            m.col_ramp((x_edge + sgn * run, 0.0, 0.5 * (z0 + z1)), (x_edge, y, 0.5 * (z0 + z1)), z1 - z0)
            m.box(min(x_edge, x_edge + sgn * run), 0, z0, max(x_edge, x_edge + sgn * run), y * 0.5, z1, jitter(deck, m.rng, 0.06), faces="xXY")


def hitching_rail(m, x0, x1, z):
    m.box(x0, 0, z - 0.08, x0 + 0.16, 1.1, z + 0.08, WOOD_D)
    m.box(x1 - 0.16, 0, z - 0.08, x1, 1.1, z + 0.08, WOOD_D)
    m.box(x0, 0.95, z - 0.05, x1, 1.07, z + 0.05, WOOD_L)


def saloon(out):
    m = LM("saloon", 11)
    W, D, F = 13.0, 9.0, 0.4   # half width, half depth, floor height
    H = 7.2
    red = hexc("#a33a2c")
    # interior floor
    m.floor_boards(-W, -D, W, D, F, WOOD)
    m.box(-W, -0.2, -D, W, F, D, WOOD_D, faces="xXzZ")
    m.col(-W, -0.3, -D, W, F, D)
    # walls: front (with door + windows), right, back, left
    door = (W - 2.0, 4.0, 0.0, 4.4)
    ops = [door, (3.0, 3.2, 1.7, 3.9), (W + 6.8, 3.2, 1.7, 3.9),   # ground floor
           (3.2, 2.2, 6.0, 8.3), (W - 1.1, 2.2, 6.0, 8.3), (W + 7.0, 2.2, 6.0, 8.3)]
    m.wall((-W, D), (W, D), 0, 11.6, red, ops, glass=GLASS, frame=CREAM, inner=WOOD_L)
    m.wall((W, D), (W, -D), 0, H, red, [(4.0, 2.4, 1.8, 4.0), (11.5, 2.4, 1.8, 4.0)], glass=GLASS, frame=CREAM, inner=WOOD_L)
    m.wall((W, -D), (-W, -D), 0, H, red, [(5.0, 2.0, 2.4, 4.0), (19.0, 2.0, 2.4, 4.0)], glass=GLASS, frame=CREAM, inner=WOOD_L)
    m.wall((-W, -D), (-W, D), 0, H, red, [(4.0, 2.4, 1.8, 4.0), (11.5, 2.4, 1.8, 4.0)], glass=GLASS, frame=CREAM, inner=WOOD_L)
    # ceiling + roof
    m.box(-W, H, -D, W, H + 0.12, D, WOOD, sub=2.2)
    m.prism_roof(-W, W, H + 0.1, -D, D - 0.3, 3.0, ROOF, over=0.4)
    m.gable_end(-W - 0.02, H + 0.1, -D, D - 0.3, 3.0, red)
    m.gable_end(W + 0.02, H + 0.1, -D, D - 0.3, 3.0, red, flip=True)
    # false front: stepped parapet + cornice + sign board
    m.box(-W - 0.1, 11.6, D - 0.22, W + 0.1, 11.9, D + 0.32, CREAM)
    m.box(-W - 0.3, 11.9, D - 0.26, W + 0.3, 12.1, D + 0.4, WOOD_D)
    for side in (-1, 1):  # corner pilasters
        m.box(side * W - 0.28, 0, D - 0.2, side * W + 0.28, 11.6, D + 0.3, CREAM)
    step = [(-7.5, 7.5, 13.2), (-4.5, 4.5, 14.2)]
    for (a, b, top) in step:
        m.wall((a, D), (b, D), 12.1, top, red, board=0.32, collide=False, t=0.24)
        m.box(a - 0.15, top, D - 0.2, b + 0.15, top + 0.22, D + 0.3, CREAM)
    # giant lettering
    m.box(-10.6, 8.6, D + 0.2, 10.6, 11.2, D + 0.3, hexc("#1f6a68"))
    m.box(-10.8, 8.45, D + 0.2, 10.8, 8.6, D + 0.33, BRASS)
    m.box(-10.8, 11.2, D + 0.2, 10.8, 11.35, D + 0.33, BRASS)
    m.text("SALOON", 0, 8.95, D + 0.3, 3.0, hexc("#ffcc5c"), depth=0.22, back=WOOD_D)
    m.bulbs((-10.6, 11.42, D + 0.36), (10.6, 11.42, D + 0.36), 30, 0.1, NEON_GOLD)
    m.bulbs((-10.6, 8.38, D + 0.36), (10.6, 8.38, D + 0.36), 30, 0.1, NEON_GOLD)
    m.text("MYSTERY SLOP", 0, 12.4, D + 0.34, 0.8, NEON_CYAN, font="Bungee-Regular", glow=0.8, depth=0.06, res=1)
    # porch + balcony
    porch(m, -W, W, D, D + 3.2, F, posts=7, roof_y=4.9, roof_col=hexc("#7b3a2f"), ramp_x=0.0, ramp_w=9.0)
    hitching_rail(m, -11.5, -6.5, D + 4.2)
    hitching_rail(m, 6.5, 11.5, D + 4.2)
    # balcony rail above the awning
    for x in range(-12, 13, 1):
        m.box(x - 0.05, 5.6, D + 1.05, x + 0.05, 6.35, D + 1.15, CREAM)
    m.box(-W, 6.3, D + 1.0, W, 6.42, D + 1.2, CREAM)
    m.box(-W, 5.52, D + 0.3, W, 5.62, D + 1.2, WOOD)
    # swinging doors
    for side, name in ((-1, "doorL"), (1, "doorR")):
        p = m.part(name)
        p.origin = (side * 2.0, F, D)
        w = -side * 1.45
        x0, x1 = (0.0, w) if w > 0 else (w, 0.0)
        p.box(x0, 0.7, -0.04, x1, 2.7, 0.04, hexc("#7a2f24"))
        for k in range(5):
            p.box(x0 + 0.06, 1.0 + k * 0.32, -0.07, x1 - 0.06, 1.14 + k * 0.32, 0.07, WOOD_L)
    # --- interior: the bar --------------------------------------------------------
    bz0, bz1 = -5.6, -4.3
    m.box(-9, F, bz0, 6.6, F + 1.25, bz1, WOOD_D)
    for k in range(32):
        x = -8.7 + k * 0.49
        m.box(x, F + 0.12, bz1, x + 0.34, F + 1.1, bz1 + 0.05, WOOD)
    m.box(-9.25, F + 1.25, bz0 - 0.1, 6.85, F + 1.4, bz1 + 0.28, hexc("#c98a3f"))
    m.box(-9.2, F + 0.1, bz1 + 0.15, 6.8, F + 0.2, bz1 + 0.26, BRASS)  # foot rail
    m.col(-9, F, bz0, 6.6, F + 1.4, bz1 + 0.2)
    # back bar: shelves, mirror, bottles
    m.box(-10, F, -D + 0.15, 7.5, F + 1.3, -D + 1.3, WOOD_D)
    m.box(-10, F + 1.3, -D + 0.15, 7.5, F + 5.1, -D + 0.5, WOOD)
    m.box(-5.2, F + 1.7, -D + 0.5, 2.7, F + 3.9, -D + 0.53, hexc("#7fb6c4"), glow=0.1)
    m.box(-5.45, F + 1.5, -D + 0.5, 2.95, F + 1.7, -D + 0.58, BRASS)
    m.box(-5.45, F + 3.9, -D + 0.5, 2.95, F + 4.1, -D + 0.58, BRASS)
    m.box(-5.45, F + 1.5, -D + 0.5, -5.2, F + 4.1, -D + 0.58, BRASS)
    m.box(2.7, F + 1.5, -D + 0.5, 2.95, F + 4.1, -D + 0.58, BRASS)
    for sx0, sx1 in ((-9.6, -5.7), (3.2, 7.1)):
        for lvl in range(3):
            y = F + 1.75 + lvl * 1.05
            m.box(sx0, y - 0.08, -D + 0.5, sx1, y, -D + 0.85, WOOD_L)
            x = sx0 + 0.2
            while x < sx1 - 0.2:
                c = m.rng.choice(BOTTLES)
                h = m.rng.uniform(0.42, 0.62)
                m.cyl(x, y, -D + 0.68, 0.075, y + h * 0.65, 0.075, c, n=5, glow=0.12, caps=False)
                m.cyl(x, y + h * 0.65, -D + 0.68, 0.075, y + h, 0.03, c, n=5, glow=0.12)
                x += m.rng.uniform(0.2, 0.32)
    m.text("NO REFUNDS", -1.25, F + 4.3, -D + 0.54, 0.5, BRASS, depth=0.05)
    # taps + mugs on the counter
    for x in (-3.0, -2.2, -1.4):
        m.cyl(x, F + 1.4, bz0 + 0.5, 0.06, F + 1.9, 0.05, BRASS, n=6)
        m.box(x - 0.04, F + 1.84, bz0 + 0.45, x + 0.04, F + 2.05, bz0 + 0.68, hexc("#c4432f"))
    # wagon-wheel chandeliers (warm baked light)
    for cx in (-7.0, 1.5):
        cy = H - 1.3
        m.cyl(cx, cy, 2.0, 1.25, cy + 0.14, 1.25, WOOD_D, n=14, caps=False)
        m.cyl(cx, cy, 2.0, 1.05, cy + 0.14, 1.05, WOOD_D, n=14, caps=False)
        for a in range(4):
            ca, sa = math.cos(a * math.pi / 4), math.sin(a * math.pi / 4)
            m.beam((cx - ca * 1.15, cy + 0.07, 2.0 - sa * 1.15), (cx + ca * 1.15, cy + 0.07, 2.0 + sa * 1.15), 0.05, WOOD_D)
        m.beam((cx, cy + 0.07, 2.0), (cx, H, 2.0), 0.03, INK)
        for a in range(8):
            ca, sa = math.cos(a * math.pi / 4), math.sin(a * math.pi / 4)
            m.ball(cx + ca * 1.15, cy + 0.32, 2.0 + sa * 1.15, 0.11, hexc("#ffdf9e"), n=6, rings=3, glow=1.0)
        m.lamp(cx, cy, 2.0, radius=12.0, power=0.14)
    m.lamp(-1.0, F + 3.0, -6.0, radius=9.0, power=0.1, col=(1.0, 0.8, 0.5))
    # duck "trophy" mounted on the wall: nobody knows why
    m.push(-W + 0.2, 4.2, 0.5, yaw=90)
    m.cyl(0, -0.6, 0.03, 0.6, -0.55, 0.6, WOOD_D, n=8)
    m.ball(0, -0.3, 0.3, 0.42, hexc("#ffd23f"), n=8)
    m.box(-0.14, -0.4, 0.68, 0.14, -0.28, 1.0, hexc("#ff8a3d"))
    m.ball(-0.18, -0.15, 0.62, 0.05, INK, n=5, rings=3)
    m.ball(0.18, -0.15, 0.62, 0.05, INK, n=5, rings=3)
    m.pop()
    # upright piano
    px, pz = -10.9, -1.0
    m.box(px - 0.9, F, pz - 1.3, px + 0.25, F + 2.0, pz + 1.3, hexc("#3a2024"))
    m.box(px + 0.25, F + 0.95, pz - 1.25, px + 0.72, F + 1.1, pz + 1.25, hexc("#3a2024"))
    m.box(px + 0.3, F + 1.1, pz - 1.15, px + 0.68, F + 1.13, pz + 1.15, CREAM)
    for k in range(18):
        z = pz - 1.1 + k * 0.128
        m.box(px + 0.45, F + 1.13, z, px + 0.68, F + 1.16, z + 0.07, INK)
    m.col(px - 0.9, F, pz - 1.3, px + 0.72, F + 2.0, pz + 1.3)
    # VIP stage (east end): velvet, throne, and a rope with legal force
    vx0 = 7.5
    m.floor_boards(vx0, -D, W, D, F + 0.8, hexc("#7a2336"), along_x=False)
    m.box(vx0 - 0.02, F, -D, vx0, F + 0.8, D, BRASS, faces="x")
    m.col(vx0, F, -D, W, F + 0.8, D)
    m.col_ramp((vx0 - 2.6, F, 6.2), (vx0, F + 0.8, 6.2), 3.0)
    for i in range(6):
        xa, xb = vx0 - 2.6 * (1 - i / 6), vx0 - 2.6 * (1 - (i + 1) / 6)
        ya, yb = F + 0.8 * i / 6, F + 0.8 * (i + 1) / 6
        m.quad(m.P(xa, ya, 7.7), m.P(xb, yb, 7.7), m.P(xb, yb, 4.7), m.P(xa, ya, 4.7), hexc("#8f2a40"))
    # invisible wall along the stage edge + rails (gate itself is a live node in the game)
    m.col(vx0 - 0.1, F, -D, vx0 + 0.05, H, 4.6)
    for z in (-8.0, -5.0, -2.0, 1.0, 4.0):
        m.cyl(vx0 + 0.2, F + 0.8, z, 0.06, F + 1.9, 0.06, BRASS, n=6)
        m.ball(vx0 + 0.2, F + 1.95, z, 0.1, BRASS, n=6, rings=3)
    for z0, z1 in ((-8.0, -5.0), (-5.0, -2.0), (-2.0, 1.0), (1.0, 4.0)):
        m.beam((vx0 + 0.2, F + 1.75, z0), (vx0 + 0.2, F + 1.6, (z0 + z1) / 2), 0.035, hexc("#c4284f"))
        m.beam((vx0 + 0.2, F + 1.6, (z0 + z1) / 2), (vx0 + 0.2, F + 1.75, z1), 0.035, hexc("#c4284f"))
    tx, tz = 10.6, -4.4
    fl = F + 0.8
    m.box(tx - 1.4, fl, tz - 1.2, tx + 1.4, fl + 0.4, tz + 1.2, hexc("#c4284f"))
    m.box(tx - 0.9, fl + 0.4, tz - 0.7, tx + 0.9, fl + 1.05, tz + 0.7, hexc("#e6b23c"))
    m.box(tx - 0.8, fl + 1.05, tz - 0.6, tx + 0.8, fl + 1.2, tz + 0.6, hexc("#a31d3f"))
    m.box(tx - 0.95, fl + 1.05, tz - 1.0, tx + 0.95, fl + 3.8, tz - 0.65, hexc("#e6b23c"))
    m.box(tx - 0.75, fl + 1.2, tz - 0.66, tx + 0.75, fl + 3.55, tz - 0.6, hexc("#a31d3f"))
    for sx in (-1, 1):
        m.box(tx + sx * 0.8 - 0.14, fl + 1.05, tz - 0.65, tx + sx * 0.8 + 0.14, fl + 1.7, tz + 0.7, hexc("#e6b23c"))
        m.ball(tx + sx * 0.95, fl + 3.95, tz - 0.82, 0.2, hexc("#ffe27a"), n=6, rings=4, glow=0.5)
    m.cyl(tx, fl + 3.8, tz - 0.82, 0.5, fl + 4.5, 0.0, hexc("#ffe27a"), n=5, glow=0.3)
    m.col(tx - 1.4, fl, tz - 1.2, tx + 1.4, fl + 0.4, tz + 1.2)
    m.col(tx - 0.95, fl + 0.4, tz - 1.0, tx + 0.95, fl + 1.2, tz + 0.7)
    m.text("VIP", vx0 + 2.6, F + 3.6, -D + 0.3, 1.1, NEON_PINK, font="Monoton-Regular", glow=0.9, depth=0.03, res=1)
    m.lamp(tx, fl + 3.0, tz + 1.0, radius=7.0, power=0.12, col=(1.0, 0.45, 0.6))
    m.room(-W, 0, -D, W, H, D, level=0.1, col=(1.0, 0.95, 0.86))
    m.finish(out)


def sheriff(out):
    """Sheriff's office + Bot Jail. Stone lower storey, adobe upper, barred cells."""
    m = LM("sheriff", 21)
    W, D, F = 9.5, 8.0, 0.4
    sand = hexc("#cdb189")
    stone = hexc("#8d8791")
    teal = hexc("#2f8f8a")
    m.floor_boards(-W, -D, W, D, F, WOOD)
    m.col(-W, -0.3, -D, W, F, D)
    ops = [(W - 2.0, 4.0, 0.0, 4.3), (2.4, 2.6, 1.7, 3.7), (W + 6.5, 2.6, 1.7, 3.7)]
    m.wall((-W, D), (W, D), 0, 9.4, sand, ops, glass=GLASS, frame=teal, inner=WOOD_L, board=0.42, jit=0.045)
    m.wall((W, D), (W, -D), 0, 6.6, sand, [(6.5, 3.0, 1.9, 3.8)], glass=GLASS, frame=teal, inner=WOOD_L, board=0.42, jit=0.045)
    m.wall((W, -D), (-W, -D), 0, 6.6, sand, [(8.0, 3.0, 2.6, 3.7)], glass=(*hexc("#8fa4b8"), 0.05), frame=stone, inner=WOOD_L, board=0.42)
    m.wall((-W, -D), (-W, D), 0, 6.6, sand, [(6.5, 3.0, 1.9, 3.8)], glass=GLASS, frame=teal, inner=WOOD_L, board=0.42, jit=0.045)
    # rough stone plinth along the front and back
    for (x0, z0, x1, z1) in ((-W - 0.1, D - 0.1, W + 0.1, D + 0.24), (-W - 0.1, -D - 0.24, W + 0.1, -D + 0.1)):
        gaps = [(x0, -2.2), (2.2, x1)] if z0 > 0 else [(x0, x1)]
        for (a, b) in gaps:
            x = a
            while x < b:
                w = min(m.rng.uniform(0.7, 1.3), b - x)
                m.box(x, 0, z0 - m.rng.uniform(0, 0.05), x + w - 0.03, m.rng.uniform(0.75, 0.95), z1 + m.rng.uniform(0, 0.05), jitter(stone, m.rng, 0.14))
                x += w
    m.box(-W, 6.6, -D, W, 6.72, D, WOOD, sub=2.2)
    m.prism_roof(-W, W, 6.7, -D, D - 0.3, 2.2, hexc("#54606e"), over=0.4)
    m.gable_end(-W - 0.02, 6.7, -D, D - 0.3, 2.2, sand)
    m.gable_end(W + 0.02, 6.7, -D, D - 0.3, 2.2, sand, flip=True)
    # false front with a star
    m.box(-W - 0.1, 9.4, D - 0.2, W + 0.1, 9.65, D + 0.3, teal)
    m.wall((-5.0, D), (5.0, D), 9.65, 10.9, sand, collide=False, board=0.42, t=0.24)
    m.box(-5.15, 10.9, D - 0.2, 5.15, 11.1, D + 0.3, teal)
    m.text("SHERIFF", 0, 6.9, D + 0.2, 2.2, hexc("#7a2f24"), depth=0.16, back=hexc("#3d1712"))
    star = hexc("#ffcf5a")
    m.push(0, 10.25, D + 0.24)
    for i in range(5):
        a0 = math.radians(90 + i * 72)
        a1 = math.radians(90 + i * 72 + 36)
        a2 = math.radians(90 + i * 72 - 36)
        p = lambda a, r: m.P(math.cos(a) * r, math.sin(a) * r, 0.08)
        m.face([p(a0, 0.62), p(a1, 0.22), p(a2, 0.22)], star, 0.25)
    m.disc(0, 0, 0.08, 0.26, star, n=10, glow=0.25)
    m.pop()
    porch(m, -W, W, D, D + 2.8, F, posts=5, roof_y=4.7, roof_col=hexc("#54606e"), ramp_x=0.0, ramp_w=7.0)
    hitching_rail(m, -8.5, -4.5, D + 3.8)
    # WANTED board on the porch (the Hall of Fame label sits in front of it in-game)
    m.box(-8.6, 1.3, D + 0.16, -3.4, 4.2, D + 0.28, WOOD_D)
    for i in range(3):
        px = -7.9 + i * 1.75
        m.box(px - 0.65, 2.45, D + 0.28, px + 0.65, 3.95, D + 0.3, hexc("#ead7ae"))
        m.text("WANTED", px, 3.68, D + 0.3, 0.26, hexc("#4a2a1a"), depth=0.005, res=1)
        m.ball(px, 3.05, D + 0.31, 0.32, hexc("#b98a5a"), n=6, rings=3)
    # interior: jail along the back with iron bars, desk
    cell_z = -2.4
    for x in [-W + 0.2 + k * 0.42 for k in range(45)]:
        if 1.0 < x < 3.4:
            continue
        m.cyl(x, F, cell_z, 0.05, F + 4.2, 0.05, hexc("#5a6068"), n=5, caps=False)
    m.box(-W, F + 4.15, cell_z - 0.1, W, F + 4.35, cell_z + 0.1, hexc("#5a6068"))
    m.box(-W, F + 2.0, cell_z - 0.07, W, F + 2.12, cell_z + 0.07, hexc("#5a6068"))
    m.col(-W, F, cell_z - 0.1, 1.0, F + 4.3, cell_z + 0.1)
    m.col(3.4, F, cell_z - 0.1, W, F + 4.3, cell_z + 0.1)
    m.box(-2.5, F, -D + 0.2, -2.3, F + 4.2, cell_z, hexc("#5a6068"))
    m.text("BOT JAIL", 2.2, F + 4.5, cell_z + 0.11, 0.62, hexc("#ffcf5a"), depth=0.05)
    # kennels of shame
    for x in (-7.0, 5.6):
        m.box(x - 1.0, F, -D + 0.3, x + 1.0, F + 0.5, -D + 2.4, hexc("#6a4a7a"))
        m.box(x - 1.0, F + 0.5, -D + 0.3, x + 1.0, F + 0.7, -D + 2.4, CREAM)
    m.box(-6.6, F, 3.2, -3.0, F + 1.15, 5.3, WOOD_D)
    m.box(-6.8, F + 1.15, 3.0, -2.8, F + 1.28, 5.5, WOOD_L)
    m.col(-6.8, F, 3.0, -2.8, F + 1.28, 5.5)
    m.lamp(0, 5.5, 2.5, radius=11.0, power=0.15)
    m.lamp(0, 3.5, -5.0, radius=9.0, power=0.07, col=(0.7, 0.8, 1.0))
    m.room(-W, 0, -D, W, 6.6, D, level=0.1, col=(1.0, 0.95, 0.86))
    m.finish(out)


def store(out):
    """General Store = the Perk Shop. Teal paint, big awning, crates of nonsense."""
    m = LM("store", 31)
    W, D, F = 8.5, 7.0, 0.4
    teal = hexc("#3f9a95")
    m.floor_boards(-W, -D, W, D, F, WOOD)
    m.col(-W, -0.3, -D, W, F, D)
    ops = [(W - 1.9, 3.8, 0.0, 4.2), (1.2, 4.0, 1.2, 3.6), (W + 3.2, 4.0, 1.2, 3.6)]
    m.wall((-W, D), (W, D), 0, 8.4, teal, ops, glass=(*hexc("#ffe0a8"), 0.3), frame=CREAM, inner=WOOD_L)
    m.wall((W, D), (W, -D), 0, 5.6, teal, [(5.5, 3.0, 1.8, 3.6)], glass=GLASS, frame=CREAM, inner=WOOD_L)
    m.wall((W, -D), (-W, -D), 0, 5.6, teal, frame=CREAM, inner=WOOD_L)
    m.wall((-W, -D), (-W, D), 0, 5.6, teal, [(5.5, 3.0, 1.8, 3.6)], glass=GLASS, frame=CREAM, inner=WOOD_L)
    m.box(-W, 5.6, -D, W, 5.72, D, WOOD, sub=2.2)
    m.prism_roof(-W, W, 5.7, -D, D - 0.3, 2.0, hexc("#7a4a33"), over=0.4)
    m.gable_end(-W - 0.02, 5.7, -D, D - 0.3, 2.0, teal)
    m.gable_end(W + 0.02, 5.7, -D, D - 0.3, 2.0, teal, flip=True)
    # false front: arched top made of steps
    m.box(-W - 0.1, 8.4, D - 0.2, W + 0.1, 8.62, D + 0.3, CREAM)
    for i, (hw, top) in enumerate(((6.0, 9.1), (3.8, 9.6), (2.0, 10.0))):
        y0 = 8.62 if i == 0 else [9.1, 9.6][i - 1]
        m.wall((-hw, D), (hw, D), y0, top, teal, collide=False, t=0.24)
        m.box(-hw - 0.12, top, D - 0.2, hw + 0.12, top + 0.15, D + 0.3, CREAM)
    m.box(-7.2, 5.95, D + 0.2, 7.2, 7.95, D + 0.3, CREAM)
    m.text("GENERAL STORE", 0, 6.3, D + 0.3, 1.25, hexc("#b5402f"), depth=0.14, back=hexc("#5a2018"))
    m.text("perks & regrets", 0, 8.75, D + 0.3, 0.55, CREAM, font="Bungee-Regular", depth=0.05, res=1)
    # striped awning (the signature of the shop)
    porch(m, -W, W, D, D + 3.0, F, posts=5, roof_y=0, ramp_x=0.0, ramp_w=7.0)
    m.posts(-W + 0.2, W - 0.2, 5, F, 4.4, D + 2.8, WOOD_L)
    n = 17
    for i in range(n):
        x0 = -W - 0.2 + (2 * W + 0.4) * i / n
        x1 = -W - 0.2 + (2 * W + 0.4) * (i + 1) / n
        c = hexc("#e5484d") if i % 2 == 0 else hexc("#fbe9c8")
        m.quad(m.P(x0, 4.3, D + 3.3), m.P(x1, 4.3, D + 3.3), m.P(x1, 5.2, D), m.P(x0, 5.2, D), c)
        m.quad(m.P(x1, 4.16, D + 3.3), m.P(x0, 4.16, D + 3.3), m.P(x0, 5.06, D), m.P(x1, 5.06, D), scale_col(c, 0.75))
        m.quad(m.P(x0, 3.95, D + 3.32), m.P(x1, 3.95, D + 3.32), m.P(x1, 4.3, D + 3.32), m.P(x0, 4.3, D + 3.32), c)
    # interior: counter + shelves of merchandise
    m.box(-5, F, -3.2, 5, F + 1.2, -2.2, WOOD_D)
    m.box(-5.2, F + 1.2, -3.3, 5.2, F + 1.32, -2.1, WOOD_L)
    m.col(-5.2, F, -3.3, 5.2, F + 1.32, -2.1)
    for side in (-1, 1):
        x0 = min(side * 2.0, side * W * 0.95)
        x1 = max(side * 2.0, side * W * 0.95)
        m.box(x0, F, -D + 0.2, x1, F + 4.2, -D + 0.6, WOOD)
        for lvl in range(4):
            y = F + 0.6 + lvl * 0.95
            m.box(x0, y - 0.07, -D + 0.5, x1, y, -D + 1.1, WOOD_L)
            x = x0 + 0.3
            while x < x1 - 0.3:
                c = m.rng.choice(BOTTLES + [hexc("#e6b23c"), CREAM])
                if m.rng.random() < 0.5:
                    m.box(x - 0.16, y, -D + 0.62, x + 0.16, y + m.rng.uniform(0.3, 0.55), -D + 0.98, c)
                else:
                    m.cyl(x, y, -D + 0.8, 0.14, y + 0.42, 0.14, c, n=7)
                x += m.rng.uniform(0.45, 0.62)
    m.lamp(0, 4.6, 0, radius=11.0, power=0.15)
    m.room(-W, 0, -D, W, 5.6, D, level=0.11, col=(1.0, 0.95, 0.86))
    m.finish(out)


def hotel(out):
    """Grand Slop Hotel = the wardrobe. Tallest building in town, balconies, pink trim."""
    m = LM("hotel", 41)
    W, D, F = 12.0, 7.5, 0.4
    pink = hexc("#e29a8e")
    trim = hexc("#fbeed2")
    roofc = hexc("#4a6a7a")
    G = (*hexc("#ffd79a"), 0.34)
    m.floor_boards(-W, -D, W, D, F, hexc("#8c5a3c"))
    m.col(-W, -0.3, -D, W, F, D)
    ops = [(W - 2.2, 4.4, 0.0, 4.5), (2.2, 3.0, 1.7, 3.9), (W + 5.2, 3.0, 1.7, 3.9)]
    for k in range(3):
        x = 3.2 + k * 7.4
        ops.append((x, 2.2, 6.0, 8.2))
        ops.append((x, 2.2, 10.0, 12.2))
    m.wall((-W, D), (W, D), 0, 13.8, pink, ops, glass=G, frame=trim, inner=hexc("#e8cfa8"))
    side = [(a, 2.2, s, s + 2.2) for a in (2.5, 10.5) for s in (1.9, 6.0, 10.0)]
    m.wall((W, D), (W, -D), 0, 13.8, pink, side, glass=G, frame=trim, inner=hexc("#e8cfa8"))
    m.wall((W, -D), (-W, -D), 0, 13.8, pink, [(a, 2.2, s, s + 2.2) for a in (4.0, 11.0, 18.0) for s in (6.0, 10.0)], glass=G, frame=trim, inner=hexc("#e8cfa8"))
    m.wall((-W, -D), (-W, D), 0, 13.8, pink, side, glass=G, frame=trim, inner=hexc("#e8cfa8"))
    # upstairs is real: a floor, and a long ramp up the east wall to reach it
    SX = 8.6
    m.floor_boards(-W, -D, SX, D, 6.15, hexc("#8c5a3c"), depth=0.15)
    m.col(-W, 5.9, -D, SX, 6.15, D)
    m.floor_boards(SX, -D, W, -D + 2.0, 6.15, hexc("#8c5a3c"), depth=0.15)
    m.col(SX, 5.9, -D, W, 6.15, -D + 2.0)
    m.col_ramp((10.3, F, D - 0.6), (10.3, 6.15, -D + 2.0), 3.2)
    steps = 26
    for i in range(steps):
        t0, t1 = i / steps, (i + 1) / steps
        z0, z1 = (D - 0.6) + (-2 * D + 2.6) * t0, (D - 0.6) + (-2 * D + 2.6) * t1
        y0, y1 = F + (6.15 - F) * t0, F + (6.15 - F) * t1
        c = jitter(hexc("#7a2336"), m.rng, 0.08)
        m.quad(m.P(8.7, y0, z0), m.P(11.9, y0, z0), m.P(11.9, y1, z1), m.P(8.7, y1, z1), c)
        m.quad(m.P(11.9, y0 - 0.2, z0), m.P(8.7, y0 - 0.2, z0), m.P(8.7, y1 - 0.2, z1), m.P(11.9, y1 - 0.2, z1), WOOD_D)
    for k in range(13):
        z = D - 1.0 - k * 1.0
        y = F + (6.15 - F) * ((D - 0.6 - z) / (2 * D - 2.6))
        m.box(8.62, y, z - 0.04, 8.7, y + 1.1, z + 0.04, BRASS)
    m.col(8.5, F, -D + 2.2, 8.7, 7.4, 3.6)  # stops short so the foot of the ramp is open
    # ground-floor ceiling sits under the boards: above them it blocks the AO bake and blacks out the floor
    m.box(-W, 5.94, -D, SX, 5.96, D, hexc("#c9a06e"), faces="y", sub=2.6)
    m.box(SX, 5.94, -D, W, 5.96, -D + 2.0, hexc("#c9a06e"), faces="y", sub=2.6)
    # corridor wall + three rooms along the back
    wallc = hexc("#d9b98a")
    for x0, x1 in ((-W, -8.6), (-6.2, -1.6), (0.8, 5.4)):
        m.box(x0, 6.15, -0.2, x1, 11.5, 0.0, wallc)
        m.col(x0, 6.15, -0.2, x1, 11.5, 0.0)
    for x in (-5.0, 2.2):
        m.box(x - 0.1, 6.15, -D, x + 0.1, 11.5, -0.2, wallc)
        m.col(x - 0.1, 6.15, -D, x + 0.1, 11.5, -0.2)
    for x0, x1, c in ((-11.6, -5.3, "#8a3a5a"), (-4.8, 1.9, "#3a6a8a"), (2.5, 8.2, "#6a8a3a")):
        xm = (x0 + x1) * 0.5
        m.box(xm - 1.4, 6.15, -7.2, xm + 1.4, 6.65, -4.2, WOOD_D)      # bed frame
        m.box(xm - 1.3, 6.65, -7.1, xm + 1.3, 6.95, -4.3, hexc(c))    # blanket
        m.box(xm - 1.1, 6.95, -7.05, xm + 1.1, 7.15, -6.3, CREAM)      # pillow
        m.col(xm - 1.4, 6.15, -7.2, xm + 1.4, 6.95, -4.2)
    m.text("NO. 1", -8.0, 9.2, 0.02, 0.4, BRASS, depth=0.02, res=1)
    m.text("MINIBAR: 900c", -1.0, 9.2, 0.02, 0.32, BRASS, font="Bungee-Regular", depth=0.02, res=1)
    m.text("DO NOT DISTURB", 3.1, 9.2, 0.02, 0.26, BRASS, font="Bungee-Regular", depth=0.02, res=1)
    m.lamp(-3, 10.0, 3.5, radius=14.0, power=0.15)
    m.lamp(-3, 10.0, -4.0, radius=12.0, power=0.12)
    m.box(-W, 13.8, -D, W, 13.95, D, hexc("#c9a06e"), sub=3.0)
    # mansard roof
    h = 2.6
    inset = 1.8
    corners = [(-W - 0.3, D + 0.3), (W + 0.3, D + 0.3), (W + 0.3, -D - 0.3), (-W - 0.3, -D - 0.3)]
    inner = [(-W + inset, D - inset), (W - inset, D - inset), (W - inset, -D + inset), (-W + inset, -D + inset)]
    for i in range(4):
        a, b = corners[i], corners[(i + 1) % 4]
        c, d = inner[(i + 1) % 4], inner[i]
        rows = 7
        for r in range(rows):
            t0, t1 = r / rows, (r + 1) / rows
            col = jitter(roofc, m.rng, 0.1)
            A = m.P(a[0] + (d[0] - a[0]) * t0, 13.95 + h * t0, a[1] + (d[1] - a[1]) * t0)
            B = m.P(b[0] + (c[0] - b[0]) * t0, 13.95 + h * t0, b[1] + (c[1] - b[1]) * t0)
            C = m.P(b[0] + (c[0] - b[0]) * t1, 13.95 + h * t1, b[1] + (c[1] - b[1]) * t1)
            D2 = m.P(a[0] + (d[0] - a[0]) * t1, 13.95 + h * t1, a[1] + (d[1] - a[1]) * t1)
            m.face([A, B, C, D2], col)
    m.box(inner[0][0], 13.95 + h - 0.02, inner[2][1], inner[1][0], 13.95 + h, inner[0][1], roofc)
    m.box(-W - 0.45, 13.75, -D - 0.45, W + 0.45, 14.0, D + 0.45, trim)
    # dormers
    for x in (-7.5, 0.0, 7.5):
        m.box(x - 1.0, 14.3, D - 1.0, x + 1.0, 16.0, D + 0.2, pink)
        m.box(x - 0.6, 14.6, D + 0.2, x + 0.6, 15.6, D + 0.23, G[:3], glow=G[3])
        m.push(x, 16.0, D - 0.4)
        m.prism_roof(-1.25, 1.25, 0.0, -0.85, 0.85, 0.7, roofc, over=0.05, row=0.25)
        m.pop()
    # balconies on the upper floors
    for y in (6.0, 10.0):
        m.floor_boards(-W, D, W, D + 1.5, y, hexc("#8c5a3c"), depth=0.14)
        for x in [-W + 0.15 + k * 0.5 for k in range(49)]:
            m.box(x - 0.035, y, D + 1.42, x + 0.035, y + 1.1, D + 1.5, trim)
        m.box(-W, y + 1.08, D + 1.4, W, y + 1.2, D + 1.56, trim)
    for x in (-W + 0.15, -6.0, 6.0, W - 0.15):
        m.box(x - 0.12, F, D + 1.3, x + 0.12, 12.4, D + 1.54, trim)
    m.box(-W - 0.2, 12.4, D, W + 0.2, 12.6, D + 1.7, roofc)
    m.text("GRAND SLOP HOTEL", 0, 4.9, D + 1.6, 1.15, hexc("#ffd257"), font="Limelight-Regular", glow=0.55, depth=0.08)
    m.box(-9.6, 4.75, D + 1.5, 9.6, 6.0, D + 1.56, hexc("#2d4a5a"))
    porch(m, -W, W, D, D + 4.0, F, roof_y=0, ramp_x=0.0, ramp_w=9.0)
    # lobby: dressing mirrors (wardrobe stations are wired in Godot)
    m.box(-W + 0.2, F, -D + 0.2, -3.0, F + 5.4, -D + 1.2, hexc("#7a2336"))
    for k in range(5):
        x = -W + 0.8 + k * 1.8
        m.box(x, F + 0.6, -D + 1.2, x + 1.3, F + 4.6, -D + 1.24, hexc("#8fd0e0"), glow=0.08)
        m.box(x - 0.08, F + 0.5, -D + 1.2, x + 1.38, F + 4.7, -D + 1.22, hexc("#e6b23c"))
    # reception desk
    m.box(1.6, F, -3.6, 7.8, F + 1.25, -2.4, hexc("#6e4326"))
    m.box(1.4, F + 1.25, -3.75, 8.0, F + 1.36, -2.25, hexc("#e6b23c"))
    m.col(1.4, F, -3.75, 8.0, F + 1.36, -2.25)
    # checkerboard rug
    for i in range(10):
        for j in range(6):
            c = hexc("#7a2336") if (i + j) % 2 == 0 else hexc("#e6b23c")
            m.box(-5 + i, F, -1 + j, -4 + i, F + 0.03, j, c, faces="Y")
    m.lamp(-3, 4.8, 1.5, radius=12.0, power=0.16)
    m.lamp(6, 4.8, -2, radius=8.0, power=0.1)
    m.room(-W, 0, -D, W, 13.8, D, level=0.11, col=(1.0, 0.95, 0.88))
    m.finish(out)


def bank(out):
    """First National Slop Bank: the Vault. Front (+z) has columns, a gap for the
    round door the game moves, and a strongroom of gold behind it."""
    m = LM("bank", 81)
    stone = hexc("#d8cfba")
    W, H = 5.0, 7.4
    m.floor_boards(-W, -4.6, W, 3.8, 0.02, hexc("#7f7a86"), along_x=False, depth=0.1)
    m.wall((-W, 3.8), (W, 3.8), 0, H, stone, [(W - 1.6, 3.2, 0.0, 4.1)], board=0.62, jit=0.05, t=0.6, frame=BRASS, inner=hexc("#5a5560"))
    m.wall((W, 3.8), (W, -4.6), 0, H, stone, board=0.62, jit=0.05, t=0.6, inner=hexc("#5a5560"))
    m.wall((W, -4.6), (-W, -4.6), 0, H, stone, board=0.62, jit=0.05, t=0.6, inner=hexc("#5a5560"))
    m.wall((-W, -4.6), (-W, 3.8), 0, H, stone, board=0.62, jit=0.05, t=0.6, inner=hexc("#5a5560"))
    m.box(-W - 0.2, H, -4.8, W + 0.2, H + 0.7, 4.0, hexc("#b8ad9a"), sub=2.5)
    m.col(-W, H, -4.6, W, H + 0.3, 3.8)
    # portico: steps, six columns, pediment, big lettering
    for i, z in enumerate((6.6, 6.0, 5.4)):
        m.box(-W - 1.2 + i * 0.1, 0, 3.9, W + 1.2 - i * 0.1, 0.16 * (i + 1) - 0.06, z, jitter(stone, m.rng, 0.04), sub=2.5)
    m.col_ramp((0, 0.0, 7.0), (0, 0.42, 5.2), 2 * W + 2.4)
    m.col(-W - 1.2, 0, 3.9, W + 1.2, 0.42, 5.3)
    for x in (-5.4, -3.3, -1.9, 1.9, 3.3, 5.4):
        m.cyl(x, 0.42, 5.0, 0.42, H, 0.36, stone, n=10, caps=False)
        m.cyl(x, H - 0.3, 5.0, 0.4, H, 0.56, CREAM, n=10, caps=False)
        m.col(x - 0.38, 0.42, 4.62, x + 0.38, H, 5.38)
    m.box(-W - 1.2, H, 3.8, W + 1.2, H + 0.7, 5.8, stone, sub=2.5)
    a, b, c = m.P(-W - 1.4, H + 0.7, 5.82), m.P(W + 1.4, H + 0.7, 5.82), m.P(0, H + 2.5, 5.82)
    m.face([a, b, c], hexc("#e6dcc4"))
    # back gable, then a roof whose ridge runs front to back so the pediment stays visible
    m.face([m.P(W + 1.4, H + 0.7, -4.8), m.P(-W - 1.4, H + 0.7, -4.8), m.P(0, H + 2.5, -4.8)], stone)
    # lead roof in strips, ridge front to back so the pediment stays visible
    X, y0, y1 = W + 1.6, H + 0.62, H + 2.56
    strips = 10
    for i in range(strips):
        zb, zf = -5.0 + 11.1 * i / strips, -5.0 + 11.1 * (i + 1) / strips
        c = jitter(hexc("#7f8a96"), m.rng, 0.08)
        m.quad(m.P(X, y0, zf), m.P(X, y0, zb), m.P(0, y1, zb), m.P(0, y1, zf), c)
        m.quad(m.P(-X, y0, zb), m.P(-X, y0, zf), m.P(0, y1, zf), m.P(0, y1, zb), c)
    m.text("FIRST NATIONAL", 0, H + 0.14, 5.82, 0.42, hexc("#7a4a33"), depth=0.05)
    m.text("SLOP BANK", 0, H + 0.88, 5.83, 0.56, hexc("#7a4a33"), depth=0.05)
    # strongroom: gold bars, coin heaps, money bags, a chandelier for no reason
    gold = hexc("#ffc935")
    for i in range(46):
        x, z = m.rng.uniform(-4.2, 4.2), m.rng.uniform(-4.0, -1.0)
        y = m.rng.uniform(0.02, 0.5) * (1.0 - abs(x) / 5.0) * 3.0
        m.push(x, y, z, yaw=m.rng.uniform(0, 180))
        m.box(-0.34, 0, -0.14, 0.34, 0.14, 0.14, jitter(gold, m.rng, 0.1), glow=0.08)
        m.pop()
    for x in (-3.4, 3.4):
        m.ball(x, 0.6, 1.8, 0.62, hexc("#a88a5a"), n=8, rings=5, sy=0.95)
        m.cyl(x, 1.1, 1.8, 0.14, 1.4, 0.24, hexc("#a88a5a"), n=7)
        m.text("$", x, 0.36, 2.42, 0.6, CREAM, depth=0.02, res=1)
    m.room(-W, 0, -4.6, W, H, 3.8, level=0.12, col=(1.0, 0.9, 0.6))
    m.room(-W - 1.4, 0, 3.8, W + 1.4, H + 0.7, 7.0, level=0.14, col=(1.0, 0.96, 0.9))  # the portico faces away from the sun
    m.lamp(0, 1.5, -2.4, radius=8.0, power=0.18, col=(1.0, 0.8, 0.4))
    m.finish(out)


def cave(out):
    """Spooky Cave: an arched mouth, a dark tunnel, then a glowing treasure chamber."""
    m = LM("cave", 82)
    rock, dark = hexc("#7b7390"), hexc("#4d4763")
    cry = hexc("#7af0ff")
    def wall_rocks(x0, z0, x1, z1, top=4.2, rows=(0.5, 1.9, 3.3)):
        m.col(min(x0, x1), 0, min(z0, z1), max(x0, x1), top, max(z0, z1))
        n = int(max(abs(x1 - x0), abs(z1 - z0)) / 1.3) + 2
        for i in range(n):
            t = i / max(1, n - 1)
            x, z = x0 + (x1 - x0) * t, z0 + (z1 - z0) * t
            for y in rows:
                m.ball(x + m.rng.uniform(-0.3, 0.3), y, z + m.rng.uniform(-0.3, 0.3), m.rng.uniform(0.95, 1.4),
                       jitter(rock if y < 3 else dark, m.rng, 0.16), n=6, rings=4, sy=0.8)
    m.box(-10, -0.05, -8, 12, 0.02, 8, hexc("#8a8096"), sub=2.0)
    m.col(-9.6, -0.1, -8, 12, 0.02, 8)
    m.col_ramp((-11.6, -0.2, 0), (-9.6, 0.02, 0), 7.0)
    # tunnel walls
    wall_rocks(-9, 2.3, 2, 2.3)
    wall_rocks(-9, -2.3, 2, -2.3)
    # chamber walls
    tall = dict(top=6.6, rows=(0.5, 1.9, 3.3, 4.7, 6.1))
    wall_rocks(2, 2.3, 2, 7, **tall)
    wall_rocks(2, -2.3, 2, -7, **tall)
    wall_rocks(2, 7, 11, 7, **tall)
    wall_rocks(2, -7, 11, -7, **tall)
    wall_rocks(11, -7, 11, 7, **tall)
    for z in (-1.9, -0.6, 0.6, 1.9):  # the wall over the tunnel's inner end
        for y in (4.9, 6.1):
            m.ball(2, y, z, 1.25, jitter(rock, m.rng, 0.16), n=6, rings=4, sy=0.8)
    # roof: tunnel is low, the chamber opens up. A solid lid behind the lumpy rocks.
    m.box(-10, 4.7, -3.8, 2.6, 5.1, 3.8, dark, sub=2.5)
    m.box(1.0, 7.1, -8.6, 12.6, 7.6, 8.6, dark, sub=2.5)
    m.col(-9, 3.6, -3, 2, 4.6, 3)
    m.col(2, 6.2, -7.5, 11.5, 7.2, 7.5)
    for i in range(30):
        x, z = m.rng.uniform(-8, 11), m.rng.uniform(-7, 7)
        low = x < 2.0
        if low and abs(z) > 3:
            continue
        y = 4.5 if low else 7.0
        m.ball(x, y, z, m.rng.uniform(1.6, 2.4), jitter(dark, m.rng, 0.14), n=6, rings=4, sy=0.7)
    for i in range(14):  # stalactites
        x, z = m.rng.uniform(3, 10), m.rng.uniform(-6, 6)
        m.cyl(x, 6.2, z, 0.34, 6.2 - m.rng.uniform(0.9, 2.2), 0.02, dark, n=6)
    # crystals: the only light down here
    for i in range(16):
        x, z = m.rng.uniform(3.2, 10), m.rng.uniform(-6, 6)
        if abs(z) < 2.0 and x > 7.0:
            continue
        h = m.rng.uniform(0.9, 2.6)
        c = cry if i % 3 else hexc("#ff7ad9")
        m.push(x, 0, z, yaw=m.rng.uniform(0, 90), roll=m.rng.uniform(-14, 14))
        m.cyl(0, 0, 0, 0.3, h * 0.75, 0.3, c, n=6, glow=0.5)
        m.cyl(0, h * 0.75, 0, 0.3, h, 0.0, c, n=6, glow=0.6)
        m.pop()
    for i in range(14):  # mushrooms line the way in
        x, z = -8 + i * 0.75, 1.4 * (1 if i % 2 else -1) + m.rng.uniform(-0.25, 0.25)
        m.cyl(x, 0, z, 0.05, 0.28, 0.05, CREAM, n=5)
        m.ball(x, 0.34, z, 0.2, cry, n=7, rings=3, sy=0.5, glow=0.7)
    # the last person who tried this
    b = hexc("#e8e0cc")
    m.ball(5.0, 0.55, 4.8, 0.3, b, n=7, rings=4)
    m.ball(4.9, 0.55, 5.1, 0.06, INK, n=4, rings=3)
    m.ball(5.15, 0.55, 5.05, 0.06, INK, n=4, rings=3)
    m.beam((5.0, 0.15, 4.2), (5.0, 0.3, 4.75), 0.05, b)
    for k in range(4):
        m.beam((4.7, 0.2 + k * 0.08, 4.3 + k * 0.1), (5.3, 0.2 + k * 0.08, 4.3 + k * 0.1), 0.02, b)
    m.beam((5.0, 0.15, 4.2), (4.3, 0.04, 3.4), 0.04, b)
    m.beam((5.0, 0.15, 4.2), (5.6, 0.04, 3.3), 0.04, b)
    m.text("TURN BACK", 3.0, 2.3, 6.2, 0.5, hexc("#ff7ad9"), font="Bungee-Regular", glow=0.8, depth=0.02, res=1, yaw=180)
    # treasure dais
    m.cyl(9.0, 0, 0, 1.9, 0.3, 1.6, hexc("#8d8791"), n=12)
    m.col(7.6, 0, -1.4, 10.4, 0.3, 1.4)
    for i in range(26):
        a = m.rng.uniform(0, math.tau)
        r = m.rng.uniform(0.4, 1.8)
        m.cyl(9.0 + math.cos(a) * r, 0.3, math.sin(a) * r, 0.11, 0.34, 0.11, hexc("#ffc935"), n=7, glow=0.25)
    # mouth
    for z in (-3.1, 3.1):
        m.ball(-9.6, 1.6, z, 1.9, rock, n=7, rings=5)
        m.ball(-9.6, 3.6, z * 0.6, 1.5, dark, n=6, rings=4)
    m.ball(-9.6, 4.8, 0, 1.8, rock, n=7, rings=5, sy=0.7)
    m.lamp(7, 2.5, 0, radius=11.0, power=0.2, col=(0.5, 0.9, 1.0))
    m.room(-13, -1, -10, 14, 10, 10, level=0.11, col=(0.8, 0.8, 1.0))  # rock on rock bakes black otherwise
    m.finish(out)


def water_tower(out):
    m = LM("water_tower", 51)
    h = 11.0
    legs = [(-2.4, -2.4), (2.4, -2.4), (2.4, 2.4), (-2.4, 2.4)]
    for i, (x, z) in enumerate(legs):
        m.beam((x * 1.5, 0, z * 1.5), (x, h, z), 0.2, WOOD_D)
        m.col(x * 1.5 - 0.3, 0, z * 1.5 - 0.3, x * 1.5 + 0.3, 3.0, z * 1.5 + 0.3)
        nx, nz = legs[(i + 1) % 4]
        for (y0, y1) in ((2.0, 6.0), (6.0, 10.0)):
            s0, s1 = 1.5 - 0.5 * y0 / h, 1.5 - 0.5 * y1 / h
            m.beam((x * s0, y0, z * s0), (nx * s1, y1, nz * s1), 0.07, WOOD)
            m.beam((nx * s0, y0, nz * s0), (x * s1, y1, z * s1), 0.07, WOOD)
    m.floor_boards(-3.6, -3.6, 3.6, 3.6, h, WOOD, depth=0.25)
    n = 24
    for i in range(n):
        a0, a1 = 2 * math.pi * i / n, 2 * math.pi * (i + 1) / n
        c = jitter(hexc("#a8693c"), m.rng, 0.14)
        r = 3.0
        m.face([m.P(math.cos(a0) * r, h + 5.0, math.sin(a0) * r), m.P(math.cos(a1) * r, h + 5.0, math.sin(a1) * r),
                m.P(math.cos(a1) * r, h, math.sin(a1) * r), m.P(math.cos(a0) * r, h, math.sin(a0) * r)], c)
    for y in (h + 0.7, h + 2.5, h + 4.3):
        m.cyl(0, y, 0, 3.05, y + 0.14, 3.05, hexc("#4a4a55"), n=24, caps=False)
    m.cyl(0, h + 5.0, 0, 3.3, h + 7.0, 0.1, hexc("#7b3a2f"), n=16)
    m.text("SLOPSVILLE", 0, h + 1.5, 3.1, 0.92, CREAM, depth=0.04)
    m.text("pop: whatever", 0, h + 0.85, 3.1, 0.42, CREAM, font="Bungee-Regular", depth=0.03, res=1)
    m.cyl(1.0, 0, -1.2, 0.18, h, 0.18, hexc("#5a6068"), n=7, caps=False)
    m.finish(out)


def outhouse(out):
    m = LM("outhouse", 61)
    m.box(-1.3, 0, -1.3, 1.3, 0.3, 1.3, WOOD_D)
    m.wall((-1.1, 1.1), (1.1, 1.1), 0.3, 3.3, WOOD_L, [(0.45, 1.3, 0.0, 2.6)], board=0.3, t=0.12, collide=False)
    m.wall((1.1, 1.1), (1.1, -1.1), 0.3, 3.3, WOOD_L, board=0.3, t=0.12, collide=False)
    m.wall((1.1, -1.1), (-1.1, -1.1), 0.3, 3.3, WOOD_L, board=0.3, t=0.12, collide=False)
    m.wall((-1.1, -1.1), (-1.1, 1.1), 0.3, 3.3, WOOD_L, board=0.3, t=0.12, collide=False)
    m.prism_roof(-1.3, 1.3, 3.3, -1.1, 1.1, 0.8, ROOF, over=0.2, row=0.3)
    m.gable_end(-1.1, 3.3, -1.1, 1.1, 0.8, WOOD_L)
    m.gable_end(1.1, 3.3, -1.1, 1.1, 0.8, WOOD_L, flip=True)
    # crescent moon above the door
    m.disc(0, 2.95, 1.18, 0.2, hexc("#ffe27a"), n=10, glow=0.5)
    m.disc(0.07, 2.97, 1.19, 0.17, WOOD_L, n=10)
    # the throne of the people
    m.box(-0.5, 0.3, -0.9, 0.5, 0.95, -0.1, CREAM)
    m.cyl(0, 0.95, -0.45, 0.46, 1.05, 0.46, hexc("#ffffff"), n=10)
    m.box(-0.55, 0.95, -1.02, 0.55, 1.9, -0.7, CREAM)
    m.col(-1.3, 0, -1.3, 1.3, 0.3, 1.3)
    m.col(-1.1, 0.3, -1.1, 1.1, 3.3, -0.95)
    m.col(-1.1, 0.3, -1.1, -0.95, 3.3, 1.1)
    m.col(0.95, 0.3, -1.1, 1.1, 3.3, 1.1)
    m.lamp(0, 2.2, 0, radius=3.0, power=0.1)
    m.finish(out)


def town_arch(out):
    """Welcome arch over the south road. Sets the tone on the way back from the meadow."""
    m = LM("town_arch", 71)
    for side in (-1, 1):
        x = side * 7.0
        m.box(x - 0.45, 0, -0.45, x + 0.45, 7.5, 0.45, WOOD_D)
        m.box(x - 0.7, 0, -0.7, x + 0.7, 1.1, 0.7, hexc("#8d8791"))
        m.col(x - 0.7, 0, -0.7, x + 0.7, 7.5, 0.7)
        m.beam((x, 0, -2.2), (x, 3.0, -0.4), 0.14, WOOD)
        m.beam((x, 0, 2.2), (x, 3.0, 0.4), 0.14, WOOD)
    m.box(-8.2, 6.3, -0.3, 8.2, 8.3, 0.3, hexc("#b5402f"))
    m.box(-8.4, 8.3, -0.4, 8.4, 8.6, 0.4, BRASS)
    m.box(-8.4, 6.0, -0.4, 8.4, 6.3, 0.4, BRASS)
    for sz, yaw in ((1, 0), (-1, 180)):
        m.push(0, 0, sz * 0.32, yaw=yaw)
        m.text("SLOPSVILLE", 0, 6.65, 0.0, 1.6, CREAM, depth=0.1)
        m.bulbs((-8.0, 8.05, 0.04), (8.0, 8.05, 0.04), 24, 0.09, NEON_GOLD)
        m.pop()
    # cattle skull: a rubber duck with horns
    m.ball(0, 9.3, 0, 0.8, hexc("#ffd23f"), n=8)
    m.box(-0.25, 9.05, 0.7, 0.25, 9.3, 1.2, hexc("#ff8a3d"))
    for side in (-1, 1):
        m.beam((side * 0.6, 9.5, 0), (side * 1.5, 10.2, 0), 0.08, CREAM)
    m.finish(out)


ALL = ["saloon", "sheriff", "store", "hotel", "bank", "cave", "water_tower", "outhouse", "town_arch"]
