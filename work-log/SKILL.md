---
name: work-log
description: Auto-sync Claude Code sessions to Notion work log. Reads accumulated session summaries from the draft area, groups by date and category with AI, writes the formal structured log, and clears drafts. No MCP — uses curl only.
version: 1.1.0
author: huojian-jan
triggers:
  - /work-log
---

You are executing the `/work-log` skill. Read the Notion draft area, organize all session entries using a template, then write the formal log and clear the drafts.

---

## Step 0: Parse arguments and load config

### 0a. Load user config

```bash
CONFIG_FILE="${HOME}/.config/work-log/config"
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

# Env vars always override config file values
PAGE_ID="${NOTION_WORKLOG_PAGE_ID:-}"
NOTION_VER="${NOTION_API_VERSION:-2022-06-28}"
NOTION_BASE="https://api.notion.com/v1"
DEFAULT_TEMPLATE="${WORK_LOG_DEFAULT_TEMPLATE:-default}"
```

### 0b. Parse skill arguments

Look at the user's message — anything after `/work-log` is the argument string. Parse it:

- If it contains `--template <name>`: extract `<name>` as `TEMPLATE_NAME`; remove the flag from remaining text
- Everything remaining after removing the flag = `FOCUS_PROMPT`
- If no `--template` flag: `TEMPLATE_NAME = DEFAULT_TEMPLATE`

**Examples:**
- `/work-log` → `TEMPLATE_NAME=default`, `FOCUS_PROMPT=""`
- `/work-log 重点记录架构决策` → `TEMPLATE_NAME=default`, `FOCUS_PROMPT="重点记录架构决策"`
- `/work-log --template minimal` → `TEMPLATE_NAME=minimal`, `FOCUS_PROMPT=""`
- `/work-log --template minimal 重点 bug 修复` → `TEMPLATE_NAME=minimal`, `FOCUS_PROMPT="重点 bug 修复"`

### 0c. Load template

```bash
SKILL_DIR="${HOME}/.agents/skills/work-log"
[ -d "${HOME}/.claude/skills/work-log" ] && SKILL_DIR="${HOME}/.claude/skills/work-log"
TEMPLATE_FILE="${SKILL_DIR}/templates/${TEMPLATE_NAME}.md"
```

```bash
if [ -f "$TEMPLATE_FILE" ]; then
  cat "$TEMPLATE_FILE"
else
  echo "WARNING: template '$TEMPLATE_NAME' not found at $TEMPLATE_FILE"
  echo "Available templates:"
  ls "${SKILL_DIR}/templates/" 2>/dev/null || echo "(none found)"
  echo "Falling back to free-form organization."
fi
```

Tell the user: "Using template: **`TEMPLATE_NAME`**" and if `FOCUS_PROMPT` is set: "Focus: `FOCUS_PROMPT`"

---

## Step 1: Check environment

```bash
echo "NOTION_API_TOKEN: ${NOTION_API_TOKEN:0:12}..."
echo "PAGE_ID: ${PAGE_ID:-(not set)}"
```

If `NOTION_API_TOKEN` is empty: stop and tell the user to set it.

If `PAGE_ID` is empty: stop and tell the user to either:
- Set `NOTION_WORKLOG_PAGE_ID` in their environment, or
- Run `~/.agents/skills/work-log/setup.sh` to configure it

---

## Step 2: Fetch page blocks and find draft callout

```bash
curl -s \
  -H "Authorization: Bearer $NOTION_API_TOKEN" \
  -H "Notion-Version: $NOTION_VER" \
  "$NOTION_BASE/blocks/$PAGE_ID/children?page_size=100"
```

Find the block where:
- `type == "callout"`
- `callout.rich_text[0].text.content` contains "草稿" or "DRAFT" (case-insensitive)

Save its `id` as `DRAFT_ID`.

If no such block exists: tell the user "No draft area found. Sessions haven't been captured yet, or the draft callout was deleted. Run setup.sh to verify hook registration." Then stop.

---

## Step 3: Read all draft entries

