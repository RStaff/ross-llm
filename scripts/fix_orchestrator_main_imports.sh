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

# Replace explicit imports in main.py that assume repo-root "apps" package
# These map to local modules inside /app at runtime.
repls = [
    (r"from\s+apps\.orchestrator\s+import\s+status\s+as\s+stafford_status", "import status as stafford_status"),
    (r"from\s+apps\.orchestrator\s+import\s+parallel_debug\s+as\s+stafford_parallel_debug", "import parallel_debug as stafford_parallel_debug"),
    (r"from\s+apps\.orchestrator\s+import\s+tasks_decompose\s+as\s+_tasks_decompose", "import tasks_decompose as _tasks_decompose"),
    (r"from\s+apps\.orchestrator\s+import\s+plan\s+as\s+_plan", "import plan as _plan"),
    (r"from\s+apps\.orchestrator\s+import\s+execution_log\s+as\s+_execution_log", "import execution_log as _execution_log"),
    (r"from\s+apps\.orchestrator\s+import\s+metrics\s+as\s+_metrics", "import metrics as _metrics"),
]

before = txt
for pat, rep in repls:
    txt = re.sub(pat, rep, txt)

# Also catch any leftover module path strings:
txt = txt.replace("apps.orchestrator.routes.", "routes.")
txt = txt.replace("apps.orchestrator.", "")

p.write_text(txt)

changed = (txt != before)
print("✅ Patched:", p, "| changed =", changed)
PY

echo
echo "🔎 Remaining 'apps.orchestrator' references in main.py (should be empty):"
grep -n "apps\.orchestrator" "$TARGET" || true
