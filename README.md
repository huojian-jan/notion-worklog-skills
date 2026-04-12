# Claude Code Notion Work Log Skill — work-log

> Automatically sync every Claude Code session to a structured Notion work log. SessionEnd hook drafts bullet summaries; `/work-log` organizes them with AI — no MCP, no manual effort.

**Install:** `npx skills add huojian-jan/notion-worklog-skills@work-log -g -y`

[English](#-overview) | [中文说明](#-概述中文)

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

---

## 🛠️ Getting Started

Setup takes about 2 minutes. The script handles most of it automatically.

### Step 1 — Install the Skill

```bash
npx skills add huojian-jan/notion-worklog-skills@work-log -g -y
```

---

### Step 2 — Run Setup

```bash
~/.agents/skills/work-log/setup.sh
```

The script walks you through everything interactively:

**What the script does automatically:**
- Opens your browser to the Notion integration page and the Anthropic API key page
- Validates your tokens
- Searches for Notion pages your integration can access
- **Creates the `日志草稿` (Log Draft) and `工作日志` (Work Log) pages for you** via the Notion API — no manual page creation or ID copying needed
- Writes `~/.config/work-log/config`
- Registers the SessionEnd hook in `~/.claude/settings.json`

**What you do manually (can't be automated):**
1. Create a Notion integration at `notion.so/my-integrations` and copy the token
2. Connect your integration to one existing Notion page (the parent — once only)

The script guides you through both steps with instructions.

**Example session:**

```
Step 1 — Notion API Token
  Opening https://www.notion.so/my-integrations ...
  Paste NOTION_API_TOKEN: secret_...
  [ok] Integration: 'work-log'

Step 2 — Anthropic API Key
  [ok] ANTHROPIC_API_KEY already set

Step 3 — Notion Pages
  Searching for pages your integration can access...
  Found 3 page(s). Choose a parent:
    1) Work
    2) Personal
    3) Projects
  Choice [1]: 1
  [ok] Created '日志草稿' (Log Draft)
  [ok] Created '工作日志' (Work Log)

Step 4 — Writing config
  [ok] Config written to: ~/.config/work-log/config

Step 5 — Registering SessionEnd hook
  [ok] Registered hook

Setup complete!
```

---

### Step 3 — First Session

Start a Claude Code session and work normally. When the session ends, the skill:
1. Calls Claude Haiku to summarize the session into 3–5 bullet points
2. Writes them to the `📝 草稿区` callout block on your `日志草稿` page

Run `/work-log` anytime to organize all accumulated drafts into a clean structured log on the `工作日志` page.

---

## 🎮 Usage

### Basic

```
/work-log
```

Reads all drafts from the draft page, organizes by date and category, writes the formal log to the log page. Drafts are **kept** by default.

### Clear drafts after organizing

```
/work-log --clear
```

Same as above, but also deletes all draft entries from the draft page after writing the log.

### With focus prompt

```
/work-log 重点记录架构决策
/work-log focus on bug fixes and debugging
```

The AI uses your text to prioritize and emphasize relevant bullets when organizing.

### With alternate template

```
/work-log --template minimal
/work-log --template minimal 重点 bug 修复
```

Templates live in `~/.agents/skills/work-log/templates/`. Copy and modify `default.md` to create your own.

---

## 📝 Output Format

### Draft area (auto-written after each session)

```
📝 草稿区（待整理）

[2026-04-12 14:30] · notion-worklog-skills
· Implemented SessionEnd hook for automatic Notion draft writes
· Completed /work-log AI categorization logic
· Published skill to skills marketplace

[2026-04-12 16:00] · blog_source
· Fixed Hexo category page rendering bug
· Updated CLAUDE.md skill routing config
```

### Formal work log (written by `/work-log`)

```
# 2026年
## 4月
### 第二周（4月7日 - 4月13日）

**4月12日 周六**

**Notion Integration**
- SessionEnd hook auto-drafts bullet summaries
- /work-log organizes drafts by date and category

---

**Deliverables:** notion-worklog-skills v1.0.0

**Daily Summary:**
Shipped the complete work-log skill — auto-draft capture to structured Notion log.
```

---

## ⚙️ Configuration

All non-secret settings live in `~/.config/work-log/config` (created by `setup.sh`):

```bash
# Draft page — session summaries auto-written here by the SessionEnd hook
NOTION_WORKLOG_DRAFT_PAGE_ID="your-draft-page-id"

# Log page — formal structured log written here by /work-log
NOTION_WORKLOG_PAGE_ID="your-log-page-id"

NOTION_API_VERSION="2022-06-28"
WORK_LOG_DEFAULT_TEMPLATE="default"
WORK_LOG_SUMMARY_LANGUAGE="zh"   # "zh" for Chinese, "en" for English
WORK_LOG_SUMMARY_MODEL="claude-haiku-4-5-20251001"
WORK_LOG_MAX_TRANSCRIPT_CHARS="6000"
```

Secrets (`NOTION_API_TOKEN`, `ANTHROPIC_API_KEY`) stay in your shell profile — never in the config file.

---

## ❓ FAQ

**Does this require any MCP server?**
No. All Notion API calls use `curl` directly.

**Do the Notion pages need any specific structure before I start?**
No. Leave both pages empty. The skill creates the `📝 草稿区` callout automatically on the first session.

**Why two pages instead of one?**
The draft page is your inbox — raw, auto-written after every session. The log page is your archive — clean, organized, always ready to share. Keeping them separate means `/work-log --clear` can safely wipe the draft inbox without touching your formal log.

**What model summarizes sessions?**
Claude Haiku (`claude-haiku-4-5-20251001`) — fast and cheap (~$0.001/session).

**Why is nothing appearing in Notion after a session?**
Check `~/.claude/work-log.log`. Common causes: `NOTION_API_TOKEN` not set, `ANTHROPIC_API_KEY` not set, or the integration wasn't connected to both pages (Step 3).

**Will `/work-log` delete my drafts?**
No, unless you pass `--clear`. Default behavior keeps all drafts so you can review them. Use `/work-log --clear` to clean up after you're happy with the organized log.

**What if a session is too short?**
Sessions under 30 characters of transcript are skipped automatically.

**Can I use this on Windows?**
The hook script requires bash, curl, and jq. Use WSL or Git Bash.

---

## 中文说明

---

## 📋 概述（中文）

`work-log` 是一个 [Claude Code](https://claude.ai/code) skill，由两部分组成：

| 部分 | 触发方式 | 功能 |
|------|---------|------|
| **SessionEnd Hook** | 自动 — 每次会话结束时 | 调用 Claude Haiku 将会话提炼为 3-5 条要点，追加到 Notion **草稿页** callout |
| **`/work-log` 命令** | 手动 — 你主动执行 | Claude 读取草稿页中的所有草稿，按日期+分类整理，写入**日志页**，可选清空草稿 |

### 为什么用这个 skill？

| Skill | 自动捕获 | AI 整理 | 写入 Notion | 无需 MCP |
|-------|---------|---------|------------|---------|
| session-log (michalparkola) | 是 | 否 | 否 | 是 |
| notion-knowledge-capture | 否 | 否 | 是 | 否 |
| **work-log（本项目）** | **是** | **是** | **是** | **是** |

---

## 🛠️ 从零开始配置

配置大约需要 2 分钟，脚本会自动完成大部分工作。

### 第一步 — 安装 skill

```bash
npx skills add huojian-jan/notion-worklog-skills@work-log -g -y
```

---

### 第二步 — 运行 setup 脚本

```bash
~/.agents/skills/work-log/setup.sh
```

脚本会全程引导你完成配置：

**脚本自动完成的事情：**
- 自动打开浏览器，跳转到 Notion 集成页面和 Anthropic API Key 页面
- 验证你输入的 Token
- 搜索你的集成能访问的 Notion 页面
- **通过 API 自动创建 `日志草稿` 和 `工作日志` 两个页面** — 无需手动创建，无需手动复制 ID
- 写入 `~/.config/work-log/config`
- 在 `~/.claude/settings.json` 中注册 SessionEnd hook

**需要你手动完成的事情（无法自动化）：**
1. 在 `notion.so/my-integrations` 创建 Notion 集成，复制 Token
2. 将集成连接到一个已有的 Notion 页面（作为父页面，只需操作一次）

脚本会在两个步骤处给出具体操作指引。

**示例运行过程：**

```
Step 1 — Notion API Token
  Opening https://www.notion.so/my-integrations ...
  Paste NOTION_API_TOKEN: secret_...
  [ok] Integration: 'work-log'

Step 2 — Anthropic API Key
  [ok] ANTHROPIC_API_KEY already set

Step 3 — Notion Pages
  Searching for pages your integration can access...
  Found 3 page(s). Choose a parent:
    1) Work
    2) Personal
    3) Projects
  Choice [1]: 1
  [ok] Created '日志草稿' (Log Draft)
  [ok] Created '工作日志' (Work Log)

Setup complete!
```

---

### 第三步 — 开始使用

正常使用 Claude Code 即可。会话结束时，skill 自动：
1. 调用 Claude Haiku 将会话提炼为 3-5 条要点
2. 写入 `日志草稿` 顶部的 `📝 草稿区` callout 块

想整理草稿时，在 Claude Code 中执行：

```
/work-log
```

草稿整理后写入 `工作日志`。默认保留草稿，加 `--clear` 参数可在整理后自动清空草稿。

---

## 🎮 使用方式

```
/work-log                         # 默认模板，整理草稿，保留草稿区
/work-log --clear                 # 默认模板，整理草稿，整理后清空草稿区
/work-log 重点记录架构决策          # 默认模板，AI 重点关注架构内容
/work-log --template minimal      # 使用精简模板
/work-log --template minimal 重点 bug 修复   # 精简模板 + 聚焦
```

模板文件在 `~/.agents/skills/work-log/templates/`，复制 `default.md` 修改即可自定义。

---

## ⚙️ 配置文件

所有非敏感设置保存在 `~/.config/work-log/config`（由 `setup.sh` 创建）：

```bash
# 草稿页（"日志草稿"）— SessionEnd hook 自动写入这里
NOTION_WORKLOG_DRAFT_PAGE_ID="your-draft-page-id"

# 日志页（"工作日志"）— /work-log 写入整理好的正式条目
NOTION_WORKLOG_PAGE_ID="your-log-page-id"

NOTION_API_VERSION="2022-06-28"
WORK_LOG_DEFAULT_TEMPLATE="default"
WORK_LOG_SUMMARY_LANGUAGE="zh"   # zh=中文，en=英文
WORK_LOG_SUMMARY_MODEL="claude-haiku-4-5-20251001"
WORK_LOG_MAX_TRANSCRIPT_CHARS="6000"
```

`NOTION_API_TOKEN` 和 `ANTHROPIC_API_KEY` 是密钥，只放在 shell profile 里，不写入配置文件。

---

## ❓ 常见问题

**需要 MCP 吗？**
不需要，所有 Notion API 调用通过 `curl` 直接完成。

**Notion 页面需要提前配置什么结构吗？**
不需要，留空即可。`📝 草稿区` callout 会在第一次会话结束时自动创建。

**为什么需要两个页面？**
草稿页（日志草稿）是收件箱，每次会话自动写入。日志页（工作日志）是档案，整理后写入。分开后可以放心用 `--clear` 清空草稿，不影响正式日志。

**`/work-log` 会清空草稿吗？**
默认不会。加 `--clear` 参数才会在整理后清空草稿区。

**会话结束后 Notion 没有内容，怎么排查？**
查看 `~/.claude/work-log.log`。常见原因：`NOTION_API_TOKEN` 未设置、`ANTHROPIC_API_KEY` 未设置、或者第三步忘记把集成连接到两个页面了。

**模型费用高吗？**
用的是 Claude Haiku，非常便宜，每次会话摘要约 $0.001。

---

## License

MIT
