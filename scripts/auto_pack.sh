#!/usr/bin/env bash
# 自动将 skills/llm-wiki-lark/ 打包为 output/llm-wiki-lark.zip（覆盖式）。
# 由 git pre-commit hook 在 skill 内容变更时调用，也可手动执行。
# 用法:
#   bash scripts/auto_pack.sh           # 直接打包
#   bash scripts/auto_pack.sh --force   # 同上（兼容形式）

set -e

cd "${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"

if ! command -v skill-pack >/dev/null 2>&1; then
  echo "[auto_pack] skill-pack CLI 未安装，跳过打包" >&2
  exit 0
fi

skill-pack skills/llm-wiki-lark -o output/llm-wiki-lark.zip -f
