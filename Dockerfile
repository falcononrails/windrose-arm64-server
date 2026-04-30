FROM --platform=linux/arm64 ghcr.io/sonroyaalmerol/steamcmd-arm64:root-bookworm

ARG HANGOVER_VERSION=11.4
ARG POWERSHELL_VERSION=7.6.1

LABEL org.opencontainers.image.title="Windrose ARM64 Server" \
      org.opencontainers.image.description="Windrose dedicated server container for ARM64 hosts using SteamCMD and Hangover" \
      org.opencontainers.image.source="https://github.com/falcononrails/windrose-arm64-server" \
      org.opencontainers.image.licenses="MIT"

ENV DEBIAN_FRONTEND=noninteractive \
    SERVER_DIR=/server \
    HOME=/home/steam \
    WINEPREFIX=/home/steam/.wine \
    WINEDEBUG=-all \
    HODLL64=libarm64ecfex.dll \
    WINEDLLOVERRIDES=mscoree,mshtml=;dwmapi=n,b;version=n,b \
    WINDROSE_APP_ID=4129620 \
    TZ=UTC

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        cabextract \
        curl \
        gosu \
        jq \
        procps \
        psmisc \
        tar \
        unzip \
        winbind \
        xauth \
        xvfb \
    && mkdir -p /opt/microsoft/powershell/7 \
    && curl -fsSL -o /tmp/powershell.tar.gz \
        "https://github.com/PowerShell/PowerShell/releases/download/v${POWERSHELL_VERSION}/powershell-${POWERSHELL_VERSION}-linux-arm64.tar.gz" \
    && tar -xzf /tmp/powershell.tar.gz -C /opt/microsoft/powershell/7 \
    && chmod 0755 /opt/microsoft/powershell/7/pwsh \
    && ln -s /opt/microsoft/powershell/7/pwsh /usr/local/bin/pwsh \
    && rm -f /tmp/powershell.tar.gz \
    && curl -fsSL -o /tmp/hangover.tar \
        "https://github.com/AndreRH/hangover/releases/download/hangover-${HANGOVER_VERSION}/hangover_${HANGOVER_VERSION}_debian12_bookworm_arm64.tar" \
    && mkdir -p /tmp/hangover \
    && tar -xf /tmp/hangover.tar -C /tmp/hangover \
    && apt-get install -y --no-install-recommends \
        /tmp/hangover/hangover-wine_*.deb \
        /tmp/hangover/hangover-libarm64ecfex_*.deb \
        /tmp/hangover/hangover-libwow64fex_*.deb \
        /tmp/hangover/hangover-wowbox64_*.deb \
    && rm -rf /var/lib/apt/lists/* /tmp/hangover /tmp/hangover.tar \
    && install -d -o steam -g steam /server /home/steam/.wine

COPY scripts/windrose-entrypoint.sh /usr/local/bin/windrose-entrypoint
COPY scripts/windrose-run.sh /usr/local/bin/windrose-run
COPY scripts/windrose-healthcheck.sh /usr/local/bin/windrose-healthcheck
COPY scripts/windrose-plus.sh /usr/local/lib/windrose-plus.sh

RUN chmod 0755 /usr/local/bin/windrose-entrypoint /usr/local/bin/windrose-run /usr/local/bin/windrose-healthcheck /usr/local/lib/windrose-plus.sh

VOLUME ["/server", "/home/steam/.wine"]
WORKDIR /server

STOPSIGNAL SIGTERM
HEALTHCHECK --interval=60s --timeout=10s --start-period=20m --retries=3 \
    CMD windrose-healthcheck

ENTRYPOINT ["windrose-entrypoint"]
