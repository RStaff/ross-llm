#!/usr/bin/env bash
set -e

echo "📥 Loading persona memory from data/persona/..."

/usr/bin/curl -s -X POST "http://127.0.0.1:8000/admin/reload-memory" \
  -H "Content-Type: application/json"

echo ""
echo "🎉 Persona memory loaded into StaffordOS!"
echo "Try:"
echo '   ross "Who are my daughters?"'
