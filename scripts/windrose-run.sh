#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[windrose] %s\n' "$*"
}

is_truthy() {
  case "${1,,}" in
    1|true|yes|y|on) return 0 ;;
    *) return 1 ;;
  esac
}

require_number() {
  local name="$1"
  local value="$2"
  if ! [[ "$value" =~ ^[0-9]+$ ]]; then
    log "$name must be a positive integer, got: $value"
    exit 64
  fi
}

SERVER_DIR="${SERVER_DIR:-/server}"
WINEPREFIX="${WINEPREFIX:-/home/steam/.wine}"
WINDROSE_APP_ID="${WINDROSE_APP_ID:-4129620}"
STEAMCMD="${STEAMCMD:-/home/steam/steamcmd/steamcmd.sh}"

SERVER_NAME="${SERVER_NAME:-Windrose ARM64}"
SERVER_PASSWORD="${SERVER_PASSWORD:-}"
SERVER_INVITE_CODE="${SERVER_INVITE_CODE:-}"
MAX_PLAYERS="${MAX_PLAYERS:-8}"
USER_SELECTED_REGION="${USER_SELECTED_REGION:-EU}"
UPDATE_ON_START="${UPDATE_ON_START:-true}"
USE_DIRECT_CONNECTION="${USE_DIRECT_CONNECTION:-false}"
SERVER_PORT="${SERVER_PORT:-7777}"
DIRECT_CONNECTION_PROXY_ADDRESS="${DIRECT_CONNECTION_PROXY_ADDRESS:-0.0.0.0}"
P2P_PROXY_ADDRESS="${P2P_PROXY_ADDRESS:-127.0.0.1}"
CONFIG_BOOT_TIMEOUT="${CONFIG_BOOT_TIMEOUT:-420}"
EXTRA_ARGS="${EXTRA_ARGS:-}"

export WINEPREFIX
export WINEDEBUG="${WINEDEBUG:--all}"
export HODLL64="${HODLL64:-libarm64ecfex.dll}"
export WINEDLLOVERRIDES="${WINEDLLOVERRIDES:-mscoree,mshtml=;dwmapi=n,b;version=n,b}"
export HOME="${HOME:-/home/steam}"

require_number "MAX_PLAYERS" "$MAX_PLAYERS"
require_number "SERVER_PORT" "$SERVER_PORT"
require_number "CONFIG_BOOT_TIMEOUT" "$CONFIG_BOOT_TIMEOUT"
if [ -n "$SERVER_INVITE_CODE" ] && ! [[ "$SERVER_INVITE_CODE" =~ ^[0-9A-Za-z]{6,}$ ]]; then
  log "SERVER_INVITE_CODE must be at least 6 alphanumeric characters"
  exit 64
fi

SERVER_EXEC="$SERVER_DIR/R5/Binaries/Win64/WindroseServer-Win64-Shipping.exe"
SERVER_DESCRIPTION="$SERVER_DIR/R5/ServerDescription.json"
SERVER_LOG="$SERVER_DIR/R5/Saved/Logs/R5.log"

windrose_process_running() {
  local proc cmdline
  for proc in /proc/[0-9]*; do
    cmdline="$(tr '\0' ' ' < "$proc/cmdline" 2>/dev/null || true)"
    case "$cmdline" in
      "$SERVER_EXEC"|"$SERVER_EXEC "*) return 0 ;;
    esac
  done
  return 1
}

update_server_once() {
  "$STEAMCMD" \
    +@sSteamCmdForcePlatformType windows \
    +force_install_dir "$SERVER_DIR" \
    +login anonymous \
    +app_update "$WINDROSE_APP_ID" validate \
    +quit
}

update_server() {
  local attempt status
  for attempt in 1 2 3; do
    log "Installing or updating Windrose dedicated server with SteamCMD (attempt $attempt/3)"
    set +e
    update_server_once
    status=$?
    set -e

    if [ "$status" -eq 0 ] && [ -x "$SERVER_EXEC" ]; then
      return 0
    fi

    if [ -x "$SERVER_EXEC" ]; then
      log "SteamCMD returned status $status, continuing with the existing server install"
      return 0
    fi

    if [ "$attempt" -lt 3 ]; then
      log "SteamCMD did not leave a runnable server executable yet; retrying"
      sleep 5
    fi
  done

  log "SteamCMD did not install $SERVER_EXEC"
  return 66
}

