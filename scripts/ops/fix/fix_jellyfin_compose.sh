#!/usr/bin/env bash
set -euo pipefail

FILE="docker-compose.yml"
test -f "$FILE" || { echo "❌ Missing $FILE"; exit 1; }

echo "==> Backup"
ts="$(date +%s)"
cp -v "$FILE" "$FILE.bak_${ts}"

echo "==> Patch docker-compose.yml (remove bad jellyfin-under-volumes; add jellyfin under services)"
python3 - <<'PY'
from pathlib import Path
import re

p = Path("docker-compose.yml")
txt = p.read_text()

# 1) Remove mistakenly-added jellyfin block under top-level volumes:
#    volumes:
#      jellyfin:
#        container_name: ...
#
# We remove only the "  jellyfin:" subtree that sits directly under a top-level "volumes:" key.
lines = txt.splitlines(True)

out = []
i = 0
while i < len(lines):
    line = lines[i]
    # Detect top-level volumes:
    if re.match(r"^volumes:\s*$", line):
        out.append(line)
        i += 1
        # Walk through children of volumes:
        while i < len(lines):
            l = lines[i]
            # next top-level key (no indentation) ends volumes section
            if re.match(r"^[A-Za-z0-9_-]+:\s*$", l) and not l.startswith(" "):
                break

            # If this is the bad "  jellyfin:" entry, skip its subtree
            if re.match(r"^  jellyfin:\s*$", l):
                i += 1
                # skip all lines that belong to jellyfin subtree (indented >= 4 spaces)
                while i < len(lines) and (lines[i].startswith("    ") or lines[i].strip() == ""):
                    i += 1
                continue

            out.append(l)
            i += 1
        continue

    out.append(line)
    i += 1

txt2 = "".join(out)

# 2) Ensure we have a services: section
if "services:\n" not in txt2 and "services:\r\n" not in txt2:
    raise SystemExit("❌ No 'services:' section found in docker-compose.yml. Open the file and paste it here.")

# 3) If jellyfin service already exists under services, do nothing
if re.search(r"^  jellyfin:\s*$", txt2, flags=re.M):
    p.write_text(txt2)
    print("ℹ️ jellyfin service already present under services; only cleanup applied (if needed).")
    raise SystemExit(0)

jellyfin_block = r"""
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    restart: unless-stopped
    networks:
      - default
    ports:
      - "8096:8096"          # web UI
      # Optional (leave commented unless you need them)
      # - "8920:8920"        # HTTPS
      # - "7359:7359/udp"    # discovery
      # - "1900:1900/udp"    # DLNA
    volumes:
      - ./_data/jellyfin/config:/config
      - ./_data/jellyfin/cache:/cache
      - ./_data/media:/media
"""

# Insert directly after the 'services:' line
txt3 = re.sub(r"^services:\s*$", "services:" + jellyfin_block, txt2, flags=re.M)

p.write_text(txt3)
print("✅ Patched docker-compose.yml (jellyfin added under services)")
PY

echo "==> Validate compose"
docker compose config >/dev/null
echo "✅ docker compose config OK"

echo "==> Start Jellyfin"
docker compose up -d jellyfin

echo
echo "✅ Jellyfin should be at: http://localhost:8096"
echo "📁 Media folder mapped to: $(pwd)/_data/media"
