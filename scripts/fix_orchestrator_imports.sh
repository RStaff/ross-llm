#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

TARGET="apps/orchestrator/main.py"
if [ ! -f "$TARGET" ]; then
  echo "❌ Not found: $TARGET"
  exit 1
fi

python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/orchestrator/main.py")
txt = p.read_text()

# 1) Remove the brittle "import shim" block if present (it causes more harm than good in Docker)
txt = re.sub(
    r"^# --- STAFFORDOS IMPORT SHIM.*?^# -{20,}\n",
    "",
    txt,
    flags=re.M | re.S
)

# 2) Replace imports that assume a repo-level `apps` package.
# In the Docker image, files are copied to /app directly, so status.py is importable as "status", etc.
replacements = [
    ("from apps.orchestrator.status import record_chat_success, record_chat_error",
     "from status import record_chat_success, record_chat_error"),
    ("from apps.orchestrator import retrieval_parallel as _retrieval_parallel",
     "import retrieval_parallel as _retrieval_parallel"),
    ("from apps.orchestrator import retrieval_parallel",
     "import retrieval_parallel"),
]

for a,b in replacements:
    txt = txt.replace(a,b)

# 3) Generic cleanup: any remaining "apps.orchestrator." references → local module refs
txt = re.sub(r"\bapps\.orchestrator\.", "", txt)

p.write_text(txt)
print("✅ Patched:", p)
PY

echo
echo "🔎 Showing top of patched file:"
sed -n '1,30p' "$TARGET"
