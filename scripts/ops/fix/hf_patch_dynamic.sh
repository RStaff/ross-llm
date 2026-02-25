#!/usr/bin/env bash
set -euo pipefail

FILE="apps/orchestrator/routes/pgvector_store.py"

echo "==> Checking file exists"
test -f "$FILE" || { echo "File not found: $FILE"; exit 1; }

cp "$FILE" "$FILE.bak_$(date +%s)"

echo "==> Inject HF provider logic safely"

python3 <<PY
from pathlib import Path

p = Path("$FILE")
txt = p.read_text()

if "EMBEDDING_PROVIDER" in txt:
    print("✅ HF patch already present — nothing to do")
    exit()

# Add env config near imports
insert_block = '''
import os
EMBEDDING_PROVIDER = os.getenv("EMBEDDING_PROVIDER", "openai")
HF_EMBED_MODEL = os.getenv("HF_EMBED_MODEL", "sentence-transformers/all-MiniLM-L6-v2")
EMBED_DIM = int(os.getenv("EMBEDDING_DIM", "1536"))
'''

# insert after first import block
lines = txt.splitlines()
for i,l in enumerate(lines):
    if l.startswith("import") or l.startswith("from"):
        continue
    lines.insert(i, insert_block)
    break

txt = "\n".join(lines)

# inject HF embedding hook
hf_hook = '''
# --- HF EMBEDDING PATCH ---
if EMBEDDING_PROVIDER.lower() == "hf":
    from embeddings_hf import embed_texts
    return embed_texts(texts)
# --- END HF EMBEDDING PATCH ---
'''

txt = txt.replace("requests.post(", hf_hook + "\n    requests.post(")

p.write_text(txt)
print("✅ Dynamic HF patch applied")
PY

echo "✅ Done"