init_wine_prefix() {
  if [ -f "$WINEPREFIX/system.reg" ]; then
    return
  fi

  log "Initializing Hangover/Wine prefix"
  xvfb-run -a wineboot -u || true
  wineserver -w || true
}

find_world_description() {
  if [ ! -f "$SERVER_DESCRIPTION" ]; then
    return 1
  fi

  local world_id
  world_id="$(jq -r '.ServerDescription_Persistent.WorldIslandId // .ServerDescription_Persistent.WorldID // empty' "$SERVER_DESCRIPTION" 2>/dev/null || true)"
  local found
  if [ -n "$world_id" ]; then
    found="$(find "$SERVER_DIR/R5/Saved/SaveProfiles/Default/RocksDB" \
      -path "*/Worlds/$world_id/WorldDescription.json" \
      -print -quit 2>/dev/null || true)"
    if [ -n "$found" ]; then
      printf '%s\n' "$found"
      return 0
    fi
  fi

  found="$(find "$SERVER_DIR/R5/Saved/SaveProfiles/Default/RocksDB" \
    -path "*/Worlds/*/WorldDescription.json" \
    -print -quit 2>/dev/null || true)"
  if [ -n "$found" ]; then
    printf '%s\n' "$found"
    return 0
  fi

  return 1
}

generate_initial_config() {
  if [ -f "$SERVER_DESCRIPTION" ]; then
    return
  fi

  log "Booting once so Windrose can create server settings"
  set +e
  xvfb-run -a wine "$SERVER_EXEC" -log -unattended -nullrhi $EXTRA_ARGS &
  local boot_pid=$!
  set -e

  local waited=0
  while [ "$waited" -lt "$CONFIG_BOOT_TIMEOUT" ]; do
    if [ -f "$SERVER_DESCRIPTION" ] && find_world_description >/dev/null 2>&1; then
      break
    fi
    sleep 2
    waited=$((waited + 2))
  done

  if kill -0 "$boot_pid" >/dev/null 2>&1; then
    pkill -TERM -P "$boot_pid" >/dev/null 2>&1 || true
    kill -TERM "$boot_pid" >/dev/null 2>&1 || true
    sleep 3
    pkill -KILL -P "$boot_pid" >/dev/null 2>&1 || true
    kill -KILL "$boot_pid" >/dev/null 2>&1 || true
  fi
  wait "$boot_pid" >/dev/null 2>&1 || true
  wineserver -k >/dev/null 2>&1 || true
  pkill -x Xvfb >/dev/null 2>&1 || true

  if [ ! -f "$SERVER_DESCRIPTION" ]; then
    log "Windrose did not create $SERVER_DESCRIPTION within ${CONFIG_BOOT_TIMEOUT}s"
    exit 70
  fi
}

patch_settings() {
  local direct_json=false
  local port_json=-1
  local password_protected_json=false
  local invite_log="preserve"
  if is_truthy "$USE_DIRECT_CONNECTION"; then
    direct_json=true
    port_json="$SERVER_PORT"
  fi
  if [ -n "$SERVER_PASSWORD" ]; then
    password_protected_json=true
  fi
  if [ -n "$SERVER_INVITE_CODE" ]; then
    invite_log="custom"
  fi

  log "Applying server settings: name=$SERVER_NAME max_players=$MAX_PLAYERS direct=$direct_json password_protected=$password_protected_json invite=$invite_log"
  local tmp
  tmp="$(mktemp)"
  jq \
    --arg server_name "$SERVER_NAME" \
    --arg password "$SERVER_PASSWORD" \
    --arg invite_code "$SERVER_INVITE_CODE" \
    --arg region "$USER_SELECTED_REGION" \
    --arg p2p_proxy "$P2P_PROXY_ADDRESS" \
    --arg direct_proxy "$DIRECT_CONNECTION_PROXY_ADDRESS" \
    --argjson max_players "$MAX_PLAYERS" \
    --argjson password_protected "$password_protected_json" \
    --argjson direct "$direct_json" \
    --argjson direct_port "$port_json" \
    '
      if ($invite_code | length) > 0 then
        .ServerDescription_Persistent.InviteCode = $invite_code
      else
        .
      end |
      .ServerDescription_Persistent.ServerName = $server_name |
      .ServerDescription_Persistent.IsPasswordProtected = $password_protected |
      .ServerDescription_Persistent.Password = $password |
      .ServerDescription_Persistent.UserSelectedRegion = $region |
      .ServerDescription_Persistent.P2pProxyAddress = $p2p_proxy |
      .ServerDescription_Persistent.MaxPlayerCount = $max_players |
      .ServerDescription_Persistent.UseDirectConnection = $direct |
      .ServerDescription_Persistent.DirectConnectionServerPort = $direct_port |
      .ServerDescription_Persistent.DirectConnectionProxyAddress = $direct_proxy
    ' "$SERVER_DESCRIPTION" > "$tmp"
  mv "$tmp" "$SERVER_DESCRIPTION"

  local world_description
  world_description="$(find_world_description || true)"
  if [ -n "$world_description" ]; then
    tmp="$(mktemp)"
    jq --arg world_name "$SERVER_NAME" '.WorldDescription.WorldName = $world_name' "$world_description" > "$tmp"
    mv "$tmp" "$world_description"
  fi
}

start_server_foreground() {
  local run_pid tail_pid status saw_process=0 deadline
  deadline=$((SECONDS + 180))

  mkdir -p "$(dirname "$SERVER_LOG")"
  touch "$SERVER_LOG" || true

  tail -n 0 -F "$SERVER_LOG" &
  tail_pid=$!

  set +e
  xvfb-run -a wine "$SERVER_EXEC" -log -unattended -nullrhi $EXTRA_ARGS &
  run_pid=$!
  set -e

  stop_server() {
    log "Stopping Windrose dedicated server"
    kill -TERM "$run_pid" >/dev/null 2>&1 || true
    pkill -TERM -P "$run_pid" >/dev/null 2>&1 || true
    sleep 3
    kill -KILL "$run_pid" >/dev/null 2>&1 || true
    pkill -KILL -P "$run_pid" >/dev/null 2>&1 || true
    kill "$tail_pid" >/dev/null 2>&1 || true
    wineserver -k >/dev/null 2>&1 || true
    pkill -x Xvfb >/dev/null 2>&1 || true
  }

  trap 'stop_server; exit 143' TERM INT

  while kill -0 "$run_pid" >/dev/null 2>&1; do
    if windrose_process_running; then
      saw_process=1
    elif [ "$saw_process" -eq 1 ]; then
      log "Windrose process exited while the wrapper was still running"
      stop_server
      wait "$run_pid" >/dev/null 2>&1 || true
      return 1
    elif [ "$SECONDS" -ge "$deadline" ]; then
      log "Windrose process did not become visible within 180 seconds"
      stop_server
      wait "$run_pid" >/dev/null 2>&1 || true
      return 1
    fi
    sleep 5
  done

  set +e
  wait "$run_pid"
  status=$?
  set -e

  trap - TERM INT
  kill "$tail_pid" >/dev/null 2>&1 || true
  wineserver -k >/dev/null 2>&1 || true
  pkill -x Xvfb >/dev/null 2>&1 || true

  return "$status"
}

if [ ! -x "$SERVER_EXEC" ] || is_truthy "$UPDATE_ON_START"; then
  update_server
fi

if [ ! -x "$SERVER_EXEC" ]; then
  log "Windrose server executable was not found at $SERVER_EXEC"
  exit 66
fi

init_wine_prefix
generate_initial_config
patch_settings

log "Starting Windrose dedicated server"
start_server_foreground
