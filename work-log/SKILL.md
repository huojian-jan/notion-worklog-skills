---
name: work-log
description: Organize Notion work log. Reads accumulated session drafts (local files or Notion draft page), groups by date and category using AI, writes the formal structured log to the Notion log page. Optionally clears drafts with --clear.
version: 1.2.0
author: huojian-jan
triggers:
  - /work-log
---

You are executing the `/work-log` skill. Read draft session entries, organize them into a formal work log, write to the Notion log page, and optionally clear drafts.

## Configuration

Set at the start of every step:

```bash
PAGE_ID="${NOTION_WORKLOG_PAGE_ID:-}"              # Notion log page (formal log written here)
DRAFT_PAGE_ID="${NOTION_WORKLOG_DRAFT_PAGE_ID:-$PAGE_ID}"  # Notion draft page (sessions auto-saved here)
NOTION_VER="${NOTION_API_VERSION:-2025-09-03}"
NOTION_BASE="https://api.notion.com/v1"
DRAFT_TARGET="${WORK_LOG_DRAFT_TARGET:-local}"
DRAFTS_DIR="${WORK_LOG_DRAFTS_DIR:-$HOME/.claude/work-log-drafts}"
```

Parse `--clear` flag from the user's command:
- If the user typed `/work-log --clear`: `CLEAR_DRAFTS=true`
- Otherwise: `CLEAR_DRAFTS=false`

## Step 1: Check environment

```bash
echo "TOKEN:        ${NOTION_API_TOKEN:0:12}..."
echo "PAGE_ID:      $PAGE_ID"
echo "DRAFT_PAGE_ID: $DRAFT_PAGE_ID"
echo "DRAFT_TARGET: $DRAFT_TARGET"
echo "CLEAR_DRAFTS: $CLEAR_DRAFTS"
```

If `NOTION_API_TOKEN` is empty: stop and tell the user to set it first (`export NOTION_API_TOKEN="..."`).

If `PAGE_ID` is empty: stop and tell the user to set `NOTION_WORKLOG_PAGE_ID` in their environment.

## Step 2: Read draft entries

**Branch based on `DRAFT_TARGET`:**

---

### If `DRAFT_TARGET == "local"` (default)

Read all `.jsonl` files from `DRAFTS_DIR`:

```bash
ls "$DRAFTS_DIR"/*.jsonl 2>/dev/null || echo "NO_FILES"
```

If no files: tell the user "No draft files found at `$DRAFTS_DIR`. Sessions haven't been captured yet, or the minimum message threshold wasn't reached." Then stop.

For each `.jsonl` file, read line by line. Each line is a JSON object:
```json
{"ts": "2026-04-12 14:30", "project": "blog_source", "transcript": "..."}
```

Parse all lines from all files. Build a structured session list:
```
[
  { "date": "2026-04-12", "timestamp": "2026-04-12 14:30", "project": "blog_source",
    "transcript": "..." },
  ...
]
```

Save file paths for cleanup in Step 6.

---

### If `DRAFT_TARGET == "notion"`

Fetch the draft page's direct children:

```bash
curl -s \
  -H "Authorization: Bearer $NOTION_API_TOKEN" \
  -H "Notion-Version: $NOTION_VER" \
  "$NOTION_BASE/blocks/$DRAFT_PAGE_ID/children?page_size=100"
```

The draft page uses a date-grouped flat structure:
- `paragraph` with bold blue text matching `^── \d{4}-\d{2}-\d{2} ──` = **date section header** → extract date
- `paragraph` with bold text matching `^· \[\d{2}:\d{2}\]` = **session header** → extract time and project
- `bulleted_list_item` blocks following a session header = that session's **bullets**

Parse all blocks and build a structured session list grouped by date. Collect all block IDs for cleanup in Step 6.

If the page is empty or has no recognizable entries: tell the user "Draft page is empty. No sessions have been captured yet." Then stop.

---

If the draft is empty in either mode: tell the user "Draft area is empty. Nothing to organize." Then stop.

## Step 3: Summarize sessions (local mode only)

**Skip this step if `DRAFT_TARGET == "notion"` (bullets are already summarized).**

For each session in the list, read its `transcript` and extract 3–5 key work points:
- Max 25 words each, in Chinese
- Only what was done — no filler
- Assign a rough topic/category label to each point

