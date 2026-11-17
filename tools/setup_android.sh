#!/usr/bin/env bash
# Installs what Godot needs to export an Android APK: export templates, the Android SDK
# (cmdline-tools, platform-tools, build-tools, platform), and the editor-setting paths.
# Needs network access to github.com and dl.google.com. JDK 17+ must be installed.
# Idempotent. Usage: tools/setup_android.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK="${ANDROID_SDK_ROOT:-$HOME/android-sdk}"
"$ROOT/tools/setup_godot.sh" --templates >/dev/null

if [ ! -x "$SDK/cmdline-tools/latest/bin/sdkmanager" ]; then
  echo "Installing Android command-line tools..."
  mkdir -p "$SDK" && cd "$SDK"
  curl -fsSL -o cmdline.zip https://dl.google.com/android/repository/commandlinetools-linux-9862592_latest.zip
  unzip -oq cmdline.zip && rm cmdline.zip
  mkdir -p cmdline-tools/latest
  for f in bin lib source.properties NOTICE.txt; do [ -e "cmdline-tools/$f" ] && mv "cmdline-tools/$f" cmdline-tools/latest/; done
fi
SM="$SDK/cmdline-tools/latest/bin/sdkmanager"
yes | "$SM" --sdk_root="$SDK" --licenses >/dev/null 2>&1 || true
"$SM" --sdk_root="$SDK" "platform-tools" "build-tools;35.0.0" "platforms;android-35" >/dev/null

# Point Godot at the SDK and JDK (editor settings are created on first editor run)
CFG="$HOME/.config/godot/editor_settings-4.7.tres"
[ -f "$CFG" ] || godot --headless --editor --quit >/dev/null 2>&1 || true
JDK="$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")"
if [ -f "$CFG" ]; then
  sed -i "s|^export/android/android_sdk_path = .*|export/android/android_sdk_path = \"$SDK\"|" "$CFG"
  sed -i "s|^export/android/java_sdk_path = .*|export/android/java_sdk_path = \"$JDK\"|" "$CFG"
  grep -q '^export/android/android_sdk_path' "$CFG" || echo "export/android/android_sdk_path = \"$SDK\"" >> "$CFG"
fi
echo "Android export ready (SDK: $SDK, JDK: $JDK)"
