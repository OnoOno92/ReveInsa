class_name GuDB
extends RefCounted
## Gu definitions. Each Gu occupies a shape inside the aperture grid.
## Placement + adjacency drives synergies and killer moves (see game/aperture.gd).
## NOTE: const dictionaries are read-only — duplicate() before modifying.

const PATH_COLORS := {
	"moon": "#9ecbff", "strength": "#c0743a", "earth": "#b39b6b", "water": "#3fa7d6",
	"fire": "#ef5b3c", "wood": "#5cb85c", "wind": "#8fe3c8", "lightning": "#c9a6ff",
	"information": "#f2d36b", "enslavement": "#d16ba5",
}

const PATH_NAMES := {
	"moon": "Moon Path", "strength": "Strength Path", "earth": "Earth Path", "water": "Water Path",
	"fire": "Fire Path", "wood": "Wood Path", "wind": "Wind Path", "lightning": "Lightning Path",
	"information": "Information Path", "enslavement": "Enslavement Path",
}

# attack.kind: projectile | fan | nova | chain
const GU := {
	# ---------------- Rank 1 ----------------
	"moonlight": {
		"name": "Moonlight Gu", "path": "moon", "rank": 1, "role": "attack",
		"shape": [Vector2i(0, 0)], "food": "moon_orchid", "feed_every": 3, "price": 25,
		"desc": "Fires a pale crescent of moonlight at the nearest foe. The most common attack Gu in the Southern Border.",
		"attack": {"kind": "projectile", "damage": 10.0, "cooldown": 0.9, "range": 240.0, "cost": 1.5, "speed": 420.0, "size": 7.0, "color": "#bfe0ff"},
	},
	"wind_blade": {
		"name": "Wind Blade Gu", "path": "wind", "rank": 1, "role": "attack",
		"shape": [Vector2i(0, 0), Vector2i(0, 1)], "food": "herb", "feed_every": 2, "price": 40,
		"desc": "Condenses a thin blade of wind that pierces through two foes.",
		"attack": {"kind": "projectile", "damage": 8.0, "cooldown": 1.2, "range": 290.0, "cost": 1.8, "speed": 560.0, "pierce": 2, "size": 5.0, "color": "#a8f5dc"},
	},
	"liquor_worm": {
		"name": "Liquor Worm", "path": "wood", "rank": 1, "role": "support",
		"shape": [Vector2i(0, 0), Vector2i(1, 0)], "food": "wine", "feed_every": 2, "price": 45,
		"desc": "Refines primeval essence. Adjacent attack Gu deal +30% damage and cost 20% less essence.",
		"aura": {"damage_mult": 0.3, "cost_mult": -0.2},
	},
	"spider_silk": {
		"name": "Spider Silk Gu", "path": "enslavement", "rank": 1, "role": "support",
		"shape": [Vector2i(0, 0)], "food": "meat", "feed_every": 2, "price": 35,
		"desc": "Coats adjacent attacks in sticky silk: hits slow enemies by 35%.",
		"aura": {"slow": 0.35},
	},
	"stone_skin": {
		"name": "Stone Skin Gu", "path": "earth", "rank": 1, "role": "defense",
		"shape": [Vector2i(0, 0), Vector2i(0, 1)], "food": "stone", "feed_every": 3, "price": 30,
		"desc": "Hardens the skin like rock. +4 armor.",
		"stats": {"armor": 4.0},
	},
	"black_boar": {
		"name": "Black Boar Gu", "path": "strength", "rank": 1, "role": "passive",
		"shape": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)], "food": "meat", "feed_every": 2, "price": 45,
		"desc": "Grants the strength of a black boar. +30 max HP, +10% damage.",
		"stats": {"max_hp": 30.0, "damage_mult": 0.1},
	},
	"vitality_leaf": {
		"name": "Vitality Leaf Gu", "path": "wood", "rank": 1, "role": "heal",
		"shape": [Vector2i(0, 0)], "food": "herb", "feed_every": 2, "price": 30,
		"desc": "Restores 18 HP when you are wounded (6s cooldown).",
		"heal": {"amount": 18.0, "cooldown": 6.0, "cost": 4.0},
	},
	"water_shield": {
		"name": "Water Shield Gu", "path": "water", "rank": 1, "role": "defense",
		"shape": [Vector2i(0, 0), Vector2i(1, 0)], "food": "herb", "feed_every": 3, "price": 50,
		"desc": "A film of water absorbs up to 25 damage and slowly reforms.",
		"stats": {"shield": 25.0},
	},
	"earth_ear": {
		"name": "Earth Communication Ear Grass", "path": "information", "rank": 1, "role": "utility",
		"shape": [Vector2i(0, 0)], "food": "herb", "feed_every": 4, "price": 35,
		"desc": "Listens through the earth. Reveals a much wider area of the map and widens your night vision.",
		"stats": {"reveal": 10.0, "light_radius": 60.0},
	},
	"jade_bone": {
		"name": "Jade Bone Gu", "path": "earth", "rank": 1, "role": "utility",
		"shape": [Vector2i(0, 0)], "food": "stone", "feed_every": 4, "price": 30,
		"desc": "Lightens the bones. +12% move speed and a wider loot pickup radius.",
		"stats": {"move_speed": 0.12, "pickup": 40.0},
	},
	# ---------------- Rank 2 ----------------
	"moon_glow": {
		"name": "Moon Glow Gu", "path": "moon", "rank": 2, "role": "attack",
		"shape": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)], "food": "moon_orchid", "feed_every": 3, "price": 160,
		"desc": "A full moon blade that pierces through 3 foes.",
		"attack": {"kind": "projectile", "damage": 24.0, "cooldown": 1.4, "range": 270.0, "cost": 3.5, "speed": 380.0, "pierce": 3, "size": 12.0, "color": "#d9ecff"},
	},
	"thunder_bead": {
		"name": "Thunder Bead Gu", "path": "lightning", "rank": 2, "role": "attack",
		"shape": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)], "food": "thunder_crystal", "feed_every": 4, "price": 170,
		"desc": "Lightning leaps between up to 3 enemies.",
		"attack": {"kind": "chain", "damage": 18.0, "cooldown": 1.8, "range": 230.0, "cost": 4.0, "count": 3, "color": "#e3d0ff"},
	},
	"fire_ember": {
		"name": "Fire Ember Gu", "path": "fire", "rank": 2, "role": "attack",
		"shape": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)], "food": "meat", "feed_every": 2, "price": 150,
		"desc": "Erupts in a ring of flame around you, burning all nearby foes.",
		"attack": {"kind": "nova", "damage": 20.0, "cooldown": 2.6, "range": 110.0, "radius": 110.0, "cost": 4.0, "color": "#ff8a4c"},
	},
	"jade_skin": {
		"name": "White Jade Gu", "path": "earth", "rank": 2, "role": "defense",
		"shape": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)], "food": "stone", "feed_every": 3, "price": 140,
		"desc": "Skin like white jade. +9 armor, +20 max HP.",
		"stats": {"armor": 9.0, "max_hp": 20.0},
	},
	"four_flavors": {
		"name": "Four Flavors Liquor Worm", "path": "wood", "rank": 2, "role": "support",
		"shape": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)], "food": "wine", "feed_every": 2, "price": 200,
		"desc": "A refined liquor worm. Adjacent attack Gu: +50% damage, 15% faster, 25% cheaper.",
		"aura": {"damage_mult": 0.5, "cooldown_mult": -0.15, "cost_mult": -0.25},
	},
	# ---------------- Rank 3 ----------------
	"bear_strength": {
		"name": "Bear Strength Gu", "path": "strength", "rank": 3, "role": "passive",
		"shape": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)], "food": "meat", "feed_every": 2, "price": 420,
		"desc": "The might of a mountain bear. +80 max HP, +25% damage.",
		"stats": {"max_hp": 80.0, "damage_mult": 0.25},
	},
	"thunder_crown": {
		"name": "Thunder Crown Gu", "path": "lightning", "rank": 3, "role": "attack",
		"shape": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(2, 1)], "food": "thunder_crystal", "feed_every": 3, "price": 480,
		"desc": "A crown of thunder that arcs across 5 enemies.",
		"attack": {"kind": "chain", "damage": 34.0, "cooldown": 2.0, "range": 260.0, "cost": 7.0, "count": 5, "color": "#f0e2ff"},
	},
}

