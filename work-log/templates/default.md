# Work Log Template: default

The default Chinese daily log format. Hierarchical Year → Month → Week → Day structure with topic categories, deliverables, and a daily summary.

---

## Page Heading Blocks

Add the following at the top of the log section **only if they don't already exist** on the page:

- `heading_1` — Year, e.g. `2026年`
- `heading_2` — Month, e.g. `4月`

---

## Day Entry Blocks (repeat for each date, oldest first)

```
heading_3     — Week label: "第X周（M月D日 - M月D日）"
paragraph     — [bold] Date + weekday: "4月12日 周六"

[Repeat for each category:]
paragraph     — [bold, color: blue] Category name
bulleted_list_item — bullet point
bulleted_list_item — bullet point
...

divider

paragraph     — [bold] "产出：deliverable1; deliverable2"
paragraph     — [bold] "今日总结："
paragraph     — [plain] One sentence summary of the day
```

---

## Categorization Rules

- Create **2–4 topic categories** per day from the bullet pool
- Category names: Chinese, 3–8 characters, functional (e.g. `Notion 接入`, `Bug 修复`, `代码重构`, `文档`, `配置`)
- **Max 4 bullets per category** — keep the most important, drop minor or redundant ones
- Deliverables: 1–3 concrete outputs (features shipped, problems fixed, docs written)
- Summary: one sentence, plain Chinese, factual not evaluative

---

## Example

```
### 第二周（4月7日 - 4月13日）

**4月12日 周六**

**Notion 接入**
- 实现 SessionEnd hook 自动写入草稿区
- 完成 /work-log 整理逻辑及分类

**发布**
- 发布 notion-worklog-skills v1.0.0 到 skills 市场
- 添加双语 README 和 SEO 优化

---

**产出：** notion-worklog-skills v1.0.0 发布；双语 README

**今日总结：**
完成了 work-log skill 的全部开发和发布工作。
```
