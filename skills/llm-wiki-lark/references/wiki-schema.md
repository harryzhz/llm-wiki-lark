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
| `articles/` | 博客文章、新闻报道 | 飞书云文档或 Markdown 上传 |
| `repos/` | 代码仓库 README / 关键文件快照 | MD 文件上传 |
| `datasets/` | 数据文件 | CSV、JSON 等直接上传 |
| `images/` | 图表、架构图、截图 | PNG/JPG 等图片上传 |
| `assets/` | 各类附件 | 直接上传 |

> 以上仅为默认值。用户可在 init 时增删改子目录列表（如删除 datasets、添加 notes）。实际子目录列表以 INDEX 目录配置表为准。

**写入方式**: raw/ 由用户负责写入，LLM 只读不写。用户将原始素材放入对应子目录后通知 LLM 进行摄入处理。

#### Raw 装配模式（init 时确定，记录在 INDEX「Wiki 配置」的 `raw_mode`）

| 模式 | 含义 | INDEX 目录配置 | 下游枚举方式 |
|------|------|---------------|-------------|
| `create`（默认） | 本 wiki 新建 `raw/` 及上表子目录 | `raw` + 各 `raw/<子目录>` 静态行 | 读 INDEX 静态子目录行 |
| `reference` | 引用一棵已有节点树（如现有知识库目录）为 raw 层 | 仅 `raw` 一行，指向**原节点真实导航 token**（wiki=node_token，drive=folder_token），无 `raw/<子目录>` 行 | 用 `scripts/list_raw_tree.sh` 实时递归枚举原树，感知后续新增 |
| `none` | 不创建 raw 层 | `raw` 行为 `-` | — |

> **reference 模式**：raw 登记的是原节点的真实导航 token，**不是快捷方式 token**（快捷方式节点无法被 list 遍历出子树）。原树原地不动、由其维护者增删；本 wiki 在每次 ingest 时实时枚举原树，无需把素材搬进来。原树可与本 wiki root 不在同一 space，故 INDEX 另存 `raw_source_space_id`，下游 `list_raw_tree.sh` 必须用它而非 root 的 space_id。

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
- `## 摘要`（等价：`## 概要`）— 核心观点 3-5 句话
- `## 关键要点`（等价：`## 核心要点`、`## 要点`）— 要点列表
- `## 提取的实体`（等价：`## 实体`、`## 涉及的实体`）— 使用 `<cite type="doc" doc-id="..."></cite>` 链接
- `## 提取的概念`（等价：`## 概念`、`## 涉及的概念`）— 使用 `<cite type="doc" doc-id="..."></cite>` 链接
- `## 原始来源`（等价：`## 原始素材`）— docx 素材使用 `<cite type="doc" doc-id="..."></cite>`；上传文件素材使用 `<source token="..." name="..."></source>`

> **等价标题说明**: lint 在做必须段落检查时按"等价"列接受替代标题。新建页面建议优先使用主标题以保持一致性。

### Entity（实体页）

**标题格式**: `Entity: <实体名称>`
**存放目录**: `wiki/entities/`
**识别标准**: 命名实体（人物/组织/产品/工具/系统），在源文档中被实质性讨论且可提取 ≥3 条关键事实。仅被一笔带过的提及不建页，在 Source 摘要中内联提及即可。

**必须段落**:
- 元数据 callout
- `## 概述`
- `## 关键事实`
- `## 出现在` — 引用源文档（等价：`## 出处`、`## 相关来源`、`## 来源`）
- `## 相关实体`（等价：`## 关联实体`）

### Concept（概念页）

**标题格式**: `Concept: <概念名称>`
**存放目录**: `wiki/concepts/`
**识别标准**: 抽象概念（理论/方法论/模式/原则/框架），在源文档中有定义或解释，且具有跨源复用价值。仅被提及名称但未展开的概念不建页。

**必须段落**:
- 元数据 callout
- `## 定义`
- `## 详细说明`（等价：`## 描述`、`## 详述`）
- `## 来源`（等价：`## 相关来源`）
- `## 相关概念`（等价：`## 关联概念`）

### Comparison（对比分析）

**标题格式**: `Comparison: <主题>` 或 `Comparison: <A> vs <B>`
**存放目录**: `wiki/comparisons/`

**必须段落**:
- 元数据 callout
- `## 对比维度`（等价：`## 维度`）
- `## 分析`（推荐表格）
- `## 结论`（等价：`## 总结`）
- `## 参考来源`（等价：`## 参考`、`## 相关来源`、`## 来源`）

### Overview（综述）

**标题格式**: `Overview: <范围>`
**存放目录**: `wiki/overviews/`

**必须段落**:
- 元数据 callout
- `## 概览`（等价：`## 概述`、`## 引言`）
- `## 核心主题`（等价：`## 主题`）
- `## 当前认知`（等价：`## 当前理解`）
- `## 开放问题`（等价：`## 未决问题`）
- `## 参考`（等价：`## 参考来源`、`## 相关来源`）

## 元数据 Callout 格式

每个 Wiki 页面（INDEX 和 LOG 除外）的**第一个块**必须是：

