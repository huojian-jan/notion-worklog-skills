#!/usr/bin/env bash
# work-log/setup.sh
# Interactive setup: creates ~/.config/work-log/config and registers the SessionEnd hook.
# Tries to auto-create Notion pages via API to minimize manual steps.

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETTINGS_FILE="${HOME}/.claude/settings.json"
HOOK_SCRIPT="${SKILL_DIR}/scripts/session-end.sh"
CONFIG_DIR="${HOME}/.config/work-log"
CONFIG_FILE="${CONFIG_DIR}/config"
NOTION_BASE="https://api.notion.com/v1"
NOTION_VER="${NOTION_API_VERSION:-2022-06-28}"

# ── Helpers ───────────────────────────────────────────────────────────────
ok()   { printf '\033[32m[ok]\033[0m %s\n' "$*"; }
info() { printf '     %s\n' "$*"; }
warn() { printf '\033[33m[warn]\033[0m %s\n' "$*"; }
err()  { printf '\033[31m[err]\033[0m %s\n' "$*" >&2; }
hr()   { echo "────────────────────────────────────────────────────"; }

open_url() {
  local url="$1"
  if command -v open &>/dev/null; then open "$url" 2>/dev/null || true
  elif command -v xdg-open &>/dev/null; then xdg-open "$url" 2>/dev/null || true
  fi
}

notion_get()  { curl -sf --max-time 15 -H "Authorization: Bearer $NOTION_API_TOKEN" -H "Notion-Version: $NOTION_VER" "$NOTION_BASE/$1" 2>/dev/null || true; }
notion_post() { curl -sf --max-time 15 -X POST -H "Authorization: Bearer $NOTION_API_TOKEN" -H "Notion-Version: $NOTION_VER" -H "Content-Type: application/json" -d "$2" "$NOTION_BASE/$1" 2>/dev/null || true; }

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   work-log skill setup                   ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── Check dependencies ────────────────────────────────────────────────────
MISSING=0
for cmd in curl jq; do
  if ! command -v "$cmd" &>/dev/null; then
    err "'$cmd' is required but not found. Install it first."
    MISSING=1
  fi
done
[ "$MISSING" -eq 1 ] && exit 1
ok "curl and jq found"

# ── Make scripts executable ───────────────────────────────────────────────
chmod +x "${SKILL_DIR}/scripts/"*.sh 2>/dev/null || true

# ── Load existing config ──────────────────────────────────────────────────
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE" 2>/dev/null || true

mkdir -p "$CONFIG_DIR"

# ═══════════════════════════════════════════════════════════════════════════
# STEP 1 — Notion API Token
# ═══════════════════════════════════════════════════════════════════════════
echo ""
hr
echo "  Step 1 — Notion API Token"
hr
echo ""

if [ -z "${NOTION_API_TOKEN:-}" ]; then
  info "You need a Notion Internal Integration Token."
  info ""
  info "Opening https://www.notion.so/my-integrations ..."
  open_url "https://www.notion.so/my-integrations"
  echo ""
  info "In the browser:"
  info "  1. Click '+ New integration'"
  info "  2. Name it (e.g. 'work-log'), click Submit"
  info "  3. Copy the token that starts with 'secret_...'"
  echo ""
  printf "  Paste NOTION_API_TOKEN: "
  read -r NOTION_API_TOKEN
  NOTION_API_TOKEN="${NOTION_API_TOKEN:-}"
  if [ -z "$NOTION_API_TOKEN" ]; then
    err "Token is required." && exit 1
  fi
  export NOTION_API_TOKEN

  echo ""
  warn "Token captured for this session only."
  info "To make it permanent, add this to ~/.zshrc (or ~/.bashrc):"
  info "  export NOTION_API_TOKEN=\"${NOTION_API_TOKEN:0:12}...\""
  info "  (Replace with your full token.)"
  info "Then run: source ~/.zshrc"
else
  ok "NOTION_API_TOKEN already set (${NOTION_API_TOKEN:0:12}...)"
fi

