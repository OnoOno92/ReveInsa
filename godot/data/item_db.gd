class_name ItemDB
extends RefCounted
## Items, crafting/refinement recipes and shops.

# price = sell value in primeval stones (buy = 2x). food = hunger restored, heal = HP restored.
const ITEMS := {
	"wood": {"name": "Wood", "desc": "Firewood and building material.", "color": "#8b5a2b", "price": 1},
	"stone": {"name": "Stone", "desc": "Common stone. Earth path Gu feed on it.", "color": "#8e8e8e", "price": 1},
	"herb": {"name": "Herb", "desc": "Medicinal grass. Many wood and wind Gu eat it.", "color": "#6abf4b", "price": 1, "heal": 4.0},
	"berries": {"name": "Berries", "desc": "Wild berries. Edible.", "color": "#c2185b", "price": 1, "food": 8.0},
	"moon_orchid": {"name": "Moon Orchid", "desc": "Petals that glow at night. Food of moon path Gu.", "color": "#b3d4ff", "price": 3},
	"meat": {"name": "Raw Meat", "desc": "Edible raw, better cooked.", "color": "#c0392b", "price": 2, "food": 10.0, "heal": -3.0},
	"cooked_meat": {"name": "Roast Meat", "desc": "Hearty and warm.", "color": "#a0522d", "price": 4, "food": 32.0, "heal": 6.0},
	"rice_ball": {"name": "Rice Ball", "desc": "Village staple.", "color": "#f5f0e1", "price": 3, "food": 24.0},
	"spirit_rice": {"name": "Spirit Rice", "desc": "Hardy grain. Plant it in a field, or cook two into a rice ball.", "color": "#efe3b0", "price": 1, "food": 5.0},
	"wine": {"name": "Bamboo Wine", "desc": "Liquor Worms adore it.", "color": "#e0c070", "price": 4},
	"pelt": {"name": "Beast Pelt", "desc": "Sells well to merchants.", "color": "#7f6a4f", "price": 4},
	"bone": {"name": "Beast Bone", "desc": "Material for Gu refinement.", "color": "#e8e2d0", "price": 3},
	"jade_shard": {"name": "Jade Shard", "desc": "Rare mineral used to refine White Jade Gu.", "color": "#a8e6cf", "price": 12},
	"thunder_crystal": {"name": "Thunder Crystal", "desc": "Crackles with stored lightning.", "color": "#d1b3ff", "price": 10},
	"beast_core": {"name": "Beast King Core", "desc": "The condensed will of a beast king.", "color": "#ffcc33", "price": 80},
	# ---------------- Pills (brewed at an alchemy furnace) ----------------
	# pill.instant: hp / essence (fractions of max), feed_all_gu; pill.buff: stat bonuses for `seconds`
	"pill_vitality": {"name": "Vitality Pill", "desc": "Instantly restores 40% of your HP.", "color": "#ff7a7a", "price": 8,
		"pill": {"instant": {"hp": 0.4}}},
	"pill_essence": {"name": "Primeval Essence Pill", "desc": "Instantly refills 60% of your primeval essence.", "color": "#7fe0a0", "price": 10,
		"pill": {"instant": {"essence": 0.6}}},
	"pill_nourish": {"name": "Gu-Nourishing Pill", "desc": "Dissolves into your aperture and feeds every Gu at once.", "color": "#e0c070", "price": 14,
		"pill": {"instant": {"feed_all_gu": 1}}},
	"pill_iron": {"name": "Iron Skin Pill", "desc": "+15 armor for 90 seconds.", "color": "#b8b8c8", "price": 9,
		"pill": {"buff": {"armor": 15.0}, "seconds": 90.0}},
	"pill_wind": {"name": "Swift Wind Pill", "desc": "+25% move speed for 90 seconds.", "color": "#a8f5dc", "price": 8,
		"pill": {"buff": {"move_speed": 0.25}, "seconds": 90.0}},
	"pill_fury": {"name": "Battle Fury Pill", "desc": "+25% damage for 60 seconds.", "color": "#ff9a3c", "price": 12,
		"pill": {"buff": {"damage_buff": 0.25}, "seconds": 60.0}},
	"pill_night": {"name": "Night Sight Pill", "desc": "Your eyes drink the moonlight: much wider vision for 150 seconds.", "color": "#bfe0ff", "price": 7,
		"pill": {"buff": {"light_radius": 140.0, "reveal": 4.0}, "seconds": 150.0}},
	"pill_breakthrough": {"name": "Breakthrough Aid Pill", "desc": "Your next cultivation session counts for 1.5x progress.", "color": "#ffd76b", "price": 30,
		"pill": {"instant": {"breakthrough_aid": 1}}},
}

