# Windrose ARM64 Server

[![Publish Docker Image](https://github.com/falcononrails/windrose-arm64-server/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/falcononrails/windrose-arm64-server/actions/workflows/docker-publish.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A Docker image for hosting a Windrose dedicated server on ARM64 cloud VMs.

The main target is Oracle Cloud Always Free on Ampere A1, where you can run an ARM64 VM with enough memory for a small Windrose server without paying for an x86 instance.

This image uses:

- [`sonroyaalmerol/steamcmd-arm64`](https://github.com/sonroyaalmerol/steamcmd-arm64) for SteamCMD on ARM64
- [`AndreRH/hangover`](https://github.com/AndreRH/hangover) to run the Windows dedicated server binary through Wine/Hangover
- Windrose dedicated server Steam app id `4129620`

This project is community maintained and is not affiliated with Windrose, Valve, Oracle, or the upstream projects above.

## Status

Invite-code mode is the default and recommended mode. It avoids inbound game ports and worked in testing on an Oracle A1 ARM64 VM.

Direct IP mode is available, but experimental on ARM64. The official Windrose guide already marks Linux/Wine as experimental, and direct mode adds extra networking behavior on top of emulation.

## Requirements

| Resource | Recommended |
| --- | --- |
| CPU | 4 ARM64 cores |
| RAM | 16 GB or more for 10 players |
| Storage | 20 GB or more |
| Host OS | Ubuntu 24.04 or another Docker-capable ARM64 Linux host |

For Oracle Always Free, a practical shape is:

- Shape: `VM.Standard.A1.Flex`
- OCPU: `4`
- Memory: `24 GB`
- Image: Ubuntu 24.04
- Boot volume: keep it inside your Always Free storage allowance

## Quick Start

Install Docker and Docker Compose on your ARM64 VM, then run:

```bash
git clone https://github.com/falcononrails/windrose-arm64-server.git
cd windrose-arm64-server
cp .env.example .env
docker compose up -d
docker compose logs -f windrose
```

The first boot can take several minutes. The container downloads the Windrose server, initializes the Wine/Hangover prefix, generates the first Windrose config files, applies your `.env` settings, then starts the server.

## Docker Compose

This repository includes a ready-to-use `docker-compose.yml`:

```yaml
services:
  windrose:
    image: ghcr.io/falcononrails/windrose-arm64-server:latest
    container_name: windrose-server
    restart: unless-stopped
    stop_grace_period: 30s
    env_file:
      - .env
    volumes:
      - ./data/server:/server
      - ./data/wine:/home/steam/.wine
```

Direct IP ports are intentionally commented out in the example because invite-code mode does not need them.

## Docker Run

You can also run the image without Compose:

```bash
docker run -d \
  --name windrose-server \
  --restart unless-stopped \
  --stop-timeout 30 \
  --platform linux/arm64 \
  --env-file .env \
  -v ./data/server:/server \
  -v ./data/wine:/home/steam/.wine \
  ghcr.io/falcononrails/windrose-arm64-server:latest
```

## Get The Invite Code

When the server is online, read the generated invite code:

```bash
docker compose exec windrose jq -r '.ServerDescription_Persistent.InviteCode' /server/R5/ServerDescription.json
```

To inspect all server settings:

```bash
docker compose exec windrose jq '.ServerDescription_Persistent' /server/R5/ServerDescription.json
```

## Configuration

Copy `.env.example` to `.env` and edit the values you care about:

```env
SERVER_NAME=Windrose ARM64
SERVER_PASSWORD=
MAX_PLAYERS=10
USER_SELECTED_REGION=EU
UPDATE_ON_START=true
USE_DIRECT_CONNECTION=false
```

Available environment variables:

| Variable | Default | Description |
| --- | --- | --- |
| `SERVER_NAME` | `Windrose ARM64` | Server and world display name |
| `SERVER_PASSWORD` | empty | Optional server password |
| `MAX_PLAYERS` | `8` | Maximum players written to Windrose settings |
| `USER_SELECTED_REGION` | `EU` | Region used by Windrose matchmaking |
| `UPDATE_ON_START` | `true` | Run SteamCMD update before each start |
| `USE_DIRECT_CONNECTION` | `false` | Enable Windrose Direct IP settings |
| `SERVER_PORT` | `7777` | Direct IP port when direct mode is enabled |
| `DIRECT_CONNECTION_PROXY_ADDRESS` | `0.0.0.0` | Direct IP bind/proxy address |
| `P2P_PROXY_ADDRESS` | `127.0.0.1` | P2P proxy address for invite-code mode |
| `CONFIG_BOOT_TIMEOUT` | `420` | Seconds to wait for first-run config generation |
| `EXTRA_ARGS` | empty | Extra arguments passed to the server executable |
| `TZ` | `UTC` | Container timezone |
| `PUID` | `1000` | UID used for persisted files |
| `PGID` | `1000` | GID used for persisted files |

Changing server settings requires a container restart:

```bash
docker compose restart windrose
```

The invite code is stored in the generated Windrose settings. Normal restarts should keep it because `/server` is persisted.

## Direct IP Mode

Invite-code mode is simpler and is the recommended default:

```env
USE_DIRECT_CONNECTION=false
```

To experiment with Direct IP:

```env
USE_DIRECT_CONNECTION=true
SERVER_PORT=7777
DIRECT_CONNECTION_PROXY_ADDRESS=0.0.0.0
```

Then uncomment the `ports` section in `docker-compose.yml`:

```yaml
ports:
  - "7777:7777/tcp"
  - "7777:7777/udp"
```

You must also open the same port in your cloud firewall. On Oracle Cloud that usually means the subnet security list or NSG, plus the VM firewall if one is enabled.

## Backups

All persistent data is stored in `./data`.

Create a backup:

```bash
docker compose down
tar -czf windrose-backup.tgz data
docker compose up -d
```

Restore a backup:

```bash
docker compose down
rm -rf data
tar -xzf windrose-backup.tgz
docker compose up -d
```

## Updating

By default, the image runs SteamCMD on every start:

```env
UPDATE_ON_START=true
```

To update the Docker image itself:

```bash
docker compose pull
docker compose up -d
```

## Troubleshooting

Show logs:

```bash
docker compose logs -f windrose
```

Check whether the Windrose process is running:

```bash
docker compose ps
```

Reset only the Wine/Hangover prefix:

```bash
docker compose down
rm -rf data/wine
docker compose up -d
```

Reset the full server and world data:

```bash
docker compose down
rm -rf data
docker compose up -d
```

## References

- Official Windrose dedicated server guide: <https://playwindrose.com/dedicated-server-guide/>
- SteamCMD on ARM64: <https://github.com/sonroyaalmerol/steamcmd-arm64>
- Hangover: <https://github.com/AndreRH/hangover>
- Existing Windrose Docker work that helped validate the config patching flow: <https://github.com/indifferentbroccoli/windrose-server-docker>

