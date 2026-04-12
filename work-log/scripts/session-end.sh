#!/usr/bin/env zsh
# work-log/scripts/session-end.sh
# SessionEnd hook: captures session summary to local file (default) or Notion.
#
# Config via environment variables:
#   WORK_LOG_DRAFT_TARGET  "local" (default) | "notion"
#   WORK_LOG_MIN_MESSAGES  minimum user messages to trigger (default: 5)
#   WORK_LOG_DRAFTS_DIR    local drafts directory (default: ~/.claude/work-log-drafts)
#   NOTION_WORKLOG_PAGE_ID Notion page ID (required for notion mode)
#   NOTION_API_TOKEN       Notion API token (required for notion mode)

set -euo pipefail

LOG_FILE="${HOME}/.claude/work-log.log"
log()     { printf '[work-log %s] %s\n' "$(date '+%H:%M:%S')" "$*" >> "$LOG_FILE" 2>/dev/null || true; }
log_err() { log "ERROR: $*"; }

log "SessionEnd hook started"

# ── Load env ──────────────────────────────────────────────────────────────────
source ~/.zshrc 2>/dev/null || true

DRAFT_TARGET="${WORK_LOG_DRAFT_TARGET:-local}"
MIN_MESSAGES="${WORK_LOG_MIN_MESSAGES:-5}"
DRAFTS_DIR="${WORK_LOG_DRAFTS_DIR:-$HOME/.claude/work-log-drafts}"

# ── Read session data ─────────────────────────────────────────────────────────
SESSION_DATA=""
if [ ! -t 0 ]; then
  SESSION_DATA=$(cat 2>/dev/null || echo "")
fi

if [ -z "$SESSION_DATA" ]; then
  log "No session data — skipping."
  exit 0
fi

