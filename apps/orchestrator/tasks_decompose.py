from __future__ import annotations

from typing import List
from fastapi import APIRouter
from pydantic import BaseModel, Field


router = APIRouter()


class TaskDecomposeRequest(BaseModel):
    """
    Request body for task decomposition.

    Example:
        {
          "goal": "Ship Abando MVP, set up marketing automation, and record launch video",
          "max_subtasks": 6
        }
    """
    goal: str = Field(..., description="High-level goal or objective to break down.")
    max_subtasks: int = Field(
        6,
        ge=1,
        le=20,
        description="Maximum number of subtasks to return.",
    )


class Task(BaseModel):
    """Single decomposed task item."""
    id: int
    text: str


class TaskDecomposeResponse(BaseModel):
    """Response for /tasks/decompose."""
    ok: bool
    goal: str
    subtasks: List[Task]


def _normalize(text: str) -> str:
    return " ".join(text.strip().split())


def heuristic_decompose(goal: str, max_subtasks: int) -> List[Task]:
    """
    Very lightweight, deterministic task decomposition.

    This does NOT call an LLM on purpose, so your orchestrator
    stays stable even if keys/env change. Later you can swap
    this out for an LLM-backed planner while keeping the same API.
    """
    g = _normalize(goal)
    if not g:
        return []

    # If the goal is short, just return a single task.
    if len(g) < 60:
        return [Task(id=1, text=g)]

    # Split on simple separators: "and", "then", commas, periods
    raw = []
    buf = g.replace(" then ", ". ").replace(" and ", ", ")

    for piece in buf.replace(";", ".").split("."):
        for chunk in piece.split(","):
            t = _normalize(chunk)
            if t:
                raw.append(t)

    # Deduplicate while preserving order
    seen = set()
    uniq: List[str] = []
    for item in raw:
        if item.lower() not in seen:
            seen.add(item.lower())
            uniq.append(item)

    if not uniq:
        uniq = [g]

    # Enforce max_subtasks
    uniq = uniq[:max_subtasks]

    return [Task(id=i + 1, text=t) for i, t in enumerate(uniq)]


@router.post("/tasks/decompose", response_model=TaskDecomposeResponse)
async def decompose_tasks(payload: TaskDecomposeRequest) -> TaskDecomposeResponse:
    """
    Break a high-level goal into smaller subtasks.

    This is your "Task Decomposition Agent" primitive.
    It can be used by higher-level flows to:
      - generate parallel retrieval queries
      - build small execution checklists
      - plan CI/CD or infra changes across steps
    """
    subtasks = heuristic_decompose(payload.goal, payload.max_subtasks)
    return TaskDecomposeResponse(
        ok=True,
        goal=payload.goal,
        subtasks=subtasks,
    )
