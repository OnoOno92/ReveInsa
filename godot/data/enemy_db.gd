class_name EnemyDB
extends RefCounted
## Enemy definitions and spawn tables per zone.

const ENEMIES := {
	"wolf": {
		"name": "Grey Wolf", "faction": "beast", "hp": 30.0, "speed": 115.0, "damage": 6.0, "attack_cd": 1.0, "radius": 13.0,
		"color": "#7d7d7d", "aggro": 260.0, "stones": [0, 1],
		"drops": [{"item": "meat", "chance": 0.7, "min": 1, "max": 1}, {"item": "pelt", "chance": 0.4, "min": 1, "max": 1}],
	},
	"boar": {
		"name": "Wild Boar", "faction": "beast", "hp": 65.0, "speed": 85.0, "damage": 10.0, "attack_cd": 1.3, "radius": 16.0,
		"color": "#5b3a29", "aggro": 180.0, "stones": [0, 2],
		"drops": [{"item": "meat", "chance": 1.0, "min": 1, "max": 2}, {"item": "bone", "chance": 0.5, "min": 1, "max": 1}],
	},
	"night_wolf": {
		"name": "Shadow Wolf", "faction": "beast", "hp": 48.0, "speed": 140.0, "damage": 9.0, "attack_cd": 0.9, "radius": 13.0,
		"color": "#2c2c44", "aggro": 340.0, "stones": [1, 3],
		"drops": [{"item": "meat", "chance": 0.6, "min": 1, "max": 1}, {"item": "pelt", "chance": 0.6, "min": 1, "max": 1}],
	},
	"thunder_wolf": {
		"name": "Thunder Crown Wolf", "faction": "beast", "hp": 150.0, "speed": 125.0, "damage": 16.0, "attack_cd": 1.0, "radius": 17.0,
		"color": "#6b5bd6", "aggro": 320.0, "stones": [4, 9],
		"drops": [{"item": "thunder_crystal", "chance": 0.8, "min": 1, "max": 2}, {"item": "pelt", "chance": 0.8, "min": 1, "max": 2}],
		"ranged": {"range": 220.0, "speed": 300.0, "damage": 10.0, "cd": 2.4, "color": "#d9c7ff"},
	},
	"demonic_master": {
		"name": "Demonic Gu Master", "faction": "demonic", "hp": 80.0, "speed": 90.0, "damage": 8.0, "attack_cd": 1.2, "radius": 13.0,
		"color": "#7a1f3d", "aggro": 300.0, "stones": [8, 20],
		"drops": [{"item": "wine", "chance": 0.3, "min": 1, "max": 2}, {"item": "moon_orchid", "chance": 0.3, "min": 1, "max": 3}],
		"gu_drop": {"pool": ["moonlight", "stone_skin", "spider_silk", "wind_blade", "liquor_worm", "jade_bone", "wolf_slave", "water_arrow", "spark"], "chance": 0.18},
		"ranged": {"range": 260.0, "speed": 340.0, "damage": 9.0, "cd": 1.6, "color": "#ff6b9a"},
	},
	"poison_toad": {
		"name": "Mire Poison Toad", "faction": "beast", "hp": 110.0, "speed": 70.0, "damage": 14.0, "attack_cd": 1.2, "radius": 18.0,
		"color": "#3f6b2a", "aggro": 220.0, "stones": [3, 6],
		"drops": [{"item": "herb", "chance": 0.8, "min": 1, "max": 3}, {"item": "bone", "chance": 0.5, "min": 1, "max": 2}],
		"ranged": {"range": 180.0, "speed": 220.0, "damage": 12.0, "cd": 2.8, "color": "#9cff57"},
	},
	# The nemesis (stats scaled from Game.nemesis by combat.gd)
	"nemesis": {
		"name": "Nemesis", "faction": "demonic", "hp": 200.0, "speed": 105.0, "damage": 12.0, "attack_cd": 1.1, "radius": 15.0,
		"color": "#3a0f24", "aggro": 1200.0, "stones": [0, 0], "drops": [], "elite": true,
		"ranged": {"range": 290.0, "speed": 380.0, "damage": 11.0, "cd": 1.25, "color": "#ff4d6d"},
	},
	# Tribulation foes (stats are scaled by the tribulation controller; "elite" shows a named HP bar)
	"trib_spirit": {
		"name": "Tribulation Spirit", "faction": "beast", "hp": 40.0, "speed": 110.0, "damage": 8.0, "attack_cd": 1.0, "radius": 11.0,
		"color": "#e8e0ff", "aggro": 900.0, "stones": [0, 0], "drops": [],
	},
	"trib_avatar": {
		"name": "Calamity Avatar", "faction": "beast", "hp": 300.0, "speed": 70.0, "damage": 14.0, "attack_cd": 1.3, "radius": 26.0,
		"color": "#f0e8ff", "aggro": 900.0, "stones": [0, 0], "drops": [], "elite": true,
		"ranged": {"range": 280.0, "speed": 300.0, "damage": 10.0, "cd": 1.8, "color": "#ffffff"},
	},
	"bear_king": {
		"name": "Mire Bear King", "faction": "beast", "hp": 900.0, "speed": 95.0, "damage": 28.0, "attack_cd": 1.4, "radius": 30.0,
		"color": "#3b2516", "aggro": 380.0, "stones": [80, 140], "boss": true,
		"drops": [{"item": "beast_core", "chance": 1.0, "min": 1, "max": 1}, {"item": "meat", "chance": 1.0, "min": 4, "max": 6}, {"item": "bone", "chance": 1.0, "min": 3, "max": 5}],
		"gu_drop": {"pool": ["bear_strength", "fire_ember", "jade_skin"], "chance": 0.5},
	},
}

## Returns [[enemy_id, weight], ...] for a zone.
static func spawn_table(zone: String, night: bool, danger: float) -> Array:
	match zone:
		"wild":
			if night:
				var t := [["night_wolf", 4], ["wolf", 3], ["boar", 1]]
				if danger > 0.5:
					t.append(["thunder_wolf", 1])
				return t
			var d := [["wolf", 4], ["boar", 3]]
			if danger > 0.6:
				d.append(["demonic_master", 1])
			return d
		"deep":
			if night:
				return [["night_wolf", 4], ["thunder_wolf", 2], ["boar", 1]]
			return [["wolf", 3], ["boar", 3], ["thunder_wolf", 1], ["demonic_master", 1]]
		"ruins":
			return [["demonic_master", 5], ["night_wolf", 2 if night else 0]]
		"forbidden":
			return [["poison_toad", 4], ["thunder_wolf", 2], ["night_wolf", 3 if night else 1]]
	return []