Replace the raw `transcript` with the extracted `bullets` array.

## Step 4: Organize by date and category

For each unique date (oldest first):

1. Collect all bullet points from all sessions that day
2. Group into 2–4 topic categories (e.g., "Notion 接入", "Bug 修复", "代码重构", "文档")
3. Keep the most important 2–4 bullets per category; drop redundant ones
4. Write a one-sentence day summary
5. Identify 1–3 main deliverables

Determine the ISO week number and build a week label: "第X周（M月D日 - M月D日）"
Determine the Chinese weekday name (周一 through 周日).

## Step 5: Write the formal log

Fetch the first 100 blocks of the **log page** (`PAGE_ID`) to check for existing year/month headings:

```bash
curl -s \
  -H "Authorization: Bearer $NOTION_API_TOKEN" \
  -H "Notion-Version: $NOTION_VER" \
  "$NOTION_BASE/blocks/$PAGE_ID/children?page_size=100"
```

Look for `heading_1` containing the current year ("2026年") and `heading_2` containing the current month ("4月"). Only include them in your blocks if they don't already exist.

Build a JSON blocks array for each date (oldest first). Structure:

```json
[
  {"type":"heading_1","heading_1":{"rich_text":[{"type":"text","text":{"content":"2026年"}}]}},
  {"type":"heading_2","heading_2":{"rich_text":[{"type":"text","text":{"content":"4月"}}]}},
  {"type":"heading_3","heading_3":{"rich_text":[{"type":"text","text":{"content":"第X周（M月D日 - M月D日）"}}]}},
  {"type":"paragraph","paragraph":{"rich_text":[{"type":"text","text":{"content":"4月12日 周六"},"annotations":{"bold":true}}]}},
  {"type":"paragraph","paragraph":{"rich_text":[{"type":"text","text":{"content":"分类名"},"annotations":{"bold":true,"color":"blue"}}]}},
  {"type":"bulleted_list_item","bulleted_list_item":{"rich_text":[{"type":"text","text":{"content":"要点"}}]}},
  {"type":"divider","divider":{}},
  {"type":"paragraph","paragraph":{"rich_text":[{"type":"text","text":{"content":"产出：xxx; yyy"},"annotations":{"bold":true}}]}},
  {"type":"paragraph","paragraph":{"rich_text":[{"type":"text","text":{"content":"今日总结："},"annotations":{"bold":true}}]}},
  {"type":"paragraph","paragraph":{"rich_text":[{"type":"text","text":{"content":"一句话总结..."}}]}}
]
```

Notes:
- Only add heading_1/heading_2 if they don't already exist on the log page
- Repeat category + bullets for each category in a date
- Add a `divider` between separate dates

Append to the **log page**:

```bash
curl -s -X PATCH \
  -H "Authorization: Bearer $NOTION_API_TOKEN" \
  -H "Notion-Version: $NOTION_VER" \
  -H "Content-Type: application/json" \
  -d "{\"children\": $BLOCKS_JSON}" \
  "$NOTION_BASE/blocks/$PAGE_ID/children"
```

Check the response for `"object":"error"`. If there's an error, report it and **stop** — do not proceed to clear drafts.

## Step 6: Clear drafts (only if `--clear`)

**Skip this step if `CLEAR_DRAFTS=false`. Tell the user they can run `/work-log --clear` to also clear the draft area.**

### If `DRAFT_TARGET == "local"` and `CLEAR_DRAFTS=true`

Delete all processed `.jsonl` files:

```bash
rm -f "$DRAFTS_DIR"/*.jsonl
```

### If `DRAFT_TARGET == "notion"` and `CLEAR_DRAFTS=true`

Delete each block from the draft page (IDs collected in Step 2), one at a time:

```bash
curl -s -X DELETE \
  -H "Authorization: Bearer $NOTION_API_TOKEN" \
  -H "Notion-Version: $NOTION_VER" \
  "$NOTION_BASE/blocks/$BLOCK_ID"
```

Delete all blocks including date headers and session entries. The page itself is kept — it will refill automatically as new sessions are captured.

## Step 7: Report

Tell the user:
- How many sessions were processed
- Which dates were covered
- How many formal log blocks were written to the log page
- Whether drafts were cleared or retained
  - If retained: "Drafts kept. Run `/work-log --clear` to clear them."
  - If cleared: "Draft area cleared and ready for new sessions."
