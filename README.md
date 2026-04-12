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

### Step 1 — Create a Notion Integration (get your API token)

1. Open **[https://www.notion.so/my-integrations](https://www.notion.so/my-integrations)** and click **"+ New integration"**

2. Fill in the form:
   - **Name:** anything, e.g. `work-log`
   - **Associated workspace:** select your Notion workspace
   - Leave other fields as defaults

3. Click **"Submit"** (or "Save")

4. On the next screen, copy the **"Internal Integration Token"**
   — this is your `NOTION_API_TOKEN`, formatted like:
   ```
   secret_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ```

> ⚠️ Keep this token private. Anyone with it can access any page you share with it.

---

### Step 2 — Create Two Notion Pages

You need **two separate pages**:

| Page | Purpose |
|------|---------|
| **Draft page** | Session summaries auto-written here after every session |
| **Log page** | Formal structured log written here when you run `/work-log` |

For each page:
1. In Notion, click **"+ New page"** in the left sidebar
2. Give it a title — recommended names:
   - Draft page: **"Log Draft"** (or **"日志草稿"**)
   - Log page: **"Work Log"** (or **"工作日志"**)
3. Leave the page body **empty**

> **Why two pages?** The draft page is your inbox — raw session bullets accumulate here automatically. The log page is your archive — clean, organized entries written by `/work-log`. Keeping them separate means your formal log is always clean and shareable.

---

### Step 3 — Connect the Integration to Both Pages ⚠️

**This step is required for each page, and often missed.** Without it, the Notion API returns 403.

Repeat these steps for **both** the draft page and the log page:

1. Open the page in Notion
2. Click the **`···`** (three dots) menu at the top-right of the page
3. Scroll down and click **"Connections"**
4. In the search box, type your integration name (e.g. `work-log`)
5. Click the integration, then click **"Confirm"**

The integration name appears in the Connections list — done for that page. Repeat for the other.

> If you don't see "Connections" in the menu, try clicking "Add connections" — it's the same thing in a slightly different Notion UI version.

---

### Step 4 — Get Both Page IDs

For each page, open it in a browser. The URL looks like:

```
https://www.notion.so/your-workspace/Work-Log-Draft-30942947b59c80f39e22eed448e5862f
                                                      └─────────── Page ID ──────────┘
```

The **Page ID** is the 32-character hex string at the end of the URL path.
You can also write it with dashes — both formats work:
```
30942947b59c80f39e22eed448e5862f
30942947-b59c-80f3-9e22-eed448e5862f   ← either is fine
```

> **Tip:** In the Notion desktop app — right-click the page in the sidebar → **"Copy link"**, then paste the link somewhere and grab the last path segment.

Note down **both** IDs — you'll need them in Step 7.

---

### Step 5 — Install the Skill

```bash
npx skills add huojian-jan/notion-worklog-skills@work-log -g -y
```

---

### Step 6 — Add API Tokens to Your Shell Profile

```bash
# Add both lines to ~/.zshrc (or ~/.bashrc on Linux)
echo 'export NOTION_API_TOKEN="secret_your_token_here"' >> ~/.zshrc
echo 'export ANTHROPIC_API_KEY="sk-ant-your_key_here"' >> ~/.zshrc

# Reload so the current shell picks them up
source ~/.zshrc
```

---

### Step 7 — Run Setup

```bash
~/.agents/skills/work-log/setup.sh
```

The setup script will:
- Ask for your **draft page ID** and **log page ID** (from Step 4) if not already set
- Write `~/.config/work-log/config` with all your settings
- Register the **SessionEnd hook** in `~/.claude/settings.json`

When it finishes you should see:
```
[ok] Draft page ID: 30942947-b59c-80f3-9e22-eed448e5862f
[ok] Log page ID:   ab123456-...
[ok] NOTION_API_TOKEN is set
[ok] ANTHROPIC_API_KEY is set
[ok] Registered SessionEnd hook: ...
Setup complete!
```

---

### Step 8 — First Session

Start a Claude Code session and work normally. When the session ends, the skill:
1. Calls Claude Haiku to summarize the session into 3–5 bullet points
2. Writes them to the `📝 草稿区` callout block on your **draft page**

Run `/work-log` anytime to organize all accumulated drafts into a clean structured log on the **log page**.

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

### 第一步 — 创建 Notion 集成（获取 Token）

1. 打开 **[https://www.notion.so/my-integrations](https://www.notion.so/my-integrations)**，点击 **"+ New integration"**

2. 填写表单：
   - **Name：** 随便填，比如 `work-log`
   - **Associated workspace：** 选择你的 Notion 工作区
   - 其他字段保持默认

3. 点击 **"Submit"**（或 "Save"）保存

4. 在下一个页面复制 **"Internal Integration Token"**
   — 这就是你的 `NOTION_API_TOKEN`，格式如下：
   ```
   secret_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ```

> ⚠️ 妥善保管这个 Token，任何拿到它的人都能访问你分享给它的 Notion 页面。

---

### 第二步 — 在 Notion 创建两个页面

你需要创建**两个独立的页面**：

| 页面 | 用途 |
|------|------|
| **草稿页** | 每次会话结束后自动写入的收件箱 |
| **日志页** | 执行 `/work-log` 后写入整理好的正式日志 |

每个页面：
1. 在 Notion 左侧边栏点击 **"+ New page"** 新建页面
2. 标题推荐使用：草稿页 **"日志草稿"**，日志页 **"工作日志"**
3. 页面内容**留空**

> **为什么要两个页面？** 草稿页是收件箱——原始会话要点自动积累在这里。日志页是档案——执行 `/work-log` 后写入整理好的正式条目，随时可以分享。两页分离后，`/work-log --clear` 可以安全清空草稿收件箱而不影响正式日志。

---

### 第三步 — 将集成分别连接到两个页面（关键步骤，容易漏掉）⚠️

**这一步必须做，而且两个页面都要做。** 跳过的话 Notion API 会返回 403，什么都写不进去。

对**草稿页**和**日志页**分别执行以下步骤：

1. 打开该页面
2. 点击页面**右上角**的 **`···`**（三个点）菜单
3. 向下找到 **"Connections"**，点击展开
4. 在搜索框输入你的集成名称（如 `work-log`）
5. 点击集成名称，再点击 **"Confirm"** 确认授权

完成后该集成会出现在 Connections 列表中，说明连接成功。对另一个页面重复同样操作。

> 如果菜单里没有 "Connections"，找找 "Add connections"，是同一个功能的不同版本 UI。

---

### 第四步 — 获取两个页面的 ID

对每个页面，在浏览器中打开，URL 格式如下：

```
https://www.notion.so/your-workspace/Work-Log-Draft-30942947b59c80f39e22eed448e5862f
                                                      └────────── 这串就是 Page ID ──┘
```

**Page ID** 是 URL 末尾的 32 位十六进制字符串，带不带分隔符都能用：

```
30942947b59c80f39e22eed448e5862f
30942947-b59c-80f3-9e22-eed448e5862f   ← 两种格式均可
```

> **小技巧：** 在 Notion 桌面端，右键点击左侧边栏的页面 → **"Copy link"**，然后粘贴链接，取最后一段路径即可。

两个页面的 ID 都记录下来，第七步会用到。

---

### 第五步 — 安装 skill

```bash
npx skills add huojian-jan/notion-worklog-skills@work-log -g -y
```

---

### 第六步 — 将 Token 写入 shell 配置文件

```bash
# 追加到 ~/.zshrc（Linux 用 ~/.bashrc）
echo 'export NOTION_API_TOKEN="secret_你的token"' >> ~/.zshrc
echo 'export ANTHROPIC_API_KEY="sk-ant-你的key"' >> ~/.zshrc

# 重新加载让当前终端生效
source ~/.zshrc
```

---

### 第七步 — 运行 setup 完成配置

```bash
~/.agents/skills/work-log/setup.sh
```

setup 脚本会：
- 分别询问**草稿页 ID** 和**日志页 ID**（第四步获取的）
- 创建 `~/.config/work-log/config` 保存所有设置
- 在 `~/.claude/settings.json` 中注册 **SessionEnd hook**

看到以下输出说明配置成功：

```
[ok] Draft page ID: 30942947-b59c-80f3-9e22-eed448e5862f
[ok] Log page ID:   ab123456-...
[ok] NOTION_API_TOKEN is set
[ok] ANTHROPIC_API_KEY is set
[ok] Registered SessionEnd hook: ...
Setup complete!
```

---

### 第八步 — 开始使用

正常使用 Claude Code 即可。会话结束时，skill 自动：
1. 调用 Claude Haiku 将会话提炼为 3-5 条要点
2. 写入**草稿页**顶部的 `📝 草稿区` callout 块

想整理草稿时，在 Claude Code 中执行：

```
/work-log
```

草稿整理后写入**日志页**。默认保留草稿，加 `--clear` 参数可在整理后自动清空草稿。

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
