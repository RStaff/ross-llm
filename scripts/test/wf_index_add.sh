#!/usr/bin/env bash
set -euo pipefail

########################################
# SAFETY GUARD: enforce correct directory
########################################
ROOT_ALLOWED="$HOME/projects/ross-llm"
CWD="$(pwd)"

if [[ "$CWD" != "$ROOT_ALLOWED" ]]; then
  echo "❌ wf_index_add.sh must be run from:"
  echo "   $ROOT_ALLOWED"
  echo "   You are currently in:"
  echo "   $CWD"
  echo
  echo "👉 Fix it with:"
  echo "   cd ~/projects/ross-llm"
  echo "   ./wf_index_add.sh"
  exit 1
fi

########################################
# CONFIG
########################################
BASE_DIR="${1:-$HOME/Legal/WholeFoods_Legal}"
INDEX_FILE="$BASE_DIR/wholefoods_index.csv"

if [[ ! -f "$INDEX_FILE" ]]; then
  echo "❌ Index file not found at:"
  echo "   $INDEX_FILE"
  echo
  echo "Make sure the folder structure exists. You can run:"
  echo "  ~/init_wholefoods_legal_folders.sh"
  echo "or pass a custom base dir, e.g.:"
  echo "  ./wf_index_add.sh \$HOME/Documents/Legal/WholeFoods_Legal"
  exit 1
fi

echo
echo "📂 Logging a document into:"
echo "   $INDEX_FILE"
echo

########################################
# PROMPTS
########################################
TODAY=$(date +%Y-%m-%d)

read -rp "Date [$TODAY]: " DATE
DATE="${DATE:-$TODAY}"

read -rp "Folder label (e.g. 01_Correspondence, 03_Exhibits): " FOLDER
read -rp "Exact filename (as stored on disk): " FILENAME
read -rp "Document type (e.g. Exhibit, Email, Motion, MediationNote): " DOCTYPE
read -rp "Short description: " DESCRIPTION
read -rp "Version (e.g. v1, v2): " VERSION
read -rp "Notes (optional): " NOTES

########################################
# CSV ESCAPING + APPEND
########################################
# Escape double quotes in text fields
DESCRIPTION_ESC=${DESCRIPTION//\"/\"\"}
NOTES_ESC=${NOTES//\"/\"\"}

ROW="\"$DATE\",\"$FOLDER\",\"$FILENAME\",\"$DOCTYPE\",\"$DESCRIPTION_ESC\",\"$VERSION\",\"$NOTES_ESC\""

echo
echo "📄 About to append this row to $INDEX_FILE:"
echo "$ROW"
echo

read -rp "Proceed? [y/N]: " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo "❌ Aborted; nothing written."
  exit 0
fi

echo "$ROW" >> "$INDEX_FILE"
echo "✅ Row appended."
