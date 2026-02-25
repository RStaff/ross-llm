#!/usr/bin/env bash
set -euo pipefail

echo "🔧 Installing StaffordOS /metrics/summary endpoint..."

mkdir -p apps/orchestrator

METRICS_PATH="apps/orchestrator/metrics.py"

cat > "$METRICS_PATH" << 'PY'
"""
StaffordOS Metrics Endpoint

Reads from data/execution_log.sqlite (simple logger) and returns:
- total calls in a time window
- average latency
- per-endpoint breakdown
"""

from fastapi import APIRouter, Query
from typing import Any, Dict, List
from datetime import datetime, timedelta
import sqlite3
import os

router = APIRouter()

DB_PATH = os.path.join("data", "execution_log.sqlite")


def _get_conn() -> sqlite3.Connection:
    # Ensure DB exists; if not, just return empty metrics
    if not os.path.exists(DB_PATH):
        # Create empty DB with matching table if somehow missing
        os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
        conn = sqlite3.connect(DB_PATH)
        cur = conn.cursor()
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS execution_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                ts TEXT NOT NULL DEFAULT (datetime('now')),
                endpoint TEXT NOT NULL,
                status INTEGER NOT NULL,
                latency_ms INTEGER NOT NULL,
                payload TEXT
            )
            """
        )
        conn.commit()
        return conn

    conn = sqlite3.connect(DB_PATH)
    return conn


@router.get("/metrics/summary")
def metrics_summary(
    window_minutes: int = Query(
        1440,
        description="Time window in minutes (default: 1440 = last 24h)",
        ge=1,
        le=60 * 24 * 7,  # up to 7 days
    )
) -> Dict[str, Any]:
    """
    Returns simple metrics for the given time window based on execution_log:
    - total calls
    - average latency
    - per-endpoint counts + avg latency
    """
    now_utc = datetime.utcnow()
    cutoff = now_utc - timedelta(minutes=window_minutes)
    cutoff_str = cutoff.strftime("%Y-%m-%d %H:%M:%S")

    conn = _get_conn()
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()

    # Overall metrics
    cur.execute(
        """
        SELECT
            COUNT(*) AS total_calls,
            COALESCE(AVG(latency_ms), 0) AS avg_latency_ms
        FROM execution_log
        WHERE ts >= ?
        """,
        (cutoff_str,),
    )
    row = cur.fetchone()
    total_calls = row["total_calls"] if row else 0
    avg_latency_ms = row["avg_latency_ms"] if row else 0

    # Per-endpoint breakdown
    cur.execute(
        """
        SELECT
            endpoint,
            COUNT(*) AS calls,
            COALESCE(AVG(latency_ms), 0) AS avg_latency_ms
        FROM execution_log
        WHERE ts >= ?
        GROUP BY endpoint
        ORDER BY calls DESC
        """,
        (cutoff_str,),
    )
    rows = cur.fetchall()
    by_endpoint: List[Dict[str, Any]] = []
    for r in rows:
        by_endpoint.append(
            {
                "endpoint": r["endpoint"],
                "calls": r["calls"],
                "avg_latency_ms": r["avg_latency_ms"],
            }
        )

    conn.close()

    return {
        "ok": True,
        "window_minutes": window_minutes,
        "since_utc": cutoff_str,
        "total_calls": total_calls,
        "avg_latency_ms": avg_latency_ms,
        "by_endpoint": by_endpoint,
    }
PY

echo "✅ Created $METRICS_PATH"

MAIN_PATH="apps/orchestrator/main.py"

if [ ! -f "$MAIN_PATH" ]; then
  echo "❌ $MAIN_PATH not found; cannot wire metrics router."
  exit 1
fi

python3 << 'PY'
from pathlib import Path
from textwrap import dedent

main_path = Path("apps/orchestrator/main.py")
text = main_path.read_text()

marker = "metrics router (auto-added)"

if marker in text:
    print("ℹ metrics router already wired into main.py")
else:
    snippet = dedent('''

    # StaffordOS metrics router (auto-added)
    try:
        from apps.orchestrator import metrics as _metrics
        app.include_router(_metrics.router)
    except Exception as e:  # pragma: no cover
        print("Warning: failed to load metrics router:", e)
    ''')
    main_path.write_text(text + snippet)
    print("✅ metrics router wired into apps/orchestrator/main.py")
PY

echo "✅ /metrics/summary endpoint installed."
echo "   After ross-up, try:"
echo "   curl -s \"http://127.0.0.1:8000/metrics/summary?window_minutes=1440\" | jq"
