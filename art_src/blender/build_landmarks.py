"""blender -b --python art_src/blender/build_landmarks.py -- <out_dir> [names...]"""
import importlib
import os
import sys
import time

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import lm  # noqa: F401
import town

MODULES = [town]
for name in ("casino", "resort", "carnival", "gamesets", "sets", "arenas", "street", "furniture"):
    if os.path.exists(os.path.join(HERE, name + ".py")):
        MODULES.append(importlib.import_module(name))

argv = sys.argv[sys.argv.index("--") + 1:]
out = argv[0]
names = argv[1:]
BUILDERS = {}
for mod in MODULES:
    for n in getattr(mod, "ALL", []):
        BUILDERS[n] = getattr(mod, n)
for n in names or sorted(BUILDERS):
    t = time.time()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    lm._fonts.clear()
    BUILDERS[n](out)
    print("BUILT", n, round(time.time() - t, 1), "s")
