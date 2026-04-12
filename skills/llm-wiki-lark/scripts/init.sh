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
#   RAW_SUBDIRS   空格分隔的 raw/ 子目录列表

set -e

: "${STORAGE_TYPE:?需要设置 STORAGE_TYPE（drive 或 wiki）}" \
  "${WIKI_NAME:?需要设置 WIKI_NAME}" \
  "${PARENT_TOKEN:?需要设置 PARENT_TOKEN}"
RAW_SUBDIRS="${RAW_SUBDIRS:-}"

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
    local title="$1" parent_token="$2" markdown="$3"
    lark-cli docs +create --as user \
      --title "$title" --folder-token "$parent_token" --markdown "$markdown"
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
    local title="$1" parent_token="$2" markdown="$3"
    lark-cli docs +create --as user \
      --title "$title" --wiki-node "$parent_token" --markdown "$markdown"
  }

else
  echo "ERROR: STORAGE_TYPE 必须是 drive 或 wiki，当前值: $STORAGE_TYPE" >&2
  exit 1
fi

# ---------- 执行初始化 ----------

run_init
