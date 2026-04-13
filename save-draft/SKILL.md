---
name: save-draft
description: Manually save current or past session transcripts to the work-log draft area. Use when sessions were missed by the auto-hook, or to capture the current session without ending it.
version: 1.0.0
author: huojian-jan
triggers:
  - /save-draft
---

You are executing the `/save-draft` skill. Scan for session transcript files, let the user pick which ones to save, then write them to the local draft area.

## Configuration

```bash
DRAFTS_DIR="${WORK_LOG_DRAFTS_DIR:-$HOME/.claude/work-log-drafts}"
PROJECTS_DIR="$HOME/.claude/projects"
MIN_MESSAGES="${WORK_LOG_MIN_MESSAGES:-3}"
```

## Step 1: Parse arguments

Check user input after `/save-draft`:
- No arguments → scan for **today's** sessions across all projects
- `--all` → scan for **all unprocessed** sessions (any date)
- `--date YYYY-MM-DD` → scan for sessions on a specific date
- A file path → process that specific transcript file directly

## Step 2: Find transcript files

Search `$PROJECTS_DIR` for `.jsonl` transcript files (exclude `subagents/` subdirectories).

For each file, quickly check:
1. Modification date matches the target date filter
2. It has at least `$MIN_MESSAGES` real user messages (lines with `type=="user"` and `.message.content` is a string)
3. **DEDUP (REQUIRED):** It has NOT already been saved. Before scanning, build a set of already-saved source paths:

```bash
SAVED_SOURCES=$(cat "$DRAFTS_DIR"/*.jsonl 2>/dev/null | jq -r '.source // empty' | sort -u)
```

Then for each candidate file, skip it if its path appears in `$SAVED_SOURCES`:

```bash
if echo "$SAVED_SOURCES" | grep -qF "$TRANSCRIPT_PATH"; then
  # Already saved — skip
  continue
fi
```

This prevents duplicate entries even if `/save-draft` is run multiple times. The `.source` field in each draft entry stores the original transcript file path for this check.

Build a list of eligible sessions with:
- File path
- Project name (extracted from parent directory name, strip the `-Users-huojian-Desktop-` prefix)
- User message count
- File modification time
- First user message preview (first 50 chars)

## Step 3: Show the user what was found

Display a numbered table:

```
Found N unprocessed session(s):

 #  | Time  | Project       | Messages | Preview
 1  | 09:25 | sync-win      | 22       | 帮我看一下我的work-log...
 2  | 13:32 | blog-source   | 8        | 更新博客的部署配置...
 3  | 16:47 | my-skills     | 3        | 帮我看一下我的work-log...

Save all? Or specify numbers (e.g. "1,3" or "all")
```

Wait for user input. If user says "all" or just confirms, process all. Otherwise process only the selected numbers.

## Step 4: Process selected sessions

For each selected transcript file:

1. Extract the project name from the file's parent directory
2. Extract the date from the file's modification time
3. Build transcript text:

```bash
jq -r '
  select(.type == "user" or .type == "assistant") |
  if .type == "user" then
    if (.message.content | type) == "string" then
      "user: " + .message.content
    else empty end
  elif .type == "assistant" then
    if (.message.content | type) == "array" then
      "assistant: " + ([.message.content[] | select(.type == "text") | .text] | join(" "))
    elif (.message.content | type) == "string" then
      "assistant: " + .message.content
    else empty end
  else empty end
' "$TRANSCRIPT_PATH" | tail -60
```

4. Truncate to 5000 chars max.

5. Save to local draft:

```bash
mkdir -p "$DRAFTS_DIR"
DRAFT_FILE="$DRAFTS_DIR/$DATE.jsonl"
TIMESTAMP=$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$TRANSCRIPT_PATH")

jq -cn \
  --arg ts "$TIMESTAMP" \
  --arg project "$PROJECT" \
  --arg transcript "$TRANSCRIPT" \
  --arg source "$TRANSCRIPT_PATH" \
  '{ts: $ts, project: $project, transcript: $transcript, source: $source}' \
  >> "$DRAFT_FILE"
```

Note: include `source` field so we can detect duplicates later.

## Step 5: Report

Tell the user:
- How many sessions were saved
- Which projects and dates were covered
- Where the drafts were written
- Remind: "Run `/work-log` to organize these drafts into the formal Notion log."
