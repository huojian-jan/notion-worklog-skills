#!/usr/bin/env bash
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
  SESSION_DATA=$(timeout 10 cat 2>/dev/null || echo "")
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

  echo "$ENTRY" >> "$DRAFT_FILE"
  log "Saved to $DRAFT_FILE (entries: $(wc -l < "$DRAFT_FILE"))"
  exit 0
fi

# ════════════════════════════════════════════════════════════════════════════
# MODE: notion
# Launch claude --print to summarize and write to Notion draft callout.
# Runs as background process (async hook).
# ════════════════════════════════════════════════════════════════════════════
if [ "$DRAFT_TARGET" = "notion" ]; then
  if [ -z "${NOTION_API_TOKEN:-}" ]; then
    log_err "NOTION_API_TOKEN not set — cannot write to Notion."
    exit 0
  fi

  PAGE_ID="${NOTION_WORKLOG_PAGE_ID:-30942947-b59c-80f3-9e22-eed448e5862f}"

  log "Launching claude to summarize + write to Notion (project: $PROJECT)"

  claude --print "$(cat <<PROMPT
你是工作日志助手。任务：把下面的会话记录整理成草稿，写入 Notion 草稿区。

**第一步：提炼要点**
从会话中提炼 3-5 条关键工作要点，要求：
- 每条不超过 25 字，中文
- 只写做了什么，不写废话

**第二步：用 curl 写入 Notion**

1. 获取页面 blocks，找 type=callout 且含「草稿」的 block 作为 DRAFT_ID：
   curl -s -H "Authorization: Bearer \$NOTION_API_TOKEN" -H "Notion-Version: 2025-09-03" "https://api.notion.com/v1/blocks/${PAGE_ID}/children?page_size=100"

2. 找到 DRAFT_ID → 追加 children（paragraph 标题 + bulleted_list_item 要点）
   找不到 → 在页面底部新建 callout（📝 草稿区（待整理），yellow_background）

请直接执行 curl，完成后输出「done」。

---
项目：${PROJECT}
时间：${TIMESTAMP}

会话记录：
${TRANSCRIPT}
PROMPT
)" >> "$LOG_FILE" 2>&1 &

  log "claude launched in background (pid: $!)"
  exit 0
fi

log_err "Unknown WORK_LOG_DRAFT_TARGET: $DRAFT_TARGET"
exit 0
