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
- **Added**: 84 custom models, 85 CC0 models, 5 music and ambience loops, UI font, roulette game, Human Cannon, spiral slide, diving tower, second Mystery Slop bar, carousel and Ferris wheel, settings system, gamepad support.

## 3 and 4. Sources and licences

See [ASSET_CREDITS.md](ASSET_CREDITS.md). All third-party models are CC0 and all fonts are OFL.

## 5. Custom models

The table lists the landmarks; with the props, set pieces and "bits" files there are 84 GLBs in all (see 7b and 7c). No Meshy or Tripo API keys were available, so these are procedural Blender builds. Run `art_src/blender/build_landmarks.py` to regenerate them.

| District | Models |
|---|---|
| Western | `saloon`, `sheriff`, `store`, `hotel`, `water_tower`, `outhouse`, `town_arch` |
| Casino | `casino`, `slot_duck`, `slot_skull`, `slot_soup`, `cards`, `back_room`, `roulette_table`, `poker_table`, `blackjack_table`, `prize_wheel`, `crash_cabinet`, `duck_track` |
| Beach | `beach_bar`, `tiki_hut`, `dock_section`, `dive_tower`, `lighthouse` |
| Minigames | `soup_pot`, `rocket`, `shrine`, `soup_raft`, `pg_camp`, `gh_fence`, `gh_hut`, `gh_rack`, `gh_plaza`, `cc_gate_big`, `cc_gate_small`, `cc_candles`, `cc_mess`, `game_bits` |
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

## 7b. Detail pass on code-built pieces

Many set pieces were built in GDScript from plain boxes and cylinders. They now keep their colliders in code (`Art.col_box` / `Art.col_cyl`) and take their look from models in `art_src/blender/sets.py`, placed at the same coordinates:

- **Props**: TNT bundles, playground and beach balls, the big ball, cones, planks, bowling pins, rubber ducks, steel beams, slatted crates, campfire logs, wrecking balls, and the cement drum. Each is built to its collision shape.
- **The Gauntlet**: start pads, the striped arch, mossy stone stepping pillars, the sweeper drum, the lashed balance beam and pendulum gantry, the bounce tower, and the trophy plinth.
- **The Chaos Yard**: the I-beam wrecking-ball gantry, scaffold towers, the steel frame tower, a cement truck, a port-a-potty, jersey barriers, and a lattice tower crane with a turning jib.
- **The Meadow and town**: plank kicker ramps, the bowling lane, Friend Ledge, pressure-plate housings, a packed cobble ring round the plaza, and water troughs with a pump.
- **The Carnival**: four custom stalls (corn dogs, soda, lost and found, restrooms) replace the kit stalls.
- **Ramps** made in code are now planks on stringers, not slabs.

## 7c. Second detail pass: minigame arenas and lobby leftovers

The same rule as 7b: colliders, triggers and every node the game animates stay in code at their old sizes; the look comes from models placed at the same anchors. New modules: `art_src/blender/arenas.py` (minigames), `street.py` (lobby pieces) and `furniture.py`.

- **Lava Soup**: a toast raft (butter, crumb, a cocktail-stick flag) on the old raft collider; cracker, carrot-coin and mushroom platforms alongside the kit foods; carrots, peas, celery, onion rings and bubbles that ride the soup as it rises; riveted pot seams, a scorched base, a rolled rim, a thermometer clipped to the rim, a leek and celery over the edge, a ring of burner flames, and a real tasting ladle. "SOUP OF THE DAY: YOU" now wraps the curved wall on the sun side; on the old wall the raking sun drew a second, shadow copy under it.
- **Pocket God**: a castaway workshop (lean-to, blueprint easel, workbench, fire pit, washing line, crates and drums, a LAUNCH sign) replaces the scattered kit tents; lattice launch masts, a hazard-ringed pad and fuel tanks; rocket stages with seams, rivets and mismatched scrap patches; carved shrine stones with an altar, offerings and a haloed duck; a proper giant hand.
- **Giant Hunt**: log palisade with shields and torches, thatched wattle huts (same little-only doorway), broken columns on worn flagstones, spear racks, mossy boulders, irregular dirt, faceted snow-capped mountains, kit trees with the old trunk colliders.
- **Cursed Casino Night**: barred, boarded and padlocked doors with their signs built in (the floating label is gone), purple candelabras by the doors, spilled chips and dropped cards.
- **Lobby**: sign posts (planked boards cut to the text, capped posts, iron brackets; text is still one-sided per face), iron street lamps with tinted glass, the Big Wheel trestle, the START pedestal and button, paving under the wheel, a wagon-wheel trampoline, the Vault's round safe door (same moving body), bounce pads and the inflatable cannon target (the parts that squash are still the animated nodes), deck-level ropes and stakes on the Narrow Bridge (still no railings), pink froth along the chasm goo's shoreline, a Chaos Yard entrance arch (its sign replaces the floating label), pallets and tool crates, a crane hook block, treasure chests, the Slide Hill summit deck and duck flag, the trophy, the striped sweeper, pressure plates, carnival poles, beach umbrellas and loungers, campfire flames, coaster cars and station, the hotel wardrobe (paint bench, hat stand, body-swap booth), the Hall of Fame board and the VIP rope.
- **Furniture**: the saloon tables, chairs and bar stools, the hotel settee, armchairs and floor lamp, the casino stools and the jail chair are custom western pieces instead of plain KayKit models.

