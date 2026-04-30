#!/usr/bin/env bash
set -euo pipefail

resolve_windrose_plus_release() {
  local version="$1"
  if [ "$version" = "latest" ]; then
    curl -fsSL "https://api.github.com/repos/HumanGenome/WindrosePlus/releases/latest" \
      | jq -r '[.tag_name, (.assets[] | select(.name == "WindrosePlus.zip") | .browser_download_url)] | @tsv'
  else
    printf '%s\t%s\n' "$version" "https://github.com/HumanGenome/WindrosePlus/releases/download/${version}/WindrosePlus.zip"
  fi
}

resolve_ue4ss_release() {
  curl -fsSL "https://api.github.com/repos/UE4SS-RE/RE-UE4SS/releases/tags/experimental-latest" \
    | jq -r '[.tag_name, (.assets[] | select((.name | test("^UE4SS_v")) and ((.name | test("^z")) | not) and ((.name | test("DEV")) | not)) | .browser_download_url)] | @tsv'
}

ensure_mods_txt_entry() {
  local mods_txt="$1"
  local mod_name="$2"

  touch "$mods_txt"
  if grep -qiE "^[[:space:]]*${mod_name}[[:space:]]*:" "$mods_txt"; then
    sed -i -E "s#^[[:space:]]*${mod_name}[[:space:]]*:[[:space:]]*[0-9]+#${mod_name} : 1#I" "$mods_txt"
  else
    printf '%s : 1\n' "$mod_name" >> "$mods_txt"
  fi
}

install_windrose_plus_files() {
  local server_dir="$1"
  local version="$2"
  local win64_dir="$server_dir/R5/Binaries/Win64"
  local ue4ss_dir="$win64_dir/ue4ss"
  local mods_dir="$ue4ss_dir/Mods"
  local wp_dir="$server_dir/windrose_plus"
  local data_dir="$server_dir/windrose_plus_data"
  local marker="$server_dir/.windrose_plus_managed_version"
  local resolved_version wp_url ue4ss_tag ue4ss_url

  if [ ! -d "$win64_dir" ]; then
    log "Windrose+ cannot install because $win64_dir does not exist"
    return 66
  fi

  IFS=$'\t' read -r resolved_version wp_url < <(resolve_windrose_plus_release "$version")
  if [ -z "$resolved_version" ] || [ -z "$wp_url" ]; then
    log "Could not resolve Windrose+ release $version"
    return 67
  fi

  if [ -f "$marker" ] \
    && [ "$(cat "$marker" 2>/dev/null || true)" = "$resolved_version" ] \
    && [ -f "$win64_dir/dwmapi.dll" ] \
    && [ -f "$ue4ss_dir/UE4SS.dll" ] \
    && [ -f "$mods_dir/WindrosePlus/Scripts/main.lua" ] \
    && [ -f "$wp_dir/server/windrose_plus_server.ps1" ]; then
    log "Windrose+ $resolved_version already installed"
    return 0
  fi

  log "Installing Windrose+ $resolved_version"
  local work
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' RETURN

  curl -fsSL -o "$work/WindrosePlus.zip" "$wp_url"
  unzip -q "$work/WindrosePlus.zip" -d "$work/wp"

  IFS=$'\t' read -r ue4ss_tag ue4ss_url < <(resolve_ue4ss_release)
  if [ -z "$ue4ss_url" ]; then
    log "Could not resolve UE4SS experimental release"
    return 67
  fi

  log "Installing UE4SS $ue4ss_tag for Windrose+"
  curl -fsSL -o "$work/ue4ss.zip" "$ue4ss_url"
  unzip -q "$work/ue4ss.zip" -d "$work/ue4ss"

  install -d "$ue4ss_dir" "$mods_dir" "$data_dir/logs" "$data_dir/rcon" "$wp_dir/config"
  cp -f "$work/ue4ss/dwmapi.dll" "$win64_dir/dwmapi.dll"
  cp -a "$work/ue4ss/ue4ss/." "$ue4ss_dir/"

  if [ -f "$work/wp/UE4SS-settings.ini" ]; then
    cp -f "$work/wp/UE4SS-settings.ini" "$ue4ss_dir/UE4SS-settings.ini"
  fi

  if [ ! -d "$mods_dir/WindrosePlus" ]; then
    cp -a "$work/wp/WindrosePlus" "$mods_dir/WindrosePlus"
  else
    rm -rf "$mods_dir/WindrosePlus/Scripts"
    cp -a "$work/wp/WindrosePlus/Scripts" "$mods_dir/WindrosePlus/Scripts"
    find "$work/wp/WindrosePlus" -maxdepth 1 -type f -exec cp -f {} "$mods_dir/WindrosePlus/" \;
  fi

  if [ -f "$work/wp/cpp-mods/HeightmapExporter/HeightmapExporter.dll" ]; then
    install -d "$mods_dir/HeightmapExporter/dlls"
    cp -f "$work/wp/cpp-mods/HeightmapExporter/HeightmapExporter.dll" "$mods_dir/HeightmapExporter/dlls/main.dll"
    printf '1\n' > "$mods_dir/HeightmapExporter/enabled.txt"
  fi

  ensure_mods_txt_entry "$mods_dir/mods.txt" "WindrosePlus"
  if [ -f "$mods_dir/HeightmapExporter/dlls/main.dll" ]; then
    ensure_mods_txt_entry "$mods_dir/mods.txt" "HeightmapExporter"
  fi

  for folder in server tools docs; do
    if [ -d "$work/wp/$folder" ]; then
      rm -rf "$wp_dir/$folder"
      cp -a "$work/wp/$folder" "$wp_dir/$folder"
    fi
  done

  if [ -d "$work/wp/config" ]; then
    find "$work/wp/config" -maxdepth 1 -name '*.default.ini' -type f -exec cp -f {} "$wp_dir/config/" \;
  fi

  printf '%s\n' "$resolved_version" > "$marker"
  printf '%s\n' "$ue4ss_tag" > "$server_dir/.ue4ss_managed_version"
  rm -rf "$work"
  trap - RETURN
}

