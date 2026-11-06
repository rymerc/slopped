class_name PerkDB
extends RefCounted
## Perk / curse definitions and match modifiers. Perks stack and last one match.

const PERKS := {
	"sprint_boots": {"name": "Sprint Boots", "good": true, "desc": "+15% move speed"},
	"extra_quiver": {"name": "Extra Quiver", "good": true, "desc": "Little: +2 spears. Giant: -15% cooldowns"},
	"thick_skull": {"name": "Thick Skull", "good": true, "desc": "Survive one fatal hit"},
	"spring_legs": {"name": "Spring Legs", "good": true, "desc": "+35% jump height"},
	"knot_master": {"name": "Knot Master", "good": true, "desc": "+50% rope tying strength"},
	"double_jump": {"name": "Double Jump", "good": true, "desc": "One extra jump in the air"},
	"feather": {"name": "Featherweight", "good": true, "desc": "-30% gravity, floaty falls"},
	"big_bones": {"name": "Big Bones", "good": true, "desc": "Hits knock you half as far"},
	"pickpocket": {"name": "Sticky Fingers", "good": true, "desc": "Shoving someone steals 5 coins"},
	"coin_magnet": {"name": "Offshore Account", "good": true, "desc": "+25% coins from this match"},
	"lead_boots": {"name": "Lead Boots", "good": false, "desc": "-15% move speed"},
	"butterfingers": {"name": "Butterfingers", "good": false, "desc": "Weak throws. Giant: +20% cooldowns"},
	"glow_stick": {"name": "Glow Stick", "good": false, "desc": "You glow. Everyone sees you."},
	"tiny_legs": {"name": "Tiny Legs", "good": false, "desc": "-40% jump height"},
	"wet_noodle": {"name": "Wet Noodle", "good": false, "desc": "-35% rope tying strength"},
	"hiccups": {"name": "Hiccups", "good": false, "desc": "You hop at random all match"},
	"loud_shoes": {"name": "Clown Shoes", "good": false, "desc": "Every step honks"},
	"glass_bones": {"name": "Glass Bones", "good": false, "desc": "Hits knock you twice as far"},
	"tax_debt": {"name": "Tax Debt", "good": false, "desc": "-50% coins from this match"},
}

## Big-wheel segments. Each spin picks one; it changes the whole next match.
const MODIFIERS := [
	{"id": "none", "name": "Nothing Weird", "color": Color("#7bdff2")},
	{"id": "low_gravity", "name": "Low Gravity", "color": Color("#b388ff")},
	{"id": "big_heads", "name": "Big Head Mode", "color": Color("#ffd23f")},
	{"id": "zoomies", "name": "Zoomies", "color": Color("#ff5fa2")},
	{"id": "slippery", "name": "Slip 'n Slide", "color": Color("#9ff0ff")},
	{"id": "tiny_giant", "name": "Tiny Giant", "color": Color("#8ce36b")},
	{"id": "mega_giant", "name": "MEGA Giant", "color": Color("#ff7a3d")},
	{"id": "glass_eyes", "name": "Glass Eyes", "color": Color("#f2f2f2")},
]

const SHOP_PRICE := 40
const CURSE_PRICE := 60


static func info(id: String) -> Dictionary:
	return PERKS.get(id, {"name": id, "good": true, "desc": ""})


static func random_good() -> String:
	return _ids(true).pick_random()


static func random_bad() -> String:
	return _ids(false).pick_random()


static func _ids(good: bool) -> Array:
	var out: Array = []
	for k: String in PERKS:
		if PERKS[k].good == good:
			out.append(k)
	return out


static func good_ids() -> Array:
	return _ids(true)


static func count(perks: Array, id: String) -> int:
	return perks.count(id)


static func speed_mult(perks: Array) -> float:
	return pow(1.15, count(perks, "sprint_boots")) * pow(0.85, count(perks, "lead_boots"))


static func jump_mult(perks: Array) -> float:
	return pow(1.35, count(perks, "spring_legs")) * pow(0.6, count(perks, "tiny_legs"))


static func tie_mult(perks: Array) -> float:
	return pow(1.5, count(perks, "knot_master")) * pow(0.65, count(perks, "wet_noodle"))


static func cooldown_mult(perks: Array) -> float:
	return pow(0.85, count(perks, "extra_quiver")) * pow(1.2, count(perks, "butterfingers"))


static func throw_mult(perks: Array) -> float:
	return pow(0.7, count(perks, "butterfingers"))


static func extra_spears(perks: Array) -> int:
	return 2 * count(perks, "extra_quiver")


## Perks that work the same in every world.
static func apply(av: Avatar, perks: Array) -> void:
	av.air_jumps = count(perks, "double_jump")
	av.gravity_mult *= pow(0.7, count(perks, "feather"))
	av.knock_resist = pow(2.0, count(perks, "big_bones")) * pow(0.5, count(perks, "glass_bones"))
	av.hiccup_perk = perks.has("hiccups")
	av.squeak_perk = perks.has("loud_shoes")


static func coin_mult(perks: Array) -> float:
	return pow(1.25, count(perks, "coin_magnet")) * pow(0.5, count(perks, "tax_debt"))


static func modifier(id: String) -> Dictionary:
	for m: Dictionary in MODIFIERS:
		if m.id == id:
			return m
	return MODIFIERS[0]


static func summary(perks: Array) -> String:
	if perks.is_empty():
		return "none"
	var names: PackedStringArray = []
	for p: String in perks:
		names.append(info(p).name)
	return ", ".join(names)
