"""Shared Blender helpers: scene reset, colormap -> vertex colour baking, GLB export."""
import bpy
import numpy as np


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def srgb_to_lin(a):
    a = np.asarray(a, dtype=np.float32)
    return np.where(a <= 0.04045, a / 12.92, ((a + 0.055) / 1.055) ** 2.4)


_img_cache = {}


def _pixels(img):
    key = img.name
    if key not in _img_cache:
        w, h = img.size
        p = np.empty(w * h * 4, dtype=np.float32)
        img.pixels.foreach_get(p)
        _img_cache[key] = (p.reshape(h, w, 4), w, h, img.colorspace_settings.name)
    return _img_cache[key]


def _material_source(mat):
    """(base colour rgba in linear, image or None) for a Principled material."""
    if mat is None or not mat.use_nodes:
        c = mat.diffuse_color if mat else (0.8, 0.8, 0.8, 1)
        return tuple(c), None
    pr = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if pr is None:
        return (0.8, 0.8, 0.8, 1), None
    inp = pr.inputs["Base Color"]
    img = None
    seen = list(inp.links)
    while seen:  # walk back through mix / multiply nodes to the image
        n = seen.pop().from_node
        if n.type == "TEX_IMAGE" and n.image is not None:
            img = n.image
            break
        for i in n.inputs:
            seen.extend(i.links)
    return tuple(inp.default_value), img


def bake_face_colors(ob):
    """Writes a CORNER colour attribute: one flat, face-centre-sampled colour per
    polygon, so a colormap turns into clean flat colours (alpha 0 = not emissive)."""
    me = ob.data
    n_loops = len(me.loops)
    cols = np.zeros((n_loops, 4), dtype=np.float32)
    uv = me.uv_layers.active
    uvs = None
    if uv is not None:
        uvs = np.empty(n_loops * 2, dtype=np.float32)
        uv.data.foreach_get("uv", uvs)
        uvs = uvs.reshape(-1, 2)
    sources = [_material_source(s.material) for s in ob.material_slots] or [((0.8, 0.8, 0.8, 1), None)]
    for p in me.polygons:
        base, img = sources[min(p.material_index, len(sources) - 1)]
        c = np.array(base[:3], dtype=np.float32)
        if img is not None and uvs is not None:
            px, w, h, cs = _pixels(img)
            u, v = uvs[p.loop_start:p.loop_start + p.loop_total].mean(axis=0)
            x = int((u % 1.0) * w) % w
            y = int((v % 1.0) * h) % h
            t = px[y, x, :3]
            if cs == "sRGB":
                t = srgb_to_lin(t)
            c = c * t
        cols[p.loop_start:p.loop_start + p.loop_total, :3] = c
    attr = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    attr.data.foreach_set("color", cols.ravel())
    me.color_attributes.active_color = attr
    me.color_attributes.render_color_index = 0


def warm_foliage(ob):
    """Kenney Nature leaves are a cool teal; pull them toward the island's greens."""
    a = ob.data.color_attributes["Col"]
    c = np.empty(len(a.data) * 4, dtype=np.float32)
    a.data.foreach_get("color", c)
    c = c.reshape(-1, 4)
    leaf = c[:, 1] > c[:, 0] * 1.15
    c[leaf, 2] *= 0.42
    c[leaf, 0] *= 1.25
    a.data.foreach_set("color", c.ravel())


def export_glb(path, objects=None):
    if objects is not None:
        bpy.ops.object.select_all(action="DESELECT")
        for o in objects:
            o.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=objects is not None,
        export_materials="NONE", export_vertex_color="ACTIVE", export_all_vertex_colors=False,
        export_texcoords=False, export_normals=True, export_yup=True,
        export_apply=True, export_animations=False, export_skins=False, export_morph=False)
