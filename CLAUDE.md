# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

This repo is a **Claude Code Skill** (`llm-wiki-lark`) — not a traditional code project. It defines how to build and maintain an LLM-driven structured knowledge base on Lark (Feishu) Drive or Wiki Space. There is no source code to build, test, or lint in the traditional sense.

The skill is invoked via Claude Code's skill system (trigger: `llm wiki`, `知识库`, etc.) and orchestrates `lark-cli` commands to manage documents on Feishu cloud drive or wiki spaces.

## Architecture

**Three-layer knowledge base on Feishu Drive or Wiki Space:**

| Layer | Location | Owner | Purpose |
|-------|----------|-------|---------|
| Schema | `AGENTS.md` (root) | User + LLM co-evolve | Structure conventions, LLM behavior rules, domain preferences |
| Raw | `raw/` (custom subdirs) | User writes, LLM read-only | Immutable source materials; subdirs customizable at init (default: papers, articles, repos, datasets, images, assets) |
| Wiki | `wiki/` (5 subdirs + INDEX + LOG) | LLM maintains | Generated knowledge: sources, entities, concepts, comparisons, overviews |

**Storage modes:** `drive` (personal cloud drive folders) or `wiki` (Feishu wiki space nodes). Configured at init, stored in `storage_type` field.

**Five operations:** `init` (create directory tree + bootstrap docs), `import` (archive raw materials), `ingest` (process raw materials into wiki pages), `query` (search + synthesize answers, optionally archive back), `lint` (health check + fix).

## Key Files

- `skills/llm-wiki-lark/SKILL.md` — Skill entry point with frontmatter, prerequisites, operation overview, and lark-cli command reference
- `skills/llm-wiki-lark/references/wiki-schema.md` — Three-layer schema, page type specs, metadata callout format, INDEX/LOG format, cross-reference rules
- `skills/llm-wiki-lark/references/templates/init.md` — Init templates for AGENTS.md, INDEX, LOG
- `skills/llm-wiki-lark/references/templates/pages.md` — Runtime templates for Source, Entity/Concept/Comparison/Overview, and log entries
- `skills/llm-wiki-lark/references/adapter/drive.md` — Drive mode command reference
- `skills/llm-wiki-lark/references/adapter/wiki.md` — Wiki mode command reference
- `skills/llm-wiki-lark/references/workflows/` — Step-by-step procedures for all five operations (init/import/ingest/query/lint)

## Critical Conventions

- **All Feishu doc/file references must use `<mention-doc token="doc_id_or_file_token" type="docx">` — raw URLs are forbidden** for cloud drive documents
- **Callout blocks use list format** (`- ` prefix per field) — Feishu swallows blank lines inside callouts, causing field merging
- **Section headings must not be duplicated** within a page (e.g., two `## 相关实体` blocks)
- **INDEX updates via `replace_range --selection-by-title`** replace everything between that heading and the next same-level heading, so the replacement must include the heading itself plus all rows (existing + new)
- **Page creation order matters** — create pages sequentially so earlier doc_ids are available for later mention-doc references
- **Incremental updates preferred** — use `append` or `replace_range` over `overwrite` when possible

## Runtime Dependencies

- `lark-cli` (`npm install -g @larksuite/cli`) — all Feishu operations go through this
- `lark-cli` skills (`npx skills add larksuite/cli -y -g`) — provides `docs +create/+fetch/+update/+search`, `drive +download`, etc.
- Authentication: `lark-cli auth login` (interactive, user must run manually)

## Local State

Config file: `~/.llm_wiki.setting.json` — stores per-wiki metadata (storage_type, space_id, root token, INDEX/AGENTS/LOG doc_ids, URLs, raw_subdirs). Supports multiple wikis via `wikis` array.
