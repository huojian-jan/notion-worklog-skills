#!/usr/bin/env bash
# work-log/setup.sh
# Interactive setup: creates ~/.config/work-log/config and registers the SessionEnd hook.

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETTINGS_FILE="${HOME}/.claude/settings.json"
HOOK_SCRIPT="${SKILL_DIR}/scripts/session-end.sh"
CONFIG_DIR="${HOME}/.config/work-log"
CONFIG_FILE="${CONFIG_DIR}/config"

echo "╔══════════════════════════════════════════╗"
echo "║   work-log skill setup                   ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── Make scripts executable ───────────────────────────────────────────────
chmod +x "${SKILL_DIR}/scripts/"*.sh 2>/dev/null || true

# ── Check dependencies ────────────────────────────────────────────────────
MISSING=0
for cmd in curl jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: '$cmd' is required but not found. Install it first." >&2
    MISSING=1
  fi
done
[ "$MISSING" -eq 1 ] && exit 1
echo "[ok] curl and jq found"

# ── Load existing config if present ───────────────────────────────────────
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE" 2>/dev/null || true

# ── Collect configuration values ──────────────────────────────────────────
echo ""
echo "── Configuration ──────────────────────────────────────────────────"
echo ""

# NOTION_WORKLOG_PAGE_ID
CURRENT_PAGE_ID="${NOTION_WORKLOG_PAGE_ID:-}"
if [ -z "$CURRENT_PAGE_ID" ]; then
  echo "Notion work log page ID (required)."
  echo "Find it in your Notion page URL: notion.so/your-workspace/<PAGE_ID>"
  printf "  Page ID: "
  read -r INPUT_PAGE_ID
  CURRENT_PAGE_ID="${INPUT_PAGE_ID:-}"
  if [ -z "$CURRENT_PAGE_ID" ]; then
    echo "ERROR: Page ID is required. Re-run setup after finding your page ID." >&2
    exit 1
  fi
else
  echo "[ok] Notion page ID: $CURRENT_PAGE_ID"
fi

# NOTION_API_VERSION
CURRENT_API_VER="${NOTION_API_VERSION:-2022-06-28}"
echo "[ok] Notion API version: $CURRENT_API_VER"

# WORK_LOG_DEFAULT_TEMPLATE
CURRENT_TEMPLATE="${WORK_LOG_DEFAULT_TEMPLATE:-default}"
echo "[ok] Default template: $CURRENT_TEMPLATE"
echo "     Available templates: $(ls "${SKILL_DIR}/templates/" 2>/dev/null | sed 's/\.md//' | tr '\n' ' ')"

# WORK_LOG_SUMMARY_LANGUAGE
CURRENT_LANG="${WORK_LOG_SUMMARY_LANGUAGE:-zh}"
echo "[ok] Summary language: $CURRENT_LANG (zh = Chinese, en = English)"

# WORK_LOG_SUMMARY_MODEL
CURRENT_MODEL="${WORK_LOG_SUMMARY_MODEL:-claude-haiku-4-5-20251001}"
echo "[ok] Summary model: $CURRENT_MODEL"

# WORK_LOG_MAX_TRANSCRIPT_CHARS
CURRENT_MAX_CHARS="${WORK_LOG_MAX_TRANSCRIPT_CHARS:-6000}"
echo "[ok] Max transcript chars: $CURRENT_MAX_CHARS"

echo ""

# ── Write config file ──────────────────────────────────────────────────────
mkdir -p "$CONFIG_DIR"
cat > "$CONFIG_FILE" <<EOF
# work-log configuration
# Edit this file to customize your setup.
# Secrets (API tokens) should stay in your shell environment, not here.

# Notion page ID for your work log (required)
NOTION_WORKLOG_PAGE_ID="${CURRENT_PAGE_ID}"

# Notion API version
NOTION_API_VERSION="${CURRENT_API_VER}"

# Default template (filename without .md in the skill's templates/ directory)
# Available: $(ls "${SKILL_DIR}/templates/" 2>/dev/null | sed 's/\.md//' | tr '\n' ' ')
WORK_LOG_DEFAULT_TEMPLATE="${CURRENT_TEMPLATE}"

# Language for session summaries: "zh" (Chinese) or "en" (English)
WORK_LOG_SUMMARY_LANGUAGE="${CURRENT_LANG}"

# Model used to summarize sessions (Claude Haiku recommended — fast and cheap)
WORK_LOG_SUMMARY_MODEL="${CURRENT_MODEL}"

# Max characters of session transcript to send for summarization
WORK_LOG_MAX_TRANSCRIPT_CHARS="${CURRENT_MAX_CHARS}"
EOF

echo "[ok] Config written to: $CONFIG_FILE"

# ── Check secret env vars ──────────────────────────────────────────────────
echo ""
if [ -z "${NOTION_API_TOKEN:-}" ]; then
  echo "[warn] NOTION_API_TOKEN is not set."
  echo "       Add to ~/.zshrc:  export NOTION_API_TOKEN='secret_...'"
else
  echo "[ok] NOTION_API_TOKEN is set"
fi

if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo "[warn] ANTHROPIC_API_KEY is not set."
  echo "       Add to ~/.zshrc:  export ANTHROPIC_API_KEY='sk-ant-...'"
else
  echo "[ok] ANTHROPIC_API_KEY is set"
fi

# ── Register SessionEnd hook ───────────────────────────────────────────────
echo ""
mkdir -p "$(dirname "${SETTINGS_FILE}")"
if [ ! -f "${SETTINGS_FILE}" ]; then
  echo '{}' > "${SETTINGS_FILE}"
fi

if ! jq '.' "${SETTINGS_FILE}" > /dev/null 2>&1; then
  echo "ERROR: ${SETTINGS_FILE} is not valid JSON. Fix it before running setup." >&2
  exit 1
fi

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
echo "  Run /work-log in Claude Code to organize drafts."
echo "  Edit $CONFIG_FILE to change settings."
echo ""
echo "  Tip: check ~/.claude/work-log.log to debug hook issues."
