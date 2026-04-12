SKILL_DIR := skills/llm-wiki-lark
OUTPUT_DIR := output
ZIP_FILE   := $(OUTPUT_DIR)/llm-wiki-lark.zip

.PHONY: pack clean install-hooks security-check

pack: clean
	@mkdir -p $(OUTPUT_DIR)
	@cd $(SKILL_DIR) && zip -r ../../$(ZIP_FILE) . -x '.*'
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
