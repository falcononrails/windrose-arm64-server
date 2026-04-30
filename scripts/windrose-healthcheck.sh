#!/usr/bin/env bash
set -euo pipefail

SERVER_DIR="${SERVER_DIR:-/server}"
SERVER_EXEC="$SERVER_DIR/R5/Binaries/Win64/WindroseServer-Win64-Shipping.exe"

for proc in /proc/[0-9]*; do
  cmdline="$(tr '\0' ' ' < "$proc/cmdline" 2>/dev/null || true)"
  case "$cmdline" in
    "$SERVER_EXEC"|"$SERVER_EXEC "*) exit 0 ;;
  esac
done

exit 1
