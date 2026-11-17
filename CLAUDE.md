# Gu Wilds (ReveInsa)

A fan survival game set in the *Reverend Insanity* world, with an original story (not Fang Yuan's). Design and roadmap: `docs/GDD.md`.

## Layout
- `godot/` — **the real game** (Godot 4.7.2, GDScript). All new work goes here.
- `src/`, `index.html` — the first web prototype (TypeScript + Vite). It's the reference for porting: data in `src/data/`, aperture rules in `src/game/aperture.ts`. Don't extend it.
- `tools/` — `setup_godot.sh` (installs pinned Godot), `godot.sh` (check / test / shot).

## Workflow
Use the `godot-dev` skill (`.claude/skills/godot-dev/SKILL.md`). Before calling any change done:
1. `tools/godot.sh check` passes
2. `tools/godot.sh test` passes
3. For anything visual, take a `tools/godot.sh shot` and look at it, at desktop and phone sizes.

## Design rules
- Combat is automatic: the player only moves (virtual stick / WASD). Gu placed in the aperture grid fire on their own.
- Aperture grid = Rank + 3 cells per side. Adjacency drives auras, path resonance and killer moves.
- Gu must be fed or they starve and die. Primeval stones are both currency and essence.
- Use original names for characters and places. RI world concepts and Gu names are fine.
