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
echo "── Notion Pages ────────────────────────────────────────────────────"
echo ""
echo "You need two Notion pages:"
echo "  1. Draft page  — session summaries are auto-written here"
echo "  2. Log page    — /work-log organizes and writes the formal log here"
echo ""
echo "Both pages must be connected to your Notion integration."
echo "(Page → ··· menu → Connections → select your integration)"
echo ""

# Draft page ID
CURRENT_DRAFT_ID="${NOTION_WORKLOG_DRAFT_PAGE_ID:-}"
if [ -z "$CURRENT_DRAFT_ID" ]; then
  printf "  Draft page ID: "
  read -r INPUT
  CURRENT_DRAFT_ID="${INPUT:-}"
  if [ -z "$CURRENT_DRAFT_ID" ]; then
    echo "ERROR: Draft page ID is required." >&2
    exit 1
  fi
else
  echo "[ok] Draft page ID: $CURRENT_DRAFT_ID"
fi

# Log page ID
CURRENT_LOG_ID="${NOTION_WORKLOG_PAGE_ID:-}"
if [ -z "$CURRENT_LOG_ID" ]; then
  printf "  Log page ID:   "
  read -r INPUT
  CURRENT_LOG_ID="${INPUT:-}"
  if [ -z "$CURRENT_LOG_ID" ]; then
    echo "ERROR: Log page ID is required." >&2
    exit 1
  fi
else
  echo "[ok] Log page ID:   $CURRENT_LOG_ID"
fi

# Other settings
CURRENT_API_VER="${NOTION_API_VERSION:-2022-06-28}"
CURRENT_TEMPLATE="${WORK_LOG_DEFAULT_TEMPLATE:-default}"
CURRENT_LANG="${WORK_LOG_SUMMARY_LANGUAGE:-zh}"
CURRENT_MODEL="${WORK_LOG_SUMMARY_MODEL:-claude-haiku-4-5-20251001}"
CURRENT_MAX_CHARS="${WORK_LOG_MAX_TRANSCRIPT_CHARS:-6000}"

echo "[ok] API version:   $CURRENT_API_VER"
echo "[ok] Template:      $CURRENT_TEMPLATE"
echo "[ok] Language:      $CURRENT_LANG  (zh=Chinese, en=English)"
echo "[ok] Model:         $CURRENT_MODEL"

# ── Write config file ──────────────────────────────────────────────────────
echo ""
mkdir -p "$CONFIG_DIR"
cat > "$CONFIG_FILE" <<EOF
# work-log configuration
# Edit this file to customize your setup.
# Secrets (NOTION_API_TOKEN, ANTHROPIC_API_KEY) belong in your shell profile, not here.

# Notion page for session draft summaries (auto-written by the SessionEnd hook)
NOTION_WORKLOG_DRAFT_PAGE_ID="${CURRENT_DRAFT_ID}"

# Notion page for the formal structured work log (written by /work-log)
NOTION_WORKLOG_PAGE_ID="${CURRENT_LOG_ID}"

# Notion API version
NOTION_API_VERSION="${CURRENT_API_VER}"

# Default template (filename without .md in the skill's templates/ directory)
# Available: $(ls "${SKILL_DIR}/templates/" 2>/dev/null | sed 's/\.md//' | tr '\n' ' ')
WORK_LOG_DEFAULT_TEMPLATE="${CURRENT_TEMPLATE}"

# Language for session summaries: "zh" (Chinese) or "en" (English)
WORK_LOG_SUMMARY_LANGUAGE="${CURRENT_LANG}"

# Model used to summarize sessions
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
echo "  Draft page: sessions auto-saved here on every session end"
echo "  Log page:   run /work-log to organize drafts into formal entries"
echo ""
echo "  /work-log           — organize (keeps drafts)"
echo "  /work-log --clear   — organize + clear draft page"
echo ""
echo "  Edit $CONFIG_FILE to change settings."
echo "  Check ~/.claude/work-log.log to debug hook issues."