## Killer moves: active when every required Gu is placed AND they form one connected group.
const KILLER_MOVES := [
	{
		"id": "boar_stone_body", "name": "Boar Stone Body", "requires": ["black_boar", "stone_skin"], "min_rank": 1,
		"desc": "Strength and earth fuse: +5 armor and a ground stomp that shakes nearby foes.",
		"stats": {"armor": 5.0},
		"attack": {"kind": "nova", "damage": 16.0, "cooldown": 4.0, "range": 95.0, "radius": 95.0, "cost": 5.0, "color": "#c9a36b"},
	},
	{
		"id": "moon_shadow_web", "name": "Moon Shadow Web", "requires": ["moonlight", "spider_silk"], "min_rank": 1,
		"desc": "Silk-laced crescents fan out in threes, slowing all they touch.",
		"attack": {"kind": "fan", "damage": 9.0, "cooldown": 2.2, "range": 250.0, "cost": 4.0, "count": 3, "spread": 0.5, "speed": 400.0, "slow": 0.5, "size": 6.0, "color": "#e7d6ff"},
	},
	{
		"id": "crescent_tide", "name": "Crescent Tide", "requires": ["moonlight", "moon_glow", "liquor_worm"], "min_rank": 2,
		"desc": "A tide of seven moon blades sweeps the field.",
		"attack": {"kind": "fan", "damage": 16.0, "cooldown": 3.5, "range": 300.0, "cost": 10.0, "count": 7, "spread": 1.0, "speed": 440.0, "pierce": 2, "size": 9.0, "color": "#cfe8ff"},
	},
	{
		"id": "thunderwind_lance", "name": "Thunderwind Lance", "requires": ["wind_blade", "thunder_bead"], "min_rank": 2,
		"desc": "Wind carries the thunder: a storm arc jumping across 6 enemies.",
		"attack": {"kind": "chain", "damage": 30.0, "cooldown": 3.0, "range": 300.0, "cost": 9.0, "count": 6, "color": "#b6fff0"},
	},
	{
		"id": "verdant_flame", "name": "Verdant Flame Rebirth", "requires": ["fire_ember", "vitality_leaf"], "min_rank": 2,
		"desc": "Wood feeds fire: a huge flame ring, and the ashes heal you (+1.5 HP/s).",
		"stats": {"hp_regen": 1.5},
		"attack": {"kind": "nova", "damage": 38.0, "cooldown": 5.0, "range": 150.0, "radius": 150.0, "cost": 10.0, "color": "#ffb347"},
	},
]

static func path_color(path: String) -> Color:
	return Color.html(PATH_COLORS[path])

static func color_of(def_id: String) -> Color:
	return path_color(GU[def_id]["path"])
