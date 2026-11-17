class_name GuDB
extends RefCounted
## Gu definitions. Each Gu occupies a shape inside the aperture grid.
## Placement + adjacency drives synergies and killer moves (see game/aperture.gd).
## NOTE: const dictionaries are read-only — duplicate() before modifying.

const PATH_COLORS := {
	"moon": "#9ecbff", "strength": "#c0743a", "earth": "#b39b6b", "water": "#3fa7d6",
	"fire": "#ef5b3c", "wood": "#5cb85c", "wind": "#8fe3c8", "lightning": "#c9a6ff",
	"information": "#f2d36b", "enslavement": "#d16ba5", "metal": "#c9c9d6",
}

const PATH_NAMES := {
	"moon": "Moon Path", "strength": "Strength Path", "earth": "Earth Path", "water": "Water Path",
	"fire": "Fire Path", "wood": "Wood Path", "wind": "Wind Path", "lightning": "Lightning Path",
	"information": "Information Path", "enslavement": "Enslavement Path", "metal": "Metal Path",
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
	"wolf_slave": {
		"name": "Wolf Enslavement Gu", "path": "enslavement", "rank": 1, "role": "summon",
		"shape": [Vector2i(0, 0), Vector2i(1, 0)], "food": "meat", "feed_every": 2, "price": 60,
		"desc": "Binds a grey wolf to your will. It fights at your side and returns 20s after falling.",
		"summon": {"kind": "wolf", "count": 1, "hp": 60.0, "damage": 7.0, "speed": 165.0, "respawn": 20.0},
	},
	"water_arrow": {
		"name": "Water Arrow Gu", "path": "water", "rank": 1, "role": "attack",
		"shape": [Vector2i(0, 0), Vector2i(1, 0)], "food": "herb", "feed_every": 3, "price": 35,
		"desc": "Shoots a heavy arrow of water that slows its target by 25%.",
		"attack": {"kind": "projectile", "damage": 9.0, "cooldown": 1.0, "range": 260.0, "cost": 1.6, "speed": 460.0, "slow": 0.25, "size": 6.0, "color": "#7fd0ff"},
	},
	"spark": {
		"name": "Spark Gu", "path": "fire", "rank": 1, "role": "attack",
		"shape": [Vector2i(0, 0)], "food": "wood", "feed_every": 2, "price": 30,
		"desc": "Flicks fast embers at the nearest foe. Weak, but very quick, and the embers burn.",
		"attack": {"kind": "projectile", "damage": 5.0, "cooldown": 0.45, "range": 200.0, "cost": 0.8, "speed": 520.0, "size": 4.0, "burn": 0.4, "color": "#ffb36b"},
	},
	"bronze_skin": {
		"name": "Bronze Skin Gu", "path": "metal", "rank": 1, "role": "defense",
		"shape": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)], "food": "stone", "feed_every": 3, "price": 55,
		"desc": "Skin takes on a bronze sheen. +7 armor, but it is bulky.",
		"stats": {"armor": 7.0},
	},
	"essence_spring": {
		"name": "Essence Spring Gu", "path": "water", "rank": 1, "role": "passive",
		"shape": [Vector2i(0, 0), Vector2i(0, 1)], "food": "moon_orchid", "feed_every": 3, "price": 50,
		"desc": "A spring of primeval essence wells in your aperture. +35% essence regen, +15 max essence.",
		"stats": {"essence_regen": 0.35, "max_essence": 15.0},
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
		"desc": "Lightning leaps between up to 3 enemies, sometimes stunning them.",
		"attack": {"kind": "chain", "damage": 18.0, "cooldown": 1.8, "range": 230.0, "cost": 4.0, "count": 3, "stun": 0.15, "color": "#e3d0ff"},
	},
	"fire_ember": {
		"name": "Fire Ember Gu", "path": "fire", "rank": 2, "role": "attack",
		"shape": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)], "food": "meat", "feed_every": 2, "price": 150,
		"desc": "Erupts in a ring of flame around you; foes keep burning afterwards.",
		"attack": {"kind": "nova", "damage": 20.0, "cooldown": 2.6, "range": 110.0, "radius": 110.0, "cost": 4.0, "burn": 0.5, "color": "#ff8a4c"},
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
	"wood_thorn": {
		"name": "Wood Thorn Gu", "path": "wood", "rank": 2, "role": "attack",
		"shape": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)], "food": "herb", "feed_every": 2, "price": 150,
		"desc": "Sprays a fan of four hard thorns.",
		"attack": {"kind": "fan", "damage": 11.0, "cooldown": 1.6, "range": 240.0, "cost": 3.5, "count": 4, "spread": 0.6, "speed": 420.0, "size": 5.0, "color": "#9be07a"},
	},
	"gust": {
		"name": "Gust Gu", "path": "wind", "rank": 2, "role": "attack",
		"shape": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)], "food": "herb", "feed_every": 3, "price": 140,
		"desc": "A burst of wind that hurls nearby foes away.",
		"attack": {"kind": "nova", "damage": 12.0, "cooldown": 3.0, "range": 120.0, "radius": 120.0, "cost": 3.5, "knockback": 160.0, "color": "#c8fff0"},
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