disable_managed_windrose_plus() {
  local server_dir="$1"
  local marker="$server_dir/.windrose_plus_managed_version"
  local win64_dir="$server_dir/R5/Binaries/Win64"
  local proxy_dll="$win64_dir/dwmapi.dll"
  local disabled_proxy="$win64_dir/dwmapi.dll.windrose-plus-disabled"
  local mods_txt="$win64_dir/ue4ss/Mods/mods.txt"

  if [ ! -f "$marker" ]; then
    return 0
  fi

  if [ -f "$proxy_dll" ]; then
    log "Disabling managed Windrose+ proxy DLL"
    mv -f "$proxy_dll" "$disabled_proxy"
  fi

  if [ -f "$mods_txt" ]; then
    sed -i -E 's#^[[:space:]]*WindrosePlus[[:space:]]*:[[:space:]]*[0-9]+#WindrosePlus : 0#I' "$mods_txt"
    sed -i -E 's#^[[:space:]]*HeightmapExporter[[:space:]]*:[[:space:]]*[0-9]+#HeightmapExporter : 0#I' "$mods_txt"
  fi
}

generated_windrose_plus_password() {
  local secret_file="$1"
  if [ -f "$secret_file" ]; then
    cat "$secret_file"
    return
  fi

  local password
  set +o pipefail
  password="$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)"
  set -o pipefail
  printf '%s\n' "$password" > "$secret_file"
  chmod 0600 "$secret_file" 2>/dev/null || true
  printf '%s\n' "$password"
}

patch_windrose_plus_config() {
  local server_dir="$1"
  local config="$server_dir/windrose_plus.json"
  local secret_file="$server_dir/.windrose_plus_rcon_password"
  local password="$WINDROSE_PLUS_RCON_PASSWORD"

  if [ -z "$password" ] && [ -f "$config" ]; then
    password="$(jq -r '.rcon.password // ""' "$config" 2>/dev/null || true)"
    if [ "$password" = "changeme" ]; then
      password=""
    fi
  fi
  if [ -z "$password" ]; then
    password="$(generated_windrose_plus_password "$secret_file")"
    log "Generated Windrose+ RCON/dashboard password at $secret_file"
  fi

  if [ ! -f "$config" ]; then
    jq -n '{}' > "$config"
  fi

  local tmp
  tmp="$(mktemp)"
  jq \
    --argjson http_port "$WINDROSE_PLUS_HTTP_PORT" \
    --arg bind_ip "$WINDROSE_PLUS_BIND_IP" \
    --arg password "$password" \
    '
      .server = (.server // {}) |
      .server.http_port = $http_port |
      .server.bind_ip = $bind_ip |
      .rcon = (.rcon // {}) |
      .rcon.enabled = true |
      .rcon.password = $password |
      .query = (.query // {}) |
      .query.enabled = true |
      .livemap = (.livemap // {}) |
      .livemap.enabled = true
    ' "$config" > "$tmp"
  mv "$tmp" "$config"
}

run_windrose_plus_pak_builder() {
  if ! is_truthy "$WINDROSE_PLUS_BUILD_PAK"; then
    return 0
  fi

  local builder="$SERVER_DIR/windrose_plus/tools/WindrosePlus-BuildPak.ps1"
  if [ ! -f "$builder" ]; then
    log "Windrose+ PAK builder was not found at $builder"
    return 68
  fi

  log "Running Windrose+ PAK builder"
  pwsh -NoProfile -NonInteractive -ExecutionPolicy Bypass \
    -File "$builder" \
    -ServerDir "$SERVER_DIR" \
    -RemoveStalePak
}

start_windrose_plus_dashboard() {
  WINDROSE_PLUS_DASHBOARD_PID=""
  if ! is_truthy "$ENABLE_WINDROSE_PLUS" || ! is_truthy "$WINDROSE_PLUS_DASHBOARD"; then
    return 0
  fi

  local dashboard="$SERVER_DIR/windrose_plus/server/windrose_plus_server.ps1"
  if [ ! -f "$dashboard" ]; then
    log "Windrose+ dashboard was not found at $dashboard"
    return 68
  fi

  mkdir -p "$SERVER_DIR/windrose_plus_data"
  log "Starting Windrose+ dashboard on ${WINDROSE_PLUS_BIND_IP}:${WINDROSE_PLUS_HTTP_PORT}"
  pwsh -NoProfile -NonInteractive -ExecutionPolicy Bypass \
    -File "$dashboard" \
    -GameDir "$SERVER_DIR" \
    -Port "$WINDROSE_PLUS_HTTP_PORT" \
    -BindIp "$WINDROSE_PLUS_BIND_IP" \
    > "$SERVER_DIR/windrose_plus_data/dashboard.log" 2>&1 &
  WINDROSE_PLUS_DASHBOARD_PID=$!
}

stop_windrose_plus_dashboard() {
  if [ -n "${WINDROSE_PLUS_DASHBOARD_PID:-}" ]; then
    kill -TERM "$WINDROSE_PLUS_DASHBOARD_PID" >/dev/null 2>&1 || true
    wait "$WINDROSE_PLUS_DASHBOARD_PID" >/dev/null 2>&1 || true
    WINDROSE_PLUS_DASHBOARD_PID=""
  fi
}
