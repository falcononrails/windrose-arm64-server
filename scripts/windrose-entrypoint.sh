#!/usr/bin/env bash
set -euo pipefail

SERVER_DIR="${SERVER_DIR:-/server}"
WINEPREFIX="${WINEPREFIX:-/home/steam/.wine}"
WINDROSE_VERSION_DIR="${WINDROSE_VERSION_DIR:-/versions}"
PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

if [ "$(id -u)" -ne 0 ]; then
  exec windrose-run
fi

if getent group steam >/dev/null 2>&1; then
  current_gid="$(getent group steam | cut -d: -f3)"
  if [ "$current_gid" != "$PGID" ]; then
    groupmod -o -g "$PGID" steam
  fi
fi

if id steam >/dev/null 2>&1; then
  current_uid="$(id -u steam)"
  if [ "$current_uid" != "$PUID" ]; then
    usermod -o -u "$PUID" steam
  fi
fi

install -d -m 0755 -o steam -g steam "$SERVER_DIR" "$WINEPREFIX" "$WINDROSE_VERSION_DIR" /home/steam
chown -R steam:steam "$SERVER_DIR" "$WINEPREFIX" "$WINDROSE_VERSION_DIR" /home/steam

exec gosu steam windrose-run