# Validate token
printf "     Validating token... "
VALIDATE_RESP=$(notion_get "users/me")
if echo "$VALIDATE_RESP" | jq -e '.object == "error"' >/dev/null 2>&1; then
  ERR=$(echo "$VALIDATE_RESP" | jq -r '.message // "unknown"' 2>/dev/null)
  echo ""
  err "Token validation failed: $ERR"
  info "Make sure you copied the full token and have internet access."
  exit 1
fi
BOT_NAME=$(echo "$VALIDATE_RESP" | jq -r '.name // .bot.owner.user.name // "unknown"' 2>/dev/null || echo "unknown")
echo "valid"
ok "Integration: '$BOT_NAME'"

# ═══════════════════════════════════════════════════════════════════════════
# STEP 2 — Anthropic API Key
# ═══════════════════════════════════════════════════════════════════════════
echo ""
hr
echo "  Step 2 — Anthropic API Key"
hr
echo ""

if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  info "Needed for Claude Haiku to summarize sessions."
  info "Get your key at: https://console.anthropic.com/settings/keys"
  info ""
  open_url "https://console.anthropic.com/settings/keys"
  printf "  Paste ANTHROPIC_API_KEY (or press Enter to skip): "
  read -r ANTHROPIC_API_KEY_INPUT
  if [ -n "${ANTHROPIC_API_KEY_INPUT:-}" ]; then
    export ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY_INPUT"
    echo ""
    warn "Key captured for this session only."
    info "Add to ~/.zshrc: export ANTHROPIC_API_KEY=\"sk-ant-...\""
    info "Then run: source ~/.zshrc"
  else
    warn "Skipped. The SessionEnd hook will not work until ANTHROPIC_API_KEY is set."
  fi
else
  ok "ANTHROPIC_API_KEY already set (${ANTHROPIC_API_KEY:0:12}...)"
fi

# ═══════════════════════════════════════════════════════════════════════════
# STEP 3 — Notion Pages
# ═══════════════════════════════════════════════════════════════════════════
echo ""
hr
echo "  Step 3 — Notion Pages"
hr
echo ""

CURRENT_DRAFT_ID="${NOTION_WORKLOG_DRAFT_PAGE_ID:-}"
CURRENT_LOG_ID="${NOTION_WORKLOG_PAGE_ID:-}"

if [ -n "$CURRENT_DRAFT_ID" ] && [ -n "$CURRENT_LOG_ID" ]; then
  ok "Draft page ID: $CURRENT_DRAFT_ID"
  ok "Log page ID:   $CURRENT_LOG_ID"
