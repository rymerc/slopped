"""Curated CC0 shortlist. id -> (pack, source file stem). See docs/ASSET_CREDITS.md."""
PACKS = {
    "pirate":      "pirate/x/Models/GLB format",
    "survival":    "survival/x/Models/GLB format",
    "coaster":     "coaster/x/Models/GLB format",
    "watercraft":  "watercraft/x/Models/GLB format",
    "fantasytown": "fantasytown/x/Models/GLB format",
    "nature":      "nature/x/Models/GLTF format",
    "retrourban":  "retrourban/x/Models/GLB format",
    "food":        "food/x/Models/GLB format",
    "kk_furniture": "kk-Furniture-Bits",
    "kk_restaurant": "kk-Restaurant-Bits",
    "kk_city":     "kk-City-Builder-Bits",
}
_P = {
 "pirate": "barrel boat-row-large boat-row-small bottle bottle-large cannon cannon-ball chest crate crate-bottles flag flag-pennant flag-high flag-high-pennant grass grass-patch grass-plant mast mast-ropes palm-bend palm-detailed-bend palm-detailed-straight palm-straight patch-sand-foliage platform platform-planks rocks-a rocks-b rocks-c rocks-sand-a rocks-sand-b rocks-sand-c ship-small ship-wreck ship-medium ship-pirate-small structure structure-fence structure-platform structure-platform-dock structure-platform-dock-small structure-roof tool-paddle tool-shovel tower-watch",
 "survival": "barrel-open bedroll bedroll-frame box box-large box-open bucket campfire-pit campfire-stand fence fence-doorway fence-fortified fish fish-large rock-a rock-b rock-c rock-flat rock-flat-grass rock-sand-a rock-sand-b rock-sand-c signpost signpost-single structure-canvas tent tent-canvas tree tree-autumn tree-autumn-tall tree-tall tree-log tree-log-small tree-trunk workbench workbench-anvil workbench-grind resource-planks resource-wood resource-stone tool-axe tool-hammer tool-pickaxe",
 "coaster": "bench flowers park-entrance ride-entrance ride-exit stall-drinks stall-food stall-information stall-toilets station station-fence station-gate support-large support-large-bottom support-small support-small-bottom trash tree tree-large train-log-flume coaster-wood-straight coaster-wood-curve coaster-wood-looping coaster-wood-corner-large coaster-wood-corner-small coaster-wood-straight-hill-complete coaster-wood-straight-bump-up coaster-wood-straight-bump-down coaster-wood-track coaster-train",
 "watercraft": "boat-fishing-small boat-house-a boat-house-b boat-house-c boat-house-d boat-row-large boat-sail-a boat-sail-b boat-speed-a boat-speed-b boat-speed-c boat-tug-a buoy buoy-flag cargo-container-a cargo-container-b cargo-pile-a ramp ship-small",
 "fantasytown": "banner-green banner-red cart cart-high chimney fence fence-broken fence-gate fountain-round-detail hedge hedge-large lantern pillar-wood planks poles stall stall-bench stall-green stall-red stall-stool tree tree-high tree-crooked rock-large rock-small rock-wide",
 "nature": "cactus_short cactus_tall flower_purpleA flower_redA flower_yellowA grass_large grass_leafs log log_large log_stack log_stackLarge mushroom_red mushroom_redGroup mushroom_tanGroup plant_bush plant_bushDetailed plant_bushLarge plant_bushSmall plant_flatTall pot_large pot_small rock_largeA rock_largeD rock_largeE rock_tallA rock_tallD rock_tallG rock_smallA rock_smallD sign statue_head statue_obelisk statue_column stump_round stump_old tent_detailedOpen tree_palm tree_palmBend tree_palmDetailedShort tree_palmDetailedTall tree_palmShort tree_palmTall tree_oak tree_fat tree_default tree_detailed tree_pineRoundA tree_pineTallA_detailed tree_pineTallC_detailed tree_plateau canoe canoe_paddle crop_pumpkin",
 "retrourban": "detail-barrier-strong-type-a detail-barrier-type-a detail-beam detail-bench detail-cables-type-a detail-dumpster-closed detail-dumpster-open pallet pallet-small planks scaffolding-floor scaffolding-poles scaffolding-structure truck-flat truck-green truck-green-cargo",
 "food": "mug glass glass-wine wine-red wine-white soda-can pizza pizza-box burger donut-sprinkles whole-ham plate plate-dinner barrel",
}
KIT = {}
for pack, names in _P.items():
    for n in names.split():
        KIT[f"{pack}_{n.replace('-', '_')}"] = (pack, n)

# KayKit assets are matched by file stem anywhere in their repo (None = all).
_K = {
 "kk_furniture": None,
 "kk_restaurant": "chair_A chair_B chair_stool crate jar_A_large jar_B_medium jar_C_small ketchup crate_potatoes crate_tomatoes food_burger food_dinner",
 "kk_city": "bench dumpster firehydrant streetlight trash_A trash_B watertower box_A box_B bush",
}