# output: {item | gu | place} ; gu_input consumes one Gu of that id (refinement)
const RECIPES := [
	{"id": "campfire", "name": "Campfire", "needs": {"wood": 6, "stone": 2}, "output": {"place": "campfire"},
		"desc": "Light in the dark. Needed for cooking."},
	{"id": "furnace", "name": "Alchemy Furnace", "needs": {"stone": 10, "wood": 6, "bone": 2}, "output": {"place": "furnace"},
		"desc": "A permanent stone furnace for brewing pills. Settlements already have one."},
	{"id": "plot", "name": "Spirit Field Plot", "needs": {"wood": 4, "stone": 2, "herb": 1}, "output": {"place": "plot"},
		"desc": "A tilled field. Plant moon orchids, herbs, berries or spirit rice and harvest Gu food."},
	{"id": "cook_rice", "name": "Rice Ball", "needs": {"spirit_rice": 2}, "near_fire": true, "output": {"item": "rice_ball"},
		"desc": "Steam two handfuls of spirit rice."},
	{"id": "cook_meat", "name": "Roast Meat", "needs": {"meat": 1}, "near_fire": true, "output": {"item": "cooked_meat"},
		"desc": "Cook raw meat over a fire."},
	{"id": "brew_wine", "name": "Bamboo Wine", "needs": {"berries": 4, "herb": 1}, "near_fire": true, "output": {"item": "wine"},
		"desc": "Ferment berries over a low flame."},
	# ---------------- Alchemy (needs a furnace) ----------------
	{"id": "a_vitality", "name": "Vitality Pill", "needs": {"herb": 3, "berries": 2}, "station": "furnace", "output": {"item": "pill_vitality"},
		"desc": "Instant 40% heal."},
	{"id": "a_essence", "name": "Primeval Essence Pill", "needs": {"moon_orchid": 2, "herb": 1}, "stones": 5, "station": "furnace", "output": {"item": "pill_essence"},
		"desc": "Refill 60% essence."},
	{"id": "a_nourish", "name": "Gu-Nourishing Pill", "needs": {"moon_orchid": 1, "meat": 2, "herb": 2}, "stones": 8, "station": "furnace", "output": {"item": "pill_nourish"},
		"desc": "Feeds every Gu at once."},
	{"id": "a_iron", "name": "Iron Skin Pill", "needs": {"stone": 4, "bone": 2, "herb": 1}, "station": "furnace", "output": {"item": "pill_iron"},
		"desc": "+15 armor for 90s."},
	{"id": "a_wind", "name": "Swift Wind Pill", "needs": {"berries": 3, "herb": 2}, "station": "furnace", "output": {"item": "pill_wind"},
		"desc": "+25% speed for 90s."},
	{"id": "a_fury", "name": "Battle Fury Pill", "needs": {"meat": 2, "thunder_crystal": 1, "herb": 1}, "station": "furnace", "output": {"item": "pill_fury"},
		"desc": "+25% damage for 60s."},
	{"id": "a_night", "name": "Night Sight Pill", "needs": {"moon_orchid": 2, "berries": 2}, "station": "furnace", "output": {"item": "pill_night"},
		"desc": "Wide night vision for 150s."},
	{"id": "a_breakthrough", "name": "Breakthrough Aid Pill", "needs": {"jade_shard": 2, "moon_orchid": 3}, "stones": 30, "station": "furnace", "output": {"item": "pill_breakthrough"},
		"desc": "Next cultivation session x1.5."},
	{"id": "r_vitality", "name": "Refine: Vitality Leaf Gu", "needs": {"herb": 6}, "stones": 12, "output": {"gu": "vitality_leaf"},
		"desc": "Refine a new healing Gu from herbs."},
	{"id": "r_spider", "name": "Refine: Spider Silk Gu", "needs": {"bone": 2, "herb": 3}, "stones": 15, "output": {"gu": "spider_silk"},
		"desc": "Weave silk around a bone core."},
	{"id": "r_jadebone", "name": "Refine: Jade Bone Gu", "needs": {"bone": 3, "stone": 4}, "stones": 15, "output": {"gu": "jade_bone"},
		"desc": "Temper bone with stone."},
	{"id": "r_wolfslave", "name": "Refine: Wolf Enslavement Gu", "needs": {"pelt": 4, "bone": 2, "meat": 2}, "stones": 30, "output": {"gu": "wolf_slave"},
		"desc": "Bind a wolf's spirit into a Gu with pelt, bone and blood."},
	{"id": "r_moonglow", "name": "Refine: Moon Glow Gu", "needs": {"moon_orchid": 6}, "stones": 40, "gu_input": "moonlight", "min_rank": 2,
		"output": {"gu": "moon_glow"}, "desc": "Advance a Moonlight Gu into rank 2 Moon Glow Gu."},
	{"id": "r_jadeskin", "name": "Refine: White Jade Gu", "needs": {"jade_shard": 3}, "stones": 40, "gu_input": "stone_skin", "min_rank": 2,
		"output": {"gu": "jade_skin"}, "desc": "Advance Stone Skin Gu with jade."},
	{"id": "r_thunder", "name": "Refine: Thunder Bead Gu", "needs": {"thunder_crystal": 3}, "stones": 45, "min_rank": 2,
		"output": {"gu": "thunder_bead"}, "desc": "Condense lightning into a Gu."},
	{"id": "r_fourflavors", "name": "Refine: Four Flavors Liquor Worm", "needs": {"wine": 6, "berries": 6}, "stones": 60, "gu_input": "liquor_worm", "min_rank": 2,
		"output": {"gu": "four_flavors"}, "desc": "Steep a Liquor Worm in four kinds of liquor."},
	{"id": "r_bear", "name": "Refine: Bear Strength Gu", "needs": {"beast_core": 1, "bone": 6}, "stones": 120, "gu_input": "black_boar", "min_rank": 3,
		"output": {"gu": "bear_strength"}, "desc": "Fuse a beast king core into a Black Boar Gu."},
]

