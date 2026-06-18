# LLM Wiki on Lark

A Skill that builds and maintains a structured, LLM-driven knowledge base on Feishu (Lark) Drive or Wiki Space.

Inspired by Andrej Karpathy's [LLM Wiki](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) — the core insight is: instead of treating LLMs as stateless RAG pipelines that re-derive knowledge from scratch on every query, let the LLM **build and maintain a persistent, structured wiki** that compounds over time. The human curates sources and asks questions; the LLM does all the bookkeeping — summarizing, cross-referencing, consistency checking — that humans inevitably abandon. This project adapts that idea to run entirely on Feishu cloud documents (Drive or Wiki Space), using `lark-cli` as the execution layer.


## Architecture

Three-layer directory structure on Feishu Drive or Wiki Space:

```
<wiki-name>/
├── AGENTS.md              # Schema: structure conventions + LLM behavior rules
├── raw/                   # Raw materials (immutable, user-maintained)
│   ├── papers/            # Customizable at init
│   ├── articles/          # Default: papers, articles, repos,
│   ├── repos/             #          datasets, images, assets
│   ├── datasets/
│   ├── images/
│   └── assets/
└── wiki/                  # Knowledge layer (LLM-generated and maintained)
    ├── INDEX              # Page registry + navigation
    ├── LOG                # Append-only operation log
    ├── sources/           # Source document summaries
    ├── entities/          # Entity pages (people, orgs, tools...)
    ├── concepts/          # Concept pages (theories, patterns...)
    ├── comparisons/       # Comparative analysis
    └── overviews/         # Thematic overviews
```

## Five Operations

| Operation | What it does |
|-----------|-------------|
| **init** | Create the full directory tree + bootstrap AGENTS.md, INDEX, LOG |
| **import** | Archive raw materials (Feishu docs, local files, external URLs) into raw/ |
| **ingest** | Process a raw source into Source/Entity/Concept pages with cross-references |
| **query** | Search the wiki, synthesize an answer, archive valuable results back |
| **lint** | Health-check: find contradictions, orphans, duplicates, blank pages, broken links |

## Prerequisites

- [lark-cli](https://github.com/larksuite/cli) (`npm install -g @larksuite/cli`)
- lark-cli skills (`npx skills add larksuite/cli -y -g`)

## Installation

Any LLM agent that supports the Skill protocol can use this skill directly (Claude Code, OpenCode, Cursor, etc.). For agents without native Skill support, you can feed the SKILL.md and workflow files as context.

### Skill-compatible Agents

```bash
npx skills add harryzhz/llm-wiki-lark -y -g
```

### Other Agents

Copy the `skills/llm-wiki-lark/` directory into your agent's context. The key file is `SKILL.md` — it routes operations to the right workflow and keeps core constraints close at hand. The `references/` subdirectory provides schema definitions, templates, command references, and step-by-step workflow procedures.

## Usage

Use natural language to trigger operations:

```
# Initialize a new knowledge base
> llm wiki init

# Import raw materials
> 把这篇文档导入到知识库

# Ingest a source document
> 把这篇文章摄入到知识库

# Query the knowledge base
> 关于 Transformer 我们知道什么？

# Run health check
> 检查知识库健康
```

## Configuration

Per-wiki metadata is stored in `~/.llm_wiki.setting.json`:

```json
{
  "wikis": [
    {
      "wiki_name": "my-wiki",
      "storage_type": "drive",
      "root_token": "...",
      "index_doc_id": "...",
      "agents_doc_id": "...",
      "log_doc_id": "...",
      "created_at": "2026-04-09"
    }
  ]
}
```

Multiple wikis are supported. When more than one wiki exists, you'll be prompted to select which one to use.

## Skill Structure

```
skills/llm-wiki-lark/
├── SKILL.md                           # Entry point + workflow routing
└── references/
    ├── wiki-schema.md                 # Page types, metadata format, INDEX/LOG spec
    ├── adapter/
    │   ├── drive.md                   # Drive mode command reference
    │   └── wiki.md                    # Wiki space mode command reference
    ├── templates/
    │   ├── init.md                    # AGENTS.md, INDEX, LOG templates
    │   └── pages.md                   # Source/Entity/Concept/Comparison/Overview templates
    └── workflows/
        ├── init.md                    # Initialization procedure
        ├── import.md                  # Raw material import procedure
        ├── ingest.md                  # Source ingestion procedure
        ├── query.md                   # Query + archive procedure
        └── lint.md                    # Health check procedure
```

## Credits

- Original idea: [LLM Wiki](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) by Andrej Karpathy
- Execution layer: [lark-cli](https://github.com/larksuite/cli) by Larksuite

## License

MIT
