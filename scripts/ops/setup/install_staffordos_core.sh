#!/usr/bin/env bash
set -euo pipefail

ROOT="$HOME/projects/ross-llm"

echo "🔧 Installing StaffordOS core (boot scripts + CLI helpers)..."

mkdir -p "$ROOT/scripts"
mkdir -p "$ROOT/logs"
mkdir -p "$HOME/bin"

########################################
# A) Root orchestrator boot script
########################################
cat << 'BOOT' > "$ROOT/staffordos_boot.sh"
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

# Activate venv if present
if [ -d "venv" ]; then
  # shellcheck disable=SC1091
  source venv/bin/activate
fi

# Load API key from config file if not already set
if [ -z "${OPENAI_API_KEY:-}" ] && [ -f "$HOME/.config/ross-llm/openai_api_key" ]; then
  export OPENAI_API_KEY="$(cat "$HOME/.config/ross-llm/openai_api_key")"
fi

mkdir -p "$ROOT/logs"

echo "🚀 Starting StaffordOS orchestrator on 127.0.0.1:8000 ..."
cd "$ROOT/apps/orchestrator"

exec uvicorn main:app \
  --host 127.0.0.1 \
  --port 8000 \
  --reload
BOOT
chmod +x "$ROOT/staffordos_boot.sh"

########################################
# B) UI boot script (separate from orchestrator)
########################################
cat << 'UI' > "$ROOT/scripts/staffordos_ui_boot.sh"
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Activate venv if present
if [ -d "venv" ]; then
  # shellcheck disable=SC1091
  source venv/bin/activate
fi

# Optional: warn if orchestrator is not healthy
if ! curl -fsS http://127.0.0.1:8000/health >/dev/null 2>&1; then
  echo "⚠ Orchestrator not healthy on 8000. Start it first with: ./staffordos_boot.sh"
fi

mkdir -p "$ROOT/logs"

echo "🖥  Starting StaffordOS UI on 127.0.0.1:8100 ..."
cd "$ROOT/apps/ui"

exec uvicorn main:app \
  --host 127.0.0.1 \
  --port 8100 \
  --reload
UI
chmod +x "$ROOT/scripts/staffordos_ui_boot.sh"

########################################
# C) ross-health (already mostly there, but ensure it exists)
########################################
cat << 'HEALTH' > "$HOME/bin/ross-health"
#!/usr/bin/env bash
curl -s http://127.0.0.1:8000/health || echo '{"ok": false}'
echo
HEALTH
chmod +x "$HOME/bin/ross-health"

########################################
# D) ross-up – start orchestrator + UI with logs
########################################
cat << 'UP' > "$HOME/bin/ross-up"
#!/usr/bin/env bash
set -euo pipefail

ROOT="$HOME/projects/ross-llm"
cd "$ROOT"

mkdir -p "$ROOT/logs"

echo "🔪 Killing anything on ports 8000/8100 first..."
lsof -tiTCP:8000,8100 -sTCP:LISTEN 2>/dev/null | xargs kill -9 2>/dev/null || true

echo "🚀 Launching orchestrator..."
nohup "$ROOT/staffordos_boot.sh" > "$ROOT/logs/orchestrator.log" 2>&1 &
echo $! > "$ROOT/.orchestrator.pid"

# Small delay so orchestrator can start
sleep 2

echo "🖥  Launching UI..."
nohup "$ROOT/scripts/staffordos_ui_boot.sh" > "$ROOT/logs/ui.log" 2>&1 &
echo $! > "$ROOT/.ui.pid"

echo "✅ StaffordOS up."
echo "   UI:        http://127.0.0.1:8100"
echo "   Health:    ross-health"
echo "   Logs:      $ROOT/logs/{orchestrator.log,ui.log}"
UP
chmod +x "$HOME/bin/ross-up"

########################################
# E) ross-down – stop everything cleanly
########################################
cat << 'DOWN' > "$HOME/bin/ross-down"
#!/usr/bin/env bash
set -euo pipefail

ROOT="$HOME/projects/ross-llm"
cd "$ROOT"

echo "🛑 Stopping StaffordOS processes..."

for f in .orchestrator.pid .ui.pid; do
  if [ -f "$f" ]; then
    PID="$(cat "$f" 2>/dev/null || echo "")"
    if [ -n "$PID" ]; then
      kill "$PID" 2>/dev/null || true
    fi
    rm -f "$f"
  fi
done

# Extra safety: kill anything on the ports
lsof -tiTCP:8000,8100 -sTCP:LISTEN 2>/dev/null | xargs kill -9 2>/dev/null || true

echo "✅ StaffordOS down."
DOWN
chmod +x "$HOME/bin/ross-down"

########################################
# F) ross-ps – quick view of what’s running
########################################
cat << 'PSH' > "$HOME/bin/ross-ps"
#!/usr/bin/env bash
set -euo pipefail

echo "🔎 Ports 8000/8100:"
lsof -nP -iTCP:8000,8100 -sTCP:LISTEN 2>/dev/null || echo "No listeners."

echo
echo "🔎 Uvicorn processes:"
ps aux | grep uvicorn | grep -v grep || echo "No uvicorn processes."
PSH
chmod +x "$HOME/bin/ross-ps"

########################################
# G) Ensure ~/bin is on PATH
########################################
if [ -f "$HOME/.zshrc" ]; then
  if ! grep -q 'export PATH="$HOME/bin:$PATH"' "$HOME/.zshrc"; then
    echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.zshrc"
    echo "ℹ Added ~/bin to PATH in .zshrc (you may need to open a new terminal)."
  fi
fi

echo "✅ StaffordOS core installed."
echo "   Use: ross-up, ross-down, ross-health, ross-ps"
