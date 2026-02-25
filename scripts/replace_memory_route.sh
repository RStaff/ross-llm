#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

TARGET="apps/orchestrator/routes/memory.py"
if [ ! -f "$TARGET" ]; then
  echo "❌ Not found: $TARGET"
  exit 1
fi

TS="$(date +%Y%m%d_%H%M%S)"
BACKUP="${TARGET}.bak_${TS}"
cp "$TARGET" "$BACKUP"
echo "🧾 Backed up -> $BACKUP"

cat > "$TARGET" <<'PY'
from __future__ import annotations

from pathlib import Path
from typing import Any, Dict

from fastapi import APIRouter

try:
    import yaml  # type: ignore
except Exception:  # pragma: no cover
    yaml = None  # type: ignore

router = APIRouter()


def _candidate_persona_dirs() -> list[Path]:
    """
    In-container layout (WORKDIR=/app):
      /app/routes/memory.py  -> parents[1] == /app
    We try:
      /app/data/persona  (if you later add it)
      /app/profiles      (you already have this)
    """
    app_dir = Path(__file__).resolve().parents[1]
    return [
        app_dir / "data" / "persona",
        app_dir / "profiles",
    ]


def _load_yaml_files() -> Dict[str, Any]:
    if yaml is None:
        return {"_error": "pyyaml_not_installed"}

    for d in _candidate_persona_dirs():
        if d.exists() and d.is_dir():
            out: Dict[str, Any] = {}
            for f in sorted(d.glob("*.y*ml")):
                try:
                    data = yaml.safe_load(f.read_text()) or {}
                except Exception as e:
                    data = {"_error": f"failed_to_parse: {e!r}"}
                out[f.stem] = data
            return out

    # nothing found
    return {}


@router.get("/memory/status")
def memory_status() -> Dict[str, Any]:
    mem = _load_yaml_files()
    keys = [k for k in mem.keys() if not k.startswith("_")]
    return {
        "status": "ok",
        "loaded_count": len(keys),
        "loaded": keys,
        "has_error": any(k.startswith("_") for k in mem.keys()),
        "candidates": [str(p) for p in _candidate_persona_dirs()],
    }
PY

echo "✅ Replaced $TARGET with a clean, Docker-safe router."

echo
echo "✅ Compile check:"
python3 -m py_compile "$TARGET"

echo
echo "🧹 Rebuild stack:"
docker compose down --remove-orphans
docker compose up -d --build

echo
echo "📜 Orchestrator logs (last 120):"
docker compose logs --tail=120 orchestrator || true

echo
echo "🌐 Host smoke test:"
curl -sv http://localhost:8001/openapi.json 2>&1 | tail -n 40 || true
curl -sv http://localhost:8001/memory/status 2>&1 | tail -n 60 || true
