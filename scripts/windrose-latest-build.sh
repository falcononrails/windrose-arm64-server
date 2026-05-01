#!/usr/bin/env bash
set -euo pipefail

APP_ID="${WINDROSE_APP_ID:-4129620}"
STEAMCMD="${STEAMCMD:-/home/steam/steamcmd/steamcmd.sh}"

"$STEAMCMD" +login anonymous +app_info_print "$APP_ID" +quit 2>/dev/null \
  | awk 'f && /"buildid"/ { gsub(/"/, ""); print $2; exit } /"branches"/ { f=1 }'