## Trigger passives (idea from Martial Improved's gu_passives.js). Active while the Gu is placed and fed.
## trigger: opener (first attack after 6s out of combat) | on_kill | on_hurt | low_hp (below 35% HP)
## on_kill stacks: "stack": {stat: per_stack}, "max": n, fade 8s after the last kill.
const PASSIVES := {
	"moonlight": {"name": "Silent Crescent", "trigger": "opener", "desc": "After 6s out of combat, its first crescent deals double damage.", "opener_mult": 2.0},
	"spark": {"name": "Kindling", "trigger": "opener", "desc": "The first spark of a fight burns three times as hot.", "opener_burn": 1.2},
	"black_boar": {"name": "Bloodlust", "trigger": "on_kill", "desc": "+5% damage per kill (max 5), fading 8s after your last kill.", "stack": {"damage_buff": 0.05}, "max": 5},
	"thunder_bead": {"name": "Static Charge", "trigger": "on_kill", "desc": "+4% move speed per kill (max 5), fading 8s after your last kill.", "stack": {"move_speed": 0.04}, "max": 5},
	"vitality_leaf": {"name": "Rooted Life", "trigger": "on_kill", "desc": "Each kill heals you for 3 HP.", "heal": 3.0},
	"essence_spring": {"name": "Wellspring", "trigger": "on_kill", "desc": "Each kill restores 2 primeval essence.", "essence": 2.0},
	"stone_skin": {"name": "Stone Retort", "trigger": "on_hurt", "desc": "When hit, 25% chance to shove nearby enemies away.", "chance": 0.25, "shove": 220.0},
	"water_shield": {"name": "Ebb and Flow", "trigger": "on_hurt", "desc": "When hit, 20% chance to restore 40% of your shield.", "chance": 0.2, "shield": 0.4},
	"spider_silk": {"name": "Tangling Web", "trigger": "on_hurt", "desc": "When hit, slows enemies around you by 40% (every 4s at most).", "chance": 1.0, "slow": 0.4, "cooldown": 4.0},
	"jade_skin": {"name": "Jade Resolve", "trigger": "low_hp", "desc": "Below 35% HP: +10 armor.", "stats": {"armor": 10.0}},
	"bear_strength": {"name": "Cornered Bear", "trigger": "low_hp", "desc": "Below 35% HP: +30% damage.", "stats": {"damage_buff": 0.3}},
	"jade_bone": {"name": "Light Bones", "trigger": "low_hp", "desc": "Below 35% HP: +20% move speed to escape.", "stats": {"move_speed": 0.2}},
}

## Named pairs: two specific Gu touching in the aperture. Smaller than killer moves.
## "stats" apply globally; "attack": {gu id: mods} tweak that Gu's attack; "heal_cost" scales heal costs.
const PAIRS := [
	{"id": "moon_water", "name": "Moon over Water", "gu": ["moonlight", "water_arrow"], "desc": "Moonlight and Water Arrow reach 15% farther.",
		"attack": {"moonlight": {"range_mult": 0.15}, "water_arrow": {"range_mult": 0.15}}},
	{"id": "iron_hide", "name": "Iron Hide", "gu": ["stone_skin", "bronze_skin"], "desc": "+3 armor.", "stats": {"armor": 3.0}},
	{"id": "spark_gale", "name": "Spark and Gale", "gu": ["spark", "wind_blade"], "desc": "Sparks ride the wind: they pierce one more foe.",
		"attack": {"spark": {"pierce_add": 1}}},
	{"id": "root_spring", "name": "Root and Spring", "gu": ["vitality_leaf", "essence_spring"], "desc": "Healing Gu cost half the essence.", "heal_cost": 0.5},
	{"id": "wolf_boar", "name": "Wolf and Boar", "gu": ["wolf_slave", "black_boar"], "desc": "Bound beasts bite 30% harder.", "stats": {"summon_damage": 0.3}},
	{"id": "silk_thunder", "name": "Silk and Thunder", "gu": ["spider_silk", "thunder_bead"], "desc": "Thunder Bead stuns 15% more often.",
		"attack": {"thunder_bead": {"stun_add": 0.15}}},
	{"id": "jade_body", "name": "Jade Body", "gu": ["jade_bone", "jade_skin"], "desc": "+10% move speed and +2 armor.", "stats": {"move_speed": 0.1, "armor": 2.0}},
	{"id": "wine_moon", "name": "Drunken Moon", "gu": ["four_flavors", "moon_glow"], "desc": "Moon Glow fires 10% faster.",
		"attack": {"moon_glow": {"cooldown_mult": -0.1}}},
]

