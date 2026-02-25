#!/usr/bin/env bash
KEY_FILE="$HOME/.config/ross-llm/openai_api_key"
if [ -f "$KEY_FILE" ]; then
  export OPENAI_API_KEY="$(cat "$KEY_FILE")"
fi
