# notion-worklog-skills

> Auto-sync Claude Code sessions to a structured Notion work log — draft on session end, organize with AI on demand.

[English](#english) | [中文](#中文)

---

## English

### What it does

**Auto (SessionEnd hook):** Every time a Claude Code session ends, the skill calls Claude Haiku to summarize the session into 3–5 bullet points and appends them to a "草稿区 (Draft)" callout block on your Notion page. Zero friction — you never have to think about it.

**Manual (`/work-log`):** When you run `/work-log`, Claude reads all accumulated draft entries, groups them by date and topic category, writes a structured daily log, and clears the drafts.

```
Session ends  →  session-end.sh  →  Notion draft area (auto)
/work-log     →  Claude reads drafts
              →  AI groups by date + category
              →  Writes formal log to Notion
              →  Clears draft area
```

### Why this skill?

| Skill | Auto-capture | AI organize | Notion | No MCP needed |
|-------|-------------|-------------|--------|---------------|
| session-log (michalparkola) | Yes | No | No | Yes |
| notion-knowledge-capture | No | No | Yes | No |
| **work-log (this)** | **Yes** | **Yes** | **Yes** | **Yes** |

This is the only skill combining automatic session capture + AI-powered organization + direct Notion writes (via `curl`, no MCP dependency).

### Install

```bash
npx skills add huojian-jan/notion-worklog-skills@work-log -g -y
```

Then run setup once to register the SessionEnd hook:

```bash
~/.claude/skills/work-log/setup.sh
```

### Requirements

- `curl` and `jq` (standard on macOS/Linux)
- [Notion integration token](https://www.notion.so/my-integrations) with access to your work log page
- `ANTHROPIC_API_KEY` for session summarization (Claude Haiku)

### Environment variables

Add to `~/.zshrc` or `~/.bashrc`:

```bash
export NOTION_API_TOKEN="secret_..."          # Required: Notion integration token
export ANTHROPIC_API_KEY="sk-ant-..."         # Required: for session summarization
export NOTION_WORKLOG_PAGE_ID="your-page-id"  # Optional: defaults to a built-in page
```

### Draft area (auto-written each session)

```
📝 草稿区（待整理）

[2026-04-12 14:30] · notion-worklog-skills
· Implemented SessionEnd hook for automatic Notion draft writes
· Completed /work-log skill organize logic with AI categorization
· Published to skills.sh marketplace

[2026-04-12 16:00] · blog_source
· Fixed category page rendering issue in Hexo blog
· Updated CLAUDE.md with skill routing configuration
```

### Formal log (written by `/work-log`)

```
# 2026年
## 4月
### 第二周（4月7日 - 4月13日）

**4月12日 周六**

**Notion Integration**
- Implemented SessionEnd hook for automatic drafts
- Completed /work-log organize logic
- Published to skills marketplace

---

**Deliverables:** notion-worklog-skills v1.0.0

**Daily Summary:**
Shipped the complete work-log skill, from auto-draft capture to structured Notion log output.
```

### Debugging

Hook errors are logged to `~/.claude/work-log.log`.

---

## 中文

### 功能介绍

这是一个 [Claude Code](https://claude.ai/code) skill，自动把每次 AI 编程会话同步到 Notion 工作日志，无需手动记录。

**自动部分（SessionEnd hook）：** 每次 Claude Code 会话结束时，脚本自动调用 Claude Haiku 将会话提炼为 3-5 条要点，追加到 Notion 页面顶部的「草稿区」callout 块中。完全自动，零打扰。

**手动整理（`/work-log`）：** 执行 `/work-log` 后，Claude 读取所有草稿条目，按日期和话题分类，整理成结构化的正式工作日志，并清空草稿区。

```
会话结束  →  session-end.sh  →  Notion 草稿区（自动）
/work-log  →  读取所有草稿
           →  AI 按日期 + 分类整理
           →  写入正式工作日志
           →  清空草稿区
```

### 为什么选择这个 skill？

| Skill | 自动捕获 | AI 整理 | 写入 Notion | 无需 MCP |
|-------|---------|---------|------------|---------|
| session-log (michalparkola) | 是 | 否 | 否 | 是 |
| notion-knowledge-capture | 否 | 否 | 是 | 否 |
| **work-log（本项目）** | **是** | **是** | **是** | **是** |

本 skill 是目前唯一集「自动会话草稿 + AI 智能整理 + 直接写入 Notion（仅用 curl，不依赖 MCP）」于一体的方案。

### 安装

```bash
npx skills add huojian-jan/notion-worklog-skills@work-log -g -y
```

安装后运行一次 setup，注册 SessionEnd hook：

```bash
~/.claude/skills/work-log/setup.sh
```

### 依赖

- `curl` 和 `jq`（macOS/Linux 自带）
- [Notion 集成 Token](https://www.notion.so/my-integrations)，需要对工作日志页面有访问权限
- `ANTHROPIC_API_KEY`，用于会话摘要（调用 Claude Haiku）

### 环境变量

添加到 `~/.zshrc` 或 `~/.bashrc`：

```bash
export NOTION_API_TOKEN="secret_..."          # 必填：Notion 集成 Token
export ANTHROPIC_API_KEY="sk-ant-..."         # 必填：用于会话摘要
export NOTION_WORKLOG_PAGE_ID="your-page-id"  # 可选：默认使用内置页面 ID
```

### 草稿区格式（每次会话自动写入）

```
📝 草稿区（待整理）

[2026-04-12 14:30] · notion-worklog-skills
· 实现了 SessionEnd hook，自动写入草稿区
· 完成 /work-log skill 的整理逻辑
· 发布到 skills.sh 市场

[2026-04-12 16:00] · blog_source
· 修复了 Hexo 博客的分类页面渲染问题
· 更新了 CLAUDE.md 的 skill routing 配置
```

### 正式日志格式（`/work-log` 生成）

```
# 2026年
## 4月
### 第二周（4月7日 - 4月13日）

**4月12日 周六**

**Notion 接入**
- 实现 SessionEnd hook 自动草稿
- 完成 /work-log 整理逻辑
- 发布到 skills 市场

---

**产出：** notion-worklog-skills v1.0.0

**今日总结：**
完成了整个 work-log skill 的开发和发布，实现从草稿到结构化日志的完整链路。
```

### 调试

Hook 错误日志写入 `~/.claude/work-log.log`，排查问题时可查看。

---

## License

MIT
