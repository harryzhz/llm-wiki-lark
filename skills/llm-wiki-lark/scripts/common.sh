#!/bin/bash
# common.sh — init.sh 共用函数库
# 使用方式：source "$(dirname "$0")/common.sh"

WIKI_SUBDIRS="sources entities concepts comparisons overviews"

# ---------- 模板函数 ----------

agents_markdown() {
  cat <<'MD'
<callout emoji="📘" background-color="light-blue">

本文档定义此 LLM Wiki 的结构约定和行为规范。LLM 在执行 ingest/query/lint 操作时必须遵循这些规则。用户和 LLM 共同维护此文档，随着知识库演进持续完善。

</callout>

## 页面类型

| 类型 | 标题前缀 | 存放目录 | 说明 |
|------|---------|---------|------|
| source | Source: | wiki/sources/ | 对 raw/ 素材的分析摘要 |
| entity | Entity: | wiki/entities/ | 人物、组织、工具、项目等 |
| concept | Concept: | wiki/concepts/ | 方法论、模式、理论等 |
| comparison | Comparison: | wiki/comparisons/ | 对比分析（通常由 query 产出） |
| overview | Overview: | wiki/overviews/ | 主题综述（通常由 query 产出） |

## 命名规范

- 标题前缀严格遵循上表
- Entity 以名词命名，Concept 以主题命名
- Source 标题取原文标题，过长时适当缩写

## 引用规范

- 文档内所有对云盘文档/文件的引用统一使用 `<mention-doc token="doc_id 或 file_token" type="docx">标题</mention-doc>`
- 禁止在文档内容中使用云盘文档/文件的原始 URL（外部链接不受此限制）
- INDEX 页面注册表的 Doc 列同样使用 mention-doc 格式

## 工作流规则

- **ingest**: 用户将素材放入 raw/ 后通知 LLM → LLM 从 raw/ 读取内容 → 在 wiki/ 创建 Source 摘要和关联页面 → Source 页的「原始来源」用 mention-doc 引用 raw/ 下的素材
- **query**: 从 INDEX 定位相关页面 → fetch 并综合回答 → 有价值的回答归档为 Overview/Comparison 回流到 wiki
- **lint**: 检查矛盾、过时声明、孤立页、缺失页面、断链、交叉引用缺失 → 生成报告 → 建议新问题和新源

## 领域约定

> 以下为默认配置，可根据使用习惯调整

- **提取粒度**: 精选（仅提取有充分信息支撑的实体/概念，≥3 条关键事实）
- **摄入模式**: 交互式（提取前展示预览并等待确认）
- **归档策略**: 推荐归档（对比分析和综述主动推荐，用户一键确认）
- **领域关键词**: （用户填写，帮助 LLM 识别领域内的重要实体和概念）

（由用户和 LLM 在使用过程中逐步补充，例如：）
（- 本知识库聚焦的领域和范围）
（- 特定术语的翻译或命名约定）
MD
}

log_init_markdown() {
  cat <<'MD'
## 操作日志

最新操作在最下方。
MD
}

# ---------- INDEX 全量内容 ----------
# 依赖环境变量（由 run_init 在调用前设置）：
#   WIKI_NAME, STORAGE_TYPE, SPACE_ID（wiki 模式）
#   ROOT_TOKEN, RAW_TOKEN, RAW_TOKEN_TABLE, WIKI_TOKEN
#   TOKEN_sources/entities/concepts/comparisons/overviews
#   AGENTS_DOC_ID, LOG_DOC_ID, TODAY

