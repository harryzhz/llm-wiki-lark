#!/bin/bash
# init.sh — 统一知识库初始化脚本（支持 drive 和 wiki 两种模式）
#
# 用法：
#   STORAGE_TYPE="drive" WIKI_NAME="my-wiki" PARENT_TOKEN="fldcnXXX" \
#     RAW_SUBDIRS="papers articles repos" bash init.sh
#
#   STORAGE_TYPE="wiki" WIKI_NAME="my-wiki" SPACE_ID="7xxx" PARENT_TOKEN="xxx" \
#     RAW_SUBDIRS="papers articles repos" bash init.sh
#
# 必填环境变量：
#   STORAGE_TYPE  存储模式：drive 或 wiki
#   WIKI_NAME     知识库名称
#   PARENT_TOKEN  父目录 token（drive 为 folder_token，wiki 为 node_token）
#   SPACE_ID      飞书知识空间 ID（仅 wiki 模式必填）
#   RAW_SUBDIRS   空格分隔的 raw/ 子目录列表（仅 RAW_MODE=create 使用）
#
# 可选环境变量（raw 层装配模式）：
#   RAW_MODE              create（默认，自建 raw/ 子目录）| reference（引用现有节点树）| none（不建 raw 层）
#   RAW_SOURCE_TOKEN      reference 模式必填：原节点真实导航 token（wiki=node_token，drive=folder_token）
#   RAW_SOURCE_SPACE_ID   reference + wiki 模式必填：原树所在 space_id（可与新 root 不同 space）

set -e

: "${STORAGE_TYPE:?需要设置 STORAGE_TYPE（drive 或 wiki）}" \
  "${WIKI_NAME:?需要设置 WIKI_NAME}" \
  "${PARENT_TOKEN:?需要设置 PARENT_TOKEN}"
RAW_SUBDIRS="${RAW_SUBDIRS:-}"
RAW_MODE="${RAW_MODE:-create}"
RAW_SOURCE_TOKEN="${RAW_SOURCE_TOKEN:-}"
RAW_SOURCE_SPACE_ID="${RAW_SOURCE_SPACE_ID:-}"

case "$RAW_MODE" in
  create|reference|none) ;;
  *) echo "ERROR: RAW_MODE 必须是 create | reference | none，当前值: $RAW_MODE" >&2; exit 1 ;;
esac

if [[ "$RAW_MODE" == "reference" ]]; then
  : "${RAW_SOURCE_TOKEN:?reference 模式需要 RAW_SOURCE_TOKEN（原节点真实导航 token）}"
  if [[ "$STORAGE_TYPE" == "wiki" ]]; then
    : "${RAW_SOURCE_SPACE_ID:?reference + wiki 模式需要 RAW_SOURCE_SPACE_ID（原树的 space_id）}"
  fi
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

# ---------- 模式适配 ----------

if [[ "$STORAGE_TYPE" == "drive" ]]; then

  _create_dir() {
    local name="$1" parent="$2"
    local data
    data=$(jq -n --arg n "$name" --arg t "$parent" '{name:$n, folder_token:$t}')
    lark-cli drive files create_folder --as user --data "$data" \
      | jq -r '.data.token'
  }

  _create_doc() {
    # drive 模式：父节点为 folder_token，统一走 v2 --parent-token
    _create_doc_v2 "$1" "$2" "$3"
  }

elif [[ "$STORAGE_TYPE" == "wiki" ]]; then

  : "${SPACE_ID:?wiki 模式需要设置 SPACE_ID}"

  _create_dir() {
    local title="$1" parent="$2"
    local data
    data=$(jq -n --arg p "$parent" --arg t "$title" \
      '{parent_node_token:$p, obj_type:"docx", node_type:"origin", title:$t}')
    lark-cli wiki nodes create --as user \
      --params "{\"space_id\":\"$SPACE_ID\"}" --data "$data" \
      | jq -r '.data.node.node_token'
  }

  _create_doc() {
    # wiki 模式：父节点为 node_token，统一走 v2 --parent-token
    _create_doc_v2 "$1" "$2" "$3"
  }

else
  echo "ERROR: STORAGE_TYPE 必须是 drive 或 wiki，当前值: $STORAGE_TYPE" >&2
  exit 1
fi

# ---------- 执行初始化 ----------

run_init
