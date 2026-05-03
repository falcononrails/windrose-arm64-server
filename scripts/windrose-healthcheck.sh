#!/usr/bin/env bash
set -euo pipefail

SERVER_DIR="${SERVER_DIR:-/server}"
SERVER_EXEC="$SERVER_DIR/R5/Binaries/Win64/WindroseServer-Win64-Shipping.exe"
SERVER_LOG="$SERVER_DIR/R5/Saved/Logs/R5.log"

for proc in /proc/[0-9]*; do
  cmdline="$(tr '\0' ' ' < "$proc/cmdline" 2>/dev/null || true)"
  case "$cmdline" in
    "$SERVER_EXEC"|"$SERVER_EXEC "*|*"WindroseServer-Win64-Shipping.exe"*)
      if [ -f "$SERVER_LOG" ]; then
        if grep -Fq "Host server is ready for owner to connect" "$SERVER_LOG"; then
          exit 0
        fi
        if grep -Eq "SetBrokenState|Cannot create Coop NetServer|Server Authorization failed|Server registration finished with error|Cannot establish connection to HTTP server" "$SERVER_LOG"; then
          exit 1
        fi
      fi
      exit 0
      ;;
  esac
done

exit 1