build_index_markdown() {
  local space_id_value="${SPACE_ID:--}"
  cat <<MD
<callout emoji="📚" background-color="light-blue">

LLM Wiki 索引 — 所有页面的注册表和导航入口。

</callout>

## 目录配置

> Token 列：云盘模式存 folder_token，知识库模式存 node_token。

| 目录 | Token |
|------|-------|
| root (${WIKI_NAME}) | ${ROOT_TOKEN} |
| raw | ${RAW_TOKEN} |
${RAW_TOKEN_TABLE}| wiki | ${WIKI_TOKEN} |
| wiki/sources | ${TOKEN_sources} |
| wiki/entities | ${TOKEN_entities} |
| wiki/concepts | ${TOKEN_concepts} |
| wiki/comparisons | ${TOKEN_comparisons} |
| wiki/overviews | ${TOKEN_overviews} |

## Wiki 配置

| 键 | 值 |
|---|---|
| wiki_name | ${WIKI_NAME} |
| storage_type | ${STORAGE_TYPE} |
| space_id | ${space_id_value} |
| 创建时间 | ${TODAY} |
| 最后更新 | ${TODAY} |
| 页面总数 | 0 |
| AGENTS doc_id | ${AGENTS_DOC_ID} |
| LOG doc_id | ${LOG_DOC_ID} |

> - \`storage_type\`：\`drive\`（云盘，默认）或 \`wiki\`（知识库）
> - \`space_id\`：仅知识库模式需要，云盘模式填 \`-\`

## 页面注册表

| 标题 | 类型 | Doc ID | Doc | 目录 | 最后更新 | 关联 |
|------|------|--------|-----|------|---------|------|
MD
}

# ---------- LOG 初始化条目 ----------

build_log_entry() {
  local raw_count
  raw_count=$(echo "$RAW_SUBDIRS" | wc -w | tr -d ' ')
  cat <<MD

### ${TODAY} INIT

- 操作: 初始化知识库
- 存储模式: ${STORAGE_TYPE}
- raw/ 子目录: ${RAW_SUBDIRS}
- 创建文件夹: ${raw_count} raw 子目录 + 5 wiki 子目录
MD
}

# ---------- 主初始化流程 ----------
# 要求调用前已定义：
#   _create_dir "$name" "$parent"   → 输出 token 字符串
#   _create_doc "$title" "$parent_token" "$markdown" → 输出 JSON（含 .data.doc_id 和 .data.doc_url）
#   STORAGE_TYPE, WIKI_NAME, PARENT_TOKEN, RAW_SUBDIRS
#   SPACE_ID（wiki 模式必填）

run_init() {
  # --- [1/9] 根目录 ---
  echo "=== [1/9] 创建根目录: $WIKI_NAME ==="
  ROOT_TOKEN=$(_create_dir "$WIKI_NAME" "$PARENT_TOKEN")
  echo "ROOT_TOKEN=$ROOT_TOKEN"

  # --- [2/9] raw/ 和 wiki/ ---
  echo "=== [2/9] 创建 raw/ 和 wiki/ ==="
  RAW_TOKEN=$(_create_dir "raw" "$ROOT_TOKEN")
  WIKI_TOKEN=$(_create_dir "wiki" "$ROOT_TOKEN")
  echo "RAW_TOKEN=$RAW_TOKEN  WIKI_TOKEN=$WIKI_TOKEN"

  # --- [3/9] raw/ 子目录 ---
  echo "=== [3/9] 创建 raw/ 子目录 ==="
  RAW_TOKEN_TABLE=""
  for subdir in $RAW_SUBDIRS; do
    echo "  创建 raw/$subdir ..."
    token=$(_create_dir "$subdir" "$RAW_TOKEN")
    echo "  raw/$subdir => $token"
    RAW_TOKEN_TABLE+="| raw/${subdir} | ${token} |"$'\n'
  done

  # --- [4/9] wiki/ 子目录 ---
  echo "=== [4/9] 创建 wiki/ 子目录 ==="
  for subdir in $WIKI_SUBDIRS; do
    echo "  创建 wiki/$subdir ..."
    token=$(_create_dir "$subdir" "$WIKI_TOKEN")
    echo "  wiki/$subdir => $token"
    declare "TOKEN_${subdir}=$token"
  done

  # --- [5/9] AGENTS.md ---
  echo "=== [5/9] 创建 AGENTS.md ==="
  local agents_result
  agents_result=$(_create_doc "AGENTS" "$ROOT_TOKEN" "$(agents_markdown)")
  read -r AGENTS_DOC_ID AGENTS_DOC_URL < <(
    echo "$agents_result" | jq -r '[.data.doc_id, (.data.doc_url // "")] | @tsv'
  )
  echo "AGENTS_DOC_ID=$AGENTS_DOC_ID"

  # --- [6/9] INDEX ---
  echo "=== [6/9] 创建 INDEX ==="
  local index_result
  index_result=$(_create_doc "INDEX" "$WIKI_TOKEN" " ")
  read -r INDEX_DOC_ID INDEX_DOC_URL < <(
    echo "$index_result" | jq -r '[.data.doc_id, (.data.doc_url // "")] | @tsv'
  )
  echo "INDEX_DOC_ID=$INDEX_DOC_ID"

  # --- [7/9] LOG ---
  echo "=== [7/9] 创建 LOG ==="
  TODAY=$(date "+%Y-%m-%d %H:%M")
  local log_result
  log_result=$(_create_doc "LOG" "$WIKI_TOKEN" "$(log_init_markdown)")
  read -r LOG_DOC_ID LOG_DOC_URL < <(
    echo "$log_result" | jq -r '[.data.doc_id, (.data.doc_url // "")] | @tsv'
  )
  echo "LOG_DOC_ID=$LOG_DOC_ID"

  # --- [8/9] 更新 INDEX ---
  echo "=== [8/9] 更新 INDEX（填入所有 token）==="
  lark-cli docs +update --as user --doc "$INDEX_DOC_ID" \
    --mode overwrite --markdown "$(build_index_markdown)"

  # --- [9/9] 追加 LOG 条目 ---
  echo "=== [9/9] 追加 LOG 初始化条目 ==="
  lark-cli docs +update --as user --doc "$LOG_DOC_ID" \
    --mode append --markdown "$(build_log_entry)"

  # --- 保存配置 + 输出摘要 ---
  echo "=== 初始化完成 ==="
  echo ""
  echo "INIT_RESULT_JSON:"
  SPACE_ID="${SPACE_ID:-}"
  ROOT_URL="${ROOT_URL:-}"
  export WIKI_NAME STORAGE_TYPE SPACE_ID ROOT_TOKEN ROOT_URL \
         INDEX_DOC_ID INDEX_DOC_URL AGENTS_DOC_ID AGENTS_DOC_URL \
         LOG_DOC_ID LOG_DOC_URL RAW_SUBDIRS TODAY
  python3 "$SCRIPT_DIR/save_config.py"
}
