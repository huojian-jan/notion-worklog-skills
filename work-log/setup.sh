#!/usr/bin/env bash
# work-log/setup.sh
# Registers the SessionEnd hook in ~/.claude/settings.json
# Run once after installing the skill.

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETTINGS_FILE="${HOME}/.claude/settings.json"
HOOK_SCRIPT="${SKILL_DIR}/scripts/session-end.sh"

echo "╔══════════════════════════════════════════╗"
echo "║   work-log skill setup                   ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# Make scripts executable
chmod +x "${SKILL_DIR}/scripts/"*.sh 2>/dev/null || true

# Check dependencies
MISSING=0
for cmd in curl jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: '$cmd' is required but not found. Install it first." >&2
    MISSING=1
  fi
done
[ "$MISSING" -eq 1 ] && exit 1
echo "[ok] curl and jq found"

# Check env vars
if [ -z "${NOTION_API_TOKEN:-}" ]; then
  echo "[warn] NOTION_API_TOKEN is not set."
  echo "       Add to ~/.zshrc:  export NOTION_API_TOKEN='secret_...'"
  echo ""
else
  echo "[ok] NOTION_API_TOKEN is set"
fi

if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo "[warn] ANTHROPIC_API_KEY is not set."
  echo "       Needed for session summarization."
  echo "       Add to ~/.zshrc:  export ANTHROPIC_API_KEY='sk-ant-...'"
  echo ""
else
  echo "[ok] ANTHROPIC_API_KEY is set"
fi

PAGE_ID="${NOTION_WORKLOG_PAGE_ID:-30942947-b59c-80f3-9e22-eed448e5862f}"
echo "[ok] Notion page ID: $PAGE_ID"
echo ""

# Ensure settings.json exists and is valid
mkdir -p "$(dirname "${SETTINGS_FILE}")"
if [ ! -f "${SETTINGS_FILE}" ]; then
  echo '{}' > "${SETTINGS_FILE}"
  echo "[ok] Created ${SETTINGS_FILE}"
fi

if ! jq '.' "${SETTINGS_FILE}" > /dev/null 2>&1; then
  echo "ERROR: ${SETTINGS_FILE} is not valid JSON. Fix it before running setup." >&2
  exit 1
fi

# Check if hook is already registered
ALREADY=$(jq -r \
  --arg cmd "$HOOK_SCRIPT" \
  '(.hooks.SessionEnd // []) |
   map(.hooks // [] | map(select(.command == $cmd)) | length > 0) |
   any |
   if . then "yes" else "no" end' \
  "${SETTINGS_FILE}" 2>/dev/null || echo "no")

if [ "$ALREADY" = "yes" ]; then
  echo "[ok] SessionEnd hook already registered — nothing to do."
else
  UPDATED=$(jq \
    --arg cmd "$HOOK_SCRIPT" \
    '.hooks //= {} |
     .hooks.SessionEnd //= [] |
     .hooks.SessionEnd += [{
       "matcher": ".*",
       "hooks": [{
         "type": "command",
         "command": $cmd,
         "timeout": 60
       }]
     }]' \
    "${SETTINGS_FILE}")
  printf '%s\n' "$UPDATED" > "${SETTINGS_FILE}"
  echo "[ok] Registered SessionEnd hook: $HOOK_SCRIPT"
fi

echo ""
echo "Setup complete!"
echo ""
echo "  Sessions will auto-save to Notion when they end."
echo "  Run /work-log in Claude Code to organize drafts into the formal log."
echo ""
echo "  Tip: check ~/.claude/work-log.log to debug if sessions aren't appearing."
