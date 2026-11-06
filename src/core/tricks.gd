class_name Tricks
extends RefCounted
## Catalogue for DIRTY DEEDS DEPT., the shop in the casino back room. Five tiers,
## each worse than the last. Most items go into your bag and you fire them from
## any world with the trick key, so a stuck W key can land mid-match.
##   hex     timed effect on one victim (see Avatar.hexed)
##   all     the same hex on everyone but you
##   action  something TrickSystem does once
##   self    protection, applied the moment you buy it
##   perk    lasts one match, stacks

const TIERS := ["PETTY", "MEAN", "CRUEL", "UNFORGIVABLE", "WAR CRIMES"]
const TIER_COLORS := [Color("#7ccf4e"), Color("#ffd23f"), Color("#ff8a3d"), Color("#ee4b4b"), Color("#b388ff")]

const ITEMS := {
	# --- tier 1: petty --------------------------------------------------------
	"stuck_w": {"tier": 0, "price": 20, "kind": "hex", "hex": "no_w", "secs": 15.0, "name": "Stuck W Key", "desc": "They cannot walk forward for 15s"},
	"cement": {"tier": 0, "price": 20, "kind": "hex", "hex": "no_jump", "secs": 15.0, "name": "Cement Shoes", "desc": "No jumping for 15s"},
	"wet_socks": {"tier": 0, "price": 15, "kind": "hex", "hex": "no_sprint", "secs": 20.0, "name": "Wet Socks", "desc": "No sprinting for 20s"},
	"squeaky": {"tier": 0, "price": 15, "kind": "hex", "hex": "squeak", "secs": 30.0, "name": "Squeaky Shoes", "desc": "Every step honks. Everyone hears it. 30s"},
	"balloon": {"tier": 0, "price": 25, "kind": "hex", "hex": "balloon", "secs": 20.0, "name": "Balloon Head", "desc": "Enormous head for 20s"},
	"lawyer": {"tier": 0, "price": 35, "kind": "self", "field": "ward", "name": "Retained Lawyer", "desc": "Blocks the next trick used on you"},
	# --- tier 2: mean ----------------------------------------------------------
	"mirror_legs": {"tier": 1, "price": 45, "kind": "hex", "hex": "swap_ad", "secs": 15.0, "name": "Mirror Legs", "desc": "A and D swap for 15s"},
	"upside": {"tier": 1, "price": 45, "kind": "hex", "hex": "invert", "secs": 15.0, "name": "Wrong Way Up", "desc": "Inverted look for 15s"},
	"goggles": {"tier": 1, "price": 40, "kind": "hex", "hex": "goggles", "secs": 15.0, "name": "Beer Goggles", "desc": "The world sways for 15s"},
	"butter": {"tier": 1, "price": 50, "kind": "hex", "hex": "butter", "secs": 15.0, "name": "Buttered Soles", "desc": "No grip for 15s"},
	"espresso": {"tier": 1, "price": 45, "kind": "hex", "hex": "espresso", "secs": 12.0, "name": "Nine Espressos", "desc": "Mouse sensitivity x4 for 12s"},
	"hiccups": {"tier": 1, "price": 50, "kind": "hex", "hex": "hiccup", "secs": 20.0, "name": "Violent Hiccups", "desc": "Random hops for 20s"},
	# --- tier 3: cruel ---------------------------------------------------------
	"backwards": {"tier": 2, "price": 90, "kind": "hex", "hex": "reverse", "secs": 12.0, "name": "Backwards Man", "desc": "All movement reversed for 12s"},
	"pie": {"tier": 2, "price": 90, "kind": "hex", "hex": "pie", "secs": 7.0, "name": "Pie in the Face", "desc": "Blinded by custard for 7s"},
	"shrink": {"tier": 2, "price": 100, "kind": "hex", "hex": "tiny", "secs": 15.0, "name": "Shrink Ray", "desc": "Tiny and weak for 15s"},
	"freeze": {"tier": 2, "price": 110, "kind": "hex", "hex": "freeze", "secs": 4.0, "name": "Ice Block", "desc": "Frozen solid for 4s"},
	"dance": {"tier": 2, "price": 95, "kind": "hex", "hex": "dance", "secs": 5.0, "name": "Compulsory Dance", "desc": "They must spin for 5s"},
	"uno": {"tier": 2, "price": 120, "kind": "self", "field": "mirror", "name": "Uno Reverse", "desc": "The next trick used on you hits the sender"},
	# --- tier 4: unforgivable ----------------------------------------------------
	"steering": {"tier": 3, "price": 160, "kind": "hex", "hex": "drunk_drive", "secs": 10.0, "name": "Possessed Legs", "desc": "Their legs pick a new direction every second"},
	"bomb": {"tier": 3, "price": 180, "kind": "action", "name": "Hot Potato Bomb", "desc": "8s fuse. Passes on touch. Then boom"},
	"swap": {"tier": 3, "price": 150, "kind": "action", "name": "Body Double", "desc": "You and the target swap places"},
	"audit": {"tier": 3, "price": 170, "kind": "action", "name": "IRS Audit", "desc": "Take 30% of their coins"},
	"loaded_dice": {"tier": 3, "price": 150, "kind": "perk", "perk": "coin_magnet", "name": "Offshore Account", "desc": "+25% coins from your next match"},
	# --- tier 5: war crimes -----------------------------------------------------
	"orbital": {"tier": 4, "price": 300, "kind": "action", "name": "Orbital Duck Strike", "desc": "A very large duck arrives from space"},
	"misfortune": {"tier": 4, "price": 320, "kind": "action", "name": "Wheel of Misfortune", "desc": "Five random hexes, one every 5s"},
	"global_w": {"tier": 4, "price": 350, "kind": "all", "hex": "no_w", "secs": 10.0, "name": "Worldwide W Outage", "desc": "Everyone else loses W for 10s"},
	"shuffle": {"tier": 4, "price": 280, "kind": "action", "name": "Musical Chairs", "desc": "Everyone swaps places at random", "untargeted": true},
	"bankrupt": {"tier": 4, "price": 500, "kind": "action", "name": "Hostile Takeover", "desc": "All their coins go. Half come to you"},
}

## Hexes the Wheel of Misfortune picks from.
const RANDOM_HEXES := ["no_w", "no_jump", "swap_ad", "invert", "butter", "reverse", "goggles", "hiccup", "dance", "balloon"]
const HEX_NAMES := {
	"no_w": "STUCK W KEY", "no_jump": "CEMENT SHOES", "no_sprint": "WET SOCKS", "squeak": "SQUEAKY SHOES",
	"balloon": "BALLOON HEAD", "swap_ad": "MIRROR LEGS", "invert": "WRONG WAY UP", "goggles": "BEER GOGGLES",
	"butter": "BUTTERED SOLES", "espresso": "NINE ESPRESSOS", "hiccup": "HICCUPS", "reverse": "BACKWARDS MAN",
	"pie": "PIE IN THE FACE", "tiny": "SHRINK RAY", "freeze": "ICE BLOCK", "dance": "COMPULSORY DANCE",
	"drunk_drive": "POSSESSED LEGS", "salt": "SALT IN THE EYES",
}


static func tier_items(tier: int) -> Array:
	var out: Array = []
	for id: String in ITEMS:
		if int(ITEMS[id].tier) == tier:
			out.append(id)
	return out


static func needs_target(id: String) -> bool:
	var it: Dictionary = ITEMS[id]
	return it.kind != "all" and not it.get("untargeted", false)
