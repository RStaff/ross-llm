#!/usr/bin/env bash
set -euo pipefail

FILE="apps/orchestrator/routes/pgvector_store.py"
test -f "$FILE" || { echo "❌ Missing $FILE"; exit 1; }

echo "==> 1) Backup file"
ts="$(date +%s)"
BAK="${FILE}.bak_${ts}"
cp -v "$FILE" "$BAK"
echo "✅ Backup at: $BAK"

echo "==> 2) Patch: fix ingest error label + add Venture Registry"
python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/orchestrator/routes/pgvector_store.py")
txt = p.read_text()

marker = "# === ROSSOS_VENTURES_V1 ==="
if marker in txt:
    print("ℹ️ Ventures block already present; leaving file unchanged.")
    raise SystemExit(0)

# --- Fix wrong error label in ingest handler (currently says retrieve_failed) ---
# Make this tolerant to whitespace / formatting.
txt = re.sub(
    r'detail=f"retrieve_failed:\s*\{e!r\}"',
    'detail=f"ingest_failed: {e!r}"',
    txt,
    count=1
)

# --- Append ventures block ---
block = f"""

{marker}
# Venture Registry: multi-venture backbone for RossOS (Abando, No Kings, etc.)
# Adds a 'ventures' table and CRUD endpoints under the SAME router.

import uuid
from datetime import datetime
from fastapi import Path as FPath, Query

def _ensure_ventures_schema():
    with _db() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                CREATE TABLE IF NOT EXISTS ventures (
                  id TEXT PRIMARY KEY,
                  name TEXT NOT NULL,
                  kind TEXT NOT NULL DEFAULT 'business',
                  status TEXT NOT NULL DEFAULT 'active',
                  goals JSONB NOT NULL DEFAULT '{{}}'::jsonb,
                  meta JSONB NOT NULL DEFAULT '{{}}'::jsonb,
                  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                );
            """)
            cur.execute("CREATE INDEX IF NOT EXISTS ventures_status_idx ON ventures(status);")
            cur.execute("CREATE INDEX IF NOT EXISTS ventures_kind_idx ON ventures(kind);")

def _now_iso():
    return datetime.utcnow().isoformat() + "Z"

class Venture(BaseModel):
    id: str
    name: str
    kind: str = "business"
    status: str = "active"
    goals: Dict[str, Any] = Field(default_factory=dict)
    meta: Dict[str, Any] = Field(default_factory=dict)
    created_at: Optional[str] = None
    updated_at: Optional[str] = None

class VentureCreate(BaseModel):
    name: str
    kind: str = "business"
    status: str = "active"
    goals: Dict[str, Any] = Field(default_factory=dict)
    meta: Dict[str, Any] = Field(default_factory=dict)

class VentureUpdate(BaseModel):
    name: Optional[str] = None
    kind: Optional[str] = None
    status: Optional[str] = None
    goals: Optional[Dict[str, Any]] = None
    meta: Optional[Dict[str, Any]] = None

