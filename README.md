# Gu Wilds (ReveInsa)

A survival game set in the *Reverend Insanity* world, with a new story. You play a young Gu Master of Shi Lan Village in the Southern Border. You move with a virtual analog stick, and the Gu in your **aperture grid** attack automatically. How you place the Gu matters: neighbouring Gu boost each other, and some combinations unlock **killer moves**.

## Run

```bash
npm install
npm run dev      # open the printed URL (works on a phone on the same network)
npm run build    # static build in dist/ (deployable to GitHub Pages etc.)
```

## Controls

| Action | Desktop | Mobile |
|---|---|---|
| Move | WASD / arrows | drag on the left side of the screen |
| Interact (chop, mine, talk) | E / Space | big round button |
| Aperture grid | Tab / I | 窍 |
| Bag / Craft & Refine / Map | B / C / M | 囊 / 炼 / minimap |
| Absorb primeval stone (restore essence) | Q | 元 |
| Rotate selected Gu | R | Rotate button |

## Project layout

```
src/
  core/      input (keyboard + virtual stick), rng/noise
  data/      Gu, killer moves, items, recipes, shops, enemies   ← balance lives here
  world/     procedural Southern Border, regional walls, POIs, resource nodes
  game/      aperture grid logic, simulation, combat, rendering
  ui/        HUD, panels (aperture editor, bag, refine, shop, cultivation, caravan)
docs/GDD.md  design document + roadmap
```

See [docs/GDD.md](docs/GDD.md) for the full design and roadmap.
