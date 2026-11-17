#!/usr/bin/env bash
# CLI wrapper for working on the Godot project without the editor GUI.
#   tools/godot.sh check                         import project + report script errors
#   tools/godot.sh test [filter]                 run GDScript tests in godot/tests (exit 1 on failure)
#   tools/godot.sh shot <scene> <out.png> [frames=30] [WxH=1280x720] [-- extra args for the scene]
#                                                render a scene under a virtual display and save a frame
#   tools/godot.sh run [godot args...]           anything else, headless
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJ="$ROOT/godot"
command -v godot >/dev/null || "$ROOT/tools/setup_godot.sh" >/dev/null
# Filter Godot's harmless container noise (no audio device)
quiet() { grep -v -E '^ALSA lib|V-Sync|set_use_vsync|^\s*$' || true; }
G=(godot --audio-driver Dummy)

cmd="${1:-}"; shift || true
case "$cmd" in
  check)
    out=$("${G[@]}" --headless --path "$PROJ" --import 2>&1 | quiet)
    errs=$(echo "$out" | grep -E -A2 'SCRIPT ERROR|Parse Error|ERROR:' || true)
    if [ -n "$errs" ]; then echo "$errs"; exit 1; fi
    "${G[@]}" --headless --path "$PROJ" -s res://tools/check_scripts.gd 2>&1 | quiet | grep -v '^Godot Engine'
    exit "${PIPESTATUS[0]}" ;;
  test)
    "${G[@]}" --headless --path "$PROJ" -s res://tests/run_tests.gd -- "${1:-}" 2>&1 | quiet
    exit "${PIPESTATUS[0]}" ;;
  shot)
    scene="$1"; out="$2"; frames="${3:-30}"; size="${4:-1280x720}"; shift 4 2>/dev/null || shift $#
    [ "${1:-}" = "--" ] && shift
    w="${size%x*}"; h="${size#*x}"
    case "$out" in /*) ;; *) out="$PWD/$out";; esac
    xvfb-run -a -s "-screen 0 ${w}x${h}x24" "${G[@]}" --path "$PROJ" --rendering-driver opengl3 \
      --resolution "$size" -s res://tools/capture.gd -- --scene="$scene" --out="$out" --frames="$frames" "$@" 2>&1 | quiet ;;
  run) "${G[@]}" --headless --path "$PROJ" "$@" 2>&1 | quiet ;;
  *) sed -n '2,9p' "$0"; exit 1 ;;
esac
