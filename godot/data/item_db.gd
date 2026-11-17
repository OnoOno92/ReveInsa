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
	"wine": {"name": "Bamboo Wine", "desc": "Liquor Worms adore it.", "color": "#e0c070", "price": 4},
	"pelt": {"name": "Beast Pelt", "desc": "Sells well to merchants.", "color": "#7f6a4f", "price": 4},
	"bone": {"name": "Beast Bone", "desc": "Material for Gu refinement.", "color": "#e8e2d0", "price": 3},
	"jade_shard": {"name": "Jade Shard", "desc": "Rare mineral used to refine White Jade Gu.", "color": "#a8e6cf", "price": 12},
	"thunder_crystal": {"name": "Thunder Crystal", "desc": "Crackles with stored lightning.", "color": "#d1b3ff", "price": 10},
	"beast_core": {"name": "Beast King Core", "desc": "The condensed will of a beast king.", "color": "#ffcc33", "price": 80},
}

# output: {item | gu | place} ; gu_input consumes one Gu of that id (refinement)
const RECIPES := [
	{"id": "campfire", "name": "Campfire", "needs": {"wood": 6, "stone": 2}, "output": {"place": "campfire"},
		"desc": "Light in the dark. Needed for cooking."},
	{"id": "cook_meat", "name": "Roast Meat", "needs": {"meat": 1}, "near_fire": true, "output": {"item": "cooked_meat"},
		"desc": "Cook raw meat over a fire."},
	{"id": "brew_wine", "name": "Bamboo Wine", "needs": {"berries": 4, "herb": 1}, "near_fire": true, "output": {"item": "wine"},
		"desc": "Ferment berries over a low flame."},
	{"id": "r_vitality", "name": "Refine: Vitality Leaf Gu", "needs": {"herb": 6}, "stones": 12, "output": {"gu": "vitality_leaf"},
		"desc": "Refine a new healing Gu from herbs."},
	{"id": "r_spider", "name": "Refine: Spider Silk Gu", "needs": {"bone": 2, "herb": 3}, "stones": 15, "output": {"gu": "spider_silk"},
		"desc": "Weave silk around a bone core."},
	{"id": "r_jadebone", "name": "Refine: Jade Bone Gu", "needs": {"bone": 3, "stone": 4}, "stones": 15, "output": {"gu": "jade_bone"},
		"desc": "Temper bone with stone."},
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
		"gu": ["moonlight", "stone_skin", "vitality_leaf", "liquor_worm", "black_boar", "earth_ear"],
		"items": ["rice_ball", "wine", "moon_orchid", "meat", "herb"],
	},
	"city": {
		"name": "Shang Clan Trading Hall",
		"gu": ["wind_blade", "water_shield", "spider_silk", "jade_bone", "moon_glow", "thunder_bead", "fire_ember", "jade_skin", "four_flavors"],
		"items": ["rice_ball", "wine", "moon_orchid", "thunder_crystal", "jade_shard", "cooked_meat"],
	},
}

static func recipe(id: String) -> Dictionary:
	for r in RECIPES:
		if r["id"] == id:
			return r
	return {}

static func color(id: String) -> Color:
	return Color.html(ITEMS[id]["color"])
