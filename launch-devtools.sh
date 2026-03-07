#!/bin/bash
# Launcher with DevTools enabled for debugging

# Change to script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Resolve electron binary: prefer system electron + local .asar-cache, fall back to AppImage
if command -v electron >/dev/null 2>&1; then
  ELECTRON_BIN="$(command -v electron)"
  ASAR_FILE=".asar-cache/app.asar"
elif [[ -x "./squashfs-root/usr/lib/node_modules/electron/dist/electron" ]]; then
  ELECTRON_BIN="./squashfs-root/usr/lib/node_modules/electron/dist/electron"
  ASAR_FILE="squashfs-root/usr/lib/node_modules/electron/dist/resources/app.asar"
else
  echo "ERROR: No electron binary found. Install electron or place an AppImage in squashfs-root/"
  exit 1
fi

# Enable logging and DevTools
export ELECTRON_ENABLE_LOGGING=1
export CLAUDE_ENABLE_LOGGING=1

# Wayland support
if [[ -n "$WAYLAND_DISPLAY" ]] || [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
  export ELECTRON_OZONE_PLATFORM_HINT=wayland
  echo "Wayland detected, using Ozone platform"
fi

# Create log directory
LOG_DIR="$HOME/.local/share/claude-cowork/logs"
mkdir -p "$LOG_DIR"

# Launch with DevTools (--inspect enables Node.js inspector)
exec "$ELECTRON_BIN" \
  "./${ASAR_FILE}" \
  --no-sandbox \
  --disable-gpu \
  --inspect "$@" 2>&1 | tee -a "$LOG_DIR/startup.log"
