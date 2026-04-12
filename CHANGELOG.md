# Changelog

All notable changes to the `work-log` skill are documented here.

## [1.2.0] - 2026-04-12

### Added
- **Two draft modes**: `local` (default, JSONL files) and `notion` (writes to Notion draft page after each session)
- **Two-page Notion architecture**: separate draft page (`NOTION_WORKLOG_DRAFT_PAGE_ID`) and log page (`NOTION_WORKLOG_PAGE_ID`) — drafts and formal log never mix
- **`/work-log --clear` flag**: optionally delete drafts after organizing; without `--clear`, drafts are preserved
- **Date-grouped draft structure**: both modes organize sessions under `── YYYY-MM-DD ──` headers
- **Auto page creation in `setup.sh`**: setup can create the 日志草稿 and 工作日志 pages automatically under a chosen parent
- **Dual install instructions in README**: separate quick-start commands for local mode vs. Notion mode

### Changed
- `session-end.sh` rewritten from bash to zsh (required for `source ~/.zshrc`)
- Notion mode now uses `claude --print` for summarization only, then executes `curl` directly — removes dependency on background `claude --print` subshell for network calls
- Session header JSON now built via `jq` to safely handle project names with special characters
- SKILL.md updated with `DRAFT_PAGE_ID` configuration and `--clear` flag parsing

### Fixed
- `timeout 10 cat` → `cat`: macOS has no GNU `timeout`, causing sessions to be silently dropped
- `echo "$ENTRY"` → `printf '%s\n' "$ENTRY"`: zsh `echo` was interpreting `\n` in JSON, writing invalid JSONL
- `source ~/.zshrc` in bash → moved to zsh shebang: bash couldn't source a zsh config file
- Scripts not executable after `npx skills add`: fixed git file mode to `100755`
- Session header JSON injection: `${PROJECT}` interpolated directly into JSON string — now escaped via `jq -Rs`

## [1.1.0] - 2026-04-10

### Added
- Template system with configurable `WORK_LOG_DEFAULT_TEMPLATE`
- Config file at `~/.config/work-log/config` written by `setup.sh`
- `WORK_LOG_SUMMARY_LANGUAGE`, `WORK_LOG_SUMMARY_MODEL`, `WORK_LOG_MAX_TRANSCRIPT_CHARS` config vars
- Automated Notion page creation in setup flow

### Changed
- Detailed bilingual setup guide in README

## [1.0.0] - 2026-04-08

### Added
- Initial release
- `session-end.sh` SessionEnd hook: auto-captures sessions to Notion draft callout
- `/work-log` skill: reads drafts, AI-organizes by date and category, writes formal log to Notion
- Bilingual README (English + 中文)
- No extra API key needed — uses Claude Code's own auth
