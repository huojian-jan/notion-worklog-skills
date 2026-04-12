#!/usr/bin/env bash
# work-log/scripts/session-end.sh
# SessionEnd hook: summarizes the Claude Code session and appends to the Notion draft page.
# Invoked automatically by Claude Code at session end. Receives session JSON on stdin.

set -euo pipefail

# ── Load user config ──────────────────────────────────────────────────────
CONFIG_FILE="${HOME}/.config/work-log/config"
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE" 2>/dev/null || true

# ── Config (env vars override config file) ────────────────────────────────
NOTION_BASE="https://api.notion.com/v1"
NOTION_VER="${NOTION_API_VERSION:-2022-06-28}"
DRAFT_PAGE_ID="${NOTION_WORKLOG_DRAFT_PAGE_ID:-}"
SUMMARY_LANGUAGE="${WORK_LOG_SUMMARY_LANGUAGE:-zh}"
SUMMARY_MODEL="${WORK_LOG_SUMMARY_MODEL:-claude-haiku-4-5-20251001}"
MAX_CHARS="${WORK_LOG_MAX_TRANSCRIPT_CHARS:-6000}"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M')
LOG_FILE="${HOME}/.claude/work-log.log"

# ── Logging ───────────────────────────────────────────────────────────────
log()     { printf '[work-log %s] %s\n' "$(date '+%H:%M:%S')" "$*" >> "$LOG_FILE" 2>/dev/null || true; }
log_err() { log "ERROR: $*"; printf '[work-log] ERROR: %s\n' "$*" >&2 || true; }

log "SessionEnd hook started"

# ── Guard: required values ────────────────────────────────────────────────
if [ -z "${NOTION_API_TOKEN:-}" ]; then
  log_err "NOTION_API_TOKEN not set — run setup.sh."
  exit 0
fi
if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  log_err "ANTHROPIC_API_KEY not set — run setup.sh."
  exit 0
fi
if [ -z "$DRAFT_PAGE_ID" ]; then
  log_err "NOTION_WORKLOG_DRAFT_PAGE_ID not set — run setup.sh."
  exit 0
fi

# ── Read session data from stdin ──────────────────────────────────────────
SESSION_DATA=""
if [ ! -t 0 ]; then
  # timeout is GNU coreutils (not on macOS by default); fall back to gtimeout then plain cat
  if command -v timeout &>/dev/null; then
    SESSION_DATA=$(timeout 10 cat 2>/dev/null || echo "")
  elif command -v gtimeout &>/dev/null; then
    SESSION_DATA=$(gtimeout 10 cat 2>/dev/null || echo "")
  else
    SESSION_DATA=$(cat 2>/dev/null || echo "")
  fi
fi

if [ -z "$SESSION_DATA" ]; then
  log "No session data received — skipping."
  exit 0
fi

