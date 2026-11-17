# Gu Wilds — Game Design Document (working title)

A fan-made survival game set in the world of *Reverend Insanity* (蛊真人). It tells a **new story**: the player is not Fang Yuan. The world (Gu, apertures, ranks, regional walls, clans, primeval stones) follows the novel's rules.

## Pillars

1. **Survive the Southern Border.** This is a Don't Starve / Minecraft-style loop: gather, eat, build fire, and live through the night.
2. **Build your aperture.** Combat is decided by how you arrange Gu in a backpack-style grid, inspired by the *Overgeared* mobile game. Position matters.
3. **Hands-off fighting, hands-on movement.** You only move with a virtual analog stick. The Gu in your aperture fire on their own when enemies come in range.
4. **The RI world is cruel and economic.** Gu must be fed or they die. Primeval stones are both money and essence. Higher-rank Gu need a higher-rank aperture.

## Core loop

```
explore → gather / hunt → feed Gu, eat → buy / refine Gu → rearrange aperture → cultivate (rank up) → push into more dangerous zones
```

## Systems (implemented in v0.1)

| System | Design | Code |
|---|---|---|
| Movement | WASD, or a floating virtual stick on the left side of the screen | `src/core/input.ts` |
| Aperture grid | Rank N gives a (3+N)×(3+N) grid. Gu have polyomino shapes and can be rotated. | `src/game/aperture.ts` |
| Auras | Support Gu (Liquor Worm, Spider Silk, Four Flavors) boost the attack Gu they touch | `computeBuild` |
| Path resonance | Same-path Gu touching each other: +15% damage per neighbour | `computeBuild` |
| Killer moves (杀招) | When a required set of Gu forms one connected group, it unlocks an extra attack or passive | `KILLER_MOVES` in `src/data/gu.ts` |
| Auto combat | Each attack Gu has its own cooldown and range and costs essence. Attack types: projectile, fan, nova, chain. | `Game.updateCombat` |
| Primeval essence | Max essence and regen scale with rank, stage and aptitude grade. The bar colour changes per rank (green copper → purple crystal). | `Game.maxEssence` |
| Aptitude | Rolled at the Aperture Awakening Ceremony (Hope Gu): Grade A/B/C | `Game.newGame` |
| Cultivation | Spend primeval stones at an elder or chamber to move through Initial → Middle → Upper → Peak, then rank up | `Game.cultivate` |
| Gu feeding | Each Gu eats a specific food every N days, at dawn. Starving Gu stop working; three days later they die. | `Game.onNewDay` |
| Survival | Hunger, HP regen, day/night (5 min per day), darkness, campfires | `Game.update` |
| Gathering | Trees, rocks, berry bushes, moon orchids, jade veins. Nodes regrow over days. | `World` nodes |
| Crafting / refinement | Campfire and cooking, plus Gu refinement recipes that can fail | `RECIPES` |
| Economy | Village and Shang Clan shops. Selling gives 40% for Gu and base price for goods. Buying costs 2×. | `SHOPS` |
| Transportation | Caravans between Shi Lan Village and Shang Clan City (fee + time) | `Game.travel` |
| World | Seeded procedural Southern Border with Regional Walls on the N, W and E edges (Central Continent, Western Desert, Eastern Sea) and sea to the south | `src/world/world.ts` |
| Zones | Village and city (safe), wilds, deep wilds, ruins (demonic Gu masters plus an inheritance), forbidden Myriad Beast Mire (Beast King boss) | `spawnTable` |
| Factions | Righteous clan village, Shang clan merchants, demonic cultivators (hostile), beasts | `ENEMIES.faction` |
| Saves | localStorage, autosave every 15s and on key actions | `Game.save/load` |

## Roadmap

### v0.2 — Depth of the Southern Border
- [x] Engine: ported to Godot 4.7 (`godot/`); the web build is kept as a reference.
- [x] Clan missions from the village elder (hunt / deliver / scout), clan contribution as a second currency, and a Clan Treasury (rare Gu, aptitude pill).
- [x] Beast tides: every 5th night, raiders storm Shi Lan Village; clan guards defend; rewards at dawn.
- [x] Enslavement path: Wolf Enslavement Gu summons a wolf companion; enemies target allies too.
- [x] +7 Gu (now 24) and +3 killer moves (now 8): Steam Burst, Wolf Pack Command, Thorned Gale; knockback on Gust Gu.
- [ ] More Gu (~40 rank 1–3) across all paths; more enslaved beasts (boar, thunder wolf).
- [ ] Gu durability and "using a higher-rank Gu costs extra essence", instead of the current hard lock.
- [ ] Buildable shelters, storage chests, and Gu-food gardens (moon orchid beds, wine brewing).
- [ ] Clan reputation and multiple clans.

### v0.25 — Gu depth (ideas carried over from Martial Improved; see `docs/LEGACY_MARTIAL_IMPROVED.md`)
- [x] Status effects (burn, stun, soaked/vulnerable) and one Dao combo per path (11), unlocked by 2+ touching same-path pairs. Crit, berserk, lifesteal, damage reduction.
- [ ] Trigger passives (on kill, on hurt, low HP) and named synergy pairs.
- [ ] Per-drop Gu rolls: potential (power/speed/efficiency/durability), nature, 1/512 shiny.
- [ ] Wild Gu sightings: timed map markers matched to biome; stand in the zone to capture.
- [ ] Alchemy furnace and pills; Gu-food garden plots with rot, tending and auto-feed.
- [ ] Breakthrough tribulation as a Dao-themed arena boss; qi deviation on failure.
- [ ] Nemesis: a named demonic rival who grows, roams, ambushes and returns stronger.

### v0.3 — Living world
- Roaming NPC Gu Masters on one unified NPC schema (clan guards are NPCs too), with a world event log.
- Seasons and calendar events (Spirit Spring, Ancient Grotto) with warnings.
- Inheritance-ruin interiors (Formation Lock, Guardian Spirit, Poison Fog rooms; Remnant Will bosses).
- More villages and clans with their own reputation and shops. Clan wars.
- Demonic-path player route: attack caravans, rob Gu masters, lose righteous reputation.
- Ruins and blessed lands as instanced dungeons with procedural layouts.
- Mounts and beast-carriage transport.

### v0.4 — Beyond the wall
- Ranks 4–5, with the climax of becoming a Gu Immortal (rank 6) and forming an immortal aperture (blessed land). That unlocks crossing a Regional Wall.
- New regions: Northern Plains (tribes, blizzards), Western Desert, Eastern Sea, Central Continent (sects).
- Immortal killer moves and dao marks.

### Platform
- Godot 4.7 project in `godot/`. [x] Android APK export (`tools/setup_android.sh`, `tools/godot.sh apk`), mobile UI scale, safe area, back button, save-on-pause. [ ] Web export preset is present but untested. [ ] Release signing keystore for the Play Store. [ ] iOS needs a Mac with Xcode.
- Art pass: replace the procedural tile atlas (`world/tileset_builder.gd`) and the `_draw()` placeholders with sprites.

## IP note
This is a non-commercial fan project. Character names, clans and locations in the game are original (Shi Lan Village, the Nameless Inheritance, the Myriad Beast Mire). It uses the novel's world concepts and Gu names. If it ever goes commercial, the RI-specific names should be replaced or licensed.
