#!/usr/bin/env zsh
# work-log/scripts/session-end.sh
# SessionEnd hook: captures session summary to local draft or Notion draft page.
#
# Config via environment variables:
#   WORK_LOG_DRAFT_TARGET       "local" (default) | "notion"
#   WORK_LOG_MIN_MESSAGES       min user messages to trigger (default: 5)
#   WORK_LOG_DRAFTS_DIR         local drafts dir (default: ~/.claude/work-log-drafts)
#   NOTION_API_TOKEN            required for notion mode
#   NOTION_WORKLOG_DRAFT_PAGE_ID  Notion draft page ID (notion mode)
#   NOTION_WORKLOG_PAGE_ID        fallback if DRAFT_PAGE_ID not set

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
# One file per date; one JSON line per session.
# No AI call needed — /work-log summarizes when triggered.
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
  log "Saved to $DRAFT_FILE (entries: $(wc -l < "$DRAFT_FILE" | tr -d ' '))"
  exit 0
fi

# ════════════════════════════════════════════════════════════════════════════
# MODE: notion
# Summarize via claude --print, then append to the dedicated Notion draft page.
#
# Draft page structure (date-grouped, blocks written directly to the page):
#   ── 2026-04-12 ──              ← date header (bold blue paragraph)
#   · [11:28] project-name        ← session header (bold paragraph)
#   • 要点1                        ← bulleted_list_item
#   • 要点2
#   · [14:30] another-project     ← next session, same date
#   ── 2026-04-13 ──              ← next date
#   ...
#
# Two separate Notion pages:
#   NOTION_WORKLOG_DRAFT_PAGE_ID  — draft page (auto-written by this hook)
#   NOTION_WORKLOG_PAGE_ID        — log page  (written by /work-log)
# ════════════════════════════════════════════════════════════════════════════
if [ "$DRAFT_TARGET" = "notion" ]; then
  if [ -z "${NOTION_API_TOKEN:-}" ]; then
    log_err "NOTION_API_TOKEN not set — cannot write to Notion."
    exit 0
  fi

  # Use dedicated draft page; fall back to log page if not configured
  DRAFT_PAGE_ID="${NOTION_WORKLOG_DRAFT_PAGE_ID:-${NOTION_WORKLOG_PAGE_ID:-}}"
  if [ -z "$DRAFT_PAGE_ID" ]; then
    log_err "Neither NOTION_WORKLOG_DRAFT_PAGE_ID nor NOTION_WORKLOG_PAGE_ID is set."
    exit 0
  fi

  NOTION_VER="2025-09-03"
  NOTION_BASE="https://api.notion.com/v1"

  log "notion mode: summarizing session (project: $PROJECT, draft page: $DRAFT_PAGE_ID)"

  # ── Step 1: Summarize with claude --print ──────────────────────────────────
  BULLETS=$(claude --print "从以下会话记录中提炼 3-5 条工作要点。要求：每条不超过 25 字，中文，只写做了什么。每条单独一行，不加序号或符号。

会话记录：
${TRANSCRIPT}" 2>/dev/null || echo "")

  if [ -z "$BULLETS" ]; then
    log_err "claude summarization failed or returned empty."
    exit 0
  fi

  log "summarized: $(echo "$BULLETS" | wc -l | tr -d ' ') bullets"

  # ── Step 2: Check if today's date header already exists on the draft page ──
  PAGE_CHILDREN=$(curl -s \
    -H "Authorization: Bearer $NOTION_API_TOKEN" \
    -H "Notion-Version: $NOTION_VER" \
    "$NOTION_BASE/blocks/$DRAFT_PAGE_ID/children?page_size=100")

  if echo "$PAGE_CHILDREN" | jq -e '.object == "error"' > /dev/null 2>&1; then
    log_err "Failed to read draft page: $(echo "$PAGE_CHILDREN" | jq -r '.message' 2>/dev/null)"
    exit 0
  fi

  LAST_DATE=$(echo "$PAGE_CHILDREN" | jq -r '
    [.results[] |
      select(.type == "paragraph") |
      (.paragraph.rich_text[0]?.text.content // "")
    ] |
    map(select(test("^── [0-9]{4}-[0-9]{2}-[0-9]{2}"))) |
    last // ""' 2>/dev/null || echo "")

  # ── Step 3: Build blocks JSON ──────────────────────────────────────────────
  BULLET_BLOCKS=""
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    ESCAPED=$(printf '%s' "$line" | jq -Rs '.')
    BULLET_BLOCKS="${BULLET_BLOCKS}{\"type\":\"bulleted_list_item\",\"bulleted_list_item\":{\"rich_text\":[{\"type\":\"text\",\"text\":{\"content\":${ESCAPED}}}]}},"
  done <<< "$BULLETS"
  BULLET_BLOCKS="${BULLET_BLOCKS%,}"

  SESSION_CONTENT=$(printf '· [%s] %s' "$TIME" "$PROJECT" | jq -Rs '.')
  SESSION_HEADER="{\"type\":\"paragraph\",\"paragraph\":{\"rich_text\":[{\"type\":\"text\",\"text\":{\"content\":${SESSION_CONTENT}},\"annotations\":{\"bold\":true}}]}}"

  EXPECTED_DATE_HEADER="── ${DATE} ──"
  if [ "$LAST_DATE" != "$EXPECTED_DATE_HEADER" ]; then
    DATE_HEADER="{\"type\":\"paragraph\",\"paragraph\":{\"rich_text\":[{\"type\":\"text\",\"text\":{\"content\":\"── ${DATE} ──\"},\"annotations\":{\"bold\":true,\"color\":\"blue\"}}]}}"
    BLOCKS_JSON="[${DATE_HEADER},${SESSION_HEADER},${BULLET_BLOCKS}]"
  else
    BLOCKS_JSON="[${SESSION_HEADER},${BULLET_BLOCKS}]"
  fi

  # ── Step 4: Append to draft page ──────────────────────────────────────────
  APPEND_RESP=$(curl -s -X PATCH \
    -H "Authorization: Bearer $NOTION_API_TOKEN" \
    -H "Notion-Version: $NOTION_VER" \
    -H "Content-Type: application/json" \
    -d "{\"children\": ${BLOCKS_JSON}}" \
    "$NOTION_BASE/blocks/$DRAFT_PAGE_ID/children")

  if echo "$APPEND_RESP" | jq -e '.object == "error"' > /dev/null 2>&1; then
    log_err "Notion append failed: $(echo "$APPEND_RESP" | jq -r '.message' 2>/dev/null)"
    exit 0
  fi

  WRITTEN=$(echo "$APPEND_RESP" | jq '.results | length' 2>/dev/null || echo "?")
  log "Written $WRITTEN blocks to Notion draft page (date: $DATE, project: $PROJECT)"
  exit 0
fi

log_err "Unknown WORK_LOG_DRAFT_TARGET: $DRAFT_TARGET"
exit 0
