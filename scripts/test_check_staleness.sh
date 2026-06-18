#!/usr/bin/env bash
# Regression tests for skills/llm-wiki-lark/scripts/check_staleness.sh.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_UNDER_TEST="$ROOT_DIR/skills/llm-wiki-lark/scripts/check_staleness.sh"
TMP_DIR="$(mktemp -d)"
FAKE_BIN="$TMP_DIR/bin"

mkdir -p "$FAKE_BIN"
trap 'rm -rf "$TMP_DIR"' EXIT

cat > "$FAKE_BIN/lark-cli" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

payload="$*"

case "${LARK_FAKE_MODE:-}" in
  exit_nonzero)
    echo "auth expired" >&2
    exit 42
    ;;
  api_code_nonzero)
    echo '{"code":999,"msg":"rate limited"}'
    ;;
  missing)
    echo '{"code":0,"data":{"metas":[]}}'
    ;;
  fallback_file)
    if echo "$payload" | grep -q '"doc_type": "file"'; then
      echo '{"code":0,"data":{"metas":[{"doc_token":"raw1","latest_modify_time":"1700000000"}]}}'
    else
      echo '{"code":0,"data":{"metas":[]}}'
    fi
    ;;
  *)
    echo "unknown LARK_FAKE_MODE" >&2
    exit 2
    ;;
esac
SH
chmod +x "$FAKE_BIN/lark-cli"

assert_json_number() {
  local json="$1"
  local filter="$2"
  local expected="$3"
  local actual

  actual=$(echo "$json" | jq -r "$filter")
  if [ "$actual" != "$expected" ]; then
    echo "Expected $filter == $expected, got $actual" >&2
    echo "$json" >&2
    exit 1
  fi
}

run_staleness_case() {
  local mode="$1"
  local input="$2"
  local output
  local status

  set +e
  output=$(PATH="$FAKE_BIN:$PATH" LARK_FAKE_MODE="$mode" bash "$SCRIPT_UNDER_TEST" <<< "$input")
  status=$?
  set -e

  printf '%s\n%s\n' "$status" "$output"
}

INPUT_DOCX='[{"source_doc_id":"src1","source_title":"Source 1","raw_token":"raw1","raw_doc_type":"docx","recorded_update":"1970-01-01 00:00"}]'
INPUT_FILE='[{"source_doc_id":"src1","source_title":"Source 1","raw_token":"raw1","raw_doc_type":"file","recorded_update":"1970-01-01 00:00"}]'

case_output=$(run_staleness_case "exit_nonzero" "$INPUT_DOCX")
case_status=$(echo "$case_output" | sed -n '1p')
case_json=$(echo "$case_output" | sed '1d')
[ "$case_status" -ne 0 ] || { echo "exit_nonzero should fail" >&2; exit 1; }
assert_json_number "$case_json" '.errors | length' "1"
assert_json_number "$case_json" '.missing | length' "0"

case_output=$(run_staleness_case "api_code_nonzero" "$INPUT_DOCX")
case_status=$(echo "$case_output" | sed -n '1p')
case_json=$(echo "$case_output" | sed '1d')
[ "$case_status" -ne 0 ] || { echo "api_code_nonzero should fail" >&2; exit 1; }
assert_json_number "$case_json" '.errors | length' "1"
assert_json_number "$case_json" '.missing | length' "0"

case_output=$(run_staleness_case "missing" "$INPUT_FILE")
case_status=$(echo "$case_output" | sed -n '1p')
case_json=$(echo "$case_output" | sed '1d')
[ "$case_status" -eq 0 ] || { echo "missing should not fail" >&2; exit 1; }
assert_json_number "$case_json" '.errors | length' "0"
assert_json_number "$case_json" '.missing | length' "1"

case_output=$(run_staleness_case "fallback_file" "$INPUT_DOCX")
case_status=$(echo "$case_output" | sed -n '1p')
case_json=$(echo "$case_output" | sed '1d')
[ "$case_status" -eq 0 ] || { echo "fallback_file should not fail" >&2; exit 1; }
assert_json_number "$case_json" '.errors | length' "0"
assert_json_number "$case_json" '.missing | length' "0"
assert_json_number "$case_json" '.stale | length' "1"

echo "check_staleness tests passed"
