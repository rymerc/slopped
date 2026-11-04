# SLOPPED — design notes

Friendslop party game: 2–12 friends, a goofy lobby hub, and 5–15 minute
asymmetric minigames that are rigged to make friends betray each other.

---

## 1. How the reference games were made (from the installed Steam files)

| Game | Engine | Netcode | Steam layer | Notable libs |
|---|---|---|---|---|
| How to Fish | Unity (URP) | **FishNet** | Heathen Steamworks + Steamworks.NET | RNNoise (voice denoise), Concentus (Opus voice) |
| Super Battle Golf | Unity (URP) | **Mirror** | Facepunch.Steamworks | DOTween, FMOD, Opus, Resonance Audio |
| Gamble With Your Friends | Unity (URP) | **Mirror + FizzySteamworks** | Steamworks.NET | DOTween, FMOD, **Dissonance** (proximity voice), AllIn1SpriteShader, Discord SDK |
| Just Act Natural | Unity | **Photon Bolt** | Heathen + Steamworks.NET | Odin Inspector, DOTween, NavMesh |
| Moon Sweepers | Unity (IL2CPP) | custom | Steamworks.NET | custom speech DLL |
| WEBFISHING | **Godot 3** | Steam P2P | **GodotSteam** | — |

Takeaways:
- **Every one of them is "cheap engine + Steam P2P lobby + host-authoritative"**. No dedicated servers. We copy this: ENet now, GodotSteam later.
- **Proximity voice chat is the secret sauce** (How to Fish, GWYF). Plan for it (GodotSteam voice or Opus over our own channel). It's what makes people scream.
- **Tween libraries everywhere** (DOTween): the "juice" is squash/stretch + snappy tweens, not complex animation. Godot's built-in `Tween` covers this.
- WEBFISHING proves Godot + GodotSteam ships a hit friendslop game at **196 MB**.

## 2. Engine + 3D model approach (low compute)

**Godot 4.5, Compatibility renderer** (OpenGL3). Runs on integrated GPUs and old laptops — the friend with the potato PC must be able to play.

The look (`src/art/`):
- **One toon shader** (`toon.gdshader`): 2-band cel + rim light, colour as a uniform. **No textures at all.**
- **Inverted-hull outline** (`outline.gdshader`) as `next_pass`. Grows from the mesh centre (not normals) so hard-edged boxes don't crack.
- **Characters = primitives**: capsule body, sphere head, googly eyes, box feet, hat. ~600 tris each. Big heads + googly eyes = instant comedy.
- Materials & meshes are cached (`Art.mat()`, `Art.box()`…), so 100 identical props share GPU resources.

