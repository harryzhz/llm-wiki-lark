---
name: llm-wiki-lark
description: "LLM Wiki：在飞书云盘或知识库中构建三层 LLM 知识库，支持 init/import/ingest/query/lint。触发词：llm wiki, 知识库, wiki ingest, wiki query, wiki lint, wiki init, wiki import, 添加素材, 导入素材"
---

# LLM Wiki on Lark

在飞书云盘或知识库中构建和维护一个 LLM 驱动的结构化知识库。支持**云盘模式**（个人云盘文件夹）和**知识库模式**（飞书知识库节点树）两种存储后端。严格遵循三层架构：**Schema**（行为规范）、**Raw**（原始素材）、**Wiki**（LLM 知识层）。

知识编译一次、持续更新，而非每次查询从零推导。LLM 负责所有维护工作 — 摘要、交叉引用、归类、一致性检查。

## 前置检查

在执行 init/import/ingest/query/lint 之前，**必须先运行以下检查**，缺失项自动安装：

```
Step 1: 检查 lark-cli
  命令: which lark-cli
  如果不存在:
    npm install -g @larksuite/cli

Step 2: 检查认证
  命令: lark-cli auth status
  如果未认证:
    提示用户运行: ! lark-cli auth login
```

## 快速决策树

| 用户意图 | 操作 |
|---------|------|
| "初始化知识库" / "创建新的 wiki" | **init** |
| "把这篇论文存到 raw" / "添加这个 URL" / "上传这个文件" / "先把素材收进来" | **import** |
| "摄入这篇文章" / "分析这个素材" / "把这个加到知识库" | **ingest** |
| "关于 X 我们知道什么" / "从知识库回答" | **query** |
| "检查知识库健康" / "有没有孤立页面" | **lint** |

## 五大操作

- 除 init 外，执行其他操作前先 fetch AGENTS 文档查看规范
- **Wiki 选择规则**（按优先级）：
  1. 用户在本次请求中指定了 wiki 名称 → 从本地配置的 wikis 数组按 `wiki_name` 匹配
  2. 当前对话上下文已确定 wiki → 沿用
  3. 读取 `~/.llm_wiki.setting.json`：仅 1 个 wiki → 自动使用；多个 wiki → 列出所有 wiki（名称 + 创建时间），请用户选择
  4. 用户直接提供 INDEX `doc_id` → 直接使用

| 操作 | 说明 | 详细步骤 |
|------|------|---------|
| **init** | 创建完整目录树 + AGENTS.md + INDEX + LOG | [init.md](references/workflows/init.md) |
| **import** | 将素材（飞书文档/本地文件/外部链接）归档到 raw/ 对应子目录 | [import.md](references/workflows/import.md) |
| **ingest** | 从 raw/ 读取素材 → 创建 Source/Entity/Concept 页面 → 维护交叉引用 | [ingest.md](references/workflows/ingest.md) |
| **query** | 从 INDEX 定位 → fetch 相关页面 → 综合回答 → 有价值的回答归档回流 | [query.md](references/workflows/query.md) |
| **lint** | 检查矛盾、孤立页、断链等 → 生成报告 → 用户确认后修复 | [lint.md](references/workflows/lint.md) |


## 命令参考

- 云盘模式命令见 [Drive Adapter](references/adapter/drive.md)
- 知识库模式命令见 [Wiki Adapter](references/adapter/wiki.md)
- 文档操作仅支持 **docs v2**，已验证 `lark-cli 1.0.98`，不提供 v1 回退。Markdown 正文须显式指定 `--doc-format markdown`。
- 命令报错时，使用 `lark-doc` / `lark-drive` / `lark-wiki` skill 获取完整参数和示例；如未安装，可通过 `npx skills add larksuite/cli -y -g` 安装。

| 操作 | v2 命令 |
|------|---------|
| 创建文档 | `lark-cli docs +create --as user --title "<TITLE>" --parent-token <PARENT_TOKEN> --content "<MARKDOWN>" --doc-format markdown` |
| 读取正文 | `lark-cli docs +fetch --as user --doc <DOC_ID> --doc-format markdown` |
| 追加正文 | `lark-cli docs +update --as user --doc <DOC_ID> --command append --content "<MARKDOWN>" --doc-format markdown` |
| 覆盖全文 | `lark-cli docs +update --as user --doc <DOC_ID> --command overwrite --content "<MARKDOWN>" --doc-format markdown` |
| 替换单块 | `lark-cli docs +update --as user --doc <DOC_ID> --command block_replace --block-id <BLOCK_ID> --content "<MARKDOWN>" --doc-format markdown` |
| 替换简单行内文本 | `lark-cli docs +update --as user --doc <DOC_ID> --command str_replace --pattern "<OLD_TEXT>" --content "<NEW_TEXT>" --doc-format markdown` |

- 创建结果从 `.data.document.document_id` / `.data.document.url` 读取；fetch 正文从 `.data.document.content` 读取。
- `--parent-token`：云盘传 `folder_token`，知识库传 `node_token`。Drive 上传、移动、快捷方式仍按各自命令使用 `--folder-token`。
- 替换段落或多块内容前，先用 `docs +fetch --doc <DOC_ID> --detail with-ids` 获取最新 block ID。单块用 `--block-id`；同一父节点下的连续闭区间用 `--start-block-id <FIRST_BLOCK_ID> --end-block-id <LAST_BLOCK_ID>`。区间包含标题时，替换内容须包含标题；不包含下一节标题。每次修改后重新 fetch，不复用旧 ID。
- `str_replace` 仅处理简单行内文本，不能替换整节、多块内容或文档/附件引用。长内容用 `--content -` 加带单引号的 heredoc，或 `--content @./draft.md`。

## 其他参考文档

- [Wiki Schema](references/wiki-schema.md): 三层架构、页面类型、元数据格式、INDEX/LOG 格式
- [Drive Adapter](references/adapter/drive.md): 云盘模式命令参考
- [Wiki Adapter](references/adapter/wiki.md): 知识库模式命令参考
- [Init Templates](references/templates/init.md): AGENTS.md、INDEX、LOG 初始模板
- [Page Templates](references/templates/pages.md): Source 摘要、Entity/Concept/Comparison/Overview/LOG 模板

## 关键约束

- **文档中引用其他飞书文档禁止使用原始 URL（外部链接除外）** — 统一使用 v2 XML 文档引用：`<cite type="doc" doc-id="<DOC_ID>"></cite>`；上传文件附件使用 `<source token="<FILE_TOKEN>" name="<FILENAME>"></source>`
- **文档中写入流程图、架构图、时序图必须用飞书画板的 DSL 格式**
- **新文档必须放入对应子目录**，创建时指定 `--parent-token`
- **飞书文档增量更新优先，避免 `overwrite`，默认使用分段写入**：`docs +create --title "<TITLE>" --parent-token <PARENT_TOKEN> --doc-format markdown --content ""` 仅写标题骨架拿到 doc_id，正文再用 `docs +update --command append --doc-format markdown --content -` 追加
