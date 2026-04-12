# Claude Code Notion Work Log Skill — work-log

> Automatically sync every Claude Code session to a structured Notion work log. SessionEnd hook drafts bullet summaries; `/work-log` organizes them with AI — no MCP, no manual effort.

**Install:** `npx skills add huojian-jan/notion-worklog-skills@work-log -g -y`

[English](#-overview) | [中文说明](#-概述)

---

## 📋 Overview

`work-log` is a Claude Code skill with two parts:

| Part | Trigger | What happens |
|------|---------|-------------|
| **SessionEnd hook** | Automatic — every session end | Claude Haiku summarizes the session into 3–5 bullets and appends them to a Notion draft callout |
| **`/work-log` command** | Manual — you run it | Claude reads all drafts, groups by date + category, writes the formal log, clears drafts |

```
Session ends  →  session-end.sh  →  Notion draft area  (automatic)
/work-log     →  Claude reads drafts
              →  AI groups by date + category
              →  Writes to formal Notion log
              →  Clears draft area
```

### Why this skill?

| Skill | Auto-capture | AI organize | Writes to Notion | No MCP needed |
|-------|-------------|-------------|-----------------|---------------|
| session-log (michalparkola) | Yes | No | No | Yes |
| notion-knowledge-capture | No | No | Yes | No |
| **work-log (this)** | **Yes** | **Yes** | **Yes** | **Yes** |

The only Claude Code skill that combines automatic session capture + AI-powered organization + direct Notion writes (via `curl` and `jq`, no MCP).

---

## 🚀 Quick Start

### 1. Install

```bash
npx skills add huojian-jan/notion-worklog-skills@work-log -g -y
```

### 2. Set environment variables

```bash
# Add to ~/.zshrc or ~/.bashrc
export NOTION_API_TOKEN="secret_..."          # Notion integration token (required)
export ANTHROPIC_API_KEY="sk-ant-..."         # For session summarization (required)
export NOTION_WORKLOG_PAGE_ID="your-page-id"  # Your Notion page ID (optional)
```

### 3. Register the hook

```bash
~/.claude/skills/work-log/setup.sh
```

That's it. Sessions now auto-save to Notion.

---

## 📝 Output Format

### Draft area (written automatically after each session)

```
📝 草稿区（待整理）

[2026-04-12 14:30] · notion-worklog-skills
· Implemented SessionEnd hook for automatic Notion draft writes
· Completed /work-log AI categorization logic
· Published skill to marketplace

[2026-04-12 16:00] · blog_source
· Fixed Hexo category page rendering
· Updated CLAUDE.md skill routing config
```

### Formal work log (written by `/work-log`)

```
# 2026年
## 4月
### Week 2 (Apr 7 – Apr 13)

**April 12, Saturday**

**Notion Integration**
- SessionEnd hook auto-drafts to Notion
- /work-log AI organizes drafts by category

---

**Deliverables:** notion-worklog-skills v1.0.0

**Daily Summary:**
Shipped the complete work-log skill — auto-draft to structured Notion log.
```

---

## ⚙️ Requirements

- `curl` and `jq` (standard on macOS / Linux)
- [Notion integration token](https://www.notion.so/my-integrations) with access to your work log page
- `ANTHROPIC_API_KEY` (Claude Haiku is used for session summarization — cheap, ~$0.001/session)

---

## ❓ FAQ

**Does this require any MCP server?**
No. All Notion API calls use `curl` directly. No MCP setup needed.

**Will it work with any Notion page?**
Yes. Set `NOTION_WORKLOG_PAGE_ID` to your page's ID. The skill creates the draft callout on first use.

**What model summarizes sessions?**
Claude Haiku (`claude-haiku-4-5-20251001`) — fast and cheap. Each session summary costs roughly $0.001.

**What if a session is too short?**
The hook skips sessions with fewer than 30 characters of transcript. Trivial sessions are not recorded.

**Where do I find errors?**
Hook errors log to `~/.claude/work-log.log`.

**Can I use this on Windows?**
The hook script requires bash, curl, and jq. Works on WSL or Git Bash.

---

## 中文说明

### 📋 概述

`work-log` 是一个 [Claude Code](https://claude.ai/code) skill，由两部分组成：

| 部分 | 触发方式 | 功能 |
|------|---------|------|
| **SessionEnd Hook** | 自动 — 每次会话结束时 | 调用 Claude Haiku 将会话提炼为 3-5 条要点，追加到 Notion 草稿区 callout |
| **`/work-log` 命令** | 手动 — 你主动执行 | Claude 读取所有草稿，按日期+分类整理，写入正式工作日志，清空草稿区 |

### 为什么用这个 skill？

| Skill | 自动捕获 | AI 整理 | 写入 Notion | 无需 MCP |
|-------|---------|---------|------------|---------|
| session-log (michalparkola) | 是 | 否 | 否 | 是 |
| notion-knowledge-capture | 否 | 否 | 是 | 否 |
| **work-log（本项目）** | **是** | **是** | **是** | **是** |

目前唯一集「自动会话草稿 + AI 智能整理 + 直接写入 Notion（仅用 curl，不依赖 MCP）」于一体的 Claude Code skill。

### 🚀 快速开始

**1. 安装**

```bash
npx skills add huojian-jan/notion-worklog-skills@work-log -g -y
```

**2. 配置环境变量**（加入 `~/.zshrc`）

```bash
export NOTION_API_TOKEN="secret_..."          # 必填：Notion 集成 Token
export ANTHROPIC_API_KEY="sk-ant-..."         # 必填：会话摘要用
export NOTION_WORKLOG_PAGE_ID="your-page-id"  # 可选：你的工作日志页面 ID
```

**3. 注册 Hook**

```bash
~/.claude/skills/work-log/setup.sh
```

完成！此后每次 Claude Code 会话结束，内容自动写入 Notion 草稿区。

### ⚙️ 依赖

- `curl` 和 `jq`（macOS / Linux 自带）
- [Notion 集成 Token](https://www.notion.so/my-integrations)，需对工作日志页面有访问权限
- `ANTHROPIC_API_KEY`，用于摘要（Claude Haiku，每次会话约 $0.001）

### ❓ 常见问题

**需要 MCP 吗？** 不需要，所有 Notion API 调用通过 `curl` 直接完成。

**报错去哪里看？** `~/.claude/work-log.log`。

**模型消耗大吗？** 使用 Claude Haiku，非常便宜，每次会话摘要约 $0.001。

---

## License

MIT
