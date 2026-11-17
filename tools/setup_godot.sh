#!/usr/bin/env bash
# Installs a pinned Godot (headless-capable editor binary) for CLI use.
# Idempotent. Usage: tools/setup_godot.sh [--templates]
#   --templates  also install export templates (needed for web/Android exports, ~1 GB)
set -euo pipefail
GODOT_VERSION="${GODOT_VERSION:-4.7.2}"
GODOT_HOME="${GODOT_HOME:-$HOME/.local/share/godot-cli}"
BIN="$GODOT_HOME/Godot_v${GODOT_VERSION}-stable_linux.x86_64"
BASE="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable"

mkdir -p "$GODOT_HOME"
if [ ! -x "$BIN" ]; then
  echo "Downloading Godot $GODOT_VERSION..."
  curl -fsSL -o "$GODOT_HOME/godot.zip" "$BASE/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
  unzip -oq "$GODOT_HOME/godot.zip" -d "$GODOT_HOME" && rm "$GODOT_HOME/godot.zip"
  chmod +x "$BIN"
fi

# Put `godot` on PATH
LINK_DIR=/usr/local/bin; [ -w "$LINK_DIR" ] || { LINK_DIR="$HOME/.local/bin"; mkdir -p "$LINK_DIR"; }
ln -sf "$BIN" "$LINK_DIR/godot"

if [ "${1:-}" = "--templates" ]; then
  TPL_DIR="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable"
  if [ ! -f "$TPL_DIR/version.txt" ]; then
    echo "Downloading export templates..."
    # Large file: resume partial downloads and retry dropped connections.
    for attempt in 1 2 3 4 5; do
      curl -fsSL -C - --retry 3 -o "$GODOT_HOME/tpl.tpz" "$BASE/Godot_v${GODOT_VERSION}-stable_export_templates.tpz" && break
      echo "download interrupted, resuming (attempt $attempt)..."; sleep 3
    done
    mkdir -p "$TPL_DIR"
    unzip -oq "$GODOT_HOME/tpl.tpz" -d "$GODOT_HOME/tpl" && mv "$GODOT_HOME"/tpl/templates/* "$TPL_DIR/" || { echo "template install failed"; exit 1; }
    rm -rf "$GODOT_HOME/tpl" "$GODOT_HOME/tpl.tpz"
  fi
fi
godot --version
