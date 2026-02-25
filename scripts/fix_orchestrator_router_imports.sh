#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

BASE="apps/orchestrator"
if [ ! -d "$BASE" ]; then
  echo "❌ Not found: $BASE"
  exit 1
fi

python3 - <<'PY'
from pathlib import Path
import re

base = Path("apps/orchestrator")
targets = []

# main + all route modules + a few likely modules that may contain "apps." imports
globs = [
    base / "main.py",
    base / "routes",
    base
]

def collect_files(p: Path):
    if p.is_file() and p.suffix == ".py":
        return [p]
    if p.is_dir():
        return [x for x in p.rglob("*.py")]
    return []

for g in globs:
    targets += collect_files(g)

targets = sorted(set(targets))

def patch_text(txt: str) -> str:
    # 1) Fix common import patterns: "from apps.orchestrator.X import Y" -> "from X import Y"
    txt = re.sub(r"(?m)^\s*from\s+apps\.orchestrator\.([a-zA-Z0-9_\.]+)\s+import\s+", r"from \1 import ", txt)
    # 2) Fix "import apps.orchestrator.X as Y" -> "import X as Y"
    txt = re.sub(r"(?m)^\s*import\s+apps\.orchestrator\.([a-zA-Z0-9_\.]+)\s+as\s+", r"import \1 as ", txt)
    # 3) Fix "import apps.orchestrator.X" -> "import X"
    txt = re.sub(r"(?m)^\s*import\s+apps\.orchestrator\.([a-zA-Z0-9_\.]+)\s*$", r"import \1", txt)

    # 4) Fix any remaining dotted references in code strings (dynamic import paths)
    #    "apps.orchestrator.routes.foo" -> "routes.foo"
    txt = txt.replace("apps.orchestrator.routes.", "routes.")
    #    "apps.orchestrator." -> "" (local module)
    txt = txt.replace("apps.orchestrator.", "")

    return txt

changed = []
for p in targets:
    before = p.read_text()
    after = patch_text(before)
    if after != before:
        p.write_text(after)
        changed.append(str(p))

print("✅ Patched files:")
for f in changed:
    print(" -", f)
print(f"Total changed: {len(changed)}")
PY

echo
echo "🔎 Sanity grep (should return 0 lines):"
grep -RIn "apps\.orchestrator" apps/orchestrator | head -n 50 || true
