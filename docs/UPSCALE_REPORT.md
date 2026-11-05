# Visual upscale report

Branch `visual-upscale`. The first commit (`09b6443`) snapshots the work in progress as it stood, so everything here can be diffed or reverted. Licences and source links are in [ASSET_CREDITS.md](ASSET_CREDITS.md).

## 1. Original asset inventory

The original game had **no model, texture or audio files**. Everything was GDScript primitives.

| Asset | Location | Quality | Decision |
|---|---|---|---|
| Walled "Slop Lounge" room | `lobby_builder.gd` | Purple box, flat rugs | **Replaced** by the town of Slopsville |
| Bar, shelves, stools | `lobby_builder.gd` | Boxes | **Replaced** by the Saloon interior |
| VIP throne + gate | `lobby_builder.gd` | Boxes | **Replaced**, leader-only logic kept |
| Wardrobe (paint, hats, swap booth) | `lobby_builder.gd` | Primitives | **Improved**, moved into the hotel lobby |
| 4 casino cabinets | `lobby_builder.gd` | Identical boxes | **Replaced** by machines with moving parts |
| Perk shop stall | `lobby_builder.gd` | Boxes | **Replaced** by the General Store |
| Bot kennel | `lobby_builder.gd` | Box doghouse | **Replaced** by the Bot Jail |
| Toilet teleporter | `lobby_builder.gd` | Primitives | **Replaced** by an outhouse |
| Trampoline, START button | `lobby_builder.gd` | Primitives | **Improved** |
| Hall of Fame | `lobby_builder.gd` | Board | **Improved**, on the sheriff's porch |
| Big Wheel | `big_wheel.gd` | Good | **Kept** |
| Terrain | `terrain.gd`, `playground.gd` | Neon green (colour-space bug) | **Improved**: bug fixed, districts, beach |
| Trees, rocks | `art.gd` | Blobby | **Replaced** on the island, kept in Giant Hunt |
| Grass, flowers | `terrain.gd` | Near-black blades | **Improved** |
| Slide Hill | `playground.gd` | Good gameplay | **Kept**, duck statue **replaced** |
| Gauntlet + Narrow Bridge | `playground.gd` | Good gameplay | **Kept** |
| Crane, wrecking ball, scaffolds | `playground.gd` | Readable | **Kept**, **supplemented** with yard clutter |
| Meadow (kickers, bowling) | `playground.gd` | Sparse | **Improved** with a campsite and farm patch |
| Vault | `playground.gd` | Grey box | **Kept**: still the weakest landmark |
| Cave | `playground.gd` | Rock blobs | **Kept** |
| Lighthouse | `playground.gd` | Floating in the sea | **Replaced** and moved onto land |
| Physics props | `prop.gd` | Primitives | **Replaced** with kit meshes, physics unchanged |
| 6 characters + hats | `chars.gd`, `art.gd` | Charming, consistent | **Kept** |
| Toon shader | `toon.gdshader` | Good base | **Improved**: emission mask, paint grain |
| Sky, water | `sky.gdshader`, `water.gdshader` | Harsh | **Improved** colours and sun glint |
| Sound effects | `sfx.gd` | Harsh movement sounds | **Improved** |

## 2. Retained, replaced, added

- **Retained**: all gameplay systems, characters, Big Wheel, Slide Hill, Gauntlet, Narrow Bridge, crane, wrecking ball, Giant Hunt.
- **Replaced**: everything marked above.
- **Added**: 26 custom landmarks, 102 CC0 models, 5 music and ambience loops, UI font, roulette game, Human Cannon, spiral slide, diving tower, second Mystery Slop bar, carousel and Ferris wheel, settings system, gamepad support.

## 3 and 4. Sources and licences

See [ASSET_CREDITS.md](ASSET_CREDITS.md). All third-party models are CC0 and all fonts are OFL.

## 5. Custom models (26)

No Meshy or Tripo API keys were available, so these are procedural Blender builds. Run `art_src/blender/build_landmarks.py` to regenerate them.

| District | Models |
|---|---|
| Western | `saloon`, `sheriff`, `store`, `hotel`, `water_tower`, `outhouse`, `town_arch` |
| Casino | `casino`, `slot_machine`, `roulette_table`, `poker_table`, `blackjack_table`, `prize_wheel`, `crash_cabinet`, `duck_track` |
| Beach | `beach_bar`, `tiki_hut`, `dock_section`, `dive_tower`, `lighthouse` |
| Chaos | `ferris_wheel`, `carousel`, `big_cannon`, `giant_duck`, `spiral_slide`, `ticket_booth` |

Collision is box shapes (`COL_*`), moving parts are separate nodes (`DYN_*`), and AO and lamp light are baked into vertex colours. Each is one material, and buildings run 5–26k triangles.

## 6. Buildings and districts

- **Slopsville** (centre): Main Street lines up with the rainbow slide, so belly-sliding delivers you into town. Bunting, bulb strings, wagons, market stalls, cacti, fountain.
- **Lucky Duck Casino** (east): walk-in interior, animated slots, roulette, wheel and duck derby that everyone in the room can see.
- **Slop Cove** (south-west, facing the sunset): widened beach, Bilge Bar, tiki huts, palms, pier, boats, wreck, diving tower.
- **The Carnival** (north-east): the shore was pushed out to fit it. Ferris wheel, carousel, helter-skelter, coaster, cannon landing target.
- **Chaos Yard** (east): containers, trucks, pallets, Human Cannon.
- **Meadow** (south): campsite, tents, fence, pumpkin patch. Friend Ledge moved to (-62, 48) to make room for the cove.