else
  info "Two pages are needed:"
  info "  日志草稿 (Log Draft)  — session summaries written here automatically"
  info "  工作日志 (Work Log)   — formal log written here by /work-log"
  echo ""
  info "Searching for Notion pages your integration can access..."

  _search_pages() {
    notion_post "search" '{"filter":{"value":"page","property":"object"},"page_size":20}'
  }

  SEARCH_RESP=$(_search_pages)
  PAGE_COUNT=$(echo "$SEARCH_RESP" | jq '.results | length // 0' 2>/dev/null || echo "0")

  if [ "$PAGE_COUNT" -eq 0 ]; then
    echo ""
    warn "No accessible pages found."
    info "You need to share one Notion page with your integration."
    info ""
    info "Quick steps:"
    info "  1. Open any page in Notion (or create a new one, e.g. 'Work')"
    info "  2. Click the '···' menu (top-right of the page)"
    info "  3. Click 'Connections' → search '$BOT_NAME' → Confirm"
    echo ""
    printf "  Press Enter when done... "
    read -r _DUMMY

    SEARCH_RESP=$(_search_pages)
    PAGE_COUNT=$(echo "$SEARCH_RESP" | jq '.results | length // 0' 2>/dev/null || echo "0")

    if [ "$PAGE_COUNT" -eq 0 ]; then
      warn "Still no pages found — falling back to manual ID entry."
    fi
  fi

  # ── Auto-create pages under a chosen parent ─────────────────────────────
  if [ "$PAGE_COUNT" -gt 0 ]; then
    echo ""
    info "Found $PAGE_COUNT page(s). Choose a parent to create the work log pages under:"
    echo ""

    # Print numbered list of page titles
    while IFS= read -r line; do
      printf '  %s\n' "$line"
    done < <(echo "$SEARCH_RESP" | jq -r '.results | to_entries[] | "\(.key + 1)) \(.value.properties.title.title[0].plain_text // "(Untitled)")"' 2>/dev/null)

    MAX_CHOICE="$PAGE_COUNT"
    echo "  $(( PAGE_COUNT + 1 ))) Enter page IDs manually instead"
    echo ""
    printf "  Choice [1]: "
    read -r PARENT_CHOICE
    PARENT_CHOICE="${PARENT_CHOICE:-1}"

    if [ "$PARENT_CHOICE" -le "$MAX_CHOICE" ] 2>/dev/null; then
      PARENT_IDX=$(( PARENT_CHOICE - 1 ))
      PARENT_ID=$(echo "$SEARCH_RESP" | jq -r ".results[$PARENT_IDX].id" 2>/dev/null || echo "")
      PARENT_TITLE=$(echo "$SEARCH_RESP" | jq -r ".results[$PARENT_IDX].properties.title.title[0].plain_text // \"(Untitled)\"" 2>/dev/null || echo "")

      echo ""
      info "Creating pages under '$PARENT_TITLE'..."

      # Create 日志草稿
      DRAFT_PAYLOAD=$(jq -cn --arg pid "$PARENT_ID" \
        '{parent:{type:"page_id",page_id:$pid},properties:{title:{title:[{text:{content:"日志草稿"}}]}}}')
      DRAFT_RESP=$(notion_post "pages" "$DRAFT_PAYLOAD")
      CURRENT_DRAFT_ID=$(echo "$DRAFT_RESP" | jq -r 'if .object == "error" then "" else .id end' 2>/dev/null || echo "")

      if [ -n "$CURRENT_DRAFT_ID" ]; then
        ok "Created '日志草稿' (Log Draft)"
        info "ID: $CURRENT_DRAFT_ID"
      else
        ERR=$(echo "$DRAFT_RESP" | jq -r '.message // "unknown"' 2>/dev/null)
        warn "Could not create '日志草稿': $ERR"
      fi

      # Create 工作日志
      LOG_PAYLOAD=$(jq -cn --arg pid "$PARENT_ID" \
        '{parent:{type:"page_id",page_id:$pid},properties:{title:{title:[{text:{content:"工作日志"}}]}}}')
      LOG_RESP=$(notion_post "pages" "$LOG_PAYLOAD")
      CURRENT_LOG_ID=$(echo "$LOG_RESP" | jq -r 'if .object == "error" then "" else .id end' 2>/dev/null || echo "")

      if [ -n "$CURRENT_LOG_ID" ]; then
        ok "Created '工作日志' (Work Log)"
        info "ID: $CURRENT_LOG_ID"
      else
        ERR=$(echo "$LOG_RESP" | jq -r '.message // "unknown"' 2>/dev/null)
        warn "Could not create '工作日志': $ERR"
      fi
    fi
  fi

  # ── Fallback: manual entry ───────────────────────────────────────────────
  if [ -z "$CURRENT_DRAFT_ID" ]; then
    echo ""
    info "Enter the '日志草稿' (Log Draft) page ID manually."
    info "Open the page in a browser — the ID is the last 32 chars of the URL."
    printf "  Draft page ID: "
    read -r CURRENT_DRAFT_ID
    [ -z "$CURRENT_DRAFT_ID" ] && err "Draft page ID is required." && exit 1
  fi

  if [ -z "$CURRENT_LOG_ID" ]; then
    info "Enter the '工作日志' (Work Log) page ID manually."
    printf "  Log page ID:   "
    read -r CURRENT_LOG_ID
    [ -z "$CURRENT_LOG_ID" ] && err "Log page ID is required." && exit 1
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════
# STEP 4 — Write config file
# ═══════════════════════════════════════════════════════════════════════════
echo ""
hr
echo "  Step 4 — Writing config"
hr
echo ""

