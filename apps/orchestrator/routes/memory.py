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
