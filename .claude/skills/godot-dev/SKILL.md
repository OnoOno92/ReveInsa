---
name: godot-dev
description: Build, test, and visually verify the Gu Wilds Godot 4 project from the command line (no editor GUI). Use for any work under godot/ — writing GDScript or .tscn scenes, running tests, checking for script errors, or taking screenshots to see what a scene looks like.
---

# Godot development workflow (Gu Wilds)

The game lives in `godot/` (Godot **4.7.2**, GL Compatibility renderer so it runs on mobile and web).
There is no editor GUI here: everything is plain text files plus the CLI wrapper `tools/godot.sh`.
The user opens the same project in their own Godot editor by pulling the branch.

## Setup (once per container)

```bash
tools/setup_godot.sh              # installs pinned Godot to ~/.local/share/godot-cli and links `godot`
tools/setup_godot.sh --templates  # + export templates (~1 GB) only when you need to export web/Android builds
```

`tools/godot.sh` runs the setup automatically if `godot` is missing.

## The loop — do this after every meaningful change

1. **`tools/godot.sh check`** — imports the project and compiles *every* `.gd` file. It prints parse errors with file:line and exits 1 on failure. Never report work as done while this fails.
2. **`tools/godot.sh test [filter]`** — runs `godot/tests/test_*.gd`. Add tests for pure logic (aperture placement, synergies, combat math, save/load).
3. **`tools/godot.sh shot <res://scene.tscn> <out.png> [frames] [WxH] [-- --key=value ...]`** — renders the scene under Xvfb for N frames and saves the viewport. **Read the PNG** to actually see the result. Use `960x540` or a phone size such as `540x1170` to check the mobile layout. Save shots to the scratchpad, not the repo.
   - Extra `--key=value` args reach the scene through `get_tree().root.get_meta("capture_args", {})`. Use them to set up a debug state (e.g. `--night=1`, `--spawn=wolf`) so the screenshot shows the thing you changed.
   - Rendering is software (llvmpipe), so it's slow: keep frames ≤ 60.

## Writing Godot files by hand

- **GDScript:** use static typing (`var hp: float`, `-> void`), `@export` for tunables, and signals for UI updates. Tabs for indentation.
- **Scenes (`.tscn`):** keep them minimal and build node trees in code (`_ready`) when that's simpler. Header: `[gd_scene load_steps=N format=3]`. `ext_resource` ids are strings, and `uid=` can be omitted. When a scene gets complex, prefer building it in code over hand-writing big `.tscn` files.
- **Autoloads (singletons):** register them in `project.godot` under `[autoload]` as `Name="*res://path.gd"`.
- **Data:** game data (Gu, items, enemies, recipes) lives in `godot/data/*.gd` as typed dictionaries/const arrays or custom `Resource` classes. Keep balance numbers there, not in logic.
- **Input:** desktop WASD plus a touch virtual stick. `emulate_touch_from_mouse` is on, so handle `InputEventScreenTouch/Drag`.
- **Assets:** after adding images or audio, run `tools/godot.sh check`; the `--import` step generates the `.import` files. `.godot/` and `*.import` are gitignored.
- `class_name` globals are only registered after an import. If a new `class_name` isn't found, run `check` once more.

## Gotchas

- A `SceneTree` script that `load()`s itself with `CACHE_MODE_IGNORE` hangs, which is why `check_scripts.gd` skips itself.
- No audio device in the container: the wrapper passes `--audio-driver Dummy`.
- `print()` output comes back through the wrapper; use it for quick debugging in tests or shots.
