#!/usr/bin/env bash
# security_check.sh — Pre-commit security gate
# Scans staged files for secrets, internal URLs, binary blobs, etc.
# Exit 0 = pass, Exit 1 = blocked (with diagnostic output).
#
# Usage:
#   scripts/security_check.sh          # check staged files (git hook mode)
#   scripts/security_check.sh --all    # check all tracked files

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

FAILURES=0
SELF="scripts/security_check.sh"

# ── Determine file list ──────────────────────────────────────────────
if [[ "${1:-}" == "--all" ]]; then
  FILES=$(git ls-files | grep -v "^${SELF}$")
else
  FILES=$(git diff --cached --name-only --diff-filter=ACMR | grep -v "^${SELF}$")
fi

if [[ -z "$FILES" ]]; then
  echo -e "${GREEN}No files to check.${NC}"
  exit 0
fi

fail() {
  echo -e "${RED}FAIL${NC} [$1] $2"
  FAILURES=$((FAILURES + 1))
}

pass() {
  echo -e "${GREEN}PASS${NC} [$1]"
}

# ── 1. Hardcoded secrets ─────────────────────────────────────────────
SECRET_PATTERNS=(
  'AKIA[0-9A-Z]{16}'                       # AWS access key
  'BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY'
  'ssh-rsa AAAA'
  'ghp_[A-Za-z0-9]{36}'                    # GitHub PAT
  'sk-[A-Za-z0-9]{20,}'                    # OpenAI-style key
)

SECRET_HIT=0
for pattern in "${SECRET_PATTERNS[@]}"; do
  if echo "$FILES" | xargs grep -lE "$pattern" 2>/dev/null | head -1 | grep -q .; then
    HITS=$(echo "$FILES" | xargs grep -lE "$pattern" 2>/dev/null)
    fail "hardcoded-secret" "pattern '$pattern' found in: $HITS"
    SECRET_HIT=1
  fi
done
if [[ $SECRET_HIT -eq 0 ]]; then
  pass "hardcoded-secret"
fi

# ── 2. Internal / intranet URLs ──────────────────────────────────────
INTERNAL_PATTERNS=(
  'https?://[a-z0-9._-]*\.bytedance\.(net|com|org)'
  'https?://[a-z0-9._-]*\.feishu\.cn'
  'https?://[a-z0-9._-]*\.larksuite\.com'
  'https?://[a-z0-9._-]*\.volces\.(com|cn)'
)

INTERNAL_HIT=0
for pattern in "${INTERNAL_PATTERNS[@]}"; do
  if echo "$FILES" | xargs grep -lEi "$pattern" 2>/dev/null | head -1 | grep -q .; then
    HITS=$(echo "$FILES" | xargs grep -lEi "$pattern" 2>/dev/null)
    fail "internal-url" "pattern '$pattern' found in: $HITS"
    INTERNAL_HIT=1
  fi
done
if [[ $INTERNAL_HIT -eq 0 ]]; then
  pass "internal-url"
fi

# ── 3. Sensitive file types ──────────────────────────────────────────
SENSITIVE_EXTS='\.env$|\.env\.|\.pem$|\.key$|\.p12$|\.pfx$|\.jks$|credentials'

SENSITIVE_FILES=$(echo "$FILES" | grep -Ei "$SENSITIVE_EXTS" || true)
if [[ -n "$SENSITIVE_FILES" ]]; then
  fail "sensitive-file" "sensitive files staged: $SENSITIVE_FILES"
else
  pass "sensitive-file"
fi

# ── 4. .gitignore coverage ──────────────────────────────────────────
GITIGNORE=".gitignore"
REQUIRED_IGNORES=('.env' '*.pem' '*.key')
IGNORE_HIT=0

if [[ -f "$GITIGNORE" ]]; then
  for entry in "${REQUIRED_IGNORES[@]}"; do
    if ! grep -qF "$entry" "$GITIGNORE"; then
      fail "gitignore" "missing required entry '$entry' in .gitignore"
      IGNORE_HIT=1
    fi
  done
fi
if [[ $IGNORE_HIT -eq 0 ]]; then
  pass "gitignore"
fi

# ── 5. Binary / media blobs ─────────────────────────────────────────
BINARY_HIT=0
while IFS= read -r f; do
  [[ -f "$f" ]] || continue
  mime=$(file --brief --mime-type "$f" 2>/dev/null || echo "unknown")
  case "$mime" in
    text/*|application/json|application/xml|inode/x-empty) ;;
    *)
      fail "binary-blob" "$f ($mime)"
      BINARY_HIT=1
      ;;
  esac
done <<< "$FILES"
if [[ $BINARY_HIT -eq 0 ]]; then
  pass "binary-blob"
fi

# ── 6. Real tokens in template files ────────────────────────────────
# Template/doc files should only contain <TOKEN>, <FOLDER_TOKEN> style placeholders,
# not real Feishu tokens (typically alphanumeric 20+ chars after known prefixes).
REAL_TOKEN_PATTERN='(folder_token|node_token|space_id|doc_id|file_token)["\x27: =]+[A-Za-z0-9]{20,}'
TEMPLATE_FILES=$(echo "$FILES" | grep -E '\.(md|sh)$' || true)

TEMPLATE_HIT=0
if [[ -n "$TEMPLATE_FILES" ]]; then
  if echo "$TEMPLATE_FILES" | xargs grep -lE "$REAL_TOKEN_PATTERN" 2>/dev/null | head -1 | grep -q .; then
    HITS=$(echo "$TEMPLATE_FILES" | xargs grep -lE "$REAL_TOKEN_PATTERN" 2>/dev/null)
    fail "real-token" "possible real token in template files: $HITS"
    TEMPLATE_HIT=1
  fi
fi
if [[ $TEMPLATE_HIT -eq 0 ]]; then
  pass "real-token"
fi

# ── Summary ──────────────────────────────────────────────────────────
echo ""
if [[ $FAILURES -gt 0 ]]; then
  echo -e "${RED}Security check failed: $FAILURES issue(s) found.${NC}"
  echo -e "${YELLOW}Fix the issues above or use 'git commit --no-verify' to bypass (not recommended).${NC}"
  exit 1
else
  echo -e "${GREEN}All security checks passed.${NC}"
  exit 0
fi
