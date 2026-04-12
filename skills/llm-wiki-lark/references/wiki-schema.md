# Wiki Schema — 知识库结构定义

本文档定义 LLM Wiki 的三层目录架构、页面类型规范和元数据约定。支持云盘和知识库两种存储模式（详见 [adapter/drive.md](adapter/drive.md) 或 [adapter/wiki.md](adapter/wiki.md)）。

## 三层架构

```
<wiki-name>/                           # 根文件夹（init 时用户自定义名称，默认 my-wiki）
├── AGENTS.md                          # Schema 层
├── raw/                               # 原始素材层（不可变，LLM 只读不写）
│   ├── <子目录1>/                     # 用户在 init 时自定义
│   ├── <子目录2>/                     # 默认: papers, articles, repos,
│   └── ...                            #        datasets, images, assets
└── wiki/                              # Wiki 层
    ├── INDEX                          # 页面注册表
    ├── LOG                            # 操作日志
    ├── sources/                       # 源文档摘要
    ├── entities/                      # 实体页
    ├── concepts/                      # 概念页
    ├── comparisons/                   # 对比分析
    └── overviews/                     # 综述
```

> **存储模式**：云盘模式下，上述文件夹为云盘文件夹（`folder_token`）；知识库模式下，文件夹为 docx 节点（`node_token`），节点本身是空文档但可拥有子节点。目录树结构和命名规则在两种模式下完全相同。
>
> **raw/ 子目录**：init 时展示默认列表 `[papers, articles, repos, datasets, images, assets]`，用户可增删改。最终列表记录在 INDEX 目录配置和本地配置中。

### Schema 层 — `AGENTS.md`

Wiki 的结构约定和 LLM 行为规范文档。定义：
- 页面类型和命名规范
- 元数据 callout 格式
- 交叉引用约定
- ingest/query/lint 工作流规则
- 用户偏好和领域特定约定

由用户和 LLM 共同维护，随着 Wiki 演进逐步完善。

### Raw 层 — `raw/`

原始素材，**不可变，LLM 只读不写**。按素材类型分子目录存放。

子目录在 init 时由用户自定义，默认提供以下 6 个：

| 子目录 | 用途 | 存放方式 |
|-------|------|---------|
| `papers/` | 学术论文 | PDF 上传或转换为 MD 后上传 |
| `articles/` | 博客文章、新闻报道 | 飞书剪存生成的飞书文档存放 |
| `repos/` | 代码仓库 README / 关键文件快照 | MD 文件上传 |
| `datasets/` | 数据文件 | CSV、JSON 等直接上传 |
| `images/` | 图表、架构图、截图 | PNG/JPG 等图片上传 |
| `assets/` | 各类附件 | 直接上传 |

> 以上仅为默认值。用户可在 init 时增删改子目录列表（如删除 datasets、添加 notes）。实际子目录列表以 INDEX 目录配置表为准。

**写入方式**: raw/ 由用户负责写入，LLM 只读不写。用户将原始素材放入对应子目录后通知 LLM 进行摄入处理。

### Wiki 层 — `wiki/`

LLM 生成和维护的所有知识页面。LLM 完全拥有此层。

- `INDEX` — 页面注册表，所有操作的入口
- `LOG` — append-only 操作日志
- `sources/` — Source 摘要页（LLM 对 raw/ 素材的分析产物）
- `entities/` — Entity 实体页
- `concepts/` — Concept 概念页
- `comparisons/` — Comparison 对比分析页
- `overviews/` — Overview 综述页

## 页面类型

### Source（源文档摘要）

**标题格式**: `Source: <原始标题>`
**存放目录**: `wiki/sources/`

**必须段落**:
- 元数据 callout
- `## 摘要` — 核心观点 3-5 句话
- `## 关键要点` — 要点列表
- `## 提取的实体` — 使用 `<mention-doc>` 链接
- `## 提取的概念` — 使用 `<mention-doc>` 链接
- `## 原始来源` — 使用 `<mention-doc>` 引用 raw/ 下的素材（文档和文件格式相同）

### Entity（实体页）

**标题格式**: `Entity: <实体名称>`
**存放目录**: `wiki/entities/`
**识别标准**: 命名实体（人物/组织/产品/工具/系统），在源文档中被实质性讨论且可提取 ≥3 条关键事实。仅被一笔带过的提及不建页，在 Source 摘要中内联提及即可。

**必须段落**:
- 元数据 callout
- `## 概述`
- `## 关键事实`
- `## 出现在` — 引用源文档
- `## 相关实体`

### Concept（概念页）

