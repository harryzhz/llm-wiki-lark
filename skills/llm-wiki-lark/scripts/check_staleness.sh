#!/bin/bash
# check_staleness.sh — 检查 raw 文档是否在 Source 页最后更新后被修改
#
# 用法: echo '<JSON_ARRAY>' | bash check_staleness.sh
#
# 输入 (stdin): JSON 数组
#   [{"source_doc_id":"...","source_title":"...","raw_token":"...","raw_doc_type":"docx","recorded_update":"2025-03-15 14:30"}]
#
# 输出 (stdout): JSON 对象
#   {"stale":[...],"missing":[...],"fresh":[...]}
#
# 依赖: jq, lark-cli (已认证)
# 兼容: bash 3.2+（macOS 默认）

set -euo pipefail

BATCH_SIZE=50
TOLERANCE_SECONDS=300  # 5 分钟容忍度

# ---------- 工具函数 ----------

unix_to_datetime() {
  local ts="$1"
  if date -r 0 "+%Y" >/dev/null 2>&1; then
    date -r "$ts" "+%Y-%m-%d %H:%M"
  else
    date -d "@$ts" "+%Y-%m-%d %H:%M"
  fi
}

datetime_to_unix() {
  local dt="$1"
  if date -j -f "%Y-%m-%d %H:%M" "$dt" "+%s" >/dev/null 2>&1; then
    date -j -f "%Y-%m-%d %H:%M" "$dt" "+%s"
  else
    date -d "$dt" "+%s"
  fi
}

normalize_timestamp() {
  local ts="$1"
  if echo "$ts" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
    echo "${ts} 23:59"
  else
    echo "$ts"
  fi
}

# ---------- 主逻辑 ----------

INPUT=$(cat)

if [ -z "$INPUT" ] || [ "$INPUT" = "[]" ] || [ "$INPUT" = "null" ]; then
  echo '{"stale":[],"missing":[],"fresh":[]}'
  exit 0
fi

ENTRY_COUNT=$(echo "$INPUT" | jq 'length')
if [ "$ENTRY_COUNT" -eq 0 ]; then
  echo '{"stale":[],"missing":[],"fresh":[]}'
  exit 0
fi

# 提取去重的 (raw_token, raw_doc_type) 对
UNIQUE_TOKENS=$(echo "$INPUT" | jq '[.[] | {raw_token, raw_doc_type}] | unique')
TOKEN_COUNT=$(echo "$UNIQUE_TOKENS" | jq 'length')

# 使用 JSON 对象作为 token → modified_time 的映射（兼容 bash 3.2）
MODIFIED_MAP='{}'

