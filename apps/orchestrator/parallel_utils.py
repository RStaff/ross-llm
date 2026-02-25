"""
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
