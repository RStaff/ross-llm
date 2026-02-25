#!/usr/bin/env bash
set -euo pipefail

ROOT="$HOME/projects/ross-llm"
CONFIG_DIR="$HOME/.config/ross-llm"
KEY_FILE="$CONFIG_DIR/openai_api_key"

echo "📍 Working in: $ROOT"
cd "$ROOT"

mkdir -p "$CONFIG_DIR"

echo ""
echo "🔐 Paste your OpenAI API key below (input is hidden)."
read -s -p "OpenAI API key: " OPENAI_KEY
echo ""

if [ -z "${OPENAI_KEY:-}" ]; then
  echo "❌ No key entered. Aborting."
  exit 1
fi

# Store key in a private config file
printf '%s\n' "$OPENAI_KEY" > "$KEY_FILE"
chmod 600 "$KEY_FILE"
echo "✅ Saved key to $KEY_FILE (chmod 600)."

# Create a small env loader that StaffordOS can use
mkdir -p scripts

cat << 'EOS' > scripts/openai_env.sh
#!/usr/bin/env bash
KEY_FILE="$HOME/.config/ross-llm/openai_api_key"
if [ -f "$KEY_FILE" ]; then
  export OPENAI_API_KEY="$(cat "$KEY_FILE")"
fi
EOS

chmod +x scripts/openai_env.sh
echo "✅ Created scripts/openai_env.sh"

# Wire env loader into staffordos_boot.sh
BOOT="$ROOT/staffordos_boot.sh"
if [ ! -f "$BOOT" ]; then
  echo "❌ Could not find $BOOT – aborting patch."
  exit 1
fi

if grep -q 'scripts/openai_env.sh' "$BOOT"; then
  echo "✔ staffordos_boot.sh already loads openai_env.sh"
else
  echo "🔧 Patching staffordos_boot.sh to load OpenAI key..."
  tmp="$(mktemp)"

  awk '
    /source venv\/bin\/activate/ {
      print;
      print "";
      print "echo \"🔐 Loading OpenAI key...\"";
      print "source \"./scripts/openai_env.sh\"";
      next
    }
    { print }
  ' "$BOOT" > "$tmp"

  cp "$BOOT" "$BOOT.bak_before_openai"
  mv "$tmp" "$BOOT"
  echo "✅ Patched staffordos_boot.sh (backup at staffordos_boot.sh.bak_before_openai)"
fi

# Quick sanity check: venv + Python + OpenAI models endpoint
echo ""
echo "🧪 Testing that Python can see OPENAI_API_KEY and call OpenAI..."

if [ ! -d "$ROOT/venv" ]; then
  echo "⚠ venv not found at $ROOT/venv — skipping live API test."
  echo "   Once venv exists, you can rerun: scripts/configure_openai_key.sh"
  echo "🎉 OpenAI key stored; StaffordOS will load it on next boot."
  exit 0
fi

# Activate venv and load env
# (this mirrors what staffordos_boot.sh will do)
source "$ROOT/venv/bin/activate"
source "$ROOT/scripts/openai_env.sh"

python - << 'PY'
import os, textwrap

key = os.getenv("OPENAI_API_KEY")
if not key:
    raise SystemExit("❌ OPENAI_API_KEY not set inside Python environment.")

print("✅ OPENAI_API_KEY is visible inside Python (value is NOT printed).")

import httpx

print("🌐 Hitting OpenAI /v1/models to verify the key works...")
url = "https://api.openai.com/v1/models"
headers = {"Authorization": f"Bearer {key}"}

try:
    with httpx.Client(timeout=15) as client:
        r = client.get(url, headers=headers)
    if r.status_code == 200:
        print("✅ OpenAI API key is valid.")
    elif r.status_code == 401:
        print("❌ 401 Unauthorized — key is invalid or revoked.")
    else:
        print(f"⚠ Unexpected status {r.status_code}:")
        print(textwrap.shorten(r.text, width=200))
except Exception as e:
    print(f"⚠ Error calling OpenAI API: {e}")

echo ""
echo "🎉 Done. From now on, StaffordOS will load your OpenAI key automatically."
echo "   Just use:"
echo "     cd ~/projects/ross-llm && ./staffordos_restart.sh"
