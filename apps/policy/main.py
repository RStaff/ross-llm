import os, re, json, time
from typing import Dict, Any
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

RULES_PATH = os.getenv("RULES_PATH", "/app/rules.json")

app = FastAPI()
POLICY_ON = True

class CheckRequest(BaseModel):
    user_id: str
    text: str

def load_rules() -> Dict[str, Any]:
    with open(RULES_PATH, "r") as f:
        return json.load(f)

RULES = load_rules()

def check_text(text: str) -> Dict[str, Any]:
    lower = text.lower()
    for rule in RULES.get("rules", []):
        mode = rule.get("mode", "substring")
        matched = False
        if mode == "substring":
            matched = any(s in lower for s in rule.get("patterns", []))
        elif mode == "regex":
            matched = any(re.search(p, text, flags=re.IGNORECASE|re.MULTILINE) for p in rule.get("patterns", []))
        if matched:
            return {
                "allow": False,
                "reason_code": rule["reason_code"],
                "message": RULES["refusal_templates"].get(rule["reason_code"], "I can’t help with that."),
                "category": rule.get("category", "unspecified"),
            }
    return {"allow": True}

@app.get("/health")
def health():
    return {"ok": True, "policy": "on" if POLICY_ON else "off"}

@app.post("/check")
def check(req: CheckRequest):
    if not POLICY_ON:
        return {"allow": True}
    t0 = time.time()
    result = check_text(req.text)
    result["latency_ms"] = int((time.time() - t0) * 1000)
    return result

@app.post("/toggle")
def toggle():
    global POLICY_ON
    POLICY_ON = not POLICY_ON
    return {"ok": True, "policy": "on" if POLICY_ON else "off"}

@app.post("/reload")
def reload_rules():
    global RULES
    try:
        RULES = load_rules()
        return {"ok": True, "rules": len(RULES.get("rules", []))}
    except Exception as e:
        raise HTTPException(500, f"failed to reload rules: {e}")

# --- prometheus metrics (appended) ---
try:
    from time import perf_counter
    from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
    from fastapi import Request
    from fastapi.responses import Response

    REQ_COUNTER = Counter(
        "http_requests_total",
        "Total HTTP requests",
        ["service", "method", "path", "status"],
    )
    REQ_LATENCY = Histogram(
        "http_request_duration_seconds",
        "Request latency in seconds",
        ["service", "method", "path"],
        buckets=(0.005,0.01,0.025,0.05,0.1,0.25,0.5,1,2,5)
    )

    SERVICE_NAME = "policy"

    @app.middleware("http")
    async def _metrics_mw(request: Request, call_next):
        start = perf_counter()
        path = request.url.path
        method = request.method
        try:
            resp = await call_next(request)
            status = getattr(resp, "status_code", 500)
            return resp
        finally:
            elapsed = perf_counter() - start
            REQ_COUNTER.labels(SERVICE_NAME, method, path, str(status)).inc()
            REQ_LATENCY.labels(SERVICE_NAME, method, path).observe(elapsed)

    @app.get("/metrics")
    def metrics():
        return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
except Exception as _e:
    # Keep app running even if metrics wiring hiccups
    pass
# --- end prometheus metrics ---
