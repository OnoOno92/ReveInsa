# Gu Wilds (ReveInsa)

A survival game set in the *Reverend Insanity* world, with a new story. You play a young Gu Master of Shi Lan Village in the Southern Border. You move with a virtual analog stick, and the Gu in your **aperture grid** attack automatically. How you place the Gu matters: neighbouring Gu boost each other, and some combinations unlock **killer moves**.

## Run (Godot — the main game)

1. Install **Godot 4.7** (standard build) from godotengine.org.
2. Open Godot → **Import** → select `godot/project.godot` → Edit → press **F5** to play.

Command line (no editor needed):

```bash
tools/setup_godot.sh                 # installs the pinned Godot CLI
tools/godot.sh check                 # compile every script
tools/godot.sh test                  # run GDScript tests
tools/godot.sh shot res://scenes/main.tscn shot.png 30 1280x720 -- --autostart=1 --at=wild --enemies=4
```

### Web prototype (reference only)

```bash
npm install && npm run dev
```

## Controls

| Action | Desktop | Mobile |
|---|---|---|
| Move | WASD / arrows | drag on the left side of the screen |
| Interact (chop, mine, talk) | E / Space | big round action button |
| Aperture grid | Tab / I | Aperture |
| Bag / Craft & Refine / Map | B / C / M | Bag / Refine / tap minimap |
| Absorb primeval stone (restore essence) | Q | Absorb |
| Rotate selected Gu | R | Rotate button |

## Project layout

```
godot/                 the game (Godot 4.7, GDScript)
  data/                Gu, killer moves, items, recipes, shops, enemies   <- balance lives here
  game/                Game autoload (rules, saves), aperture logic, combat, fx, pickups
  world/               procedural Southern Border data, tileset builder, world scene, props, lights
  actors/              player, enemies
  ui/                  HUD, panels (aperture editor, bag, refine, shop, cultivation, caravan), title
  tests/               GDScript tests (tools/godot.sh test)
  tools/               screenshot + script-check harnesses
src/, index.html       original web prototype (TypeScript), kept as reference
tools/                 setup_godot.sh, godot.sh
docs/GDD.md            design document + roadmap
```

See [docs/GDD.md](docs/GDD.md) for the full design and roadmap.
