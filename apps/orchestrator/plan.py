from __future__ import annotations

import time
from typing import Any, Dict, List, Optional

import httpx
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from execution_log import log_event

router = APIRouter(tags=["plan"])


class PlanRequest(BaseModel):
    goal: str
    max_subtasks: int = 6
    top_k: int = 2


@router.post("/plan")
async def plan_endpoint(body: PlanRequest) -> Dict[str, Any]:
    """
    High-level planner endpoint.

    - Calls /tasks/decompose to break the goal into subtasks
    - Calls /retrieve/multi to fetch parallel context for each subtask
    - Logs execution via Execution Logger
    """
    start = time.time()
    status_code: int = 200

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            # 1) Decompose goal into subtasks
            decompose_payload = {
                "goal": body.goal,
                "max_subtasks": body.max_subtasks,
            }
            decomp_resp = await client.post(
                "http://127.0.0.1:8000/tasks/decompose",
                json=decompose_payload,
            )
            decomp_data = decomp_resp.json()

            if not decomp_resp.is_success or not decomp_data.get("ok", False):
                raise HTTPException(
                    status_code=500,
                    detail={
                        "message": "Task decomposition failed",
                        "payload": decomp_data,
                    },
                )

            subtasks: List[Dict[str, Any]] = decomp_data.get("subtasks", [])
            if not subtasks:
                # Fallback: single subtask using the goal itself
                subtasks = [
                    {"id": 1, "text": body.goal},
                ]

            # 2) Parallel retrieval for each subtask text
            queries = [s.get("text", "") for s in subtasks if s.get("text")]
            if not queries:
                queries = [body.goal]

            retrieve_payload = {
                "queries": queries,
                "top_k": body.top_k,
            }
            retr_resp = await client.post(
                "http://127.0.0.1:8000/retrieve/multi",
                json=retrieve_payload,
            )
            retr_data = retr_resp.json()

            # We don't hard-fail if retrieval isn't ok; we just include what we got
            retrieval_block: Dict[str, Any] = retr_data

        latency_ms = int((time.time() - start) * 1000)

        result: Dict[str, Any] = {
            "ok": True,
            "goal": body.goal,
            "subtasks": subtasks,
            "retrieval": retrieval_block,
            "latency_ms": float(latency_ms),
        }

        # Log success
        log_event(
            endpoint="/plan",
            status=200,
            latency_ms=latency_ms,
            payload={
                "goal": body.goal,
                "max_subtasks": body.max_subtasks,
                "top_k": body.top_k,
                "subtask_count": len(subtasks),
                "retrieval_ok": bool(retrieval_block.get("ok", False)),
            },
        )

        return result

    except HTTPException:
        # Let FastAPI handle this but still log it
        latency_ms = int((time.time() - start) * 1000)
        log_event(
            endpoint="/plan",
            status=500,
            latency_ms=latency_ms,
            payload={
                "goal": body.goal,
                "max_subtasks": body.max_subtasks,
                "top_k": body.top_k,
                "error": "HTTPException in plan_endpoint",
            },
        )
        raise

    except Exception as e:  # pragma: no cover
        latency_ms = int((time.time() - start) * 1000)
        log_event(
            endpoint="/plan",
            status=500,
            latency_ms=latency_ms,
            payload={
                "goal": body.goal,
                "max_subtasks": body.max_subtasks,
                "top_k": body.top_k,
                "error": repr(e),
            },
        )
        raise HTTPException(
            status_code=500,
            detail={"message": "Unexpected error in /plan", "error": repr(e)},
        )
