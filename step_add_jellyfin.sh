#!/usr/bin/env bash
set -euo pipefail

FILE="docker-compose.yml"
test -f "$FILE" || { echo "❌ Missing $FILE"; exit 1; }

echo "==> Backup"
ts="$(date +%s)"
cp -v "$FILE" "$FILE.bak_${ts}"

# If already present, skip
if grep -q "^[[:space:]]*jellyfin:" "$FILE"; then
  echo "ℹ️ jellyfin already present in $FILE"
else
  echo "==> Appending Jellyfin service"
  cat >> "$FILE" <<'YAML'

  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    restart: unless-stopped
    networks:
      - default
    ports:
      - "8096:8096"          # web UI
      # Optional HTTPS + discovery (only enable if you need them)
      # - "8920:8920"        # HTTPS
      # - "7359:7359/udp"    # discovery
      # - "1900:1900/udp"    # DLNA
    volumes:
      - ./_data/jellyfin/config:/config
      - ./_data/jellyfin/cache:/cache
      # Put media here (or point to an external drive path)
      - ./_data/media:/media
YAML
fi

echo "==> Validate compose"
docker compose config >/dev/null
echo "✅ docker compose config OK"

echo "==> Start Jellyfin"
docker compose up -d jellyfin

echo
echo "✅ Jellyfin should be at: http://localhost:8096"
echo "📁 Media folder mapped to: $(pwd)/_data/media"
