#!/usr/bin/env bash
set -euo pipefail

FILE="scripts/configure_openai_key.sh"

# Remove the broken Python block and replace it with a safe one
tmp="$(mktemp)"

awk '
  /python - <</ { in_py=1; print; next }
  /PY/ && in_py==1 { in_py=0; print "import os, textwrap"; print ""; print "key = os.getenv(\"OPENAI_API_KEY\")"; print "if not key:"; print "    raise SystemExit(\"❌ OPENAI_API_KEY not set inside Python environment.\")"; print ""; print "print(\"✅ OPENAI_API_KEY is visible inside Python (value is NOT printed).\")"; print ""; print "import httpx"; print ""; print "print(\"🌐 Hitting OpenAI /v1/models to verify the key works...\")"; print "url = \"https://api.openai.com/v1/models\""; print "headers = {\"Authorization\": f\"Bearer {key}\"}"; print ""; print "try:"; print "    with httpx.Client(timeout=15) as client:"; print "        r = client.get(url, headers=headers)"; print "    if r.status_code == 200:"; print "        print(\"✅ OpenAI API key is valid.\")"; print "    elif r.status_code == 401:"; print "        print(\"❌ 401 Unauthorized — key is invalid or revoked.\")"; print "    else:"; print "        print(f\"⚠ Unexpected status {r.status_code}:\")"; print "        print(textwrap.shorten(r.text, width=200))"; print "except Exception as e:"; print "    print(f\"⚠ Error calling OpenAI API: {e}\")"; print; print "PY"; next }
  in_py==1 { next }
  { print }
' "$FILE" > "$tmp"

cp "$FILE" "$FILE.bak_before_fix"
mv "$tmp" "$FILE"

echo "✅ Sanity test block fixed. Backup saved at $FILE.bak_before_fix"
