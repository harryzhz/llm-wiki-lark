#!/bin/bash
# list_raw_tree.sh — 递归枚举 raw 引用节点的整棵子树，输出扁平 JSON
#
# 用于「reference 模式」：raw 层引用一棵已有节点树时，下游（ingest/import/lint）
# 用本脚本实时枚举原树，感知原树后续新增的子目录/文档，而非依赖 INDEX 静态快照。
#
# 用法 (全部走环境变量):
#   STORAGE_TYPE=wiki  SPACE_ID=<原树space_id> RAW_TOKEN=<原节点node_token> [MAX_DEPTH=8] bash list_raw_tree.sh
#   STORAGE_TYPE=drive RAW_TOKEN=<原文件夹folder_token>                      [MAX_DEPTH=8] bash list_raw_tree.sh
#
# 入参:
#   STORAGE_TYPE  drive | wiki（必填）
#   RAW_TOKEN     递归起点导航 token：wiki=原节点 node_token，drive=原文件夹 folder_token（必填）
#   SPACE_ID      原树所在知识空间 id（wiki 模式必填；务必是原树的 space_id，不是新 root 的）
#   MAX_DEPTH     最大递归深度，默认 8（防环/防超深）
#   ROOT_PATH     输出 path 的根前缀，默认 "raw"
#
# 输出 (stdout): JSON 对象
#   {"nodes":[{token,obj_token,type,title,path,is_container,depth}, ...],"errors":[...]}
#     - token:        导航 token（wiki=node_token / drive=file|folder token）
#     - obj_token:    可 fetch 的 doc id（wiki=obj_token / drive 非文件夹=token / 文件夹=空串）
#     - type:         节点类型（wiki=obj_type / drive=type，如 docx/sheet/bitable/file/folder）
#     - is_container: true=容器（可再递归），false=叶子
#     - path:         人类可读层级路径，根为 ROOT_PATH
#   当 lark-cli/API 失败时，errors 非空且脚本以非 0 退出；
#   下游必须据此区分「真的无子节点」与「调用失败」，不得把失败当作「无新增」。
#
# 依赖: jq, lark-cli（已认证）
# 兼容: bash 3.2+（macOS 默认）

set -uo pipefail

STORAGE_TYPE="${STORAGE_TYPE:?需要 STORAGE_TYPE（drive 或 wiki）}"
RAW_TOKEN="${RAW_TOKEN:?需要 RAW_TOKEN（递归起点导航 token）}"
SPACE_ID="${SPACE_ID:-}"
MAX_DEPTH="${MAX_DEPTH:-8}"
ROOT_PATH="${ROOT_PATH:-raw}"

ERROR_EXIT_CODE=1
ERROR_KIND_BAD_INPUT="bad_input"
ERROR_KIND_EXIT_NONZERO="cli_exit_nonzero"
ERROR_KIND_INVALID_JSON="cli_invalid_json"
ERROR_KIND_API_ERROR="api_error"
ERROR_KIND_MAX_DEPTH="max_depth_exceeded"

NODES="[]"
ERRORS="[]"
CHILDREN="[]"        # list_children 的输出（全局，walk 内立即拷贝为 local）
API_RESPONSE=""

append_error() {
  local context="$1" kind="$2" message="$3" response="$4"
  ERRORS=$(echo "$ERRORS" | jq \
    --arg context "$context" --arg kind "$kind" \
    --arg message "$message" --arg response "$response" \
    '. + [{"context": $context, "kind": $kind, "message": $message, "response": $response}]')
}

output_result() {
  jq -n --argjson nodes "$NODES" --argjson errors "$ERRORS" \
    '{"nodes": $nodes, "errors": $errors}'
}

if [[ "$STORAGE_TYPE" != "drive" && "$STORAGE_TYPE" != "wiki" ]]; then
  append_error "input" "$ERROR_KIND_BAD_INPUT" "STORAGE_TYPE 必须是 drive 或 wiki，当前: $STORAGE_TYPE" ""
  output_result
  exit "$ERROR_EXIT_CODE"
fi
if [[ "$STORAGE_TYPE" == "wiki" && -z "$SPACE_ID" ]]; then
  append_error "input" "$ERROR_KIND_BAD_INPUT" "wiki 模式需要 SPACE_ID（原树的 space_id）" ""
  output_result
  exit "$ERROR_EXIT_CODE"
fi