batch_start=0
while [ "$batch_start" -lt "$TOKEN_COUNT" ]; do
  batch_end=$((batch_start + BATCH_SIZE))
  if [ "$batch_end" -gt "$TOKEN_COUNT" ]; then
    batch_end=$TOKEN_COUNT
  fi

  # 构造 batch_query 请求体
  REQUEST_DOCS=$(echo "$UNIQUE_TOKENS" | jq --argjson start "$batch_start" --argjson end "$batch_end" \
    '[.[$start:$end][] | {"doc_token": .raw_token, "doc_type": .raw_doc_type}]')

  REQUEST_BODY=$(jq -n --argjson docs "$REQUEST_DOCS" '{"request_docs": $docs}')

  # 调用 Lark API
  RESPONSE=$(lark-cli api --as user POST /open-apis/drive/v1/metas/batch_query \
    --data "$REQUEST_BODY" 2>/dev/null || echo '{}')

  # 解析响应，将每个 doc 的 modified_time 写入映射
  # 响应格式: {"code":0,"data":{"metas":[{"doc_token":"...","latest_modify_time":"unix_ts_string",...}]}}
  METAS=$(echo "$RESPONSE" | jq -r '.data.metas // []')
  META_COUNT=$(echo "$METAS" | jq 'length')

  idx=0
  while [ "$idx" -lt "$META_COUNT" ]; do
    token=$(echo "$METAS" | jq -r ".[$idx].doc_token")
    modified_time=$(echo "$METAS" | jq -r ".[$idx].latest_modify_time // .[$idx].edit_time // \"0\"")
    if [ "$modified_time" != "0" ] && [ "$modified_time" != "null" ]; then
      MODIFIED_MAP=$(echo "$MODIFIED_MAP" | jq --arg k "$token" --arg v "$modified_time" '. + {($k): $v}')
    fi
    idx=$((idx + 1))
  done

  # 对未找到的 token，尝试用 file 类型重试
  retry_idx=$batch_start
  while [ "$retry_idx" -lt "$batch_end" ]; do
    token=$(echo "$UNIQUE_TOKENS" | jq -r ".[$retry_idx].raw_token")
    doc_type=$(echo "$UNIQUE_TOKENS" | jq -r ".[$retry_idx].raw_doc_type")
    existing=$(echo "$MODIFIED_MAP" | jq -r --arg k "$token" '.[$k] // ""')
    if [ -z "$existing" ] && [ "$doc_type" = "docx" ]; then
      RETRY_BODY=$(jq -n --arg t "$token" '{"request_docs": [{"doc_token": $t, "doc_type": "file"}]}')
      RETRY_RESP=$(lark-cli api --as user POST /open-apis/drive/v1/metas/batch_query \
        --data "$RETRY_BODY" 2>/dev/null || echo '{}')
      retry_time=$(echo "$RETRY_RESP" | jq -r '.data.metas[0].latest_modify_time // .data.metas[0].edit_time // "0"')
      if [ "$retry_time" != "0" ] && [ "$retry_time" != "null" ]; then
        MODIFIED_MAP=$(echo "$MODIFIED_MAP" | jq --arg k "$token" --arg v "$retry_time" '. + {($k): $v}')
      fi
    fi
    retry_idx=$((retry_idx + 1))
  done

  batch_start=$batch_end
done

# 逐条比较，生成结果
STALE="[]"
MISSING="[]"
FRESH="[]"

idx=0
while [ "$idx" -lt "$ENTRY_COUNT" ]; do
  source_doc_id=$(echo "$INPUT" | jq -r ".[$idx].source_doc_id")
  source_title=$(echo "$INPUT" | jq -r ".[$idx].source_title")
  raw_token=$(echo "$INPUT" | jq -r ".[$idx].raw_token")
  recorded_update=$(echo "$INPUT" | jq -r ".[$idx].recorded_update")

  raw_modified_unix=$(echo "$MODIFIED_MAP" | jq -r --arg k "$raw_token" '.[$k] // ""')

  if [ -z "$raw_modified_unix" ]; then
    MISSING=$(echo "$MISSING" | jq --arg title "$source_title" --arg token "$raw_token" \
      '. + [{"source_title": $title, "raw_token": $token, "error": "not found"}]')
    idx=$((idx + 1))
    continue
  fi

  raw_modified_dt=$(unix_to_datetime "$raw_modified_unix")
  normalized_recorded=$(normalize_timestamp "$recorded_update")
  recorded_unix=$(datetime_to_unix "$normalized_recorded")

  delta=$((raw_modified_unix - recorded_unix))

  if [ "$delta" -gt "$TOLERANCE_SECONDS" ]; then
    delta_hours=$((delta / 3600))
    STALE=$(echo "$STALE" | jq \
      --arg title "$source_title" \
      --arg doc_id "$source_doc_id" \
      --arg token "$raw_token" \
      --arg recorded "$recorded_update" \
      --arg modified "$raw_modified_dt" \
      --argjson hours "$delta_hours" \
      '. + [{"source_title": $title, "source_doc_id": $doc_id, "raw_token": $token, "recorded_update": $recorded, "raw_modified": $modified, "delta_hours": $hours}]')
  else
    FRESH=$(echo "$FRESH" | jq \
      --arg title "$source_title" \
      --arg doc_id "$source_doc_id" \
      --arg recorded "$recorded_update" \
      --arg modified "$raw_modified_dt" \
      '. + [{"source_title": $title, "source_doc_id": $doc_id, "recorded_update": $recorded, "raw_modified": $modified}]')
  fi

  idx=$((idx + 1))
done

# 输出最终结果
jq -n --argjson stale "$STALE" --argjson missing "$MISSING" --argjson fresh "$FRESH" \
  '{"stale": $stale, "missing": $missing, "fresh": $fresh}'