@router.post("/ventures", response_model=Venture)
def create_venture(payload: VentureCreate) -> Venture:
    try:
        _ensure_ventures_schema()
        vid = uuid.uuid4().hex[:24]
        with _db() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO ventures (id, name, kind, status, goals, meta, created_at, updated_at)
                    VALUES (%s, %s, %s, %s, %s::jsonb, %s::jsonb, NOW(), NOW())
                    RETURNING created_at::text, updated_at::text
                    """,
                    (vid, payload.name, payload.kind, payload.status, json.dumps(payload.goals), json.dumps(payload.meta)),
                )
                created_at, updated_at = cur.fetchone()
        return Venture(
            id=vid,
            name=payload.name,
            kind=payload.kind,
            status=payload.status,
            goals=payload.goals,
            meta=payload.meta,
            created_at=created_at,
            updated_at=updated_at,
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"ventures_create_failed: {e!r}")

@router.get("/ventures", response_model=List[Venture])
def list_ventures(
    status: Optional[str] = Query(default=None),
    kind: Optional[str] = Query(default=None),
    limit: int = Query(default=100, ge=1, le=500),
) -> List[Venture]:
    try:
        _ensure_ventures_schema()
        clauses = []
        params = []
        if status:
            clauses.append("status = %s")
            params.append(status)
        if kind:
            clauses.append("kind = %s")
            params.append(kind)
        where = ("WHERE " + " AND ".join(clauses)) if clauses else ""
        params.append(limit)

        with _db() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute(
                    f"""
                    SELECT id, name, kind, status, goals, meta,
                           created_at::text as created_at,
                           updated_at::text as updated_at
                    FROM ventures
                    {where}
                    ORDER BY updated_at DESC
                    LIMIT %s
                    """,
                    params,
                )
                rows = cur.fetchall()

        return [
            Venture(
                id=r["id"],
                name=r["name"],
                kind=r["kind"],
                status=r["status"],
                goals=r["goals"] or {{}},
                meta=r["meta"] or {{}},
                created_at=r["created_at"],
                updated_at=r["updated_at"],
            )
            for r in rows
        ]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"ventures_list_failed: {e!r}")

@router.get("/ventures/{venture_id}", response_model=Venture)
def get_venture(venture_id: str = FPath(...)) -> Venture:
    try:
        _ensure_ventures_schema()
        with _db() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute(
                    """
                    SELECT id, name, kind, status, goals, meta,
                           created_at::text as created_at,
                           updated_at::text as updated_at
                    FROM ventures
                    WHERE id = %s
                    """,
                    (venture_id,),
                )
                r = cur.fetchone()
        if not r:
            raise HTTPException(status_code=404, detail="venture_not_found")
        return Venture(
            id=r["id"],
            name=r["name"],
            kind=r["kind"],
            status=r["status"],
            goals=r["goals"] or {{}},
            meta=r["meta"] or {{}},
            created_at=r["created_at"],
            updated_at=r["updated_at"],
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"venture_get_failed: {e!r}")

@router.patch("/ventures/{venture_id}", response_model=Venture)
def update_venture(venture_id: str, payload: VentureUpdate) -> Venture:
    try:
        _ensure_ventures_schema()
        fields = []
        params = []
        if payload.name is not None:
            fields.append("name = %s"); params.append(payload.name)
        if payload.kind is not None:
            fields.append("kind = %s"); params.append(payload.kind)
        if payload.status is not None:
            fields.append("status = %s"); params.append(payload.status)
        if payload.goals is not None:
            fields.append("goals = %s::jsonb"); params.append(json.dumps(payload.goals))
        if payload.meta is not None:
            fields.append("meta = %s::jsonb"); params.append(json.dumps(payload.meta))

        if not fields:
            return get_venture(venture_id)

        params.append(venture_id)

        with _db() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    f"""
                    UPDATE ventures
                    SET {", ".join(fields)}, updated_at = NOW()
                    WHERE id = %s
                    """,
                    params,
                )

        return get_venture(venture_id)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"venture_update_failed: {e!r}")

@router.delete("/ventures/{venture_id}")
def delete_venture(venture_id: str):
    try:
        _ensure_ventures_schema()
        with _db() as conn:
            with conn.cursor() as cur:
                cur.execute("DELETE FROM ventures WHERE id = %s", (venture_id,))
        return {{"ok": True, "deleted": venture_id}}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"venture_delete_failed: {e!r}")

@router.get("/brief/daily")
def daily_brief():
    \"\"\"Minimal daily brief v1: lists ventures + simple counts.\"\"\"
    try:
        _ensure_ventures_schema()
        _ensure_schema()  # pgvector docs schema
        with _db() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT COUNT(*) FROM ventures;")
                ventures_ct = cur.fetchone()[0]
                cur.execute("SELECT COUNT(*) FROM docs;")
                docs_ct = cur.fetchone()[0]
        ventures = list_ventures(limit=50)
        return {{
            "ok": True,
            "timestamp": _now_iso(),
            "summary": {{
                "ventures_count": ventures_ct,
                "docs_count": docs_ct,
            }},
            "ventures": [v.model_dump() for v in ventures],
            "next_actions": [
                "Add/confirm ventures (Abando, No Kings Athletics, Stafford Media Consulting).",
                "Ingest a few key docs per venture (roadmaps, notes, metrics).",
                "Next step: UI Command Center reads /brief/daily + /ventures.",
            ],
        }}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"daily_brief_failed: {e!r}")
"""

p.write_text(txt + block)
print("✅ Patched:", p)
PY

echo "==> 3) Rebuild + restart orchestrator"
docker compose up -d --build orchestrator

echo "==> 4) Wait for health"
for i in {1..60}; do
  if curl -sf http://localhost:8001/health >/dev/null; then
    echo "✅ orchestrator healthy"
    echo "==> 5) Confirm endpoints exist in OpenAPI"
    curl -sS http://localhost:8001/openapi.json | python3 - <<'PY'
import sys, json
d=json.load(sys.stdin)
paths=set(d.get("paths", {}).keys())
want=["/ventures","/brief/daily"]
print("found:", {p:(p in paths) for p in want})
PY
    exit 0
  fi
  sleep 1
done

echo "❌ orchestrator did not become healthy"
docker compose ps
docker compose logs --tail=200 orchestrator || true
exit 1