## Dao combos: when 2+ pairs of same-path Gu touch in the aperture, that path's effect turns on.
## "attack" keys apply to attacks of that path; "stats" keys apply globally.
## Attack effect keys: burn (fraction of hit dealt again over 3s), stun (chance, 0.6s),
## vulnerable (foe takes +X damage for 3s), pierce_add, count_add (chain jumps).
const DAO_COMBOS := {
	"moon": {"name": "Moonlit Edge", "desc": "Moon path attacks pierce one more foe and burn faintly.", "attack": {"pierce_add": 1, "burn": 0.2}},
	"fire": {"name": "Inferno", "desc": "Fire path attacks set foes ablaze: 60% of each hit burns again over 3s.", "attack": {"burn": 0.6}},
	"lightning": {"name": "Thunder Chain", "desc": "Lightning attacks jump to one more foe and stun 30% of the time.", "attack": {"count_add": 1, "stun": 0.3}},
	"water": {"name": "Flowing Tide", "desc": "Water attacks soak foes: they take 20% more damage from everything for 3s.", "attack": {"vulnerable": 0.2}},
	"wood": {"name": "Verdant Life", "desc": "You heal for 6% of all damage you deal.", "stats": {"lifesteal": 0.06}},
	"earth": {"name": "Iron Bastion", "desc": "You take 20% less damage.", "stats": {"damage_taken": -0.2}},
	"strength": {"name": "Blood Frenzy", "desc": "Below half HP, every attack deals +40% damage.", "stats": {"berserk": 0.4}},
	"metal": {"name": "Blade Storm", "desc": "Every attack has a 20% chance to strike for double damage.", "stats": {"crit": 0.2}},
	"wind": {"name": "Gale Step", "desc": "+15% move speed, and wind attacks pierce one more foe.", "stats": {"move_speed": 0.15}, "attack": {"pierce_add": 1}},
	"enslavement": {"name": "Pack Bond", "desc": "Bound beasts bite 40% harder.", "stats": {"summon_damage": 0.4}},
	"information": {"name": "Far Sight", "desc": "Every attack reaches 20% farther.", "stats": {"range_mult": 0.2}},
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
	{
		"id": "wolf_pack", "name": "Wolf Pack Command", "requires": ["wolf_slave", "earth_ear"], "min_rank": 1,
		"desc": "The earth carries your commands: one more wolf answers, and the pack bites 50% harder.",
		"stats": {"summon_count": 1.0, "summon_damage": 0.5},
	},
	{
		"id": "steam_burst", "name": "Steam Burst", "requires": ["water_arrow", "spark"], "min_rank": 1,
		"desc": "Water meets fire: a scalding cloud bursts around you, slowing everything inside.",
		"attack": {"kind": "nova", "damage": 14.0, "cooldown": 3.5, "range": 95.0, "radius": 95.0, "cost": 4.0, "slow": 0.3, "color": "#e8f4ff"},
	},
	{
		"id": "thorned_gale", "name": "Thorned Gale", "requires": ["gust", "wood_thorn"], "min_rank": 2,
		"desc": "The gale carries a storm of thorns in every direction.",
		"attack": {"kind": "fan", "damage": 14.0, "cooldown": 4.0, "range": 260.0, "cost": 9.0, "count": 12, "spread": 6.0, "speed": 400.0, "pierce": 2, "size": 5.0, "color": "#b8f59a"},
	},
]

static func path_color(path: String) -> Color:
	return Color.html(PATH_COLORS[path])

static func color_of(def_id: String) -> Color:
	return path_color(GU[def_id]["path"])