Pipeline for real assets later (when primitives aren't enough):
1. Blender, **< 1.5k tris per character, < 300 per prop**, no subdivision.
2. **One shared 256×256 "palette" texture** (a grid of flat colour squares); UV each face onto a colour square. One material for the whole game → near-zero draw-call overhead, recolour by swapping the palette (same trick as Synty / many friendslop games).
3. Export `.glb`; in Godot, override material with the toon shader + outline.
4. Animation: **skeletal only for the body, everything else procedural** (waddle, hand bob, squash) like `Avatar._animate()`. 3–4 bones is plenty (root, body, head, two hands).
5. Use `MultiMeshInstance3D` for grass/trees/crowds if counts go > 200.
6. Physics: static primitives only; never trimesh colliders on characters.

Budget target: 60 fps at 1080p on Intel Iris Xe with 12 players.

## 3. Structure

- **Lobby (Slop Lounge)**: wardrobe (paint / hat / body swap), mystery-slop bar, VIP throne (leader only), perk shop, casino (slots, crash, lil' wheel, duck race), bot kennel, toilet teleporter, trampoline, hall of fame. **Big Wheel + START button** in the centre: spin picks the match **modifier**, then the minigame launches.
- **Rank swagger**: leader = 1.35× size, faster, crown, can **smite** (G); loser = 0.62× size, slow, "feeble". Ranking is by total score.
- **Perks/curses**: bought or gambled in the lobby, **stack**, last **one match**. Curses can be sent to friends (anonymous… mostly).
- **Modifiers** (wheel): Low Gravity, Big Head Mode, Zoomies, Slip 'n Slide, Tiny Giant, MEGA Giant, Glass Eyes, Nothing Weird. Modifier × perks × role = no two matches alike.

## 4. Minigame brainstorm (1-vs-many / few-vs-many)

Each has a **betrayal hook**: a reason for the majority to screw each other.

1. **GIANT HUNT** *(implemented)* — 1 slow giant vs fast littles. Littles blind his eyes with spears, string tripwires, and tie him up while he's down. Giant: stomp, 8 s slap, 20 s ice pee, 30 s fire fart.
   *Betrayal*: only the little who places the tripping rope + most ties gets the "Rope Lord" bonus. Future: giant can **offer a deal** — one little gets spared and paid if they cut ropes.
2. **POCKET GOD** — leader from the lobby becomes a god with a top-down camera and a power wheel (lightning, flood, meteor, giant hand, "make them dance"). The masses win by building a **rocket out of scrap** to escape the island, or by **praying** (holding E at shrines) to fill a mutiny meter that dethrones the god.
   *Betrayal*: the god can **anoint a prophet** — that player gets immunity + double points if the god wins.
3. **FAKE SHEEP** (Just Act Natural style) — everyone is a sheep in a herd of 60 AI sheep. One wolf player (or two) must eat the right sheep; sheep win by surviving, wolf wins by eating players. Sheep can **bleat** to emote and give themselves away.
   *Betrayal*: a sheep who points out another player to the wolf gets 2× points if that player is eaten.
4. **HOT POTATO HEIST** — a crew robs a bank; one secret traitor (Deceit style) sabotages. Loot is carried physically (ragdolly bags). Escape van leaves at a timer — **anyone can drive off early with whatever's in the van**.
5. **THE FLOOR IS LAVA SOUP** — a chef (1 player) slowly raises boiling soup in a giant pot; tiny vegetables (everyone else) climb utensils. Chef can stir (whirlpool), add salt (blinds), taste (scoop players). Last veggie standing wins.
6. **BIG BABY** — one player is a giant toddler; everyone else is a toy that must get back into the toy box before Mom comes home. Baby can throw, chew, and "put in mouth" (jail). Toys free each other but jailing someone else first gives a head start.
7. **DUCK COURT** — a judge (lobby leader) watches a trial: one defendant must convince everyone with proximity voice they weren't the one who stole the bread. Jury votes; correct votes earn coins, the actual thief earns big if acquitted.
8. **TOWER OF BABBLE** — everyone co-builds a physics tower to reach a prize; one secret saboteur is told to make it collapse at the exact moment someone touches the top.
9. **CURSED CASINO NIGHT** — whole minigame inside the lobby casino: highest coins after 8 min wins, but you can steal chips by slapping, and the house (a player) controls the odds.
10. **GOOSE ON THE LOOSE** — one honking goose vs. villagers trying to finish chores. Goose steals items and hides them; villagers win on chores, goose wins by stealing the golden bell.

## 5. Making it absurd (rules of thumb)

- **Bodily functions as weapons** (pee ice, fire fart) — always telegraphed with sound/text ("*rumble*").
- **Physics betrayals**: everything that can knock you over can also knock over your friends.
- **Exaggerated scale differences** (giant 4–5.5×, loser 0.6×); scale = status.
- **Announcer toasts that name names** ("Gorp cursed Mildred with Wet Noodle").
- **Ragdoll / fall-over on trip**; giant face-planting is the money shot.
- **Lobby props with no purpose** (toilet teleport, throne that does nothing, mystery slop).
- Bad perks that are funny rather than punishing (glow stick, tiny legs).

## 6. Balancing GIANT HUNT

Current numbers (`src/minigames/giant/giant_rules.gd`, `giant_game.gd`):

| Knob | Value | Why |
|---|---|---|
| Giant size / speed | 4× / 4.6 m/s (sprint ×1.15) | slower than littles but huge reach |
| Little size / speed | 0.6× / 7 m/s (sprint ×1.55) | can always outrun if not cornered |
| Stomp | 1.4 s cd, 0.3 s windup, r 2.6, **jump to dodge** | skill-based basic attack |
| Slap | 8 s cd, 0.6 s windup with red telegraph, r 4.2 + knockback ring | AoE punish for groups |
| Ice pee | 20 s cd, r 5 patch, 25 s | area denial; also slippery for the giant |
| Fire fart | 30 s cd, 0.45 s rumble, 10 m 110° cone **behind** | punishes rope-planters behind him |
| Eyes | 3 hits each (Glass Eyes: 1) | each blinded eye blacks out half his screen |
| Trip | 3.5 s + 1.25 s per blind eye, 2.5 s immunity after | blindness feeds the win condition |
| Ties | 13 / team size per tie, 1 s cd, +0.15 s trip each (max +1.5 s) | team-size-fair; needs ~3 trips |
| Bind decay | 1 /s while standing | must chain trips, not trickle |
| Clock | 150 + 45 s × littles (4–10 min) | giant wins at time-out |
| Rewards | survivors +2 / dead littles +1 / giant win +3 score | |

Principles:
- **Bot-vs-bot sims** (`tests/match_sim.gd`) are the first gate: target giant win-rate ~45–55 % with bots, then playtest with humans (humans dodge ropes better as giant and coordinate better as littles; both shift).
- Scale everything per-little where a team acts (ties, clock), never per-player globally.
- Keep every kill **telegraphed**: warning circle, rumble text, windups. Deaths should feel funny, not cheap.
- Perks stack multiplicatively (1.15^n) so stacking is strong but not infinite; curses mirror perks.
- Catch-up: losers are tiny/slow in the **lobby only** (status, not gameplay). The giant pick rotates by fewest-times-giant so nobody hogs it.

## 7. Roadmap

1. GodotSteam: Steam lobbies/invites + P2P transport (replace ENet, keep the same RPCs).
2. Proximity voice chat.
3. Audio pass (fart, splat, wheel clicks) — biggest juice-per-hour.
4. POCKET GOD minigame (uses the lobby leader as god).
5. Glb character pipeline + palette texture; ragdoll trip.
6. Betrayal systems: giant deals, Rope Lord bonus, anonymous curse reveal at match end.
