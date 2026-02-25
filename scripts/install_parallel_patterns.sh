#!/usr/bin/env bash
set -euo pipefail

echo "🔧 Installing StaffordOS parallel tools + debug route..."

# Always run from repo root (scripts/ is one level below)
cd "$(dirname "$0")/.."

########################################
# A) Create apps/orchestrator/parallel_utils.py
########################################
python3 << 'PY'
from pathlib import Path
base = Path("apps/orchestrator")
base.mkdir(parents=True, exist_ok=True)

parallel_utils = base / "parallel_utils.py"

parallel_utils.write_text(
    '''"""
Lightweight agent-style helpers for StaffordOS.

- run_parallel: run multiple async "tool" jobs concurrently.
- double_check: call the same model twice and return both answers
  plus a naive "best" pick (longer answer wins).
"""
from __future__ import annotations

import asyncio
from typing import Any, Awaitable, Callable, Iterable, List, Sequence, Dict

AsyncJob = Callable[[], Awaitable[Any]]


async def run_parallel(jobs: Sequence[AsyncJob]) -> List[Any]:
    """
    Run a sequence of async jobs in parallel and return their results.

    Any exceptions are returned as-is in the results list, so callers
    can inspect and handle them.
    """
    if not jobs:
        return []
    results = await asyncio.gather(*(job() for job in jobs), return_exceptions=True)
    return list(results)


async def double_check(
    call_model: Callable[[str], Awaitable[str]],
    prompt: str,
) -> Dict[str, Any]:
    """
    Very simple "careful mode":

    - Calls the same model function twice with the same prompt.
    - Returns both answers and picks the longer one as 'best'.

    You can swap this out later for a smarter judge or editor agent.
    """
    ans_a, ans_b = await asyncio.gather(
        call_model(prompt),
        call_model(prompt),
    )

    a = ans_a or ""
    b = ans_b or ""
    best = a if len(a) >= len(b) else b

    return {
        "answer_a": ans_a,
        "answer_b": ans_b,
        "best": best,
    }
'''
)

print(f"✅ parallel_utils.py written to {parallel_utils}")
PY

########################################
# B) Create apps/orchestrator/parallel_debug.py
########################################
python3 << 'PY'
from pathlib import Path

base = Path("apps/orchestrator")
base.mkdir(parents=True, exist_ok=True)

parallel_debug = base / "parallel_debug.py"

parallel_debug.write_text(
    '''"""
Debug endpoint to prove that run_parallel works.

GET /debug/parallel-demo

Returns JSON with three fake jobs that were executed concurrently.
"""
from __future__ import annotations

import asyncio
from fastapi import APIRouter

from .parallel_utils import run_parallel

router = APIRouter()


@router.get("/debug/parallel-demo")
async def parallel_demo():
    async def fake_job(name: str, delay: float):
        await asyncio.sleep(delay)
        return {"job": name, "delay": delay}

    results = await run_parallel(
        [
            lambda: fake_job("job_a", 0.10),
            lambda: fake_job("job_b", 0.20),
            lambda: fake_job("job_c", 0.05),
        ]
    )

    return {
        "ok": True,
        "pattern": "parallel_tools",
        "results": results,
    }
'''
)

print(f"✅ parallel_debug.py written to {parallel_debug}")
PY

########################################
# C) Wire parallel_debug router into apps/orchestrator/main.py
########################################
python3 << 'PY'
from pathlib import Path

path = Path("apps/orchestrator/main.py")
if not path.exists():
    raise SystemExit("❌ apps/orchestrator/main.py not found – are you in the ross-llm repo root?")

text = path.read_text()

marker = "parallel_debug router (auto-added)"
if marker in text:
    print("ℹ parallel_debug router already included in main.py – no changes.")
else:
    snippet = f"""

# StaffordOS parallel_debug router (auto-added)
try:
    from apps.orchestrator import parallel_debug as stafford_parallel_debug
    app.include_router(stafford_parallel_debug.router)
except Exception as e:  # pragma: no cover
    print("Warning: failed to load parallel_debug router:", e)
"""

    path.write_text(text.rstrip() + snippet)
    print("✅ parallel_debug router include appended to apps/orchestrator/main.py")
PY

echo "✅ Parallel tools + debug route installed."
echo "   Test: curl http://127.0.0.1:8000/debug/parallel-demo"