Primitives deliberately left: ramp planks (already planks on stringers), slide-lane rail sticks, the sweeper's flat hazard disc, pendulum and crane cables, far backdrop islands (pure silhouettes in fog), the lighthouse beam, and the casino's flying cards and chips (short-lived FX).

## 8. Remaining visual deficiencies

- **Upstairs spaces are walk-tested**: the saloon gallery, the saloon's outside stairs, both hotel balconies and the hotel's side stairs are all covered by the town walk test, which now also checks each route ends on the right floor.
- **Nature kit bushes** are now tinted toward the meadow palette in code (`Playground.BUSH_TINT`). They are still the kit shapes.
- **NPCs** carry one thing each, fidget (scratch, check a watch, shift about) and slowly wave when you get close. They still have no voices beyond the mutter lines.
- **Avatars walk through saloon doors and bar stools** by design. The swing doors must be walked through, and stools with collision would box players away from the bar and break the town walk routes. Tables, the settee and the jail furniture keep their colliders.
- **Music occlusion is cheap and box-based** (`src/audio/room_muffle.gd`). The saloon, casino, sheriff, store and hotel are boxes. A music or surf source whose room differs from the camera's is turned down 9 dB and low-passed to 900 Hz, eased over a third of a second. Only the players' own volume and filter change, so the buses and sliders are untouched. There's no portal logic: an open door muffles the same as a wall, and porches inside a building's footprint count as indoors.
- **Audio pass (2026-11-08)**: every synthesised clip was rendered and measured. `click`, `slap` and `hiss` were raw white noise and are now filtered. `knock` is 3 dB quieter and `thud` 2.5 dB, since props repeat them. Call sites: the death bonk −6 dB (it sat on top of the death whistle) and the death whistle −2 dB; pendulum bonk +6 → +2 dB; god slap +6 → +2 dB; Giant slap +8 → +4 dB; fire fart +8 → +4 dB.
- **Not heard by a human:** audio levels and the synthesised music were checked by construction and measurement only. Nobody has listened to them yet, including the slide sound you asked about. Sliders are there if anything needs nudging.
- **Gamepad and the display-mode revert dialog** are now covered by `tests/ui_test.gd`: every pad binding, the stick and button flow through `Input`, the countdown revert, and Keep. A real controller has still never been plugged in.

## 9. Performance

Measured at 1600x900 on an RTX 4080 Super with vsync off, Medium preset:

| View | Before: draws / ms | After: draws / ms | Primitives before → after |
|---|---|---|---|
| Spawn | 1964 / 4.40 | 686 / 3.04 | 270k → 738k |
| Street | 2260 / 4.79 | 876 / 2.82 | 262k → 713k |
| Overview | 1594 / 5.04 | 850 / 2.89 | 179k → 593k |
| East | 686 / 3.35 | 548 / 2.81 | 192k → 539k |

After the rides, Vault, cave and hotel upstairs were added, the same probe reads: Spawn 949 draws / 3.52 ms, Street 1560 / 3.17, Overview 1203 / 3.08, East 844 / 2.85, with 690k to 910k primitives. Draws are up, mostly from Street, but frame time is about the same. Low-end machines haven't been tested.

The saloon upstairs, hotel balcony and NPC props and eyes add about 100 draws and 0.2 to 0.3 ms, measured back to back against the previous commit on the same machine.

The 2026-11-08 detail pass (minigame arenas, lobby leftovers, furniture), measured back to back against the commit before it: Spawn 928–949 → 861–909 draws, 3.37–3.53 → 3.36–3.44 ms; Street 1547–1561 → 1493–1519, 3.20–3.71 → 3.07–3.14 ms; Overview 1069–1075 → 1029–1043, 2.89–3.00 → 2.81–2.83 ms; East 812–820 → 785–790, 2.80–2.88 → 2.81–2.82 ms. Primitives rose 5–8% (1.06M → 1.15M at Spawn), video memory from about 118 MB to 127 MB, and first world frame stayed about 1.45 s. Draws fell because many separate primitive nodes became batched geometry. The minigame arenas were not perf-probed.

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

`bake_kit.py` needs the source packs downloaded and laid out as in `art_src/kit_manifest.py`. Only 85 of the 321 baked models are committed; re-bake to get others. Don't name a node ending in `_wheel`, `_col`, `_rigid` or similar: Godot's importer treats those suffixes as hints.

## Tests

```
godot --headless --path . -s tests/town_test.gd -- --host --bots=1       # walks to every station
godot --headless --path . -s tests/smoke_test.gd -- --host --bots=3
godot --headless --path . -s tests/smoke_test.gd -- --host --bots=4 --giant
godot --headless --path . -s tests/physics_test.gd -- --host --bots=2
godot --headless --path . -s tests/settings_test.gd
godot --headless --path . -s tests/ui_test.gd                            # gamepad + display revert
godot --headless --path . -- --host --bots=1                             # then, in a second shell:
godot --headless --path . -s tests/net_test.gd -- --join=127.0.0.1
```

`scripts/test_all.ps1` runs all of these one at a time and cleans up after each. It uses port 24690, so it can run with the game open. Pass `--port=N` to any run to do the same by hand. `tests/rides_test.gd` covers the coaster, Ferris wheel, every cannon target, the toilet, the helter-skelter and poker ranks.