Lighting is now golden hour: low sun from the south-west, warm horizon, cool shadows, and baked interiors.

## 7. Scenes and resources modified

There are no `.tscn` changes: worlds are built in code, and all node names and RPC paths are unchanged.

- **New**: `src/art/batch.gd`, `src/art/kit.gd`, `src/world/dress.gd`, `src/core/settings.gd`, `src/ui/settings_menu.gd`, `src/audio/ambience.gd`, `art_src/`, `assets/`, `tests/{town,net,settings}_test.gd`, `tests/{perf_probe,lm_preview,lm_stage}.gd`.
- **Rewritten**: `src/lobby/lobby_builder.gd`, most of `src/lobby/playground.gd`.
- **Modified**: `lobby.gd`, `casino.gd`, `casino_ui.gd`, `world_base.gd`, `terrain.gd`, `art.gd`, `prop.gd`, `toon.gdshader`, `water.gdshader`, `sfx.gd`, `avatar.gd` (audio + toggle sprint only), `cam_rig.gd` (settings + gamepad look only), `input_setup.gd`, `giant_game.gd`, `giant_hud.gd`, `net.gd` (one constant), `main.gd`, `ui.gd`, `project.godot`, `scripts/run_windows.ps1`.

## Behaviour changes to review

- **`BOT_BASE` raised from 1,000,000 to 2^31** in `net.gd`. This fixes a multiplayer bug that predates this work: client peer ids are random up to 2^31, so nearly every real client counted as a bot and never received casino results. `tests/net_test.gd` covers it.
- **Stations moved** into buildings. Interactions are unchanged except that SLOTS now has six machines, and Bilge Bar is a second Mystery Slop bar.
- **`Esc` is now the `menu` action**, with Start on gamepads. Key prompts show the player's real bindings.
- **New game logic**: roulette (host-authoritative, 10c, pays x2 / x14), Human Cannon (owner-side velocity, like bounce pads), and a `dive` challenge. Only the machine animations use a new RPC.
- **Movement audio**: the slide loop was rewritten (dark, seamless, eases in and out, peak -20 dB, was -6). Steps, jumps, landings and dives are 8–10 dB quieter, and all have their own Movement slider.

## 8. Remaining visual deficiencies

- **The Vault** is still a grey box, and **the cave** is still rock blobs.
- **Town ground** is flat dirt. Ruts, cobbles and plank crossings would add a lot up close.
- **Interiors are sparse**: the hotel upstairs doesn't exist, and the jail has no prisoners.
- **Some Nature kit bushes** still read too neon from far away.
- **Poker and blackjack tables are decorative**, with static dealers. Only roulette is playable.
- **The coaster and Ferris wheel can't be ridden.**
- **Avatars walk through saloon doors and stools**; these have no collision by design.
- **Music passes through walls.** There's no occlusion.
- **Not heard by a human:** audio levels and the synthesised music were checked by construction only. Nobody has listened to them yet, including the slide sound you asked about. Sliders are there if anything needs nudging.
- **Gamepad and the display-mode revert dialog were not exercised** by any test.

## 9. Performance

Measured at 1600x900 on an RTX 4080 Super with vsync off, Medium preset:

| View | Before: draws / ms | After: draws / ms | Primitives before → after |
|---|---|---|---|
| Spawn | 1964 / 4.40 | 686 / 3.04 | 270k → 738k |
| Street | 2260 / 4.79 | 876 / 2.82 | 262k → 713k |
| Overview | 1594 / 5.04 | 850 / 2.89 | 179k → 593k |
| East | 686 / 3.35 | 548 / 2.81 | 192k → 539k |

World build went from 946 ms to about 1190 ms, and video memory from 80 MB to 96 MB. Assets add 20 MB to the repo. **None of this was tested on low-end hardware**, which is the real target, so try the Low preset on the weakest machine in your group.

Why it holds up: `Batch` merges static scenery into chunked meshes with one material, so 1000 parts cost a few draw calls. Clutter sits on a no-shadow layer that culls at distance. Almost no real lights are used, because light is baked.

Recommendations, in order:

1. Test the Low preset on an integrated GPU.
2. Label3D is now the largest source of draw calls. Bake station signs into the landmarks.
3. Merge prop parts into one mesh per kind to cut props' draw calls.
4. Avoid adding omni lights near batches, since each one re-renders the whole chunk in Compatibility.
5. Consider `.import` settings to skip LOD generation on GLBs, which the batcher never uses.

## Rebuilding assets

```
tools\blender\...\blender.exe -b --python art_src/blender/build_landmarks.py -- assets/models/custom [names]
tools\blender\...\blender.exe -b --python art_src/blender/bake_kit.py -- <downloads> assets/models/kit [ids]
python art_src/make_audio.py
python art_src/make_grain.py
```

`bake_kit.py` needs the source packs downloaded and laid out as in `art_src/kit_manifest.py`. Only 102 of the 321 baked models are committed; re-bake to get others. Don't name a node ending in `_wheel`, `_col`, `_rigid` or similar: Godot's importer treats those suffixes as hints.

## Tests

```
godot --headless --path . -s tests/town_test.gd -- --host --bots=1       # walks to every station
godot --headless --path . -s tests/smoke_test.gd -- --host --bots=3
godot --headless --path . -s tests/smoke_test.gd -- --host --bots=4 --giant
godot --headless --path . -s tests/physics_test.gd -- --host --bots=2
godot --headless --path . -s tests/settings_test.gd
godot --headless --path . -- --host --bots=1                             # then, in a second shell:
godot --headless --path . -s tests/net_test.gd -- --join=127.0.0.1
```

All pass on the final build.
