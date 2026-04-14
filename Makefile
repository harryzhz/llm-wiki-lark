SKILL_DIR := skills/llm-wiki-lark
OUTPUT_DIR := output
ZIP_FILE   := $(OUTPUT_DIR)/llm-wiki-lark.zip

.PHONY: pack clean install-hooks security-check

# Patterns to exclude from the skill zip
# NOTE: zip requires '*/' suffix to match directories recursively
ZIP_EXCLUDES := \
	'.*'                   \
	'*/__pycache__/*'      \
	'*/__pycache__'        \
	'*.pyc'                \
	'*.pyo'                \
	'*/node_modules/*'     \
	'*/node_modules'       \
	'*/*.egg-info/*'       \
	'*/*.egg-info'         \
	'*.log'                \
	'*.tmp'                \
	'*.bak'                \
	'*.orig'               \
	'*.swp'                \
	'*.swo'                \
	'.DS_Store'            \
	'Thumbs.db'

pack: clean
	@mkdir -p $(OUTPUT_DIR)
	@cd $(SKILL_DIR) && zip -r ../../$(ZIP_FILE) . $(addprefix -x ,$(ZIP_EXCLUDES))
	@echo "Packed: $(ZIP_FILE)"

clean:
	@rm -f $(ZIP_FILE)

install-hooks:
	@chmod +x scripts/security_check.sh
	@echo '#!/usr/bin/env bash' > .git/hooks/pre-commit
	@echo 'exec "$(git rev-parse --show-toplevel)/scripts/security_check.sh"' >> .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
	@echo "pre-commit hook installed."

security-check:
	@bash scripts/security_check.sh --all
