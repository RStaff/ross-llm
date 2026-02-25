#!/usr/bin/env bash
set -euo pipefail

echo "🔧 Installing /plan endpoint..."

python3 << 'PY'
from pathlib import Path
from textwrap import dedent

root = Path("apps/orchestrator")
root.mkdir(parents=True, exist_ok=True)

plan_path = root / "plan.py"

if not plan_path.exists():
    plan_path.write_text(dedent('''
    from fastapi import APIRouter, HTTPException
    from pydantic import BaseModel
    import httpx
    import time
    from typing import List, Any, Dict

    router = APIRouter()

    ORCH_URL = "http://127.0.0.1:8000"

    class PlanRequest(BaseModel):
        goal: str
        max_subtasks: int = 6
        top_k: int = 2

    @router.post("/plan")
    async def make_plan(payload: PlanRequest) -> Dict[str, Any]:
        """
        High-level planning endpoint:
        1) Decompose goal into subtasks via /tasks/decompose
        2) Fetch parallel context via /retrieve/multi
        """
        async with httpx.AsyncClient() as client:
            # 1) Decompose goal
            try:
                decomp_resp = await client.post(
                    f"{ORCH_URL}/tasks/decompose",
                    json={
                        "goal": payload.goal,
                        "max_subtasks": payload.max_subtasks,
                    },
                    timeout=10.0,
                )
                decomp_resp.raise_for_status()
            except Exception as e:
                raise HTTPException(
                    status_code=502,
                    detail=f"Failed to decompose goal: {e}",
                )

            decomp_json = decomp_resp.json()
            if not decomp_json.get("ok"):
                raise HTTPException(
                    status_code=500,
                    detail="tasks/decompose returned ok!=true",
                )

            subtasks = [s["text"] for s in decomp_json.get("subtasks", [])]
            if not subtasks:
                # Nothing to retrieve, just return decomposition
                return {
                    "ok": True,
                    "goal": payload.goal,
                    "subtasks": decomp_json.get("subtasks", []),
                    "retrieval": None,
                }

            # 2) Parallel retrieval
            try:
                t0 = time.time()
                retr_resp = await client.post(
                    f"{ORCH_URL}/retrieve/multi",
                    json={
                        "queries": subtasks,
                        "top_k": payload.top_k,
                    },
                    timeout=30.0,
                )
                retr_resp.raise_for_status()
                t1 = time.time()
            except Exception as e:
                raise HTTPException(
                    status_code=502,
                    detail=f"Failed parallel retrieval: {e}",
                )

            retr_json = retr_resp.json()

            return {
                "ok": True,
                "goal": payload.goal,
                "subtasks": decomp_json.get("subtasks", []),
                "retrieval": retr_json,
                "latency_ms": (t1 - t0) * 1000.0,
            }
    ''').lstrip())
    print(f"✅ Created {plan_path}")
else:
    print(f"ℹ {plan_path} already exists; leaving it unchanged.")

# Wire router into main.py
main_path = root / "main.py"
if not main_path.exists():
    raise SystemExit("❌ apps/orchestrator/main.py not found; cannot wire /plan router.")

text = main_path.read_text()
marker = "plan router (auto-added)"

if marker in text:
    print("ℹ plan router already wired into main.py")
else:
    snippet = dedent('''

    # StaffordOS plan router (auto-added)
    try:
        from apps.orchestrator import plan as _plan
        app.include_router(_plan.router)
    except Exception as e:  # pragma: no cover
        print("Warning: failed to load plan router:", e)
    ''')
    main_path.write_text(text + snippet)
    print("✅ plan router wired into apps/orchestrator/main.py")
PY

echo "✅ /plan endpoint installed."