```html
<callout emoji="📋" background-color="pale-gray">

- **类型**: source | entity | concept | comparison | overview
- **创建时间**: YYYY-MM-DD HH:mm
- **最后更新**: YYYY-MM-DD HH:mm
- **来源**: <cite type="doc" doc-id="<SOURCE_DOC_ID>"></cite>
- **关联**: <cite type="doc" doc-id="<ENTITY_DOC_ID>"></cite>

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
> **reference 模式**：只有 `raw` 一行（指向被引用原节点的真实导航 token），没有 `raw/<子目录>` 行；子目录由下游 `list_raw_tree.sh` 实时枚举。

```markdown
## Wiki 配置

| 键 | 值 |
|---|---|
| wiki_name | <用户自定义名称> |
| storage_type | drive 或 wiki |
| space_id | <知识空间ID，仅 wiki 模式> |
| raw_mode | create / reference / none |
| raw_source_token | <reference 模式：原节点真实导航 token；否则 -> |
| raw_source_space_id | <reference + wiki：原树 space_id；否则 -> |
| 创建时间 | YYYY-MM-DD HH:mm |
| 最后更新 | YYYY-MM-DD HH:mm |
| 页面总数 | N |
| AGENTS doc_id | <AGENTS_DOC_ID> |
| LOG doc_id | <LOG_DOC_ID> |

## 页面注册表

| 标题 | 类型 | Doc ID | Doc | 目录 | 最后更新 | 关联 | 别名 | 标签 | Raw Token | 出链 | 入链 | 证据数 | 摘要 |
|------|------|--------|-----|------|---------|------|------|------|-----------|------|------|--------|------|
```

### 页面注册表字段说明

- **Doc**: 使用 v2 XML 文档引用格式: `<cite type="doc" doc-id="<doc_id>"></cite>`，飞书会渲染为可点击的文档引用卡片；`<cite>` 不承载自定义显示文本，标题由飞书根据目标文档自动渲染
- **扩展索引字段**: 新版本 INDEX 应使用以下完整表头，旧 INDEX 缺列时按空值兼容读取，下一次写回注册表时补齐：

```markdown
| 标题 | 类型 | Doc ID | Doc | 目录 | 最后更新 | 关联 | 别名 | 标签 | Raw Token | 出链 | 入链 | 证据数 | 摘要 |
|------|------|--------|-----|------|---------|------|------|------|-----------|------|------|--------|------|
```

- **别名**: 中英文名、缩写、常见别称，使用 `;` 分隔，用于 query 粗召回和去重。
- **标签**: 主题、领域、技术栈或来源类别，使用 `;` 分隔。
- **Raw Token**: Source 页对应 raw 文档的 doc_id/file_token；非 Source 页面为空或填主要来源 token。
- **出链/入链**: 当前页引用/被引用的 wiki doc_id 列表，使用 `;` 分隔。
- **证据数**: 页面内直接引用 Source 或原始证据的数量。
- **摘要**: 一句话摘要，供 query 在不 fetch 正文时做初筛。

### 索引操作规则

- **读取**: `lark-cli docs +fetch --doc <INDEX_DOC_ID> --doc-format markdown` → 正文在 `.data.document.content`，解析获得 token 映射（云盘为 folder_token，知识库为 node_token）和页面注册表
- **更新注册表 / 更新配置（首选：整篇重建 + overwrite）**: INDEX 完全由 LLM 拥有，每次操作开始已 fetch 读全。合并新增/变更后整体重写——
  ```
  lark-cli docs +update --doc <INDEX_DOC_ID> --command overwrite --doc-format markdown --content - <<'EOF'
  # INDEX

  ...（完整三节：目录配置 / Wiki 配置 / 页面注册表，含全部已有+新增行）...
  EOF
  ```
  ⚠️ overwrite 会清空重写，markdown 内容**必须以 `# INDEX` 一级标题开头**以保留文档标题。
- **小改动备选（targeted str_replace）**: 仅改个别字段（如「页面总数」「最后更新」）时，用 `docs +update --doc <INDEX_DOC_ID> --command str_replace --doc-format markdown --pattern '旧片段' --content '新片段'` 精确替换那一行，避免重写整篇。
- 不要 append 新表行——append 出的表格行不会并入原表，会成为孤立 block。

## LOG 文档格式

`wiki/LOG` 是 append-only 操作日志。每个条目以 `---` 分隔，时间戳使用 ISO 8601，详见 [templates/pages.md](templates/pages.md) 的「日志条目模板」章节。

## 交叉引用规则

```html
<cite type="doc" doc-id="<DOC_ID>"></cite>
```

1. **doc-id 必须使用 doc_id / obj_token**（即文档 token）
2. `<cite>` 不写标签体；需要补充说明时写在标签后，例如：`<cite type="doc" doc-id="<DOC_ID>"></cite> — 说明`
3. 上传文件附件使用 `<source token="<FILE_TOKEN>" name="<FILENAME>"></source>`，不要伪装成文档引用
4. **禁止使用旧格式 `<mention-doc ...>`**；在 v2 写入中它会被当作普通文本转义，lint 必须标为 ERROR
5. **双向链接** — 创建 A 引用 B 时，也应更新 B 引用 A
6. 从 INDEX 页面注册表中查找 doc_id
