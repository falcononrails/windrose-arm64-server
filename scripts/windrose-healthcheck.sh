#!/usr/bin/env bash
set -euo pipefail

SERVER_DIR="${SERVER_DIR:-/server}"
SERVER_EXEC="$SERVER_DIR/R5/Binaries/Win64/WindroseServer-Win64-Shipping.exe"
SERVER_LOG="$SERVER_DIR/R5/Saved/Logs/R5.log"
WINDROSE_CONTROL_DIR="${WINDROSE_CONTROL_DIR:-$SERVER_DIR/windrose_panel_data}"
RUNTIME_STATE="$WINDROSE_CONTROL_DIR/runtime_state.json"

runtime_state() {
  [ -f "$RUNTIME_STATE" ] || return 0
  sed -n 's/.*"state"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$RUNTIME_STATE" | head -1
}

case "$(runtime_state)" in
  ready|stopped)
    exit 0
    ;;
esac

for proc in /proc/[0-9]*; do
  cmdline="$(tr '\0' ' ' < "$proc/cmdline" 2>/dev/null || true)"
  case "$cmdline" in
    "$SERVER_EXEC"|"$SERVER_EXEC "*|*"WindroseServer-Win64-Shipping.exe"*)
      if [ -f "$SERVER_LOG" ]; then
        if grep -Eq "SetBrokenState|Cannot create Coop NetServer|Server Authorization failed|Server registration finished with error|Cannot establish connection to HTTP server" "$SERVER_LOG"; then
          exit 1
        fi
      fi
      exit 1
      ;;
  esac
done

exit 1
