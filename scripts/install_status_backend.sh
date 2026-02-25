#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "🔧 Creating apps/orchestrator/status.py ..."

mkdir -p apps/orchestrator

cat << 'PY' > apps/orchestrator/status.py
from fastapi import APIRouter
from pydantic import BaseModel
from typing import Optional
import time

router = APIRouter()

_start_time = time.time()
_last_error: Optional[str] = None
_last_error_at: Optional[float] = None
_last_chat_latency_ms: Optional[float] = None
_total_chats: int = 0
_total_chat_errors: int = 0


class StatusResponse(BaseModel):
    ok: bool
    uptime_seconds: float
    last_error: Optional[str]
    last_error_at: Optional[float]
    last_chat_latency_ms: Optional[float]
    total_chats: int
    total_chat_errors: int


def record_chat_success(latency_ms: float) -> None:
    global _total_chats, _last_chat_latency_ms
    _total_chats += 1
    _last_chat_latency_ms = latency_ms


def record_chat_error(message: str) -> None:
    global _total_chats, _total_chat_errors, _last_error, _last_error_at
    _total_chats += 1
    _total_chat_errors += 1
    _last_error = message
    _last_error_at = time.time()


@router.get("/status", response_model=StatusResponse)
async def get_status() -> StatusResponse:
    return StatusResponse(
        ok=True,
        uptime_seconds=time.time() - _start_time,
        last_error=_last_error,
        last_error_at=_last_error_at,
        last_chat_latency_ms=_last_chat_latency_ms,
        total_chats=_total_chats,
        total_chat_errors=_total_chat_errors,
    )
PY

MAIN="apps/orchestrator/main.py"

if [ ! -f "$MAIN" ]; then
  echo "❌ $MAIN not found. Adjust the path in install_status_backend.sh."
  exit 1
fi

if grep -q "status.router" "$MAIN"; then
  echo "✅ status router already wired into main.py – skipping patch."
else
  echo "🔧 Patching $MAIN to include status router ..."
  python3 - "$MAIN" << 'PY'
import sys, pathlib

path = pathlib.Path(sys.argv[1])
text = path.read_text()

# Append safe import + include at the end of the file
snippet = """

# StaffordOS status router (auto-added)
try:
    from apps.orchestrator import status as stafford_status
    app.include_router(stafford_status.router)
except Exception as e:  # pragma: no cover
    print("Warning: failed to load status router:", e)
"""

if "status router (auto-added)" in text:
    print("Status snippet already present.")
else:
    path.write_text(text + snippet)
    print("Status snippet appended to", path)
PY
fi

echo "✅ Status backend installed."
