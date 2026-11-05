class_name Progress
extends RefCounted
## Local player progression: XP -> levels -> costume unlocks, plus lifetime
## "playground challenges" (first completion pays big, repeats pay a little).
## Saved per machine in user://progress.cfg. The host awards XP through
## Net.award(); the level rides along in the profile so the wardrobe can
## validate unlocks.

const SAVE := "user://progress.cfg"
const CHALLENGES := {
	"gauntlet": {"name": "Beat the Gauntlet", "xp": 120},
	"summit": {"name": "Plant a flag on Slide Hill", "xp": 60},
	"vault": {"name": "Crack the Vault with a friend", "xp": 100},
	"ledge": {"name": "Reach Friend Ledge (needs a boost)", "xp": 80},
	"cave": {"name": "Find the cave treasure", "xp": 60},
	"yeet": {"name": "Yeet a friend off something high", "xp": 50},
	"boom": {"name": "Blow up a TNT barrel", "xp": 40},
	"slide": {"name": "Belly-slide down Slide Hill", "xp": 40},
	"giant_win": {"name": "Win a round of Giant Hunt", "xp": 150},
	"dive": {"name": "High-dive off the Slop Cove tower", "xp": 50},
}

static var xp := 0
static var level := 1
static var done: Dictionary = {}
static var listeners: Array[Callable] = []
static var _loaded := false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(SAVE) == OK:
		xp = int(cfg.get_value("p", "xp", 0))
		level = maxi(1, int(cfg.get_value("p", "level", 1)))
		done = cfg.get_value("p", "done", {})


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("p", "xp", xp)
	cfg.set_value("p", "level", level)
	cfg.set_value("p", "done", done)
	cfg.save(SAVE)


static func need(lvl: int) -> int:
	return 100 + 60 * (lvl - 1)


## Unlocks granted on reaching `lvl` (display names).
static func unlocks_at(lvl: int) -> Array[String]:
	var out: Array[String] = []
	for k: String in Chars.UNLOCK:
		if int(Chars.UNLOCK[k]) == lvl:
			out.append("%s costume" % Chars.LABELS[k])
	return out


static func add(amount: int, reason: String) -> void:
	ensure_loaded()
	if amount <= 0:
		return
	xp += amount
	var unlocked: Array[String] = []
	var leveled := false
	while xp >= need(level):
		xp -= need(level)
		level += 1
		leveled = true
		unlocked.append_array(unlocks_at(level))
	save()
	for cb: Callable in listeners:
		if cb.is_valid():
			cb.call(amount, reason, leveled, unlocked)


## Returns true the first time ever.
static func challenge(id: String) -> bool:
	ensure_loaded()
	var c: Dictionary = CHALLENGES.get(id, {"name": id, "xp": 20})
	var first := not done.has(id)
	if first:
		done[id] = true
		add(int(c.xp), "NEW: %s" % c.name)
	else:
		add(maxi(5, int(c.xp) / 6), str(c.name))
	return first
