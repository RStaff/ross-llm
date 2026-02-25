#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

MAIN="apps/orchestrator/main.py"

if [ ! -f "$MAIN" ]; then
  echo "❌ $MAIN not found. Adjust the path in patch_chat_metrics.sh."
  exit 1
fi

if grep -q "record_chat_success" "$MAIN"; then
  echo "✅ Chat metrics already wired – skipping."
  exit 0
fi

echo "🔧 Patching $MAIN to add chat metrics imports + wrapper..."

python3 - "$MAIN" << 'PY'
import sys, pathlib, textwrap

path = pathlib.Path(sys.argv[1])
text = path.read_text()

if "from apps.orchestrator.status import record_chat_success" not in text:
    text = text.replace(
        "from fastapi import",
        "from fastapi import",
    )
    # just append imports at top
    lines = text.splitlines()
    # Insert after first 'from fastapi' import or at top
    inserted = False
    for i, line in enumerate(lines):
        if line.startswith("from fastapi import"):
            lines.insert(i+1, "from apps.orchestrator.status import record_chat_success, record_chat_error")
            inserted = True
            break
    if not inserted:
        lines.insert(0, "from apps.orchestrator.status import record_chat_success, record_chat_error")
    text = "\n".join(lines)

if "@app.post(\"/chat\")" not in text:
    print("⚠️ Could not find @app.post(\"/chat\") in main.py; no wrapper added.")
    path.write_text(text)
    sys.exit(0)

# This does NOT change your existing function; it wraps with timing.
if "latency_ms =" in text and "record_chat_success(" in text:
    print("Metrics logic seems already present.")
    path.write_text(text)
    sys.exit(0)

snippet = '''
@app.post("/chat")
async def chat_endpoint(payload: ChatRequest) -> ChatResponse:  # type: ignore[name-defined]
    import time
    start = time.time()
    try:
        reply = await handle_chat(payload)  # you can customize this name if needed
        latency_ms = (time.time() - start) * 1000.0
        record_chat_success(latency_ms)
        return reply
    except Exception as e:  # pragma: no cover
        latency_ms = (time.time() - start) * 1000.0
        record_chat_error(f"{type(e).__name__}: {e}")
        from fastapi import HTTPException
        raise HTTPException(status_code=500, detail="Internal error") from e
'''

print("\\n⚠️ NOTE: A template chat_endpoint was appended.")
print("   You may want to adapt handle_chat(...) to your real function.")

text = text + "\n" + textwrap.dedent(snippet)
path.write_text(text)
PY

echo "✅ Chat metrics patch applied (template)."
