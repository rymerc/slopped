"""Landmark construction kit (Blender, headless).

Coordinates are Godot's: x right, y up, +z out of the building's front door. One
LM collects flat-coloured faces into a single static mesh, plus box colliders
(COL_*) and separately animated parts (DYN_*). Finish() bakes ambient occlusion
and lamp light into the vertex colours, then writes one GLB.

Vertex colour convention (see src/art/toon.gdshader): rgb = linear albedo,
alpha = emission mask (0 matte, 1 full neon; small values read as baked light).
"""
import math
import os
import random

import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
FONT_DIR = os.path.join(os.path.dirname(HERE), "fonts")


def hexc(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def jitter(c, rng, amt=0.1):
    k = 1.0 + rng.uniform(-amt, amt)
    return (c[0] * k, c[1] * k, c[2] * k)


def mix(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def scale_col(c, k):
    return tuple(x * k for x in c)


def _to_blender(v):
    return (v[0], -v[2], v[1])


class LM:
    def __init__(self, name, seed=1):
        self.name = name
        self.rng = random.Random(seed)
        self.verts = []
        self.faces = []
        self.fcols = []
        self.cols = []    # (xform, size) box colliders
        self.lamps = []   # (pos, radius, intensity, colour)
        self.rooms = []   # (min, max, level, colour): flat fill light inside a box
        self.dyn = {}     # name -> sub-LM
        self.xf = [Matrix.Identity(4)]
        self.origin = (0.0, 0.0, 0.0)  # DYN parts: pivot, in the parent's space

    # --- transform stack --------------------------------------------------------
    def push(self, x=0, y=0, z=0, yaw=0.0, pitch=0.0, roll=0.0, s=1.0):
        m = Matrix.Translation((x, y, z)) @ Matrix.Rotation(math.radians(yaw), 4, "Y") \
            @ Matrix.Rotation(math.radians(pitch), 4, "X") @ Matrix.Rotation(math.radians(roll), 4, "Z") @ Matrix.Scale(s, 4)
        self.xf.append(self.xf[-1] @ m)

    def pop(self):
        self.xf.pop()

    def P(self, x, y, z):
        return self.xf[-1] @ Vector((x, y, z))

    # --- primitive faces ---------------------------------------------------------
    def face(self, pts, col, glow=0.0):
        """pts: Vectors in current-world space, CCW seen from outside (Godot axes)."""
        i = len(self.verts)
        self.verts.extend(pts)
        self.faces.append(tuple(range(i, i + len(pts))))
        self.fcols.append((col[0], col[1], col[2], glow))

    def quad(self, a, b, c, d, col, glow=0.0, sub=0.0):
        """a b c d world points; `sub` tessellates so AO has vertices to land on."""
        if sub <= 0.0:
            self.face([a, b, c, d], col, glow)
            return
        nu = max(1, int(math.ceil((b - a).length / sub)))
        nv = max(1, int(math.ceil((d - a).length / sub)))
        for j in range(nv):
            for i in range(nu):
                u0, u1, v0, v1 = i / nu, (i + 1) / nu, j / nv, (j + 1) / nv
                p = lambda u, v: a.lerp(b, u).lerp(d.lerp(c, u), v)
                self.face([p(u0, v0), p(u1, v0), p(u1, v1), p(u0, v1)], col, glow)

    def box(self, x0, y0, z0, x1, y1, z1, col, glow=0.0, sub=0.0, top=None, faces="xXyYzZ"):
        P = self.P
        a = [P(x0, y0, z0), P(x1, y0, z0), P(x1, y1, z0), P(x0, y1, z0),
             P(x0, y0, z1), P(x1, y0, z1), P(x1, y1, z1), P(x0, y1, z1)]
        if "z" in faces: self.quad(a[1], a[0], a[3], a[2], col, glow, sub)
        if "Z" in faces: self.quad(a[4], a[5], a[6], a[7], col, glow, sub)
        if "x" in faces: self.quad(a[0], a[4], a[7], a[3], col, glow, sub)
        if "X" in faces: self.quad(a[5], a[1], a[2], a[6], col, glow, sub)
        if "y" in faces: self.quad(a[0], a[1], a[5], a[4], col, glow, sub)
        if "Y" in faces: self.quad(a[7], a[6], a[2], a[3], top or col, glow, sub)

    def beam(self, a, b, r, col, glow=0.0):
        """Square beam between two local points."""
        a, b = Vector(a), Vector(b)
        d = b - a
        up = Vector((0, 1, 0)) if abs(d.normalized().y) < 0.95 else Vector((1, 0, 0))
        s = d.cross(up).normalized() * r
        t = s.cross(d).normalized() * r
        P = self.P
        cs = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
        A = [P(*(a + s * x + t * y)) for x, y in cs]
        B = [P(*(b + s * x + t * y)) for x, y in cs]
        for i in range(4):
            j = (i + 1) % 4
            self.face([A[j], A[i], B[i], B[j]], col, glow)
        self.face(A, col, glow)
        self.face(list(reversed(B)), col, glow)

    def cyl(self, x, y0, z, r0, y1, r1, col, n=10, glow=0.0, caps=True):
        P = self.P
        ring = lambda y, r: [P(x + math.cos(2 * math.pi * i / n) * r, y, z + math.sin(2 * math.pi * i / n) * r) for i in range(n)]
        A, B = ring(y0, r0), ring(y1, r1)
        for i in range(n):
            j = (i + 1) % n
            self.face([A[j], A[i], B[i], B[j]], col, glow)
        if caps:
            if r0 > 0.001:
                self.face(A, col, glow)
            if r1 > 0.001:
                self.face(list(reversed(B)), col, glow)

    def ball(self, x, y, z, r, col, n=8, rings=5, glow=0.0, sy=1.0):
        P = self.P
        pts = []
        for j in range(rings + 1):
            t = math.pi * j / rings
            pts.append([P(x + math.sin(t) * math.cos(2 * math.pi * i / n) * r, y + math.cos(t) * r * sy,
                          z + math.sin(t) * math.sin(2 * math.pi * i / n) * r) for i in range(n)])
        for j in range(rings):
            for i in range(n):
                k = (i + 1) % n
                self.face([pts[j][i], pts[j][k], pts[j + 1][k], pts[j + 1][i]], col, glow)

    def disc(self, x, y, z, r, col, n=16, glow=0.0, axis="z"):
        """Flat disc facing +z (or +y)."""
        P = self.P
        if axis == "z":
            pts = [P(x + math.cos(-2 * math.pi * i / n) * r, y + math.sin(-2 * math.pi * i / n) * r, z) for i in range(n)]
        else:
            pts = [P(x + math.cos(2 * math.pi * i / n) * r, y, z + math.sin(2 * math.pi * i / n) * r) for i in range(n)]
        self.face(pts[::-1], col, glow)

    def prism_roof(self, x0, x1, y, z0, z1, h, col, over=0.5, row=0.55, row_jit=0.09):
        """Shingled gable: ridge along x, rows of overlapping strips, solid gable ends left to walls."""
        rng = self.rng
        zm = (z0 + z1) * 0.5
        for side, zedge in ((-1, z0 - over), (1, z1 + over)):
            run = zm - zedge
            slope = (h + over * h / abs(zm - z0)) / abs(run)
            rows = max(2, int(abs(run) / row))
            for r in range(rows):
                t0, t1 = r / rows, (r + 1) / rows
                za, zb = zedge + run * t0, zedge + run * t1
                ya = y - over * h / abs(zm - z0) + (abs(run) * t0) * slope
                yb = y - over * h / abs(zm - z0) + (abs(run) * t1) * slope
                c = jitter(col, rng, row_jit)
                lip = 0.08
                a = self.P(x0 - over, ya - lip, za)
                b = self.P(x1 + over, ya - lip, za)
                cc = self.P(x1 + over, yb, zb)
                d = self.P(x0 - over, yb, zb)
                if side > 0:
                    self.face([a, b, cc, d], c)
                else:
                    self.face([b, a, d, cc], c)
                # underside, held off the top skin so the AO bake doesn't read the
                # pair as sealed (coincident faces bake solid black)
                ua, ub, uc, ud = [self.P(px, py - 0.14, pz) for (px, py, pz) in (
                    (x0 - over, ya - lip, za), (x1 + over, ya - lip, za), (x1 + over, yb, zb), (x0 - over, yb, zb))]
                if side > 0:
                    self.face([ub, ua, ud, uc], scale_col(col, 0.5))
                else:
                    self.face([ua, ub, uc, ud], scale_col(col, 0.5))

    def gable_end(self, x, y, z0, z1, h, col, flip=False):
        zm = (z0 + z1) * 0.5
        a, b, c = self.P(x, y, z0), self.P(x, y, z1), self.P(x, y + h, zm)
        self.face([a, b, c] if not flip else [b, a, c], col)

    # --- architecture ------------------------------------------------------------
    def wall(self, a, b, y0, y1, col, openings=(), board=0.32, t=0.28, inner=None, frame=None,
             glass=None, jit=0.09, collide=True, sub=2.2):
        """Clapboard wall from local a to b (x, z), outer face on the right of a->b.
        openings: (start_along_wall, width, sill, head) in metres; sill 0 = door gap."""
        ax, az = a
        bx, bz = b
        length = math.hypot(bx - ax, bz - az)
        yaw = -math.degrees(math.atan2(bz - az, bx - ax))
        self.push(ax, 0, az, yaw=yaw)   # local: x along the wall, +z outward... see below
        rng = self.rng
        inner = inner or scale_col(col, 0.85)
        ops = sorted(openings)
        rows = max(1, int(round((y1 - y0) / board)))
        bh = (y1 - y0) / rows
        for r in range(rows):
            ya, yb = y0 + r * bh, y0 + (r + 1) * bh
            spans = [(0.0, length)]
            for (s0, w, sill, head) in ops:
                if yb > sill and ya < head:
                    new = []
                    for (u0, u1) in spans:
                        if s0 > u0:
                            new.append((u0, min(u1, s0)))
                        if s0 + w < u1:
                            new.append((max(u0, s0 + w), u1))
                    spans = new
            for (u0, u1) in spans:
                if u1 - u0 < 0.02:
                    continue
                c = jitter(col, rng, jit)
                lip = 0.035 if r % 2 else 0.0
                self.box(u0, ya, -t * 0.5, u1, yb, t * 0.5 + lip, c, faces="xXyYZ")
                self.box(u0, ya, -t * 0.5, u1, yb, -t * 0.5 + 0.001, inner, faces="z", sub=sub)
        fr = frame or hexc("#e8d6ae")
        for (s0, w, sill, head) in ops:
            f = 0.12
            d = t * 0.5 + 0.09
            self.box(s0 - f, sill if sill > 0 else y0, -d, s0, head + f, d, fr)
            self.box(s0 + w, sill if sill > 0 else y0, -d, s0 + w + f, head + f, d, fr)
            self.box(s0 - f, head, -d, s0 + w + f, head + f, d, fr)
            if sill > 0:
                self.box(s0 - f * 1.6, sill - f, -d - 0.05, s0 + w + f * 1.6, sill, d + 0.05, fr)
                g = glass or (*hexc("#ffc774"), 0.32)
                self.box(s0, sill, -0.02, s0 + w, head, 0.02, g[:3], glow=g[3])
                self.box(s0 + w * 0.5 - 0.035, sill, -0.05, s0 + w * 0.5 + 0.035, head, 0.05, fr)
                self.box(s0, (sill + head) * 0.5 - 0.035, -0.05, s0 + w, (sill + head) * 0.5 + 0.035, 0.05, fr)
        if collide:
            cuts = [0.0]
            for (s0, w, sill, head) in ops:
                if sill <= y0 + 0.01:
                    self.col(cuts[-1], y0, -t * 0.5, s0, y1, t * 0.5)
                    self.col(s0, head, -t * 0.5, s0 + w, y1, t * 0.5)
                    cuts.append(s0 + w)
            self.col(cuts[-1], y0, -t * 0.5, length, y1, t * 0.5)
        self.pop()

    def posts(self, x0, x1, n, y0, y1, z, col, r=0.13):
        for i in range(n):
            x = x0 + (x1 - x0) * i / max(1, n - 1)
            self.box(x - r, y0, z - r, x + r, y1, z + r, jitter(col, self.rng, 0.08))

    def floor_boards(self, x0, z0, x1, z1, y, col, board=0.42, along_x=True, depth=0.2, sub=2.2):
        """Plank floor. Each board is its own quad with colour jitter."""
        rng = self.rng
        if along_x:
            n = int((z1 - z0) / board)
            for i in range(n):
                z = z0 + (z1 - z0) * i / n
                z2 = z0 + (z1 - z0) * (i + 1) / n
                self.box(x0, y - depth, z, x1, y, z2 - 0.012, jitter(col, rng, 0.1), sub=sub, faces="Y")
                self.box(x0, y - depth, z2 - 0.012, x1, y - 0.03, z2, scale_col(col, 0.55), faces="Y")
        else:
            n = int((x1 - x0) / board)
            for i in range(n):
                x = x0 + (x1 - x0) * i / n
                x2 = x0 + (x1 - x0) * (i + 1) / n
                self.box(x, y - depth, z0, x2 - 0.012, y, z1, jitter(col, rng, 0.1), sub=sub, faces="Y")
                self.box(x2 - 0.012, y - depth, z0, x2, y - 0.03, z1, scale_col(col, 0.55), faces="Y")
        self.box(x0, y - depth, z0, x1, y, z1, scale_col(col, 0.6), faces="xXzZ")

    def text(self, s, x, y, z, size, col, font="Rye-Regular", depth=0.08, glow=0.0, align="CENTER", yaw=0.0, back=None, res=2):
        """Extruded mesh lettering. (x, y, z) is the centre of the text's baseline."""
        cu = bpy.data.curves.new("t", "FONT")
        cu.body = s
        cu.font = _font(font)
        cu.size = size
        cu.extrude = depth * 0.5
        cu.align_x = align
        cu.align_y = "BOTTOM_BASELINE" if "BOTTOM_BASELINE" in {i.identifier for i in cu.bl_rna.properties["align_y"].enum_items} else "BOTTOM"
        cu.resolution_u = res
        ob = bpy.data.objects.new("t", cu)
        bpy.context.scene.collection.objects.link(ob)
        dg = bpy.context.evaluated_depsgraph_get()
        me = ob.evaluated_get(dg).to_mesh()
        self.push(x, y, z, yaw=yaw)
        side = back or scale_col(col, 0.45)
        for p in me.polygons:
            pts = []
            for vi in p.vertices:
                v = me.vertices[vi].co
                pts.append(self.P(v.x, v.y, v.z))
            n = p.normal
            front = n.z > 0.5
            self.face(pts, col if front else side, glow if front else glow * 0.3)
        self.pop()
        ob.to_mesh_clear()
        bpy.data.objects.remove(ob)
        bpy.data.curves.remove(cu)

    def bulbs(self, a, b, n, r, col, glow=1.0, sides=6):
        """String of marquee bulbs between two local points."""
        a, b = Vector(a), Vector(b)
        for i in range(n):
            p = a.lerp(b, i / max(1, n - 1))
            self.ball(p.x, p.y, p.z, r, col, n=sides, rings=3, glow=glow)

    # --- colliders / lights / dynamic parts ---------------------------------------
    def col(self, x0, y0, z0, x1, y1, z1):
        c = Vector(((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5))
        size = Vector((abs(x1 - x0), abs(y1 - y0), abs(z1 - z0)))
        self.cols.append((self.xf[-1] @ Matrix.Translation(c), size))

    def col_ramp(self, a, b, w, t=0.3):
        """Walkable ramp: top surface runs along a->b (local points)."""
        a, b = Vector(a), Vector(b)
        d = b - a
        length = d.length
        yaw = math.atan2(d.x, d.z)
        pitch = -math.asin(d.y / length)
        m = Matrix.Translation((a + b) * 0.5) @ Matrix.Rotation(yaw, 4, "Y") @ Matrix.Rotation(pitch, 4, "X") @ Matrix.Translation((0, -t * 0.5, 0))
        self.cols.append((self.xf[-1] @ m, Vector((w, t, length))))

    def lamp(self, x, y, z, radius=9.0, power=0.1, col=(1.0, 0.88, 0.68)):
        p = self.P(x, y, z)
        self.lamps.append((np.array([p.x, p.y, p.z], dtype=np.float32), radius, power, col))

    def room(self, x0, y0, z0, x1, y1, z1, level=0.06, col=(1.0, 0.85, 0.7)):
        """Flat fill light for everything inside a box (interiors have no sun)."""
        a, b = self.P(x0, y0, z0), self.P(x1, y1, z1)
        lo = np.array([min(a.x, b.x), min(a.y, b.y), min(a.z, b.z)], dtype=np.float32)
        hi = np.array([max(a.x, b.x), max(a.y, b.y), max(a.z, b.z)], dtype=np.float32)
        self.rooms.append((lo, hi, level, col))

    def part(self, name, seed=2):
        sub = LM(name, seed)
        self.dyn[name] = sub
        return sub

    # --- output --------------------------------------------------------------------
    def _object(self, name, ao=True, ao_samples=48, ao_dist=3.5):
        me = bpy.data.meshes.new(name)
        verts = [_to_blender(v) for v in self.verts]
        # Winding authored CCW in Godot axes; the axis swap keeps handedness.
        me.from_pydata(verts, [], self.faces)
        me.update()
        ob = bpy.data.objects.new(name, me)
        ob.location = _to_blender(self.origin)
        bpy.context.scene.collection.objects.link(ob)
        n_loops = len(me.loops)
        cols = np.zeros((n_loops, 4), dtype=np.float32)
        starts = np.empty(len(me.polygons), dtype=np.int32)
        totals = np.empty(len(me.polygons), dtype=np.int32)
        me.polygons.foreach_get("loop_start", starts)
        me.polygons.foreach_get("loop_total", totals)
        fc = np.array(self.fcols, dtype=np.float32)
        cols[:] = np.repeat(fc, totals, axis=0)
        attr = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
        attr.data.foreach_set("color", cols.ravel())
        if ao:
            mult = _bake_ao(ob, ao_samples, ao_dist)
            cols[:, :3] *= mult[:, None]
        if self.lamps or self.rooms:
            _bake_lamps(me, cols, self.lamps, self.rooms)
        attr.data.foreach_set("color", cols.ravel())
        me.color_attributes.active_color = attr
        me.color_attributes.render_color_index = me.color_attributes.find("Col")
        return ob

    def finish(self, out_dir, ao=True):
        scene = bpy.context.scene
        objs = [self._object(self.name, ao=ao)]
        print(f"{self.name}: {sum(len(f) - 2 for f in self.faces)} tris, {len(self.cols)} colliders")
        for k, sub in self.dyn.items():
            o = sub._object("DYN_" + k, ao=False)
            objs.append(o)
        for i, (m, size) in enumerate(self.cols):
            me = bpy.data.meshes.new("c")
            h = size * 0.5
            vs = [(-h.x, -h.y, -h.z), (h.x, -h.y, -h.z), (h.x, h.y, -h.z), (-h.x, h.y, -h.z),
                  (-h.x, -h.y, h.z), (h.x, -h.y, h.z), (h.x, h.y, h.z), (-h.x, h.y, h.z)]
            me.from_pydata([_to_blender(v) for v in vs], [], [(0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (2, 3, 7, 6), (0, 3, 7, 4), (1, 2, 6, 5)])
            me.update()
            ob = bpy.data.objects.new(f"COL_{i}", me)
            scene.collection.objects.link(ob)
            ob.matrix_world = _godot_matrix_to_blender(m)
            objs.append(ob)
        for o in objs:
            if o.type == "MESH" and len(o.data.color_attributes) == 0:
                a = o.data.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
        bpy.context.view_layer.update()
        path = os.path.join(out_dir, self.name + ".glb")
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
                                  export_materials="NONE", export_vertex_color="ACTIVE",
                                  export_all_vertex_colors=False, export_texcoords=False,
                                  export_normals=True, export_yup=True, export_apply=False,
                                  export_animations=False, export_skins=False, export_morph=False)
        print("WROTE", path, os.path.getsize(path) // 1024, "KB")


_B = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))


def _godot_matrix_to_blender(m):
    return _B @ m @ _B.inverted()


_fonts = {}


def _font(name):
    if name not in _fonts:
        _fonts[name] = bpy.data.fonts.load(os.path.join(FONT_DIR, name + ".ttf"))
    return _fonts[name]


def _bake_ao(ob, samples, dist):
    """Cycles AO to a corner colour attribute. Returns per-loop multiplier."""
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = False
    if scene.world is None:
        scene.world = bpy.data.worlds.new("w")
    scene.world.light_settings.distance = dist
    me = ob.data
    ao = me.color_attributes.new("AO", "FLOAT_COLOR", "CORNER")
    me.color_attributes.active_color = ao
    if not me.materials:
        mat = bpy.data.materials.new("bake")
        mat.use_nodes = True
        me.materials.append(mat)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.bake(type="AO", target="VERTEX_COLORS", margin=0)
    a = np.empty(len(me.loops) * 4, dtype=np.float32)
    ao.data.foreach_get("color", a)
    v = a.reshape(-1, 4)[:, 0]
    print(f"  AO {ob.name}: min {v.min():.2f} mean {v.mean():.2f} max {v.max():.2f}")
    me.color_attributes.remove(me.color_attributes["AO"])
    me.materials.clear()
    return 0.42 + 0.58 * np.clip(v, 0.0, 1.0) ** 0.8


def _bake_lamps(me, cols, lamps, rooms=()):
    """Warm point lights painted into the vertices: rgb tints toward the lamp, alpha
    adds a small self-illumination so rooms read as lit even in sun shadow."""
    n = len(me.vertices)
    co = np.empty(n * 3, dtype=np.float32)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    co = np.stack([co[:, 0], co[:, 2], -co[:, 1]], axis=1)  # back to Godot axes
    idx = np.empty(len(me.loops), dtype=np.int32)
    me.loops.foreach_get("vertex_index", idx)
    pts = co[idx]
    light = np.zeros(len(pts), dtype=np.float32)
    tint = np.zeros((len(pts), 3), dtype=np.float32)
    for pos, radius, power, c in lamps:
        d = np.linalg.norm(pts - pos, axis=1)
        f = np.clip(1.0 - d / radius, 0.0, 1.0) ** 2 * power
        light += f
        tint += f[:, None] * np.array(c, dtype=np.float32)
    for lo, hi, level, c in rooms:
        inside = np.all((pts >= lo - 0.05) & (pts <= hi + 0.05), axis=1)
        f = inside * level
        light += f
        tint += f[:, None] * np.array(c, dtype=np.float32)
    mask = light > 0.0
    tint[mask] /= light[mask, None]
    k = np.clip(light * 2.0, 0.0, 0.3)[:, None]
    cols[:, :3] = cols[:, :3] * (1.0 - k) + cols[:, :3] * tint * k * 1.2
    cols[:, 3] = np.maximum(cols[:, 3], np.clip(light, 0.0, 0.3))
