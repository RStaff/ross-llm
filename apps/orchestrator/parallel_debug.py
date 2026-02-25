"""
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
