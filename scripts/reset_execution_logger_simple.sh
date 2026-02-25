#!/usr/bin/env bash
set -euo pipefail

echo "🔧 Resetting Execution Logger to simple SQLite implementation..."

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_MOD_PATH="$ROOT_DIR/apps/orchestrator/execution_log.py"
DATA_DIR="$ROOT_DIR/data"

mkdir -p "$DATA_DIR"

cat > "$LOG_MOD_PATH" << 'PY'
from __future__ import annotations

import json
import sqlite3
import threading
import time
from pathlib import Path
from typing import Any, Dict, List

from fastapi import APIRouter, Query

# Simple SQLite-backed execution logger
DB_PATH = Path(__file__).resolve().parent.parent.parent / "data" / "execution_log.sqlite"
_DB_LOCK = threading.Lock()

router = APIRouter(prefix="/logs", tags=["logs"])


def _init_db() -> None:
    with _DB_LOCK:
        conn = sqlite3.connect(DB_PATH)
        try:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS execution_log (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    ts TEXT NOT NULL,
                    endpoint TEXT NOT NULL,
                    status INTEGER NOT NULL,
                    latency_ms INTEGER NOT NULL,
                    payload TEXT
                )
                """
            )
            conn.commit()
        finally:
            conn.close()


_init_db()


def log_event(
    endpoint: str,
    status: int,
    latency_ms: int,
    payload: Dict[str, Any] | None = None,
) -> None:
    """
    Lightweight log sink used by orchestrator endpoints.

    Called from e.g.:

        log_event(
            endpoint="/plan",
            status=status,
            latency_ms=int((time.time() - start) * 1000),
            payload={...},
        )
    """
    if payload is None:
        payload = {}

    record = {
        "endpoint": endpoint,
        "status": status,
        "latency_ms": int(latency_ms),
        "payload": payload,
    }

    with _DB_LOCK:
        conn = sqlite3.connect(DB_PATH)
        try:
            conn.execute(
                """
                INSERT INTO execution_log (ts, endpoint, status, latency_ms, payload)
                VALUES (?, ?, ?, ?, ?)
                """,
                (
                    time.strftime("%Y-%m-%d %H:%M:%S"),
                    record["endpoint"],
                    record["status"],
                    record["latency_ms"],
                    json.dumps(record["payload"], ensure_ascii=False),
                ),
            )
            conn.commit()
        finally:
            conn.close()


@router.get("/latest")
async def latest_logs(limit: int = Query(20, ge=1, le=200)) -> Dict[str, Any]:
    """
    Return the most recent N log rows for quick inspection.

    Response shape:

    {
      "ok": true,
      "count": 3,
      "rows": [
        {
          "id": 3,
          "ts": "...",
          "endpoint": "/plan",
          "status": 200,
          "latency_ms": 12,
          "payload": { ... }
        }
      ]
    }
    """
    _init_db()

    with _DB_LOCK:
        conn = sqlite3.connect(DB_PATH)
        conn.row_factory = sqlite3.Row
        try:
            cur = conn.execute(
                """
                SELECT id, ts, endpoint, status, latency_ms, payload
                FROM execution_log
                ORDER BY id DESC
                LIMIT ?
                """,
                (limit,),
            )
            rows = cur.fetchall()
        finally:
            conn.close()

    parsed: List[Dict[str, Any]] = []
    for row in rows:
        try:
            payload = json.loads(row["payload"]) if row["payload"] else {}
        except Exception:
            payload = {"raw": row["payload"]}

        parsed.append(
            {
                "id": row["id"],
                "ts": row["ts"],
                "endpoint": row["endpoint"],
                "status": row["status"],
                "latency_ms": row["latency_ms"],
                "payload": payload,
            }
        )

    return {
        "ok": True,
        "count": len(parsed),
        "rows": parsed,
    }
PY

echo "✅ apps/orchestrator/execution_log.py reset to simple logger."

echo "ℹ No changes to main.py wiring were made. It should still have:"
echo "   from apps.orchestrator import execution_log as _execution_log"
echo "   app.include_router(_execution_log.router)"