# ── Extract project name ──────────────────────────────────────────────────
PROJECT=$(echo "$SESSION_DATA" | jq -r '
  (.project_path // .cwd // "") |
  if . != "" then split("/") | last else "" end
' 2>/dev/null || echo "")

# ── Extract transcript messages ───────────────────────────────────────────
MESSAGES=$(echo "$SESSION_DATA" | jq -r '
  (.transcript // .messages // []) |
  if type == "array" then
    .[-40:] |
    map(
      ((.role // .type // "?") | ascii_downcase) + ": " +
      (
        if   (.content | type) == "string" then .content
        elif (.content | type) == "array"  then
          [.content[] |
            if type == "object" then (.text // .delta // "")
            else ""
            end
          ] | join(" ")
        else ""
        end
      )
    ) |
    map(select(length > 5)) |
    join("\n")
  else ""
  end
' 2>/dev/null || echo "")

if [ -z "$MESSAGES" ] || [ "${#MESSAGES}" -lt 30 ]; then
  log "Session transcript too short — skipping."
  exit 0
fi

TRANSCRIPT="${MESSAGES:0:$MAX_CHARS}"
log "Summarizing (project: ${PROJECT:-unknown}, lang: $SUMMARY_LANGUAGE, chars: ${#TRANSCRIPT})"

# ── Build prompt based on language config ─────────────────────────────────
if [ "$SUMMARY_LANGUAGE" = "en" ]; then
  SUMMARY_PROMPT="From the following Claude Code session transcript, extract 3-5 key work points.\nRules:\n1. Max 20 words each\n2. English only\n3. Output ONLY a JSON string array: [\"point1\",\"point2\"]\n4. No other content\n\nProject: ${PROJECT:-unknown}\n\n${TRANSCRIPT}"
else
  SUMMARY_PROMPT="从以下Claude Code会话记录中，提炼3-5条最重要的工作要点。\n要求：\n1. 每条不超过25字\n2. 使用中文\n3. 只输出JSON字符串数组：[\"要点1\",\"要点2\"]\n4. 不要输出任何其他内容\n\n项目：${PROJECT:-unknown}\n\n${TRANSCRIPT}"
fi

# ── Call Claude Haiku to summarize ────────────────────────────────────────
SUMMARY_RESP=$(curl -s --max-time 30 \
  -X POST "https://api.anthropic.com/v1/messages" \
  -H "x-api-key: ${ANTHROPIC_API_KEY}" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d "$(jq -cn \
    --arg model "$SUMMARY_MODEL" \
    --arg prompt "$SUMMARY_PROMPT" \
    '{model: $model, max_tokens: 300, messages: [{role: "user", content: $prompt}]}')" \
  2>/dev/null) || true

if [ -z "$SUMMARY_RESP" ]; then
  log_err "Claude API call failed or timed out."
  exit 0
fi

BULLETS_RAW=$(echo "$SUMMARY_RESP" | jq -r '.content[0].text // ""' 2>/dev/null || echo "")
BULLETS_JSON=$(echo "$BULLETS_RAW" | jq -c '. // []' 2>/dev/null || echo "[]")
BULLET_COUNT=$(echo "$BULLETS_JSON" | jq 'length' 2>/dev/null || echo "0")

if [ "$BULLET_COUNT" -eq 0 ]; then
  log_err "No bullets parsed. Response: ${BULLETS_RAW:0:200}"
  exit 0
fi

log "Got $BULLET_COUNT bullets"

# ── Build Notion blocks ───────────────────────────────────────────────────
HEADER_TEXT="[$TIMESTAMP]${PROJECT:+ · $PROJECT}"

BLOCKS_JSON=$(jq -cn \
  --arg header "$HEADER_TEXT" \
  --argjson bullets "$BULLETS_JSON" \
  '[
    {
      type: "paragraph",
      paragraph: {
        rich_text: [{
          type: "text",
          text: {content: $header},
          annotations: {bold: true, color: "gray"}
        }]
      }
    }
  ] + ($bullets | map({
    type: "bulleted_list_item",
    bulleted_list_item: {
      rich_text: [{type: "text", text: {content: ("· " + .)}}]
    }
  }))')

# ── Find or create draft callout on the draft page ────────────────────────
PAGE_RESP=$(curl -s --max-time 15 \
  -H "Authorization: Bearer $NOTION_API_TOKEN" \
  -H "Notion-Version: $NOTION_VER" \
  "$NOTION_BASE/blocks/$DRAFT_PAGE_ID/children?page_size=100" 2>/dev/null) || true

if [ -z "$PAGE_RESP" ]; then
  log_err "Failed to fetch draft page blocks (ID: $DRAFT_PAGE_ID)."
  exit 0
fi

DRAFT_CALLOUT_ID=$(echo "$PAGE_RESP" | jq -r '
  (.results // []) |
  map(select(
    .type == "callout" and
    ((.callout.rich_text[0].text.content // "") | test("草稿|DRAFT"; "i"))
  )) |
  first | .id // ""
' 2>/dev/null || echo "")

if [ -n "$DRAFT_CALLOUT_ID" ]; then
  # Append to existing draft callout
  RESP=$(curl -s --max-time 15 \
    -X PATCH \
    -H "Authorization: Bearer $NOTION_API_TOKEN" \
    -H "Notion-Version: $NOTION_VER" \
    -H "Content-Type: application/json" \
    -d "{\"children\": $BLOCKS_JSON}" \
    "$NOTION_BASE/blocks/$DRAFT_CALLOUT_ID/children" 2>/dev/null) || true

  if [ -z "$RESP" ] || echo "$RESP" | jq -e '.object == "error"' >/dev/null 2>&1; then
    log_err "Append failed: $(echo "$RESP" | jq -r '.message // "network error"' 2>/dev/null)"
    exit 0
  fi
  log "Appended $BULLET_COUNT bullets to draft callout ($DRAFT_CALLOUT_ID)"
else
  # Create draft callout on the page
  CALLOUT_JSON=$(jq -cn \
    --argjson children "$BLOCKS_JSON" \
    '[{
      type: "callout",
      callout: {
        rich_text: [{type: "text", text: {content: "📝 草稿区（待整理）"}}],
        icon: {type: "emoji", emoji: "📝"},
        color: "yellow_background",
        children: $children
      }
    }]')

  RESP=$(curl -s --max-time 15 \
    -X PATCH \
    -H "Authorization: Bearer $NOTION_API_TOKEN" \
    -H "Notion-Version: $NOTION_VER" \
    -H "Content-Type: application/json" \
    -d "{\"children\": $CALLOUT_JSON}" \
    "$NOTION_BASE/blocks/$DRAFT_PAGE_ID/children" 2>/dev/null) || true

  if [ -z "$RESP" ] || echo "$RESP" | jq -e '.object == "error"' >/dev/null 2>&1; then
    log_err "Create callout failed: $(echo "$RESP" | jq -r '.message // "network error"' 2>/dev/null)"
    exit 0
  fi
  log "Created draft callout with $BULLET_COUNT bullets"
fi

log "Done."
exit 0
