#!/usr/bin/env bash
set -euo pipefail

echo "🔧 Patching apps/orchestrator/plan.py with Execution Logger wiring..."

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLAN_PATH="$ROOT_DIR/apps/orchestrator/plan.py"

if [ ! -f "$PLAN_PATH" ]; then
  echo "❌ $PLAN_PATH not found. Are you in ~/projects/ross-llm?"
  exit 1
fi

BACKUP_PATH="${PLAN_PATH}.bak_$(date +%Y%m%d_%H%M%S)"
cp "$PLAN_PATH" "$BACKUP_PATH"
echo "📦 Backed up existing plan.py to: $BACKUP_PATH"

cat > "$PLAN_PATH" << 'PY'
from __future__ import annotations

import time
from typing import Any, Dict, List

from fastapi import APIRouter
from pydantic import BaseModel

# We use the existing orchestrator modules you already installed
from apps.orchestrator import tasks_decompose
from apps.orchestrator import retrieval_parallel

# NEW: execution logger hook
from apps.orchestrator.execution_log import log_event


router = APIRouter(prefix="/plan", tags=["plan"])


class PlanRequest(BaseModel):
    goal: str
    max_subtasks: int = 5
    top_k: int = 2


@router.post("/")
async def make_plan(req: PlanRequest) -> Dict[str, Any]:
    """
    Global planning endpoint.

    1) Decomposes a high-level goal into subtasks via /tasks/decompose
    2) Runs parallel retrieval for each subtask via /retrieve/multi
    3) Logs the execution via Execution Logger
    """
    start = time.time()
    status = 200

    try:
        # 1) Decompose the goal into subtasks
        subtasks_resp = await tasks_decompose.decompose_goal(
            {
                "goal": req.goal,
                "max_subtasks": req.max_subtasks,
            }
        )
        subtasks: List[Dict[str, Any]] = subtasks_resp.get("subtasks", [])

        # 2) Use subtasks as queries for parallel retrieval (fallback to goal)
        queries: List[str] = [s["text"] for s in subtasks] if subtasks else [req.goal]

        retrieval_resp = await retrieval_parallel.retrieve_multi(
            {
                "queries": queries,
                "top_k": req.top_k,
            }
        )

        result: Dict[str, Any] = {
            "ok": True,
            "goal": req.goal,
            "subtasks": subtasks,
            "retrieval": retrieval_resp,
            "latency_ms": int((time.time() - start) * 1000),
        }
        return result

    except Exception as e:
        status = 500
        result = {
            "ok": False,
            "error": str(e),
            "latency_ms": int((time.time() - start) * 1000),
        }
        return result

    finally:
        # Always try to log – but never break the endpoint if logging fails
        try:
            log_event(
                endpoint="/plan",
                status=status,
                latency_ms=int((time.time() - start) * 1000),
                payload={
                    "goal": req.goal,
                    "max_subtasks": req.max_subtasks,
                    "top_k": req.top_k,
                },
            )
        except Exception as log_err:  # pragma: no cover
            print("Warning: failed to log /plan execution:", log_err)
PY

echo "✅ apps/orchestrator/plan.py patched with logging."