const SHOPS := {
	"village": {
		"name": "Village Merchant",
		"gu": ["moonlight", "spark", "water_arrow", "stone_skin", "vitality_leaf", "liquor_worm", "black_boar", "earth_ear"],
		"items": ["rice_ball", "spirit_rice", "wine", "moon_orchid", "meat", "herb"],
	},
	"city": {
		"name": "Shang Clan Trading Hall",
		"gu": ["wind_blade", "water_shield", "spider_silk", "jade_bone", "bronze_skin", "essence_spring",
			"moon_glow", "thunder_bead", "fire_ember", "wood_thorn", "gust", "jade_skin", "four_flavors"],
		"items": ["rice_ball", "wine", "moon_orchid", "thunder_crystal", "jade_shard", "cooked_meat",
			"pill_vitality", "pill_essence", "pill_nourish"],
	},
}

static func recipe(id: String) -> Dictionary:
	for r in RECIPES:
		if r["id"] == id:
			return r
	return {}

static func color(id: String) -> Color:
	return Color.html(ITEMS[id]["color"])


## Recipe tab: "craft" | "refine" (Gu) | "alchemy" (pills)
static func category(r: Dictionary) -> String:
	if r.get("station", "") == "furnace":
		return "alchemy"
	if r["output"].has("gu"):
		return "refine"
	return "craft"


## Field crops: plant one of the item to sow it.
## grow = days to ripen; yield = base harvest (+ quality from tending, max 3);
## night = growth multiplier at night. Ripe crops rot after ROT_DAYS.
const CROPS := {
	"moon_orchid": {"grow": 1.0, "yield": 2, "night": 1.5},
	"herb": {"grow": 0.6, "yield": 3, "night": 1.0},
	"berries": {"grow": 0.5, "yield": 3, "night": 1.0},
	"spirit_rice": {"grow": 0.8, "yield": 4, "night": 1.0},
}
const ROT_DAYS := 1.0
