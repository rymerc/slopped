"""Blender headless: curated CC0 kit models -> single-mesh, vertex-coloured GLBs.
blender -b --python art_src/blender/bake_kit.py -- <download_root> <out_dir> [ids...]"""
import bpy
import glob
import json
import os
import sys
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.dirname(HERE))
import common
from kit_manifest import KIT, PACKS, _K

argv = sys.argv[sys.argv.index("--") + 1:]
root, out = argv[0], argv[1]
only = set(argv[2:])
os.makedirs(out, exist_ok=True)

jobs = {}
for kid, (pack, stem) in KIT.items():
    jobs[kid] = os.path.join(root, PACKS[pack], stem + ".glb")
for pack, names in _K.items():
    files = glob.glob(os.path.join(root, PACKS[pack], "**", "*.gltf"), recursive=True) + \
        glob.glob(os.path.join(root, PACKS[pack], "**", "*.glb"), recursive=True)
    index = {}
    for f in files:
        index.setdefault(os.path.splitext(os.path.basename(f))[0], f)
    for stem in (names.split() if names else sorted(index)):
        if stem in index:
            jobs[f"{pack}_{stem}"] = index[stem]
        else:
            print("MISSING", pack, stem)

report = {}
for kid, path in sorted(jobs.items()):
    if only and kid not in only:
        continue
    if not os.path.exists(path):
        alt = path.replace("GLTF format", "GLB format")
        alt2 = path[:-4] + ".gltf"
        path = alt if os.path.exists(alt) else alt2
        if not os.path.exists(path):
            print("MISSING", kid, path)
            continue
    common.clear()
    common._img_cache.clear()
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not meshes:
        print("NOMESH", kid)
        continue
    for o in meshes:
        common.bake_face_colors(o)
        if kid.startswith("nature_") or kid.startswith("coaster_tree") or kid.startswith("coaster_flowers"):
            common.warm_foliage(o)
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    ob.name = kid
    ob.data.materials.clear()
    common.export_glb(os.path.join(out, kid + ".glb"), [ob])
    bb = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
    report[kid] = {"tris": sum(len(p.vertices) - 2 for p in ob.data.polygons),
                   "size": [round(max(v[i] for v in bb) - min(v[i] for v in bb), 3) for i in (0, 2, 1)]}
    print("OK", kid, report[kid])
with open(os.path.join(out, "..", "kit_report.json"), "w") as f:
    json.dump(report, f, indent=0, sort_keys=True)
print("BAKED", len(report))
