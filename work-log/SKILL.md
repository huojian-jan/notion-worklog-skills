---
name: work-log
description: Organize Notion work log. Reads accumulated session drafts (local files or Notion callout), groups by date and category using AI, writes the formal structured log to Notion, then clears drafts.
version: 1.1.0
author: huojian-jan
triggers:
  - /work-log
---

You are executing the `/work-log` skill. Read the Notion draft area, organize all session entries into a formal work log, then clear the drafts.

## Configuration

Set at the start of every step:

```bash
PAGE_ID="${NOTION_WORKLOG_PAGE_ID:-30942947-b59c-80f3-9e22-eed448e5862f}"
NOTION_VER="${NOTION_API_VERSION:-2022-06-28}"
NOTION_BASE="https://api.notion.com/v1"
DRAFT_TARGET="${WORK_LOG_DRAFT_TARGET:-local}"
DRAFTS_DIR="${WORK_LOG_DRAFTS_DIR:-$HOME/.claude/work-log-drafts}"
```

## Step 1: Check environment

```bash
echo "TOKEN: ${NOTION_API_TOKEN:0:12}..."
echo "PAGE_ID: $PAGE_ID"
echo "DRAFT_TARGET: $DRAFT_TARGET"
echo "DRAFTS_DIR: $DRAFTS_DIR"
```

If `NOTION_API_TOKEN` is empty: stop and tell the user to set it in their environment first (`export NOTION_API_TOKEN="..."`).

## Step 2: Read draft entries

**Branch based on `DRAFT_TARGET`:**

---

### If `DRAFT_TARGET == "local"` (default)

Read all `.jsonl` files from `DRAFTS_DIR`:

```bash
ls "$DRAFTS_DIR"/*.jsonl 2>/dev/null || echo "NO_FILES"
```

If no files: tell the user "No draft files found at `$DRAFTS_DIR`. Sessions haven't been captured yet, or the minimum message threshold wasn't reached." Then stop.

For each `.jsonl` file, read line by line. Each line is a JSON object with:
```json
{"ts": "2026-04-12 14:30", "project": "blog_source", "transcript": "...full transcript..."}
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

If no such block exists: tell the user "No draft callout found. Sessions haven't been captured yet, or the draft callout was deleted. Ensure the hook is registered by running setup.sh." Then stop.

```bash
curl -s \
  -H "Authorization: Bearer $NOTION_API_TOKEN" \
  -H "Notion-Version: $NOTION_VER" \
  "$NOTION_BASE/blocks/$DRAFT_ID/children?page_size=100"
```

Collect all child block IDs (needed for cleanup in Step 6).

Parse entries:
- `paragraph` block with bold text starting with `[YYYY-MM-DD HH:MM]` = session header
- `bulleted_list_item` blocks after a header = that session's bullets

Build a structured session list from these blocks.

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

Check the first 100 blocks of the page for existing year/month headings:

```bash
# Already fetched in Step 2 (notion mode) — reuse that response
# For local mode: fetch now
curl -s \
  -H "Authorization: Bearer $NOTION_API_TOKEN" \
  -H "Notion-Version: $NOTION_VER" \
  "$NOTION_BASE/blocks/$PAGE_ID/children?page_size=100"
```

Look for `heading_1` containing the current year ("2026年") and `heading_2` containing
the current month ("4月"). Only include them in your blocks if they don't already exist.

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
- Only add heading_1/heading_2 if they don't already exist on the page
- Repeat category + bullets for each category in a date
- Add a `divider` between separate dates

Append to the page:

```bash
curl -s -X PATCH \
  -H "Authorization: Bearer $NOTION_API_TOKEN" \
  -H "Notion-Version: $NOTION_VER" \
  -H "Content-Type: application/json" \
  -d "{\"children\": $BLOCKS_JSON}" \
  "$NOTION_BASE/blocks/$PAGE_ID/children"
```

Check the response for `"object":"error"`. If there's an error, report it and **stop** — do not proceed to delete drafts.

## Step 6: Clear drafts

**Branch based on `DRAFT_TARGET`:**

### If `DRAFT_TARGET == "local"`

Delete all processed `.jsonl` files:

```bash
rm -f "$DRAFTS_DIR"/*.jsonl
```

### If `DRAFT_TARGET == "notion"`

Delete each child block from the draft callout (IDs collected in Step 2), one at a time:

```bash
curl -s -X DELETE \
  -H "Authorization: Bearer $NOTION_API_TOKEN" \
  -H "Notion-Version: $NOTION_VER" \
  "$NOTION_BASE/blocks/$BLOCK_ID"
```

Do NOT delete the parent draft callout block itself — keep the container for future sessions.

## Step 7: Report

Tell the user:
- How many sessions were processed
- Which dates were covered
- How many formal log blocks were written
- That the draft area has been cleared and is ready for new sessions
