# Notes on the old project: Martial Improved

Source: https://github.com/OnoOno92/Martial_RevIns. It is a vanilla-JS idle/menu RPG, about 3.8 MB, built on the same idea: Reverend Insanity combined with Overgeared Hero.
These notes record what was worth carrying into Gu Wilds and what wasn't. File references point into that repo.

## What it is
- A menu and tab RPG: cultivation clicker, sect management, disciples, NPC world simulation, auto-battle on per-body-part 5×5 grids, dungeons, market, nemesis rivals, tribulations and farming.
- Its world is generic xianxia (Mortal Continent → Immortal Domain, tier gates). It has **no canon RI geography**: no Southern Border, no Regional Walls, no Shang clan.
- None of its 49 Gu use canon RI names. Gu Wilds is already more canon.
- Its original story premise is "Shattered Soul / Heaven's Blessed" (`DESIGN_HB_WORLD.md:24-43`). An earlier pitch leaned on Fang Yuan's ending; that one is **not** to be used, and neither is the "Spring Autumn Insight" gift.

## Adopt (adapted to real-time survival)

| Idea | Source | How it lands in Gu Wilds |
|---|---|---|
| Dao combo effects: one signature on-hit effect per path (burn, chain, lifesteal, pierce, damage reduction, berserk) | `gu_dao_registry.js:9-165` | Each path gains an effect once ≥2 same-path adjacent pairs exist in the aperture |
| Status effects: burn, bleed, poison, stun, slow | `combat.js` top, `auto_battle.js:197` | Real-time DoTs and crowd control on enemies |
| Trigger passives: on_kill, on_hurt, hp_below_X, first_hit, kill stacks | `gu_passives.js:53-498` | Per-Gu passive hooks in combat |
| Named synergy pairs, plus path-count tiers at 3 and 5 Gu | `gu_passives.js:503-597` | Set bonuses next to the existing killer-move graph |
| Per-drop rolls: potential 0-31 (power, speed, efficiency, durability), natures, shiny 1/512 | `gu_potential.js`, `gu_natures.js`, `gu_shiny.js` | Every wild or dropped Gu is unique; shiny is a palette swap |
| Wild Gu sightings: timed rumors matched to biome, NPCs compete for them | `gu_hunting.js:13-275` | Map markers; stand in the area to channel a capture |
| Evolution recipes with a pity rule (guaranteed after 3 fails) | `gu_refinement.js:69-73,177`, `gu_refining.js:23-27` | Refinement bench chains |
| Size-scaled cooldown and cost | `auto_battle.js:19,372` | Bigger Gu hit harder and fire slower (tuning rule) |
| Feed Gu with HP (demonic emergency option) | `gu_system.js:1532` | Aperture panel button |
| Gu-food garden: growth stages, overgrowth/rot, tending, element and season bonuses, auto-feed | `farming.js:8-170,380` | Buildable plots at camp or village |
| Pills and alchemy: heal, cleanse, qi stabilizer, tribulation protection, breakthrough aid | `crafting.js:2056`, `bridges.js:32-130` | Alchemy furnace and timed consumables |
| Breakthrough tribulation boss, themed by your dominant Dao; qi deviation on failure | `progression.js:652-790`, `combat.js:2575` | Arena storm with telegraphed strikes when breaking rank |
| Nemesis: a rival who grows, roams, builds a grudge, ambushes and raids, and returns stronger | `nemesis.js:70-260,592` | A named demonic Gu Master hunting the player |
| Roaming NPC Gu Masters using one unified NPC schema, plus an event log | `UNIFIED_NPC_DESIGN.md`, `world_npcs.js` | 5-8 persistent NPCs; clan guards are NPCs with affiliation=clan |
| Path mastery (attainment) and Dao marks: per-path XP from use gives permanent bonuses | `attainment_system.js:7-24`, `gu_system.js:2265-2313` | Long-term progression |
| Inheritance-ruin rooms (Formation Lock, Guardian Spirit, Poison Fog, Mirror Maze) and a Remnant Will boss ladder | `legacy_dungeons.js:8-33`, `ancient_battle_site.js` | Instanced interior for the Nameless Inheritance Ruins |
| Blessed Land stability meter (every fight or harvest drains it; at 0 you are ejected) | `RI_WORLD_DESIGN.md:171-184` | Temporary grottos and blessed-land fragments |
| Calendar with seasons and festival days; scheduled events with warnings (Spirit Spring, Ancient Grotto) | `calendar.js:11-160`, `world_events.js:5-108` | Seasons and events on top of the day/night cycle |
| Biome points of interest with tags (Beast Den, Inscription Wall, Hidden Spring) | `world_builder.js:42-112` | Procedural POIs inside biomes |
| Body cultivation: a durability bar that soaks damage | `body_cultivation.js:7-60,272` | Second progression track |
| World Darkness / Concealment meter and a black-market fence | `world_darkness.js`, `black_market.js` | Demonic-path loop and the Shang City underbelly |
| Refine timing minigame (3 pulses, gold zone) | `refine_minigame.js` | Optional skill bonus on refinement |
| Price drop when the player oversells one item | `market.js:385-410` | Shop pricing |

## Skip
- Click-to-circulate qi, sect salary and duty screens, disciple story arcs, auction bidding, offline progress. These are menu or idle mechanics.
- Rarity tiers (they duplicate rank), formation arrays as written, and the killer-move discovery roll (our placed-and-connected rule is better).
- Upgradable aptitude via wall-shattering is not canon. We keep a limited clan pill instead.

## Lessons (pain points not to repeat)
- Systems missing from saves ("Save failed: {}", fields stripped by normalizeState). **Every new system must live in the one save dictionary, and a save/load round-trip test must cover it.**
- Global name collisions and duplicate NPC systems. Use one schema per concept from day one.
- Multiplier sprawl across 12+ modules. Use one central modifier stack with caps.
- Huge files (`sect.js` 474 KB) and 30+ status markdown files. Keep modules small; keep `docs/GDD.md` as the single roadmap.
- Leftover generic-xianxia rank names. Use one rank vocabulary: RI ranks 1-9 with Initial/Middle/Upper/Peak.
