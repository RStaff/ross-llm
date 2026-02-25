#!/usr/bin/env bash
set -euo pipefail

ROOT="$HOME/projects/ross-llm"
cd "$ROOT"

echo "🔧 Backing up existing staffordos_boot.sh (if present)..."
if [ -f "staffordos_boot.sh" ]; then
  cp staffordos_boot.sh "staffordos_boot.sh.bak-$(date +%Y%m%d-%H%M%S)"
fi

cat << 'EOS' > staffordos_boot.sh
#!/usr/bin/env bash
set -euo pipefail

ROOT="$HOME/projects/ross-llm"
cd "$ROOT"

echo "🚀 StaffordOS boot starting..."
echo "1️⃣ Activating virtualenv..."

if [ -d "venv" ]; then
  # shellcheck disable=SC1091
  source venv/bin/activate
else
  echo "❌ Python venv not found at $ROOT/venv"
  exit 1
fi

echo "🔐 Loading OpenAI key..."
KEY_FILE="$HOME/.config/ross-llm/openai_api_key"
if [ -f "$KEY_FILE" ]; then
  export OPENAI_API_KEY="$(cat "$KEY_FILE")"
else
  echo "❌ OpenAI key file not found at $KEY_FILE"
  exit 1
fi

echo "3️⃣ Launching orchestrator API on http://127.0.0.1:8000 ..."
cd apps/orchestrator
exec uvicorn main:app --port 8000 --reload
EOS

chmod +x staffordos_boot.sh
echo "✅ staffordos_boot.sh replaced with orchestrator-only version."
echo "   It no longer touches port 8100; UI is started only via scripts/staffordos_ui_boot.sh"

echo "🔧 Ensuring ~/bin exists and is on PATH..."
mkdir -p "$HOME/bin"
if ! grep -q 'export PATH="$HOME/bin:$PATH"' "$HOME/.zshrc"; then
  echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.zshrc"
fi

echo "🩺 Installing ross-health helper..."
cat << 'EOH' > "$HOME/bin/ross-health"
#!/usr/bin/env bash
curl -s http://127.0.0.1:8000/health || echo '{"ok": false}'
EOH
chmod +x "$HOME/bin/ross-health"

echo "✅ Done. staffordos_boot.sh + ross-health are now configured."
