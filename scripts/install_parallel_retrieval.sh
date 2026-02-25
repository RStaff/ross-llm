#!/usr/bin/env bash
set -euo pipefail

echo "🔧 Installing Parallel Retrieval module..."

# Go to repo root (this script lives in scripts/)
cd "$(dirname "$0")/.."

python3 << 'PY'
from pathlib import Path
from textwrap import dedent

base = Path("apps/orchestrator")
base.mkdir(parents=True, exist_ok=True)
path = base / "retrieval_parallel.py"

if not path.exists():
    code = dedent('''
    from __future__ import annotations

    import asyncio
    import time
    from typing import List, Dict, Any

    from fastapi import APIRouter
    from pydantic import BaseModel, Field


    router = APIRouter()


    class MultiRetrieveRequest(BaseModel):
        """Request body for parallel retrieval."""
        queries: List[str] = Field(
            ...,
            description="Natural language search or retrieval queries.",
        )
        top_k: int = Field(
            3,
            ge=1,
            le=20,
            description="Max stub 'documents' to return per query.",
        )


    class RetrieveHit(BaseModel):
        """Per-query retrieval result."""
        query: str
        documents: List[Dict[str, Any]]
        latency_ms: float


    class MultiRetrieveResponse(BaseModel):
        """Response for /retrieve/multi."""
        ok: bool
        results: List[RetrieveHit]
        total_queries: int
        total_latency_ms: float


    async def simple_keyword_retriever(query: str, top_k: int) -> List[Dict[str, Any]]:
        """
        Placeholder backend for retrieval.

        Right now this just returns stubbed 'documents' so the architecture
        is solid without requiring a real vector DB or RAG implementation.
        Later you can replace this with calls into:
          - pgvector / Postgres
          - a local embeddings store
          - your Abando / Ross-LLM memory layer
        """
        docs: List[Dict[str, Any]] = []
        for i in range(top_k):
            docs.append(
                {
                    "id": f"stub-{i+1}",
                    "score": 1.0 - (i * 0.1),
                    "snippet": f"(stub) result {i+1} for query: {query}",
                }
            )
        return docs


    @router.post("/retrieve/multi", response_model=MultiRetrieveResponse)
    async def multi_retrieve(payload: MultiRetrieveRequest) -> MultiRetrieveResponse:
        """
        Run retrieval for several queries in parallel.

        This is the foundation of your 'Parallel Retrieval Search' module.
        It fans out all queries concurrently, measures per-query latency,
        and returns structured results you can feed into higher-level agents.
        """
        t0 = time.time()

        async def run_one(q: str) -> RetrieveHit:
            start = time.time()
            docs = await simple_keyword_retriever(q, payload.top_k)
            return RetrieveHit(
                query=q,
                documents=docs,
                latency_ms=(time.time() - start) * 1000.0,
            )

        # Fan out in parallel
        tasks = [run_one(q) for q in payload.queries]
        raw_results = await asyncio.gather(*tasks, return_exceptions=True)

        results: List[RetrieveHit] = []
        for q, item in zip(payload.queries, raw_results):
            if isinstance(item, Exception):
                # Keep the shape stable even on error
                results.append(
                    RetrieveHit(
                        query=q,
                        documents=[
                            {
                                "id": "error",
                                "score": 0.0,
                                "snippet": f"retrieval error: {item}",
                            }
                        ],
                        latency_ms=0.0,
                    )
                )
            else:
                results.append(item)

        total_latency_ms = (time.time() - t0) * 1000.0

        return MultiRetrieveResponse(
            ok=True,
            results=results,
            total_queries=len(results),
            total_latency_ms=total_latency_ms,
        )
    ''').lstrip()
    path.write_text(code)
    print("✅ Created apps/orchestrator/retrieval_parallel.py")
else:
    print("ℹ apps/orchestrator/retrieval_parallel.py already exists; leaving as-is.")


# Wire the router into apps/orchestrator/main.py
main_path = base / "main.py"
if not main_path.exists():
    raise SystemExit("❌ apps/orchestrator/main.py not found; cannot wire router.")

text = main_path.read_text()
marker = "retrieval_parallel router (auto-added)"

if marker in text:
    print("ℹ retrieval_parallel router already wired into main.py")
else:
    snippet = dedent('''

    # StaffordOS parallel retrieval router (auto-added)
    try:
        from apps.orchestrator import retrieval_parallel as _retrieval_parallel
        app.include_router(_retrieval_parallel.router)
    except Exception as e:  # pragma: no cover
        print("Warning: failed to load retrieval_parallel router:", e)
    ''')
    main_path.write_text(text + snippet)
    print("✅ retrieval_parallel router wired into apps/orchestrator/main.py")
PY

echo "✅ Parallel Retrieval module installed."
