#!/usr/bin/env bash
set -euo pipefail

echo "🔧 Patching apps/orchestrator/metrics.py to reuse Execution Logger DB..."

METRICS_PATH="apps/orchestrator/metrics.py"

cat > "$METRICS_PATH" << 'PY'
"""
StaffordOS Metrics Endpoint (logger-aligned)

Reads from the SAME DB as apps/orchestrator/execution_log.py and returns:
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

# Reuse DB_PATH from execution_log so we NEVER drift
try:
    from apps.orchestrator.execution_log import DB_PATH as EXEC_DB_PATH  # type: ignore
    DB_PATH = EXEC_DB_PATH
    print(f"[metrics] Using Execution Logger DB_PATH={DB_PATH}")
except Exception:
    # Fallback if import fails for some reason
    DB_PATH = os.path.join("data", "execution_log.sqlite")
    print(f"[metrics] Fallback DB_PATH={DB_PATH}")


def _get_conn() -> sqlite3.Connection:
    """
    Open a connection to the execution_log database.

    We DO NOT create tables here; execution_log is the source of truth.
    """
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
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

    NOTE: We assume execution_log has columns:
      id, ts (TEXT), endpoint (TEXT), status (INT), latency_ms (INT), payload (TEXT)
    """
    now_utc = datetime.utcnow()
    cutoff = now_utc - timedelta(minutes=window_minutes)
    cutoff_str = cutoff.strftime("%Y-%m-%d %H:%M:%S")

    conn = _get_conn()
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

echo "✅ apps/orchestrator/metrics.py now imports DB_PATH from execution_log."
echo "   After ross-up, try:"
echo "   curl -s \"http://127.0.0.1:8000/metrics/summary?window_minutes=1440\" | jq"