# 调用一次 lark-cli list；成功把响应放入全局 API_RESPONSE 返回 0，失败 append_error 返回 1
_call_list() {
  local params="$1" context="$2"
  local cmd_status
  # 基线未开 errexit（仅 set -uo pipefail），命令失败不会中断；显式捕获退出码
  if [[ "$STORAGE_TYPE" == "wiki" ]]; then
    API_RESPONSE=$(lark-cli wiki nodes list --as user --params "$params" 2>&1)
  else
    API_RESPONSE=$(lark-cli drive files list --as user --params "$params" 2>&1)
  fi
  cmd_status=$?

  if [ "$cmd_status" -ne 0 ]; then
    append_error "$context" "$ERROR_KIND_EXIT_NONZERO" "lark-cli 退出码 $cmd_status" "$API_RESPONSE"
    return 1
  fi
  if ! echo "$API_RESPONSE" | jq -e . >/dev/null 2>&1; then
    append_error "$context" "$ERROR_KIND_INVALID_JSON" "lark-cli 返回非 JSON" "$API_RESPONSE"
    return 1
  fi
  # CLI 错误包装: {"ok":false,"error":{...}}
  if echo "$API_RESPONSE" | jq -e '(.ok == false) or (.error != null)' >/dev/null 2>&1; then
    local emsg
    emsg=$(echo "$API_RESPONSE" | jq -r '.error.message // .error.msg // "unknown error"')
    append_error "$context" "$ERROR_KIND_API_ERROR" "$emsg" "$API_RESPONSE"
    return 1
  fi
  return 0
}

# 列出 parent 的全部直接子项（处理分页），结果归一化到全局 CHILDREN
# 归一化项: {nav, obj, type, title, is_container}
# 成功返回 0；任一页失败 append_error 返回 1
list_children() {
  local parent="$1" context="$2"
  CHILDREN="[]"
  local page_token="" params resp_items has_more next_token normalized

  while : ; do
    if [[ "$STORAGE_TYPE" == "wiki" ]]; then
      params=$(jq -n --arg s "$SPACE_ID" --arg p "$parent" --arg pt "$page_token" \
        'if $pt == "" then {space_id:$s, parent_node_token:$p}
         else {space_id:$s, parent_node_token:$p, page_token:$pt} end')
    else
      params=$(jq -n --arg f "$parent" --arg pt "$page_token" \
        'if $pt == "" then {folder_token:$f}
         else {folder_token:$f, page_token:$pt} end')
    fi

    if ! _call_list "$params" "$context"; then
      return 1
    fi

    if [[ "$STORAGE_TYPE" == "wiki" ]]; then
      # shortcut 节点不递归（避免跨树/成环）：is_container 仅在 origin 且 has_child 时为真
      normalized=$(echo "$API_RESPONSE" | jq '[.data.items[]? | {
        nav: .node_token,
        obj: (.obj_token // ""),
        type: (.obj_type // ""),
        title: (.title // ""),
        is_container: ((.has_child == true) and (.node_type != "shortcut"))
      }]')
      has_more=$(echo "$API_RESPONSE" | jq -r '.data.has_more // false')
      next_token=$(echo "$API_RESPONSE" | jq -r '.data.page_token // ""')
    else
      normalized=$(echo "$API_RESPONSE" | jq '[.data.files[]? | {
        nav: .token,
        obj: (if .type == "folder" then "" else .token end),
        type: (.type // ""),
        title: (.name // ""),
        is_container: (.type == "folder")
      }]')
      has_more=$(echo "$API_RESPONSE" | jq -r '.data.has_more // false')
      next_token=$(echo "$API_RESPONSE" | jq -r '.data.next_page_token // ""')
    fi

    CHILDREN=$(echo "$CHILDREN" | jq --argjson add "$normalized" '. + $add')

    if [ "$has_more" = "true" ] && [ -n "$next_token" ] && [ "$next_token" != "null" ]; then
      page_token="$next_token"
    else
      break
    fi
  done
  return 0
}

# 递归遍历；NODES/ERRORS 为全局累加
walk() {
  local parent="$1" path="$2" depth="$3"
  if [ "$depth" -gt "$MAX_DEPTH" ]; then
    append_error "$path" "$ERROR_KIND_MAX_DEPTH" "达到 MAX_DEPTH=$MAX_DEPTH，停止下探" ""
    return
  fi
  if ! list_children "$parent" "depth=$depth path=$path token=$parent"; then
    return
  fi

  local children_json count i
  children_json="$CHILDREN"     # 拷贝为 local，递归安全
  count=$(echo "$children_json" | jq 'length')
  i=0
  while [ "$i" -lt "$count" ]; do
    local nav obj ntype title is_container child_path
    nav=$(echo "$children_json" | jq -r ".[$i].nav")
    obj=$(echo "$children_json" | jq -r ".[$i].obj")
    ntype=$(echo "$children_json" | jq -r ".[$i].type")
    title=$(echo "$children_json" | jq -r ".[$i].title")
    is_container=$(echo "$children_json" | jq -r ".[$i].is_container")
    child_path="$path/$title"

    NODES=$(echo "$NODES" | jq \
      --arg t "$nav" --arg o "$obj" --arg ty "$ntype" --arg ti "$title" \
      --arg p "$child_path" --argjson ic "$is_container" --argjson d "$depth" \
      '. + [{"token":$t,"obj_token":$o,"type":$ty,"title":$ti,"path":$p,"is_container":$ic,"depth":$d}]')

    if [ "$is_container" = "true" ]; then
      walk "$nav" "$child_path" $((depth + 1))
    fi
    i=$((i + 1))
  done
}

walk "$RAW_TOKEN" "$ROOT_PATH" 1

output_result
if [ "$(echo "$ERRORS" | jq 'length')" -ne 0 ]; then
  exit "$ERROR_EXIT_CODE"
fi
