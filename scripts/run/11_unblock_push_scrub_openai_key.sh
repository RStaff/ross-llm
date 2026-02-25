#!/usr/bin/env bash
set -euo pipefail
[[ -n "${BASH_VERSION:-}" ]] || { echo "Run with bash: bash $0"; exit 1; }

git rev-parse --show-toplevel >/dev/null
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

echo "=============================="
echo "11 — UNBLOCK PUSH: SCRUB OPENAI KEY + AMEND COMMIT"
echo "Repo: $ROOT"
echo "=============================="
echo

# --- config ---
TARGET="scripts/cli/set_openai_env.sh"

# Grab last commit message (we will re-create it)
LAST_MSG="$(git log -1 --pretty=%B | tr -d '\r')"

echo "==> Last commit message will be preserved:"
echo "----------------------------------------"
echo "$LAST_MSG"
echo "----------------------------------------"
echo

echo "==> Safety: ensure we are ahead of origin/main (push previously failed)."
git fetch -q origin || true
AHEAD="$(git rev-list --count origin/main..HEAD 2>/dev/null || echo 0)"
if [[ "$AHEAD" -lt 1 ]]; then
  echo "NOTE: This script expects your last commit NOT to be on origin/main."
  echo "If you already forced something, STOP and paste: git log --oneline -5"
fi
echo

echo "==> Soft reset HEAD~1 (keeps changes, removes the commit so we can re-commit cleanly)..."
git reset --soft HEAD~1

echo
echo "==> Scrubbing OpenAI key material from tracked scripts..."

if [[ -f "$TARGET" ]]; then
  # If file contains an sk- style key, replace it with a safe loader pattern
  if grep -Eq 'sk-[A-Za-z0-9]{20,}' "$TARGET"; then
    echo "FOUND key-like token in $TARGET. Rewriting file to safe loader."
    cat > "$TARGET" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ -n "${BASH_VERSION:-}" ]] || { echo "Run with bash: bash $0"; exit 1; }

# Safe OpenAI env loader:
# - Put your real key in .env.secrets (ignored by git)
# - This script sources it if present, otherwise expects OPENAI_API_KEY already in env

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SECRETS_FILE="$ROOT/.env.secrets"

if [[ -f "$SECRETS_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$SECRETS_FILE"
fi

if [[ -z "${OPENAI_API_KEY:-}" ]]; then
  echo "ERROR: OPENAI_API_KEY is not set."
  echo "Fix: add it to $SECRETS_FILE like:"
  echo "  export OPENAI_API_KEY='sk-...'"
  exit 1
fi

export OPENAI_API_KEY
echo "OPENAI_API_KEY loaded (from env or .env.secrets)."
EOF
    chmod +x "$TARGET" || true
  else
    echo "OK: $TARGET exists but no key-like token detected."
  fi
else
  echo "OK: $TARGET not present; skipping."
fi

echo
echo "==> Add an example secrets template (optional, safe) ..."
if [[ ! -f ".env.secrets.example" ]]; then
  cat > .env.secrets.example <<'EOF'
# Copy to .env.secrets (this real file is ignored by git)
# export OPENAI_API_KEY='REDACTED_OPENAI_KEY'
EOF
  git add .env.secrets.example
fi

echo
echo "==> Harden .gitignore just in case..."
touch .gitignore
grep -qxF ".env.secrets" .gitignore || echo ".env.secrets" >> .gitignore

echo
echo "==> Stage scrubbed files..."
git add "$TARGET" .gitignore .env.secrets.example 2>/dev/null || true

echo
echo "==> Quick staged secret scan (sk-...)"
if git diff --cached | grep -Eq 'sk-[A-Za-z0-9]{20,}'; then
  echo "ERROR: A key-like token is still present in staged changes."
  echo "Run: git diff --cached | grep -n 'sk-'"
  exit 1
fi

echo
echo "==> Re-commit with the same message..."
git commit -m "$LAST_MSG"

echo
echo "==> Done. Now run:"
echo "  bash scripts/run/03_guard_no_secrets.sh"
echo "  git push"
