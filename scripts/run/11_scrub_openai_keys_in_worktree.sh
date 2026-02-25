#!/usr/bin/env bash
set -euo pipefail
[[ -n "${BASH_VERSION:-}" ]] || { echo "Run with bash: bash $0"; exit 1; }

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

echo "11 — SCRUB OPENAI KEYS IN WORKTREE (tracked files only)"
echo "Repo: $ROOT"
echo

PATTERN='(sk|rk)-[A-Za-z0-9_-]{10,}'

echo "==> Scanning tracked files for key-like tokens..."
HITS="$(git ls-files -z | xargs -0 -I{} bash -lc "grep -nE '$PATTERN' \"{}\" >/dev/null 2>&1 && echo \"{}\" || true")"

if [[ -z "${HITS}" ]]; then
  echo "OK: No key-like tokens found in tracked files."
else
  echo "Found in:"
  echo "$HITS" | sed 's/^/ - /'
  echo
  echo "==> Redacting in-place (REDACTED_OPENAI_KEY)..."
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    perl -pi -e "s/$PATTERN/REDACTED_OPENAI_KEY/g" "$f"
  done <<< "$HITS"
  echo "Done redacting."
fi

echo
echo "==> Writing safe example secrets file (.env.secrets.example)"
cat > .env.secrets.example <<'EOF'
# Copy to .env.secrets (DO NOT COMMIT)
OPENAI_API_KEY="paste_your_key_here"
EOF

echo
echo "==> Ensure .env.secrets is ignored (safe)"
grep -q '^\.env\.secrets$' .gitignore 2>/dev/null || echo ".env.secrets" >> .gitignore

echo
echo "==> Quick verify (tracked files):"
if git ls-files -z | xargs -0 grep -nE "$PATTERN" >/dev/null 2>&1; then
  echo "❌ Still found key-like tokens in tracked files."
  git ls-files -z | xargs -0 grep -nE "$PATTERN" | head -n 20
  exit 1
fi
echo "✅ No key-like tokens in tracked files."
