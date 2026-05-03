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

require_float() {
  local name="$1"
  local value="$2"
  if ! [[ "$value" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    log "$name must be a positive number, got: $value"
    exit 64
  fi
}

require_bool() {
  local name="$1"
  local value="${2,,}"
  case "$value" in
    1|true|yes|y|on|0|false|no|n|off) ;;
    *)
      log "$name must be a boolean, got: $2"
      exit 64
      ;;
  esac
}

normalize_choice() {
  local name="$1"
  local value="${2,,}"
  shift 2
  local choice
  for choice in "$@"; do
    if [ "$value" = "${choice,,}" ]; then
      printf '%s\n' "$choice"
      return 0
    fi
  done

  log "$name must be one of: $*"
  exit 64
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
SERVER_CRASH_RESTART_ATTEMPTS="${SERVER_CRASH_RESTART_ATTEMPTS:-3}"
SERVER_CRASH_RESTART_DELAY="${SERVER_CRASH_RESTART_DELAY:-45}"
SERVER_CRASH_RESTART_RESET_AFTER="${SERVER_CRASH_RESTART_RESET_AFTER:-600}"
SERVER_READY_TIMEOUT="${SERVER_READY_TIMEOUT:-300}"
SERVER_BROKEN_REGISTRATION_RESTART_DELAY="${SERVER_BROKEN_REGISTRATION_RESTART_DELAY:-30}"
EXTRA_ARGS="${EXTRA_ARGS:-}"

WORLD_PRESET_TYPE="${WORLD_PRESET_TYPE:-}"
COMBAT_DIFFICULTY="${COMBAT_DIFFICULTY:-}"
MOB_HEALTH_MULTIPLIER="${MOB_HEALTH_MULTIPLIER:-}"
MOB_DAMAGE_MULTIPLIER="${MOB_DAMAGE_MULTIPLIER:-}"
SHIP_HEALTH_MULTIPLIER="${SHIP_HEALTH_MULTIPLIER:-}"
SHIP_DAMAGE_MULTIPLIER="${SHIP_DAMAGE_MULTIPLIER:-}"
BOARDING_DIFFICULTY_MULTIPLIER="${BOARDING_DIFFICULTY_MULTIPLIER:-}"
COOP_STATS_CORRECTION_MULTIPLIER="${COOP_STATS_CORRECTION_MULTIPLIER:-}"
COOP_SHIP_STATS_CORRECTION_MULTIPLIER="${COOP_SHIP_STATS_CORRECTION_MULTIPLIER:-}"
COOP_SHARED_QUESTS="${COOP_SHARED_QUESTS:-}"
EASY_EXPLORE="${EASY_EXPLORE:-}"

ENABLE_WINDROSE_PLUS="${ENABLE_WINDROSE_PLUS:-false}"
WINDROSE_PLUS_VERSION="${WINDROSE_PLUS_VERSION:-latest}"
WINDROSE_PLUS_RCON_PASSWORD="${WINDROSE_PLUS_RCON_PASSWORD:-}"
WINDROSE_PLUS_HTTP_PORT="${WINDROSE_PLUS_HTTP_PORT:-8780}"
WINDROSE_PLUS_BIND_IP="${WINDROSE_PLUS_BIND_IP:-0.0.0.0}"
WINDROSE_PLUS_DASHBOARD="${WINDROSE_PLUS_DASHBOARD:-true}"
WINDROSE_PLUS_BUILD_PAK="${WINDROSE_PLUS_BUILD_PAK:-false}"

ENABLE_PANEL="${ENABLE_PANEL:-false}"
PANEL_HOST="${PANEL_HOST:-0.0.0.0}"
PANEL_PORT="${PANEL_PORT:-8790}"
PANEL_PASSWORD="${PANEL_PASSWORD:-}"
PANEL_SECRET="${PANEL_SECRET:-}"
WINDROSE_VERSION_DIR="${WINDROSE_VERSION_DIR:-/versions}"
WINDROSE_CONTROL_DIR="${WINDROSE_CONTROL_DIR:-$SERVER_DIR/windrose_panel_data}"
WINDROSE_VERSION_PIN_FILE="${WINDROSE_VERSION_PIN_FILE:-$WINDROSE_VERSION_DIR/version-pin.json}"
WINDROSE_UPDATE_LOG="${WINDROSE_UPDATE_LOG:-$WINDROSE_CONTROL_DIR/update.log}"
WINDROSE_ROLLBACK_LOG="${WINDROSE_ROLLBACK_LOG:-$WINDROSE_CONTROL_DIR/rollback.log}"
WINDROSE_STEAM_LATEST_CACHE="${WINDROSE_STEAM_LATEST_CACHE:-$WINDROSE_VERSION_DIR/steam-latest.json}"

export WINEPREFIX
export WINEDEBUG="${WINEDEBUG:--all}"
export HODLL64="${HODLL64:-libarm64ecfex.dll}"
export WINEDLLOVERRIDES="${WINEDLLOVERRIDES:-mscoree,mshtml=;dwmapi=n,b;version=n,b}"
export HOME="${HOME:-/home/steam}"

require_number "MAX_PLAYERS" "$MAX_PLAYERS"
require_number "SERVER_PORT" "$SERVER_PORT"
require_number "CONFIG_BOOT_TIMEOUT" "$CONFIG_BOOT_TIMEOUT"
require_number "SERVER_CRASH_RESTART_ATTEMPTS" "$SERVER_CRASH_RESTART_ATTEMPTS"
require_number "SERVER_CRASH_RESTART_DELAY" "$SERVER_CRASH_RESTART_DELAY"
require_number "SERVER_CRASH_RESTART_RESET_AFTER" "$SERVER_CRASH_RESTART_RESET_AFTER"
require_number "SERVER_READY_TIMEOUT" "$SERVER_READY_TIMEOUT"
require_number "SERVER_BROKEN_REGISTRATION_RESTART_DELAY" "$SERVER_BROKEN_REGISTRATION_RESTART_DELAY"
require_number "PANEL_PORT" "$PANEL_PORT"
[ -z "$MOB_HEALTH_MULTIPLIER" ] || require_float "MOB_HEALTH_MULTIPLIER" "$MOB_HEALTH_MULTIPLIER"
[ -z "$MOB_DAMAGE_MULTIPLIER" ] || require_float "MOB_DAMAGE_MULTIPLIER" "$MOB_DAMAGE_MULTIPLIER"
[ -z "$SHIP_HEALTH_MULTIPLIER" ] || require_float "SHIP_HEALTH_MULTIPLIER" "$SHIP_HEALTH_MULTIPLIER"
[ -z "$SHIP_DAMAGE_MULTIPLIER" ] || require_float "SHIP_DAMAGE_MULTIPLIER" "$SHIP_DAMAGE_MULTIPLIER"
[ -z "$BOARDING_DIFFICULTY_MULTIPLIER" ] || require_float "BOARDING_DIFFICULTY_MULTIPLIER" "$BOARDING_DIFFICULTY_MULTIPLIER"
[ -z "$COOP_STATS_CORRECTION_MULTIPLIER" ] || require_float "COOP_STATS_CORRECTION_MULTIPLIER" "$COOP_STATS_CORRECTION_MULTIPLIER"
[ -z "$COOP_SHIP_STATS_CORRECTION_MULTIPLIER" ] || require_float "COOP_SHIP_STATS_CORRECTION_MULTIPLIER" "$COOP_SHIP_STATS_CORRECTION_MULTIPLIER"
[ -z "$COOP_SHARED_QUESTS" ] || require_bool "COOP_SHARED_QUESTS" "$COOP_SHARED_QUESTS"
[ -z "$EASY_EXPLORE" ] || require_bool "EASY_EXPLORE" "$EASY_EXPLORE"
require_number "WINDROSE_PLUS_HTTP_PORT" "$WINDROSE_PLUS_HTTP_PORT"
[ -z "$WORLD_PRESET_TYPE" ] || WORLD_PRESET_TYPE="$(normalize_choice "WORLD_PRESET_TYPE" "$WORLD_PRESET_TYPE" Easy Medium Hard)"
[ -z "$COMBAT_DIFFICULTY" ] || COMBAT_DIFFICULTY="$(normalize_choice "COMBAT_DIFFICULTY" "$COMBAT_DIFFICULTY" Easy Normal Hard)"
if [ -n "$SERVER_INVITE_CODE" ] && ! [[ "$SERVER_INVITE_CODE" =~ ^[0-9A-Za-z]{6,}$ ]]; then
  log "SERVER_INVITE_CODE must be at least 6 alphanumeric characters"
  exit 64
fi

SERVER_EXEC="$SERVER_DIR/R5/Binaries/Win64/WindroseServer-Win64-Shipping.exe"
SERVER_DESCRIPTION="$SERVER_DIR/R5/ServerDescription.json"
SERVER_LOG="$SERVER_DIR/R5/Saved/Logs/R5.log"

# shellcheck source=/usr/local/lib/windrose-plus.sh
. /usr/local/lib/windrose-plus.sh

ensure_version_dir_not_nested() {
  local server_real version_real
  server_real="$(realpath -m "$SERVER_DIR")"
  version_real="$(realpath -m "$WINDROSE_VERSION_DIR")"
  case "$version_real" in
    "$server_real"|"$server_real"/*)
      log "WINDROSE_VERSION_DIR must not be inside SERVER_DIR. Got WINDROSE_VERSION_DIR=$WINDROSE_VERSION_DIR SERVER_DIR=$SERVER_DIR"
      exit 64
      ;;
  esac
}

windrose_process_running() {
  local proc cmdline
  for proc in /proc/[0-9]*; do
    [ -r "$proc/cmdline" ] || continue
    cmdline="$(tr '\0' ' ' < "$proc/cmdline" 2>/dev/null || true)"
    case "$cmdline" in
      *"WindroseServer-Win64-Shipping.exe"*) return 0 ;;
    esac
  done
  return 1
}

manifest_build() {
  local manifest="$SERVER_DIR/steamapps/appmanifest_${WINDROSE_APP_ID}.acf"
  [ -f "$manifest" ] || return 0
  awk -F'"' '/"buildid"/{print $4; exit}' "$manifest" 2>/dev/null || true
}

version_pin_target() {
  if [ -f "$WINDROSE_VERSION_PIN_FILE" ]; then
    sed -n 's/.*"target_build"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$WINDROSE_VERSION_PIN_FILE" | head -1
  else
    printf 'latest\n'
  fi
}

snapshot_build_for_path() {
  local path="$1"
  local manifest="$path/steamapps/appmanifest_${WINDROSE_APP_ID}.acf"
  [ -f "$manifest" ] || return 0
  awk -F'"' '/"buildid"/{print $4; exit}' "$manifest" 2>/dev/null || true
}

snapshot_exists_for_build() {
  local build="$1" candidate
  [ -n "$build" ] || return 1
  [ -d "$WINDROSE_VERSION_DIR" ] || return 1
  while IFS= read -r -d '' candidate; do
    [ "$(snapshot_build_for_path "$candidate")" = "$build" ] && return 0
  done < <(find "$WINDROSE_VERSION_DIR" -maxdepth 1 -type d \( -name 'server-before-update-*' -o -name 'server-before-rollback-*' -o -name 'server-snapshot-*' \) -print0 2>/dev/null)
  return 1
}

snapshot_current_if_missing() {
  local build="$1" target stamp
  [ -n "$build" ] && [ "$build" != "unknown" ] || return 0
  mkdir -p "$WINDROSE_VERSION_DIR"
  if snapshot_exists_for_build "$build"; then
    log "Saved install already exists for Steam build $build"
    return 0
  fi
  stamp="$(date -u +%Y%m%d_%H%M%S)"
  target="$WINDROSE_VERSION_DIR/server-snapshot-pre-update-${build}-${stamp}"
  log "Saving current install before update: $target"
  cp -a "$SERVER_DIR" "$target"
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
  local pin_target current_build
  pin_target="$(version_pin_target)"
  if [ "$pin_target" != "latest" ] && [ -x "$SERVER_EXEC" ]; then
    log "Steam update skipped because server is pinned to build $pin_target"
    return 0
  fi

  current_build="$(manifest_build)"
  snapshot_current_if_missing "${current_build:-unknown}"

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
  timeout 120s wineserver -w || true
  wineserver -k >/dev/null 2>&1 || true
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

patch_world_settings() {
  local requested_settings="${WORLD_PRESET_TYPE}${COMBAT_DIFFICULTY}${MOB_HEALTH_MULTIPLIER}${MOB_DAMAGE_MULTIPLIER}${SHIP_HEALTH_MULTIPLIER}${SHIP_DAMAGE_MULTIPLIER}${BOARDING_DIFFICULTY_MULTIPLIER}${COOP_STATS_CORRECTION_MULTIPLIER}${COOP_SHIP_STATS_CORRECTION_MULTIPLIER}${COOP_SHARED_QUESTS}${EASY_EXPLORE}"
  if [ -z "$requested_settings" ]; then
    return
  fi

  local world_description
  world_description="$(find_world_description || true)"
  if [ -z "$world_description" ]; then
    log "WorldDescription.json not found; skipping world settings"
    return
  fi

  log "Applying world settings"
  local tmp
  tmp="$(mktemp)"
  jq \
    --arg world_preset "$WORLD_PRESET_TYPE" \
    --arg combat_tag "WDS.Parameter.CombatDifficulty.${COMBAT_DIFFICULTY}" \
    --arg shared "$COOP_SHARED_QUESTS" \
    --arg easy "$EASY_EXPLORE" \
    --arg mob_health "$MOB_HEALTH_MULTIPLIER" \
    --arg mob_damage "$MOB_DAMAGE_MULTIPLIER" \
    --arg ship_health "$SHIP_HEALTH_MULTIPLIER" \
    --arg ship_damage "$SHIP_DAMAGE_MULTIPLIER" \
    --arg boarding "$BOARDING_DIFFICULTY_MULTIPLIER" \
    --arg coop_stats "$COOP_STATS_CORRECTION_MULTIPLIER" \
    --arg coop_ship_stats "$COOP_SHIP_STATS_CORRECTION_MULTIPLIER" \
    --arg key_shared '{"TagName": "WDS.Parameter.Coop.SharedQuests"}' \
    --arg key_easy '{"TagName": "WDS.Parameter.EasyExplore"}' \
    --arg key_mob_health '{"TagName": "WDS.Parameter.MobHealthMultiplier"}' \
    --arg key_mob_damage '{"TagName": "WDS.Parameter.MobDamageMultiplier"}' \
    --arg key_ship_health '{"TagName": "WDS.Parameter.ShipsHealthMultiplier"}' \
    --arg key_ship_damage '{"TagName": "WDS.Parameter.ShipsDamageMultiplier"}' \
    --arg key_boarding '{"TagName": "WDS.Parameter.BoardingDifficultyMultiplier"}' \
    --arg key_coop_stats '{"TagName": "WDS.Parameter.Coop.StatsCorrectionModifier"}' \
    --arg key_coop_ship_stats '{"TagName": "WDS.Parameter.Coop.ShipStatsCorrectionModifier"}' \
    --arg key_combat '{"TagName": "WDS.Parameter.CombatDifficulty"}' \
    '
      def bool_value($value):
        ($value | ascii_downcase) as $v |
        ($v == "1" or $v == "true" or $v == "yes" or $v == "y" or $v == "on");

      if ($world_preset | length) > 0 then
        .WorldDescription.WorldPresetType = $world_preset
      else
        .
      end |
      .WorldDescription.WorldSettings = (.WorldDescription.WorldSettings // {}) |
      .WorldDescription.WorldSettings.BoolParameters = (.WorldDescription.WorldSettings.BoolParameters // {}) |
      .WorldDescription.WorldSettings.FloatParameters = (.WorldDescription.WorldSettings.FloatParameters // {}) |
      .WorldDescription.WorldSettings.TagParameters = (.WorldDescription.WorldSettings.TagParameters // {}) |
      if ($shared | length) > 0 then .WorldDescription.WorldSettings.BoolParameters[$key_shared] = bool_value($shared) else . end |
      if ($easy | length) > 0 then .WorldDescription.WorldSettings.BoolParameters[$key_easy] = bool_value($easy) else . end |
      if ($mob_health | length) > 0 then .WorldDescription.WorldSettings.FloatParameters[$key_mob_health] = ($mob_health | tonumber) else . end |
      if ($mob_damage | length) > 0 then .WorldDescription.WorldSettings.FloatParameters[$key_mob_damage] = ($mob_damage | tonumber) else . end |
      if ($ship_health | length) > 0 then .WorldDescription.WorldSettings.FloatParameters[$key_ship_health] = ($ship_health | tonumber) else . end |
      if ($ship_damage | length) > 0 then .WorldDescription.WorldSettings.FloatParameters[$key_ship_damage] = ($ship_damage | tonumber) else . end |
      if ($boarding | length) > 0 then .WorldDescription.WorldSettings.FloatParameters[$key_boarding] = ($boarding | tonumber) else . end |
      if ($coop_stats | length) > 0 then .WorldDescription.WorldSettings.FloatParameters[$key_coop_stats] = ($coop_stats | tonumber) else . end |
      if ($coop_ship_stats | length) > 0 then .WorldDescription.WorldSettings.FloatParameters[$key_coop_ship_stats] = ($coop_ship_stats | tonumber) else . end |
      if ($combat_tag | endswith(".")) then . else .WorldDescription.WorldSettings.TagParameters[$key_combat] = {"TagName": $combat_tag} end
    ' "$world_description" > "$tmp"
  mv "$tmp" "$world_description"
}

generated_secret() {
  local secret_file="$1"
  local length="${2:-32}"
  if [ -f "$secret_file" ]; then
    cat "$secret_file"
    return
  fi

  local secret
  set +o pipefail
  secret="$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$length")"
  set -o pipefail
  printf '%s\n' "$secret" > "$secret_file"
  chmod 0600 "$secret_file" 2>/dev/null || true
  printf '%s\n' "$secret"
}

start_panel() {
  PANEL_PID=""
  if ! is_truthy "$ENABLE_PANEL"; then
    return 0
  fi

  mkdir -p "$WINDROSE_CONTROL_DIR" "$WINDROSE_VERSION_DIR"
  if [ -z "$PANEL_PASSWORD" ]; then
    PANEL_PASSWORD="$(generated_secret "$SERVER_DIR/.windrose_panel_password" 32)"
    log "Generated panel password at $SERVER_DIR/.windrose_panel_password"
  fi
  if [ -z "$PANEL_SECRET" ]; then
    PANEL_SECRET="$(generated_secret "$SERVER_DIR/.windrose_panel_secret" 48)"
  fi

  export PANEL_HOST PANEL_PORT PANEL_PASSWORD PANEL_SECRET
  export WINDROSE_GAME_DIR="$SERVER_DIR"
  export WINDROSE_BACKUP_DIR="$SERVER_DIR/backups"
  export WINDROSE_PANEL_MODE=container
  export WINDROSE_CONTROL_DIR
  export WINDROSE_INSTALL_PARENT="$WINDROSE_VERSION_DIR"
  export WINDROSE_VERSION_PIN_FILE
  export WINDROSE_UPDATE_LOG
  export WINDROSE_ROLLBACK_LOG
  export WINDROSE_STEAM_LATEST_CACHE
  export SOURCE_RCON_HOST="${SOURCE_RCON_HOST:-127.0.0.1}"
  export SOURCE_RCON_PORT="${SOURCE_RCON_PORT:-27065}"

  log "Starting Windrose panel on ${PANEL_HOST}:${PANEL_PORT}"
  python3 /opt/windrose-panel/windrose_panel.py > "$WINDROSE_CONTROL_DIR/panel.log" 2>&1 &
  PANEL_PID=$!
}

stop_panel() {
  if [ -n "${PANEL_PID:-}" ]; then
    kill -TERM "$PANEL_PID" >/dev/null 2>&1 || true
    wait "$PANEL_PID" >/dev/null 2>&1 || true
    PANEL_PID=""
  fi
}

read_control_action() {
  local command_file="$WINDROSE_CONTROL_DIR/command.json"
  [ -f "$command_file" ] || return 1
  jq -r '.action // empty' "$command_file" 2>/dev/null || true
}

clear_control_action() {
  rm -f "$WINDROSE_CONTROL_DIR/command.json"
}

write_runtime_state() {
  local state="$1"
  mkdir -p "$WINDROSE_CONTROL_DIR"
  jq -n --arg state "$state" --argjson ts "$(date -u +%s)" '{state:$state,timestamp:$ts}' > "$WINDROSE_CONTROL_DIR/runtime_state.json"
}

wait_while_stopped() {
  local action
  write_runtime_state "stopped"
  log "Windrose server is stopped; panel remains available"
  while true; do
    action="$(read_control_action || true)"
    case "$action" in
      start|restart)
        clear_control_action
        write_runtime_state "starting"
        return 0
        ;;
    esac
    sleep 2
  done
}

start_server_foreground() {
  local run_pid tail_pid status saw_process=0 process_deadline ready_deadline
  local log_start_line current_log_lines recent_log ready_seen=0
  process_deadline=$((SECONDS + 180))
  ready_deadline=$((SECONDS + SERVER_READY_TIMEOUT))

  mkdir -p "$(dirname "$SERVER_LOG")"
  touch "$SERVER_LOG" || true
  log_start_line="$(wc -l < "$SERVER_LOG" 2>/dev/null || printf '0')"

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
    stop_windrose_plus_dashboard || true
    sleep 3
    kill -KILL "$run_pid" >/dev/null 2>&1 || true
    pkill -KILL -P "$run_pid" >/dev/null 2>&1 || true
    kill "$tail_pid" >/dev/null 2>&1 || true
    wineserver -k >/dev/null 2>&1 || true
    pkill -x Xvfb >/dev/null 2>&1 || true
  }

  trap 'stop_server; exit 143' TERM INT

  while kill -0 "$run_pid" >/dev/null 2>&1; do
    local action
    action="$(read_control_action || true)"
    case "$action" in
      restart)
        log "Restart requested by panel"
        clear_control_action
        stop_server
        wait "$run_pid" >/dev/null 2>&1 || true
        return 75
        ;;
      stop)
        log "Stop requested by panel"
        clear_control_action
        stop_server
        wait "$run_pid" >/dev/null 2>&1 || true
        return 76
        ;;
    esac

    if windrose_process_running; then
      saw_process=1
    elif [ "$saw_process" -eq 1 ]; then
      log "Windrose process exited while the wrapper was still running"
      stop_server
      wait "$run_pid" >/dev/null 2>&1 || true
      return 1
    elif [ "$SECONDS" -ge "$process_deadline" ]; then
      log "Windrose process did not become visible within 180 seconds"
      stop_server
      wait "$run_pid" >/dev/null 2>&1 || true
      return 1
    fi

    if [ "$ready_seen" -eq 0 ] && [ -f "$SERVER_LOG" ]; then
      current_log_lines="$(wc -l < "$SERVER_LOG" 2>/dev/null || printf '0')"
      if [ "$current_log_lines" -lt "$log_start_line" ]; then
        log_start_line=0
      fi
      if [ "$current_log_lines" -gt "$log_start_line" ]; then
        recent_log="$(tail -n +"$((log_start_line + 1))" "$SERVER_LOG" 2>/dev/null || true)"
        if printf '%s\n' "$recent_log" | grep -Fq "Host server is ready for owner to connect"; then
          ready_seen=1
          log "Windrose host registration is ready"
        elif printf '%s\n' "$recent_log" | grep -Eq "SetBrokenState|Cannot create Coop NetServer|Server Authorization failed|Server registration finished with error|Cannot establish connection to HTTP server"; then
          log "Windrose host registration failed before the server became ready"
          stop_server
          wait "$run_pid" >/dev/null 2>&1 || true
          return 77
        fi
      fi
    fi

    if [ "$ready_seen" -eq 0 ] && [ "$SECONDS" -ge "$ready_deadline" ]; then
      log "Windrose did not report host readiness within ${SERVER_READY_TIMEOUT}s"
      stop_server
      wait "$run_pid" >/dev/null 2>&1 || true
      return 77
    fi
    sleep 5
  done

  set +e
  wait "$run_pid"
  status=$?
  set -e

  trap - TERM INT
  kill "$tail_pid" >/dev/null 2>&1 || true
  stop_windrose_plus_dashboard || true
  wineserver -k >/dev/null 2>&1 || true
  pkill -x Xvfb >/dev/null 2>&1 || true

  return "$status"
}

prepare_server() {
  if [ "${SKIP_UPDATE_ONCE:-0}" = "1" ] && [ -x "$SERVER_EXEC" ]; then
    log "Steam update skipped for immediate crash retry"
    SKIP_UPDATE_ONCE=0
  elif [ ! -x "$SERVER_EXEC" ] || is_truthy "$UPDATE_ON_START"; then
    update_server
  fi

  if [ ! -x "$SERVER_EXEC" ]; then
    log "Windrose server executable was not found at $SERVER_EXEC"
    exit 66
  fi

  init_wine_prefix
  generate_initial_config
  patch_settings
  patch_world_settings

  if is_truthy "$ENABLE_WINDROSE_PLUS"; then
    install_windrose_plus_files "$SERVER_DIR" "$WINDROSE_PLUS_VERSION"
    patch_windrose_plus_config "$SERVER_DIR"
    run_windrose_plus_pak_builder
  else
    disable_managed_windrose_plus "$SERVER_DIR"
  fi
}

shutdown_all() {
  stop_windrose_plus_dashboard || true
  stop_panel || true
}

trap 'shutdown_all; exit 143' TERM INT

ensure_version_dir_not_nested
mkdir -p "$WINDROSE_CONTROL_DIR" "$WINDROSE_VERSION_DIR"
clear_control_action
start_panel

SKIP_UPDATE_ONCE=0
crash_retries=0

while true; do
  prepare_server
  log "Starting Windrose dedicated server"
  write_runtime_state "running"
  start_windrose_plus_dashboard
  run_started=$SECONDS
  set +e
  start_server_foreground
  status=$?
  set -e
  run_duration=$((SECONDS - run_started))
  trap 'shutdown_all; exit 143' TERM INT

  case "$status" in
    75)
      write_runtime_state "restarting"
      continue
      ;;
    76)
      wait_while_stopped
      continue
      ;;
    77)
      log "Retrying Windrose after failed host registration in ${SERVER_BROKEN_REGISTRATION_RESTART_DELAY}s"
      write_runtime_state "restarting"
      crash_retries=0
      SKIP_UPDATE_ONCE=1
      sleep "$SERVER_BROKEN_REGISTRATION_RESTART_DELAY"
      continue
      ;;
    139)
      if [ "$run_duration" -ge "$SERVER_CRASH_RESTART_RESET_AFTER" ]; then
        crash_retries=0
      fi
      crash_retries=$((crash_retries + 1))
      if [ "$crash_retries" -le "$SERVER_CRASH_RESTART_ATTEMPTS" ]; then
        log "Windrose exited with segmentation fault after ${run_duration}s; retrying in ${SERVER_CRASH_RESTART_DELAY}s (${crash_retries}/${SERVER_CRASH_RESTART_ATTEMPTS})"
        write_runtime_state "crashed"
        SKIP_UPDATE_ONCE=1
        sleep "$SERVER_CRASH_RESTART_DELAY"
        continue
      fi
      log "Windrose exited with segmentation fault after ${run_duration}s; retry limit reached"
      shutdown_all
      exit "$status"
      ;;
    *)
      shutdown_all
      exit "$status"
      ;;
  esac
done
