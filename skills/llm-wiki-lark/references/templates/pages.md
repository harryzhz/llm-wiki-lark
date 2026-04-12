# Page Templates — 页面与日志条目模板

操作运行时用于创建 wiki 页面和追加日志条目的模板。模板中 `{{...}}` 为占位符。`<mention-doc>` 的 token 从 INDEX 页面注册表查找。

> 页面类型定义: [wiki-schema.md](../wiki-schema.md)

---

## Source 摘要模板

**标题**: `Source: {{原始标题}}`
**存放**: `wiki/sources/`

```markdown
<callout emoji="📋" background-color="pale-gray">

- **类型**: source
- **创建时间**: {{YYYY-MM-DD HH:mm}}
- **最后更新**: {{YYYY-MM-DD HH:mm}}
- **原始来源**: <mention-doc token="{{RAW_DOC_ID_OR_FILE_TOKEN}}" type="docx">{{原始标题}}</mention-doc>
- **关联**: {{<mention-doc> 链接列表}}

</callout>

## 摘要

{{3-5 句话概括核心观点}}

## 关键要点

- {{要点 1}}
- {{要点 2}}
- {{要点 3}}

## 提取的实体

- <mention-doc token="{{doc_id}}" type="docx">Entity: {{名称}}</mention-doc> — {{角色}}

## 提取的概念

- <mention-doc token="{{doc_id}}" type="docx">Concept: {{名称}}</mention-doc> — {{体现}}

## 原始来源

- <mention-doc token="{{RAW_DOC_ID_OR_FILE_TOKEN}}" type="docx">{{标题}}</mention-doc>
```

---

## Entity / Concept / Comparison / Overview 模板

与之前版本相同，唯一区别是创建时需指定目标文件夹（云盘模式用 `--folder-token`，知识库模式用 `--wiki-node`，详见 [adapter/drive.md](../adapter/drive.md) 或 [adapter/wiki.md](../adapter/wiki.md)）。模板内容不重复列出，参见 [wiki-schema.md](../wiki-schema.md) 中各页面类型的必须段落定义。

---

## 日志条目模板

### INIT

```markdown

---

### {{ISO_TIMESTAMP}} — INIT

**操作**: 初始化 LLM Wiki
**详情**:
- 创建目录树: my-wiki/ → raw/, wiki/, wiki/sources|entities|concepts|comparisons|overviews/
- 创建 AGENTS.md (doc_id: {{AGENTS_DOC_ID}})
- 创建 INDEX (doc_id: {{INDEX_DOC_ID}})
- 创建 LOG (doc_id: {{LOG_DOC_ID}})
```

### INGEST

```markdown

---

### {{ISO_TIMESTAMP}} — INGEST

**来源**: "{{源文档标题}}"
**操作**:
- 创建源摘要: <mention-doc token="{{doc_id}}" type="docx">Source: {{标题}}</mention-doc>
- {{创建/更新页面列表}}
- 更新索引（新增 {{N}} 个页面）
```

### QUERY

```markdown

---

### {{ISO_TIMESTAMP}} — QUERY

**问题**: "{{用户查询}}"
**参考页面**:
- <mention-doc token="{{doc_id}}" type="docx">{{页面标题}}</mention-doc>
- {{其他参考页面}}
**归档**: {{<mention-doc token="{{doc_id}}" type="docx">Comparison/Overview: {{标题}}</mention-doc> 或 "无"}}
```

### LINT

```markdown

---

### {{ISO_TIMESTAMP}} — LINT

**范围**: {{检查范围，如"全量" 或 "抽样 N 页"}}
**发现**:
- ERROR: {{N}} 项
- WARNING: {{N}} 项
- INFO: {{N}} 项
- SUGGESTION: {{N}} 项
**修复**: {{已修复项列表 或 "无"}}
```

### IMPORT

```markdown

---

### {{ISO_TIMESTAMP}} — IMPORT

**素材**:
- 标题: "{{素材标题}}"
- 类型: {{飞书文档 | 本地文件 | 外部链接}}
- 原始来源: {{doc_id / 本地路径 / 原始 URL}}
**目标目录**: `{{raw/papers/ | raw/articles/ | raw/repos/ | raw/datasets/ | raw/images/ | raw/assets/}}`
**操作**: {{移动文档 | 上传文件 | 抓取并创建文档}}
**结果**: <mention-doc token="{{doc_id 或 file_token}}" type="docx">{{标题}}</mention-doc>
**后续**: {{立即执行 ingest | 跳过，待后续摄入}}
```

批量导入多个素材时，一条 LOG 汇总所有素材：

```markdown

---

### {{ISO_TIMESTAMP}} — IMPORT

**批量导入 {{N}} 个素材**:
- <mention-doc token="{{token1}}" type="docx">{{标题1}}</mention-doc> → `raw/articles/`（外部链接）
- <mention-doc token="{{token2}}" type="docx">{{标题2}}</mention-doc> → `raw/papers/`（本地文件）
**后续**: {{立即执行 ingest | 跳过，待后续摄入}}
```
