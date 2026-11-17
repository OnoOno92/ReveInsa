class_name GuRoll
extends RefCounted
## Every Gu is unique: four potentials (0-31), a nature, and a rare shiny variant.
## Idea carried over from Martial Improved (gu_potential.js, gu_natures.js, gu_shiny.js).
##
## Instance fields added by roll(): "pot": {power, speed, eff, dur}, "nature": String, "shiny": bool
##   power -> +damage, and bigger stats / auras / heals / summons
##   speed -> shorter cooldowns
##   eff   -> cheaper essence costs
##   dur   -> the Gu can go longer between feedings

const KEYS := ["power", "speed", "eff", "dur"]
const KEY_NAMES := {"power": "Power", "speed": "Speed", "eff": "Efficiency", "dur": "Durability"}
const SHINY_CHANCE := 1.0 / 512.0

## [up, down]: +10% to the first trait, -10% to the second ("" = neutral)
const NATURES := {
	"steady": ["", ""], "calm": ["", ""],
	"fierce": ["power", "eff"], "wild": ["power", "speed"], "gluttonous": ["power", "dur"],
	"swift": ["speed", "power"], "keen": ["speed", "eff"], "sly": ["speed", "dur"],
	"frugal": ["eff", "speed"], "patient": ["eff", "power"],
	"hardy": ["dur", "speed"], "docile": ["dur", "power"],
}

## Potential range and shiny odds per source.
const SOURCES := {
	"starter": {"min": 8, "max": 20, "shiny": 0.0},
	"shop": {"min": 0, "max": 20, "shiny": 0.0},
	"wild": {"min": 0, "max": 31, "shiny": SHINY_CHANCE},
	"refine": {"min": 5, "max": 31, "shiny": SHINY_CHANCE},
	"clan": {"min": 10, "max": 26, "shiny": 0.0},
	"inherit": {"min": 16, "max": 31, "shiny": 1.0 / 64.0},
}


static func roll(rng: RandomNumberGenerator, source := "wild", force_shiny := false) -> Dictionary:
	var src: Dictionary = SOURCES.get(source, SOURCES["wild"])
	var pot := {}
	for k in KEYS:
		pot[k] = rng.randi_range(src["min"], src["max"])
	var names := NATURES.keys()
	var shiny: bool = force_shiny or rng.randf() < src["shiny"]
	var r := {"pot": pot, "nature": names[rng.randi() % names.size()], "shiny": shiny}
	if shiny:
		_shine(r)
	return r


## Shiny Gu: every potential +8 (max 31).
static func _shine(r: Dictionary) -> void:
	for k in KEYS:
		r["pot"][k] = mini(31, r["pot"][k] + 8)


## Old saves had no rolls: give them an average, neutral profile.
static func ensure(inst: Dictionary) -> void:
	if not inst.has("pot"):
		inst["pot"] = {"power": 12, "speed": 12, "eff": 12, "dur": 12}
	for k in KEYS:
		inst["pot"][k] = int(inst["pot"].get(k, 12))
	if not inst.has("nature") or not NATURES.has(inst["nature"]):
		inst["nature"] = "steady"
	inst["shiny"] = bool(inst.get("shiny", false))


## Refining a Gu into its advanced form keeps its soul: nature, shiny, potentials +3.
static func inherit(from: Dictionary) -> Dictionary:
	var r := {"pot": {}, "nature": from.get("nature", "steady"), "shiny": from.get("shiny", false)}
	for k in KEYS:
		r["pot"][k] = mini(31, int(from.get("pot", {}).get(k, 12)) + 3)
	return r


static func _nature_mult(inst: Dictionary, key: String) -> float:
	var n: Array = NATURES.get(inst.get("nature", "steady"), ["", ""])
	if n[0] == key:
		return 1.1
	if n[1] == key:
		return 0.9
	return 1.0


## A Gu without rolls (e.g. in tests) is neutral: potential 0 = multiplier 1.0.
static func _pot(inst: Dictionary, key: String) -> float:
	return float(inst.get("pot", {}).get(key, 0))


## Multiplier on damage, stats, auras, heals and summons.
static func power_mult(inst: Dictionary) -> float:
	return (1.0 + _pot(inst, "power") / 100.0) * _nature_mult(inst, "power")

## Multiplier on cooldowns (lower is faster).
static func cooldown_mult(inst: Dictionary) -> float:
	return (1.0 - _pot(inst, "speed") / 200.0) / _nature_mult(inst, "speed")

## Multiplier on essence cost (lower is cheaper).
static func cost_mult(inst: Dictionary) -> float:
	return (1.0 - _pot(inst, "eff") / 125.0) / _nature_mult(inst, "eff")

## Extra days the Gu can go between feedings.
static func feed_bonus(inst: Dictionary) -> int:
	var b := 1 if _pot(inst, "dur") >= 20.0 else 0
	var n := _nature_mult(inst, "dur")
	if n > 1.0:
		b += 1
	elif n < 1.0:
		b -= 1
	return b

## Effective days between feedings for this Gu.
static func feed_every(inst: Dictionary) -> int:
	return maxi(1, int(GuDB.GU[inst["def"]]["feed_every"]) + feed_bonus(inst))


static func total(inst: Dictionary) -> int:
	var t := 0
	for k in KEYS:
		t += int(_pot(inst, k))
	return t


static func grade(inst: Dictionary) -> String:
	var t := total(inst)
	if t >= 110: return "S"
	if t >= 90: return "A"
	if t >= 70: return "B"
	if t >= 50: return "C"
	if t >= 30: return "D"
	return "F"


const GRADE_COLORS := {"S": "#ff9de2", "A": "#ffd76b", "B": "#9ecbff", "C": "#7cfc8a", "D": "#c8c0b0", "F": "#8a8378"}

static func grade_color(inst: Dictionary) -> String:
	return GRADE_COLORS[grade(inst)]


static func sell_value(inst: Dictionary) -> int:
	var base: float = GuDB.GU[inst["def"]]["price"] * 0.4 * (0.6 + total(inst) / 124.0 * 0.8)
	return floori(base * (3.0 if inst.get("shiny", false) else 1.0))


static func nature_label(inst: Dictionary) -> String:
	var nat: String = inst.get("nature", "steady")
	var n: Array = NATURES.get(nat, ["", ""])
	if n[0] == "":
		return nat.capitalize()
	return "%s (+%s, -%s)" % [nat.capitalize(), KEY_NAMES[n[0]], KEY_NAMES[n[1]]]


## One-line summary like "Grade A - Fierce - P23 S12 E30 D5"
static func summary(inst: Dictionary) -> String:
	var p: Dictionary = inst.get("pot", {})
	return "%sGrade %s - %s - P%d S%d E%d D%d" % ["SHINY " if inst.get("shiny", false) else "", grade(inst),
		inst.get("nature", "steady").capitalize(), p.get("power", 0), p.get("speed", 0), p.get("eff", 0), p.get("dur", 0)]
