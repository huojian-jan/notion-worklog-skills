# notion-worklog-skills

A [Claude Code](https://claude.ai/code) skill that automatically syncs sessions to a structured Notion work log.

## How it works

**Auto (SessionEnd hook):** Every time a Claude Code session ends, the skill summarizes the session into 3–5 bullet points and appends them to a "草稿区" callout block on your Notion page.

**Manual (`/work-log`):** When you run `/work-log`, Claude reads all draft entries, organizes them by date and category, writes the formal log structure, and clears the drafts.

```
┌──────────────────────────────────────────────────────┐
│  Session ends  →  session-end.sh  →  Notion 草稿区  │
│  /work-log     →  Claude reads drafts                │
│                →  AI organizes by date + category    │
│                →  Writes to formal log               │
│                →  Clears draft area                  │
└──────────────────────────────────────────────────────┘
```

## Install

```bash
npx skills add huojian-jan/notion-worklog-skills@work-log -g -y
```

Then run setup once:

```bash
~/.claude/skills/work-log/setup.sh
```

## Requirements

- `curl` and `jq` (standard on macOS/Linux)
- Notion integration token with access to your work log page
- Anthropic API key (for session summarization via Claude Haiku)

## Environment variables

Add to `~/.zshrc` or `~/.bashrc`:

```bash
export NOTION_API_TOKEN="secret_..."          # Required
export NOTION_WORKLOG_PAGE_ID="your-page-id"  # Optional, has a default
export ANTHROPIC_API_KEY="sk-ant-..."         # Required for session summarization
```

## Draft area format

Each session appends to a callout block marked "📝 草稿区":

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

## Formal log format

After running `/work-log`:

```
# 2026年
## 4月
### 第二周（4月7日 - 4月13日）

**4月12日 周六**

**Notion 接入**
- 实现 SessionEnd hook 自动草稿
- 完成 /work-log 整理逻辑
- 发布到 skills.sh 市场

---

**产出：** notion-worklog-skills v1.0.0

**今日总结：**
完成了整个 work-log skill 的开发和发布，实现从草稿到结构化日志的完整链路。
```

## Why this skill?

| Skill | Storage | Auto-capture | AI organize | Notion |
|-------|---------|-------------|-------------|--------|
| session-log (michalparkola) | Local MD | Yes | No | No |
| notion-knowledge-capture | Notion | No | No | Yes (MCP) |
| **work-log (this)** | **Notion** | **Yes** | **Yes** | **Yes (curl)** |

This is the only skill combining session auto-drafting + AI organization + direct Notion writes (no MCP dependency).

## Debugging

Hook errors are logged to `~/.claude/work-log.log`. Check it if sessions aren't appearing in Notion.

## License

MIT