CURRENT_API_VER="${NOTION_API_VERSION:-2022-06-28}"
CURRENT_TEMPLATE="${WORK_LOG_DEFAULT_TEMPLATE:-default}"
CURRENT_LANG="${WORK_LOG_SUMMARY_LANGUAGE:-zh}"
CURRENT_MODEL="${WORK_LOG_SUMMARY_MODEL:-claude-haiku-4-5-20251001}"
CURRENT_MAX_CHARS="${WORK_LOG_MAX_TRANSCRIPT_CHARS:-6000}"

cat > "$CONFIG_FILE" <<EOF
# work-log configuration — edit to customize
# Secrets (NOTION_API_TOKEN, ANTHROPIC_API_KEY) belong in your shell profile, not here.

# Draft page (日志草稿) — session summaries auto-written here by the SessionEnd hook
NOTION_WORKLOG_DRAFT_PAGE_ID="${CURRENT_DRAFT_ID}"

# Log page (工作日志) — formal structured log written here by /work-log
NOTION_WORKLOG_PAGE_ID="${CURRENT_LOG_ID}"

# Notion API version
NOTION_API_VERSION="${CURRENT_API_VER}"

# Default template (filename without .md in the skill's templates/ directory)
# Available: $(ls "${SKILL_DIR}/templates/" 2>/dev/null | sed 's/\.md//' | tr '\n' ' ' || echo "default minimal")
WORK_LOG_DEFAULT_TEMPLATE="${CURRENT_TEMPLATE}"

# Language for session summaries: "zh" (Chinese) or "en" (English)
WORK_LOG_SUMMARY_LANGUAGE="${CURRENT_LANG}"

# Model used to summarize sessions
WORK_LOG_SUMMARY_MODEL="${CURRENT_MODEL}"

# Max characters of session transcript to send for summarization
WORK_LOG_MAX_TRANSCRIPT_CHARS="${CURRENT_MAX_CHARS}"
EOF

ok "Config written to: $CONFIG_FILE"

# ═══════════════════════════════════════════════════════════════════════════
# STEP 5 — Register SessionEnd hook
# ═══════════════════════════════════════════════════════════════════════════
echo ""
hr
echo "  Step 5 — Registering SessionEnd hook"
hr
echo ""

mkdir -p "$(dirname "${SETTINGS_FILE}")"
[ ! -f "${SETTINGS_FILE}" ] && echo '{}' > "${SETTINGS_FILE}"

if ! jq '.' "${SETTINGS_FILE}" > /dev/null 2>&1; then
  err "${SETTINGS_FILE} is not valid JSON. Fix it before running setup."
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
  ok "SessionEnd hook already registered — nothing to do."
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
  ok "Registered: $HOOK_SCRIPT"
fi

# ═══════════════════════════════════════════════════════════════════════════
# DONE
# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   Setup complete!                        ║"
echo "╚══════════════════════════════════════════╝"
echo ""
info "Every session end → bullets auto-saved to 日志草稿"
info "Run /work-log anytime to organize drafts into 工作日志"
echo ""
info "  /work-log            — organize (keep drafts)"
info "  /work-log --clear    — organize + clear draft page"
echo ""
info "Debug: ~/.claude/work-log.log"
info "Config: $CONFIG_FILE"
echo ""

# Remind about shell profile if keys were entered interactively
if [ "${_PROMPTED_TOKEN:-false}" = "true" ] || [ "${_PROMPTED_KEY:-false}" = "true" ]; then
  warn "Remember to add API keys to your shell profile so they persist:"
  [ -z "${NOTION_API_TOKEN:-}" ]   || info "  export NOTION_API_TOKEN=\"${NOTION_API_TOKEN}\""
  [ -z "${ANTHROPIC_API_KEY:-}" ]  || info "  export ANTHROPIC_API_KEY=\"${ANTHROPIC_API_KEY}\""
  info "Then: source ~/.zshrc"
fi
