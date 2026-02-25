#!/usr/bin/env bash
set -euo pipefail

echo "🔧 Installing Execution Logger module..."

if [ ! -d "apps/orchestrator" ]; then
  echo "❌ apps/orchestrator not found. Are you in ~/projects/ross-llm ?"
  exit 1
fi

# 1) Create apps/orchestrator/execution_log.py
python3 << 'PY'
from pathlib import Path
from textwrap import dedent

path = Path("apps/orchestrator/execution_log.py")
path.parent.mkdir(parents=True, exist_ok=True)

code = dedent('''
from __future__ import annotations

import json
import sqlite3
from pathlib import Path
from typing import Any, Dict, List

from fastapi import APIRouter, Query

# Simple execution log using SQLite
DB_PATH = Path("data/execution_log.db")


def _init_db() -> None:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    try:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS execution_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                ts TEXT NOT NULL,
                endpoint TEXT NOT NULL,
                status INTEGER,
                latency_ms INTEGER,
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
    Minimal logger you can call from any endpoint.

    Example from an endpoint:

        start = time.time()
        ...
        log_event("/plan", 200, int((time.time() - start)*1000), {"goal": goal})
    """
    if payload is None:
        payload = {}

    # Keep payload bounded
    try:
        payload_json = json.dumps(payload)
    except Exception:
        payload_json = "{}"

    if len(payload_json) > 10_000:
        payload_json = payload_json[:10_000]

    conn = sqlite3.connect(DB_PATH)
    try:
        conn.execute(
            """
            INSERT INTO execution_log (ts, endpoint, status, latency_ms, payload)
            VALUES (datetime('now'), ?, ?, ?, ?)
            """,
            (endpoint, status, latency_ms, payload_json),
        )
        conn.commit()
    finally:
        conn.close()


router = APIRouter(prefix="/logs", tags=["logs"])


@router.get("/latest")
async def logs_latest(limit: int = Query(50, ge=1, le=500)) -> Dict[str, Any]:
    """
    Return the most recent log entries.

    Example:
        GET /logs/latest?limit=20
    """
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        cur = conn.cursor()
        cur.execute(
            """
            SELECT id, ts, endpoint, status, latency_ms, payload
            FROM execution_log
            ORDER BY id DESC
            LIMIT ?
            """,
            (limit,),
        )
        rows = [dict(r) for r in cur.fetchall()]
    finally:
        conn.close()

    return {
        "ok": True,
        "count": len(rows),
        "rows": rows,
    }
''')

path.write_text(code)
print(f"✅ Created {path}")
PY

# 2) Wire router into apps/orchestrator/main.py
python3 << 'PY'
from pathlib import Path
from textwrap import dedent

main_path = Path("apps/orchestrator/main.py")
if not main_path.exists():
    raise SystemExit("❌ apps/orchestrator/main.py not found; cannot wire execution_log router.")

text = main_path.read_text()
marker = "execution_log router (auto-added)"

if marker in text:
    print("ℹ execution_log router already wired into main.py")
else:
    snippet = dedent('''

    # StaffordOS execution_log router (auto-added)
    try:
        from apps.orchestrator import execution_log as _execution_log
        app.include_router(_execution_log.router)
    except Exception as e:  # pragma: no cover
        print("Warning: failed to load execution_log router:", e)
    ''')
    main_path.write_text(text + snippet)
    print("✅ execution_log router wired into apps/orchestrator/main.py")
PY

echo "✅ Execution Logger installed."
echo "   After ross-up, try:"
echo "   curl -s http://127.0.0.1:8000/logs/latest | jq"