# ── Filter: skip short sessions ───────────────────────────────────────────────
MSG_COUNT=$(echo "$SESSION_DATA" | jq '
  [(.transcript // .messages // [])[] |
    select((.role // .type // "") | test("human|user"; "i"))
  ] | length
' 2>/dev/null || echo "0")

log "User messages: $MSG_COUNT (min: $MIN_MESSAGES, target: $DRAFT_TARGET)"

if [ "$MSG_COUNT" -lt "$MIN_MESSAGES" ]; then
  log "Short session — skipping."
  exit 0
fi

# ── Extract metadata ──────────────────────────────────────────────────────────
PROJECT=$(echo "$SESSION_DATA" | jq -r '
  (.project_path // .cwd // "") |
  if . != "" then split("/") | last else "unknown" end
' 2>/dev/null || echo "unknown")

TIMESTAMP=$(date '+%Y-%m-%d %H:%M')
DATE=$(date '+%Y-%m-%d')
TIME=$(date '+%H:%M')

TRANSCRIPT=$(echo "$SESSION_DATA" | jq -r '
  (.transcript // .messages // []) |
  .[-30:] |
  map(
    ((.role // .type // "?") | ascii_downcase) + ": " +
    (
      if   (.content | type) == "string" then .content
      elif (.content | type) == "array"  then
        [.content[] | if type == "object" then (.text // "") else "" end] | join(" ")
      else ""
      end
    )
  ) |
  map(select(length > 5)) |
  join("\n")
' 2>/dev/null || echo "")

TRANSCRIPT="${TRANSCRIPT:0:5000}"

if [ -z "$TRANSCRIPT" ]; then
  log "Empty transcript — skipping."
  exit 0
fi

# ════════════════════════════════════════════════════════════════════════════
# MODE: local (default)
# Save raw session entry to ~/.claude/work-log-drafts/YYYY-MM-DD.jsonl
# Each file = one date; each line = one session.
# No AI call needed — /work-log skill summarizes when triggered.
# ════════════════════════════════════════════════════════════════════════════
if [ "$DRAFT_TARGET" = "local" ]; then
  mkdir -p "$DRAFTS_DIR"
  DRAFT_FILE="$DRAFTS_DIR/$DATE.jsonl"

  ENTRY=$(jq -cn \
    --arg ts "$TIMESTAMP" \
    --arg project "$PROJECT" \
    --arg transcript "$TRANSCRIPT" \
    '{ts: $ts, project: $project, transcript: $transcript}')

  printf '%s\n' "$ENTRY" >> "$DRAFT_FILE"
  log "Saved to $DRAFT_FILE (entries: $(wc -l < "$DRAFT_FILE"))"
  exit 0
fi

# ════════════════════════════════════════════════════════════════════════════
# MODE: notion
# Summarize via claude --print, then write to Notion draft callout with curl.
#
# Draft callout structure (flat children, date-grouped):
#   ── 2026-04-12 ──              ← date header (bold blue paragraph)
#   · [11:28] project-name        ← session header (bold paragraph)
#   • 要点1                        ← bulleted_list_item
#   • 要点2
#   · [14:30] another-project     ← next session, same date
#   ── 2026-04-13 ──              ← next date
#   ...
# ════════════════════════════════════════════════════════════════════════════
if [ "$DRAFT_TARGET" = "notion" ]; then
  if [ -z "${NOTION_API_TOKEN:-}" ]; then
    log_err "NOTION_API_TOKEN not set — cannot write to Notion."
    exit 0
  fi

  PAGE_ID="${NOTION_WORKLOG_PAGE_ID:-30942947-b59c-80f3-9e22-eed448e5862f}"
  NOTION_VER="2025-09-03"
  NOTION_BASE="https://api.notion.com/v1"

  log "notion mode: summarizing session (project: $PROJECT)"

  # ── Step 1: Summarize with claude --print ──────────────────────────────────
  BULLETS=$(claude --print "从以下会话记录中提炼 3-5 条工作要点。要求：每条不超过 25 字，中文，只写做了什么。每条单独一行，不加序号或符号。

会话记录：
${TRANSCRIPT}" 2>/dev/null || echo "")

  if [ -z "$BULLETS" ]; then
    log_err "claude summarization failed or returned empty."
    exit 0
  fi

  log "summarized: $(echo "$BULLETS" | wc -l | tr -d ' ') bullets"

  # ── Step 2: Find or create the draft callout ───────────────────────────────
  PAGE_BLOCKS=$(curl -s \
    -H "Authorization: Bearer $NOTION_API_TOKEN" \
    -H "Notion-Version: $NOTION_VER" \
    "$NOTION_BASE/blocks/$PAGE_ID/children?page_size=100")

  DRAFT_ID=$(echo "$PAGE_BLOCKS" | jq -r '
    .results[] |
    select(.type == "callout") |
    select(.callout.rich_text[0].text.content | test("草稿|DRAFT"; "i")) |
    .id' 2>/dev/null | head -1)

  if [ -z "$DRAFT_ID" ] || [ "$DRAFT_ID" = "null" ]; then
    log "No draft callout found — creating one."
    CREATE_RESP=$(curl -s -X PATCH \
      -H "Authorization: Bearer $NOTION_API_TOKEN" \
      -H "Notion-Version: $NOTION_VER" \
      -H "Content-Type: application/json" \
      -d '{"children":[{"type":"callout","callout":{"rich_text":[{"type":"text","text":{"content":"草稿区（待整理）"}}],"icon":{"type":"emoji","emoji":"📝"},"color":"yellow_background"}}]}' \
      "$NOTION_BASE/blocks/$PAGE_ID/children")
    DRAFT_ID=$(echo "$CREATE_RESP" | jq -r '.results[0].id' 2>/dev/null)
    if [ -z "$DRAFT_ID" ] || [ "$DRAFT_ID" = "null" ]; then
      log_err "Failed to create draft callout: $(echo "$CREATE_RESP" | jq -r '.message // "unknown"' 2>/dev/null)"
      exit 0
    fi
    log "Created draft callout: $DRAFT_ID"
  fi

  # ── Step 3: Check if today's date header already exists ────────────────────
  DRAFT_CHILDREN=$(curl -s \
    -H "Authorization: Bearer $NOTION_API_TOKEN" \
    -H "Notion-Version: $NOTION_VER" \
    "$NOTION_BASE/blocks/$DRAFT_ID/children?page_size=100")

  LAST_DATE=$(echo "$DRAFT_CHILDREN" | jq -r '
    [.results[] |
      select(.type == "paragraph") |
      (.paragraph.rich_text[0]?.text.content // "")
    ] |
    map(select(test("^── [0-9]{4}-[0-9]{2}-[0-9]{2}"))) |
    last // ""' 2>/dev/null || echo "")

  # ── Step 4: Build blocks JSON ──────────────────────────────────────────────
  # Build bullet blocks from BULLETS (one line per bullet)
  BULLET_BLOCKS=""
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    ESCAPED=$(printf '%s' "$line" | jq -Rs '.')
    BULLET_BLOCKS="${BULLET_BLOCKS}{\"type\":\"bulleted_list_item\",\"bulleted_list_item\":{\"rich_text\":[{\"type\":\"text\",\"text\":{\"content\":${ESCAPED}}}]}},"
  done <<< "$BULLETS"
  BULLET_BLOCKS="${BULLET_BLOCKS%,}"

  SESSION_HEADER="{\"type\":\"paragraph\",\"paragraph\":{\"rich_text\":[{\"type\":\"text\",\"text\":{\"content\":\"· [${TIME}] ${PROJECT}\"},\"annotations\":{\"bold\":true}}]}}"

  EXPECTED_DATE_HEADER="── ${DATE} ──"
  if [ "$LAST_DATE" != "$EXPECTED_DATE_HEADER" ]; then
    DATE_HEADER="{\"type\":\"paragraph\",\"paragraph\":{\"rich_text\":[{\"type\":\"text\",\"text\":{\"content\":\"── ${DATE} ──\"},\"annotations\":{\"bold\":true,\"color\":\"blue\"}}]}}"
    BLOCKS_JSON="[${DATE_HEADER},${SESSION_HEADER},${BULLET_BLOCKS}]"
  else
    BLOCKS_JSON="[${SESSION_HEADER},${BULLET_BLOCKS}]"
  fi

  # ── Step 5: Append to draft callout ───────────────────────────────────────
  APPEND_RESP=$(curl -s -X PATCH \
    -H "Authorization: Bearer $NOTION_API_TOKEN" \
    -H "Notion-Version: $NOTION_VER" \
    -H "Content-Type: application/json" \
    -d "{\"children\": ${BLOCKS_JSON}}" \
    "$NOTION_BASE/blocks/$DRAFT_ID/children")

  if echo "$APPEND_RESP" | jq -e '.object == "error"' > /dev/null 2>&1; then
    log_err "Notion append failed: $(echo "$APPEND_RESP" | jq -r '.message' 2>/dev/null)"
    exit 0
  fi

  WRITTEN=$(echo "$APPEND_RESP" | jq '.results | length' 2>/dev/null || echo "?")
  log "Written $WRITTEN blocks to Notion draft (date: $DATE, project: $PROJECT)"
  exit 0
fi

log_err "Unknown WORK_LOG_DRAFT_TARGET: $DRAFT_TARGET"
exit 0