**标题格式**: `Concept: <概念名称>`
**存放目录**: `wiki/concepts/`
**识别标准**: 抽象概念（理论/方法论/模式/原则/框架），在源文档中有定义或解释，且具有跨源复用价值。仅被提及名称但未展开的概念不建页。

**必须段落**:
- 元数据 callout
- `## 定义`
- `## 详细说明`
- `## 来源`
- `## 相关概念`

### Comparison（对比分析）

**标题格式**: `Comparison: <主题>` 或 `Comparison: <A> vs <B>`
**存放目录**: `wiki/comparisons/`

**必须段落**:
- 元数据 callout
- `## 对比维度`
- `## 分析`（推荐表格）
- `## 结论`
- `## 参考来源`

### Overview（综述）

**标题格式**: `Overview: <范围>`
**存放目录**: `wiki/overviews/`

**必须段落**:
- 元数据 callout
- `## 概览`
- `## 核心主题`
- `## 当前认知`
- `## 开放问题`
- `## 参考`

## 元数据 Callout 格式

每个 Wiki 页面（INDEX 和 LOG 除外）的**第一个块**必须是：

```html
<callout emoji="📋" background-color="pale-gray">

- **类型**: source | entity | concept | comparison | overview
- **创建时间**: YYYY-MM-DD HH:mm
- **最后更新**: YYYY-MM-DD HH:mm
- **来源**: <mention-doc token="doxcnXXX" type="docx">Source: 标题</mention-doc>
- **关联**: <mention-doc token="doxcnYYY" type="docx">Entity: 名称</mention-doc>

</callout>
```

> **重要**: callout 内的空行会被飞书吞掉导致字段合并为单行。必须使用**列表格式**（`- ` 前缀）确保每个字段独立成行。

## INDEX 文档格式

`wiki/INDEX` 是整个 Wiki 的核心注册表和导航入口。

```markdown
## 目录配置

| 目录 | Token |
|------|-------|
| root (<wiki-name>) | <ROOT_TOKEN> |
| raw | <RAW_TOKEN> |
| raw/<子目录1> | <TOKEN> |
| raw/<子目录2> | <TOKEN> |
| ... | ... |
| wiki | <WIKI_TOKEN> |
| wiki/sources | <SOURCES_TOKEN> |
| wiki/entities | <ENTITIES_TOKEN> |
| wiki/concepts | <CONCEPTS_TOKEN> |
| wiki/comparisons | <COMPARISONS_TOKEN> |
| wiki/overviews | <OVERVIEWS_TOKEN> |
```

> Token 列：云盘模式存 `folder_token`（fldcn...），知识库模式存 `node_token`（wikcn...）。
> raw/ 子目录行数量和名称由 init 时用户确认的列表决定。

```markdown
## Wiki 配置

| 键 | 值 |
|---|---|
| wiki_name | <用户自定义名称> |
| storage_type | drive 或 wiki |
| space_id | <知识空间ID，仅 wiki 模式> |
| 创建时间 | YYYY-MM-DD HH:mm |
| 最后更新 | YYYY-MM-DD HH:mm |
| 页面总数 | N |
| AGENTS doc_id | doxcnAGENTS |
| LOG doc_id | doxcnLOG |

## 页面注册表

| 标题 | 类型 | Doc ID | Doc | 目录 | 最后更新 | 关联 |
|------|------|--------|-----|------|---------|------|
```

### 页面注册表字段说明

- **Doc**: 使用 mention-doc 引用格式: `<mention-doc token="<doc_id>" type="docx"><文档标题></mention-doc>`，飞书会渲染为可点击的文档引用卡片

### 索引操作规则

- **读取**: `lark-cli docs +fetch --doc <INDEX_DOC_ID>` → 解析获得 token 映射（云盘为 folder_token，知识库为 node_token）和页面注册表
- **更新注册表**: `docs +update --mode replace_range --selection-by-title "## 页面注册表"`
- **更新配置**: `docs +update --mode replace_range --selection-by-title "## Wiki 配置"`

## LOG 文档格式

`wiki/LOG` 是 append-only 操作日志，格式同之前版本。每个条目以 `---` 分隔，时间戳使用 ISO 8601。

## 交叉引用规则

```html
<mention-doc token="doxcnXXXX" type="docx">显示文本</mention-doc>
```

1. **token 必须使用 doc_id**（`doxcn...` 格式）
2. **type 固定为 docx**
3. **双向链接** — 创建 A 引用 B 时，也应更新 B 引用 A
4. 从 INDEX 页面注册表中查找 doc_id
