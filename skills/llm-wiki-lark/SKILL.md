---
name: llm-wiki-lark
description: "LLM Wiki：在飞书云盘或知识库中构建三层目录架构的 LLM 知识库。支持云盘和知识库两种存储模式。支持知识库初始化(init)、素材导入(import)、源文档摄入(ingest)、知识查询(query)、健康检查(lint)。当用户需要将文档、文章、笔记整理成结构化知识库，或从已建知识库中检索、合成答案时使用。触发词：llm wiki, 知识库, 知识库摄入, 知识库查询, wiki ingest, wiki query, wiki lint, wiki init, wiki import, 添加素材, 添加文档到知识库, 添加原始素材, 导入素材"
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


## 工具命令速查

| 操作 | 命令 |
|------|------|
| 创建文件夹 | `lark-cli drive files create_folder --as user --data '{"name":"xxx","folder_token":"父目录"}'` |
| 创建文档（指定目录） | `lark-cli docs +create --as user --title "xxx" --folder-token <FOLDER> --markdown "..."` |
| 读取文档 | `lark-cli docs +fetch --as user --doc <DOC_ID>` |
| 追加内容 | `lark-cli docs +update --as user --doc <DOC_ID> --mode append --markdown "..."` |
| 覆盖文档 | `lark-cli docs +update --as user --doc <DOC_ID> --mode overwrite --markdown "..."` |
| 替换段落 | `lark-cli docs +update --as user --doc <DOC_ID> --mode replace_range --selection-by-title "## 标题" --markdown "..."` |
| 重命名文档 | `lark-cli docs +update --as user --doc <DOC_ID> --new-title "新标题" --mode append --markdown " "` |
| 下载文件 | `cd /tmp && lark-cli drive +download --file-token <TOKEN> --output ./<文件名>` |
| 搜索文档 | `lark-cli docs +search --query "关键词"` |
| 列出目录内容 | `lark-cli drive files list --as user --params '{"folder_token":"<FOLDER_TOKEN>"}'` |
| 创建快捷方式 | `lark-cli drive +create-shortcut --as user --file-token <TOKEN> --type <docx\|file\|bitable\|doc\|sheet\|mindnote\|slides> --folder-token <FOLDER>` |
| 上传文件到目录 | `lark-cli drive +upload --as user --file <本地绝对路径> --folder-token <FOLDER>` |
| 移动文件/文档 | `lark-cli drive +move --as user --file-token <TOKEN> --type <docx\|file\|folder> --folder-token <TARGET>` |

### 知识库模式命令速查

| 操作 | 命令 |
|------|------|
| 获取节点信息 | `lark-cli wiki spaces get_node --as user --params '{"token":"<NODE_TOKEN>"}'` |
| 创建节点 | `lark-cli wiki nodes create --as user --params '{"space_id":"<SPACE_ID>"}' --data '{"parent_node_token":"<PARENT>","obj_type":"docx","node_type":"origin","title":"xxx"}'` |
| 列出子节点 | `lark-cli wiki nodes list --as user --params '{"space_id":"<SPACE_ID>","parent_node_token":"<NODE_TOKEN>"}'` |
| 创建文档到节点 | `lark-cli docs +create --as user --title "xxx" --wiki-node <NODE_TOKEN> --markdown "..."` |

> 知识库模式下，读取/更新/搜索文档的命令与云盘模式相同（`docs +fetch/+update/+search`）。完整命令参考见 [adapter/drive.md](references/adapter/drive.md) 和 [adapter/wiki.md](references/adapter/wiki.md)。

**命令报错时**：以上为常用命令速查，不保证覆盖所有参数和用法。如果 `lark-cli` 命令执行报错，应使用 `lark-doc` / `lark-drive` / `lark-wiki` skill 获取完整的命令文档和示例。如未安装，可通过 `npx skills add larksuite/cli -y -g` 安装。

## 其他参考文档

- [Wiki Schema](references/wiki-schema.md): 三层架构、页面类型、元数据格式、INDEX/LOG 格式
- [Drive Adapter](references/adapter/drive.md): 云盘模式命令参考
- [Wiki Adapter](references/adapter/wiki.md): 知识库模式命令参考
- [Init Templates](references/templates/init.md): AGENTS.md、INDEX、LOG 初始模板
- [Page Templates](references/templates/pages.md): Source 摘要、Entity/Concept/Comparison/Overview/LOG 模版

## 关键约束

- **文档中引用其他文档/文件禁止使用原始 URL（（外部链接除外））** — 统一使用 `<mention-doc>`, **`<mention-doc>` token 必须用 `doc_id` 或 `file_token`**，type 固定 `docx`（文档和文件引用格式相同）
- **文档中写入流程图、架构图、时序头必须用飞书画板的 DSL 格式**
- **新文档必须放入对应子目录**
- **飞书文档增量更新优先，避免`overwrite`, 默认使用分段写入**: `docs +create` 仅写标题，内容用 `docs +update --mode append` 追加
