#!/usr/bin/env python3
"""
save_config.py — 将 init 结果写入 ~/.llm_wiki.setting.json 并输出 JSON 摘要

所有值从环境变量读取：
  WIKI_NAME, STORAGE_TYPE, SPACE_ID, TODAY
  ROOT_TOKEN, ROOT_URL
  INDEX_DOC_ID, INDEX_DOC_URL
  AGENTS_DOC_ID, AGENTS_DOC_URL
  LOG_DOC_ID, LOG_DOC_URL
  RAW_SUBDIRS（空格分隔）
"""

import json
import os
import shutil
import sys

CONFIG_PATH = os.path.expanduser("~/.llm_wiki.setting.json")

entry = {
    "wiki_name":    os.environ["WIKI_NAME"],
    "storage_type": os.environ["STORAGE_TYPE"],
    "space_id":     os.environ.get("SPACE_ID", ""),
    "root_token":   os.environ["ROOT_TOKEN"],
    "root_url":     os.environ.get("ROOT_URL", ""),
    "index_doc_id": os.environ["INDEX_DOC_ID"],
    "index_doc_url": os.environ.get("INDEX_DOC_URL", ""),
    "agents_doc_id": os.environ["AGENTS_DOC_ID"],
    "agents_doc_url": os.environ.get("AGENTS_DOC_URL", ""),
    "log_doc_id":   os.environ["LOG_DOC_ID"],
    "log_doc_url":  os.environ.get("LOG_DOC_URL", ""),
    "raw_subdirs":  os.environ.get("RAW_SUBDIRS", "").split(),
    "created_at":   os.environ["TODAY"],
}

cfg = {"wikis": []}

if os.path.exists(CONFIG_PATH):
    try:
        with open(CONFIG_PATH) as f:
            cfg = json.load(f)
        if not isinstance(cfg.get("wikis"), list):
            cfg["wikis"] = []
    except (json.JSONDecodeError, ValueError):
        backup = CONFIG_PATH + ".bak"
        shutil.copy2(CONFIG_PATH, backup)
        print(f"WARNING: 配置文件损坏，已备份到 {backup}，重新创建", file=sys.stderr)
        cfg = {"wikis": []}

cfg["wikis"] = [w for w in cfg["wikis"] if w.get("wiki_name") != entry["wiki_name"]]
cfg["wikis"].append(entry)

with open(CONFIG_PATH, "w") as f:
    json.dump(cfg, f, ensure_ascii=False, indent=2)

print(json.dumps(entry, ensure_ascii=False, indent=2))
