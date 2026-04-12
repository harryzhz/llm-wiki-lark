SKILL_DIR := skills/llm-wiki-lark
OUTPUT_DIR := output
ZIP_FILE   := $(OUTPUT_DIR)/llm-wiki-lark.zip

.PHONY: pack clean

pack: clean
	@mkdir -p $(OUTPUT_DIR)
	@cd $(SKILL_DIR) && zip -r ../../$(ZIP_FILE) . -x '.*'
	@echo "Packed: $(ZIP_FILE)"

clean:
	@rm -f $(ZIP_FILE)
