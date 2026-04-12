# work-log — Claude Code Notion Work Log Skill

> Automatically capture every Claude Code session to a structured Notion work log — no MCP, no extra API key required.

**Local draft mode** (default — sessions saved locally, organized on demand):
```bash
npx skills add huojian-jan/notion-worklog-skills@work-log -g -y
~/.agents/skills/work-log/setup.sh
```

**Notion draft mode** (sessions written to Notion instantly after each session):
```bash
npx skills add huojian-jan/notion-worklog-skills@work-log -g -y
~/.agents/skills/work-log/setup.sh
echo 'export WORK_LOG_DRAFT_TARGET=notion' >> ~/.zshrc && source ~/.zshrc
```

[English](#overview) | [中文说明](#概述中文)

---

## Overview

`work-log` is a Claude Code skill with two parts:

| Part | Trigger | What happens |
|------|---------|-------------|
| **SessionEnd hook** | Automatic — every session end | Saves session metadata to a local file (or Notion). Non-blocking, runs in background. |
| **`/work-log` command** | Manual — you run it | Claude reads all captured sessions, groups by date + category, writes the formal log to Notion, clears local files. |

```
Session ends  →  session-end.sh (async, background)
              →  saves to ~/.claude/work-log-drafts/YYYY-MM-DD.jsonl  (default)
                 or Notion draft callout                               (optional)

/work-log     →  Claude reads draft files
              →  AI summarizes + groups by date + category
              →  Writes structured log to Notion
              →  Clears draft files
```

### Why this skill?

| Skill | Auto-capture | AI organize | Writes to Notion | No extra API key |
|-------|-------------|-------------|-----------------|-----------------|
| session-log (michalparkola) | Yes | No | No | Yes |
| notion-knowledge-capture | No | No | Yes | No |
| **work-log (this)** | **Yes** | **Yes** | **Yes** | **Yes** |

---

## Getting Started

### Step 1 — Install

```bash
npx skills add huojian-jan/notion-worklog-skills@work-log -g -y
```

### Step 2 — Choose your draft mode

#### Mode A: Local Draft (default, recommended)

Sessions are saved locally as `.jsonl` files. Run `/work-log` whenever you want to organize + push to Notion.

```bash
~/.agents/skills/work-log/setup.sh
```

Add to `~/.zshrc`:
```bash
export NOTION_API_TOKEN="your_token_here"
```

#### Mode B: Notion Draft (instant sync)

Sessions are summarized and written to a Notion draft area automatically after each session ends.

```bash
~/.agents/skills/work-log/setup.sh
echo 'export WORK_LOG_DRAFT_TARGET=notion' >> ~/.zshrc && source ~/.zshrc
```

Add to `~/.zshrc`:
```bash
export NOTION_API_TOKEN="your_token_here"
export WORK_LOG_DRAFT_TARGET=notion
```

**Both modes require:**
1. A Notion integration token from [notion.so/my-integrations](https://www.notion.so/my-integrations)
2. The integration connected to your work log page (click `···` → Connections)

### Step 3 — Work normally

Sessions are captured automatically in the background. Run `/work-log` whenever you want to organize them.

---

## Usage

```
/work-log                    # organize drafts → write to Notion → clear local files
```

---

## Output Format

### Local draft files (auto-written, default)

`~/.claude/work-log-drafts/2026-04-12.jsonl`:
```jsonl
{"ts":"2026-04-12 10:30","project":"blog_source","transcript":"..."}
{"ts":"2026-04-12 14:20","project":"notion-worklog-skills","transcript":"..."}
```

### Notion formal log (written by `/work-log`)

```
2026年                           ← H1
  4月                            ← H2
    第二周（4月7日 - 4月13日）      ← H3

    4月12日 周六                   ← bold
      Notion 接入                  ← bold blue (category)
      · SessionEnd hook 自动写入草稿
      · /work-log 整理并写入正式日志
      ─────────────────────────
      产出：work-log skill v1.0
      今日总结：打通 Notion 工作日志自动化全链路。
```

---

## Configuration

All config is via environment variables (add to `~/.zshrc`):

| Variable | Default | Description |
|----------|---------|-------------|
| `NOTION_API_TOKEN` | — | **Required** for Notion writes |
| `NOTION_WORKLOG_PAGE_ID` | `30942947-...` | Target Notion page ID |
| `WORK_LOG_DRAFT_TARGET` | `local` | `local` or `notion` |
| `WORK_LOG_MIN_MESSAGES` | `5` | Min user messages to trigger capture |
| `WORK_LOG_DRAFTS_DIR` | `~/.claude/work-log-drafts` | Local draft storage directory |

### Draft target modes

**`local` (default)** — no extra dependencies, no token needed at session end:
```bash
# default, nothing to set
```

**`notion`** — writes directly to a Notion draft callout after each session:
```bash
export WORK_LOG_DRAFT_TARGET=notion
# NOTION_API_TOKEN must be set
```

---

## How it works

### SessionEnd hook (`session-end.sh`)

Fires automatically when a Claude Code session ends. Configured as `async: true` — never blocks your workflow.

Skips sessions with fewer than `WORK_LOG_MIN_MESSAGES` user messages (default: 5).

In `local` mode: saves `{ts, project, transcript}` to a dated `.jsonl` file. No AI call, instant.

In `notion` mode: launches `claude --print` in the background to summarize the session and write to the Notion draft callout. Uses Claude Code's own auth — no separate `ANTHROPIC_API_KEY` needed.

### `/work-log` skill (`SKILL.md`)

When you run `/work-log`, Claude:
1. Reads all `.jsonl` files from `~/.claude/work-log-drafts/`
2. Summarizes and categorizes each session using its own in-context intelligence
3. Groups entries by date, assigns 2–4 categories per day (max 4 bullets each)
4. Writes structured blocks to the Notion work log page
5. Deletes the processed local files

---

## Troubleshooting

Check the hook log:
```bash
tail -f ~/.claude/work-log.log
```

**Nothing appearing after sessions?**
- Confirm `SessionEnd` hook is registered: check `~/.claude/settings.json`
- Session might be below `WORK_LOG_MIN_MESSAGES` threshold (default: 5)
- In `notion` mode: confirm `NOTION_API_TOKEN` is set and the integration has page access

**`/work-log` says "no drafts"?**
- Check `~/.claude/work-log-drafts/` for `.jsonl` files
- Confirm the hook script is executable: `chmod +x ~/.agents/skills/work-log/scripts/session-end.sh`

---

## Requirements

- Claude Code with `claude` CLI in PATH
- `curl` and `jq`
- Notion API token (for `/work-log` Notion writes)

---

## 概述（中文）

`work-log` 是一个 Claude Code skill，分两部分：

| 部分 | 触发 | 功能 |
|------|------|------|
| **SessionEnd Hook** | 自动，每次会话结束 | 把会话元数据保存到本地文件（或 Notion），后台运行，不阻塞前台 |
| **`/work-log` 命令** | 手动 | Claude 读取所有草稿，按日期+分类整理，写入 Notion 正式日志，清空草稿 |

### 配置说明

| 环境变量 | 默认值 | 说明 |
|----------|--------|------|
| `NOTION_API_TOKEN` | — | **必填**，用于写入 Notion |
| `NOTION_WORKLOG_PAGE_ID` | 内置 | 工作日志 Notion 页面 ID |
| `WORK_LOG_DRAFT_TARGET` | `local` | `local`（本地文件）或 `notion`（直接写 Notion） |
| `WORK_LOG_MIN_MESSAGES` | `5` | 触发记录的最小用户消息数，短会话自动跳过 |
| `WORK_LOG_DRAFTS_DIR` | `~/.claude/work-log-drafts` | 本地草稿目录 |

### 两种草稿模式

**`local`（默认）** — 最简单，不需要额外 API Key：
会话结束时把原始数据存到 `~/.claude/work-log-drafts/YYYY-MM-DD.jsonl`，等你执行 `/work-log` 时由 Claude 在上下文中做摘要和分类。

**`notion`** — 会话结束后直接写入 Notion 草稿区：
```bash
export WORK_LOG_DRAFT_TARGET=notion
```
在后台启动新的 `claude --print` 进程做摘要，复用 Claude Code 自身的认证，不需要单独的 `ANTHROPIC_API_KEY`。

### 排查问题

```bash
tail -f ~/.claude/work-log.log   # 查看 hook 运行日志
ls ~/.claude/work-log-drafts/    # 查看本地草稿文件
```

---

## License

MIT