```bash
curl -s \
  -H "Authorization: Bearer $NOTION_API_TOKEN" \
  -H "Notion-Version: $NOTION_VER" \
  "$NOTION_BASE/blocks/$DRAFT_ID/children?page_size=100"
```

Collect all child block IDs (needed for cleanup in Step 6).

Parse the entries:
- `paragraph` block with bold text starting with `[YYYY-MM-DD HH:MM]` = session header
- `bulleted_list_item` blocks after a header = that session's bullets

Build a structured session list:
```
[
  { "date": "2026-04-12", "timestamp": "2026-04-12 14:30",
    "project": "notion-worklog-skills",
    "bullets": ["要点1", "要点2"] },
  ...
]
```

If the draft is empty: tell the user "Draft area is empty. Nothing to organize." Then stop.

---

## Step 4: Organize by date and category

For each unique date, collect all bullet points from all sessions that day.

**If a template was loaded (Step 0c):** follow the template's categorization rules exactly.

**If no template file was found:** use your own judgment — group into 2–4 topic categories, keep the most important 2–4 bullets per category, drop redundant ones.

**If `FOCUS_PROMPT` is set:** prioritize and emphasize bullets related to `FOCUS_PROMPT`. When writing summaries and choosing which bullets to keep, give weight to content matching the focus.

For each date also determine:
- The ISO week label (e.g. "第二周（4月7日 - 4月13日）")
- The Chinese weekday name
- 1–3 main deliverables
- A one-sentence day summary

---

## Step 5: Write formal log blocks

Check the page blocks from Step 2 for existing year/month headings.

**Follow the loaded template's block structure exactly.** If no template was loaded, use the default format (heading hierarchy + categories + divider + deliverables + summary).

Build the Notion JSON blocks array. Reference for block types:

```json
{"type":"heading_1","heading_1":{"rich_text":[{"type":"text","text":{"content":"2026年"}}]}}
{"type":"heading_2","heading_2":{"rich_text":[{"type":"text","text":{"content":"4月"}}]}}
{"type":"heading_3","heading_3":{"rich_text":[{"type":"text","text":{"content":"第X周（M月D日 - M月D日）"}}]}}
{"type":"paragraph","paragraph":{"rich_text":[{"type":"text","text":{"content":"4月12日 周六"},"annotations":{"bold":true}}]}}
{"type":"paragraph","paragraph":{"rich_text":[{"type":"text","text":{"content":"分类名"},"annotations":{"bold":true,"color":"blue"}}]}}
{"type":"bulleted_list_item","bulleted_list_item":{"rich_text":[{"type":"text","text":{"content":"要点"}}]}}
{"type":"divider","divider":{}}
{"type":"paragraph","paragraph":{"rich_text":[{"type":"text","text":{"content":"产出：xxx"},"annotations":{"bold":true}}]}}
{"type":"paragraph","paragraph":{"rich_text":[{"type":"text","text":{"content":"今日总结："  },"annotations":{"bold":true}}]}}
{"type":"paragraph","paragraph":{"rich_text":[{"type":"text","text":{"content":"一句话总结..."}}]}}
```

Append to the page:

```bash
curl -s -X PATCH \
  -H "Authorization: Bearer $NOTION_API_TOKEN" \
  -H "Notion-Version: $NOTION_VER" \
  -H "Content-Type: application/json" \
  -d "{\"children\": $BLOCKS_JSON}" \
  "$NOTION_BASE/blocks/$PAGE_ID/children"
```

Check response for `"object":"error"`. If error, report it and **stop** — do not proceed to delete drafts.

---

## Step 6: Clear drafts

Delete each child block from the draft callout (IDs from Step 3) one at a time:

```bash
curl -s -X DELETE \
  -H "Authorization: Bearer $NOTION_API_TOKEN" \
  -H "Notion-Version: $NOTION_VER" \
  "$NOTION_BASE/blocks/$BLOCK_ID"
```

Do NOT delete the parent draft callout itself — keep the container for future sessions.

---

## Step 7: Report

Tell the user:
- Template used and any focus prompt applied
- How many sessions were processed and which dates covered
- How many blocks were written to the formal log
- Draft area cleared, ready for new sessions
