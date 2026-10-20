#!/usr/bin/env python3
"""Exercise init against a v2-only CLI double, without touching Lark or user config."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


INIT_SCRIPT = Path(__file__).resolve().parents[1] / "skills/llm-wiki-lark/scripts/init.sh"

FAKE_CLI = r'''
import json
import os
from pathlib import Path
import sys

state_path = Path(os.environ["LARK_TEST_STATE"])
state = json.loads(state_path.read_text()) if state_path.exists() else {"dirs": [], "docs": [], "updates": []}
args = sys.argv[1:]

def option(name):
    return args[args.index(name) + 1]

def finish(response):
    state_path.write_text(json.dumps(state))
    print(json.dumps(response))

def fail():
    state_path.write_text(json.dumps(state))
    print("simulated CLI failure", file=sys.stderr)
    sys.exit(42)

if args[:2] == ["docs", "+create"]:
    allowed = {"--as", "--title", "--parent-token", "--content", "--doc-format"}
    assert set(args[2::2]) <= allowed, args
    assert option("--as") == "user"
    title = option("--title") if "--title" in args else option("--content")[7:-8]
    doc = {"id": "doc-" + title, "title": title, "parent": option("--parent-token"), "content": ""}
    state["docs"].append(doc)
    if os.environ.get("LARK_TEST_FAILURE") == "create-" + title:
        fail()
    document_id = doc["id"]
    if os.environ.get("LARK_TEST_FAILURE") == "missing-id":
        document_id = None
    if os.environ.get("LARK_TEST_FAILURE") == "invalid-id":
        document_id = 123
    finish({"ok": True, "data": {"document": {"document_id": document_id, "url": "test:doc/" + doc["id"]}}})
elif args[:2] == ["docs", "+update"]:
    assert set(args[2::2]) == {"--as", "--doc", "--command", "--doc-format", "--content"}, args
    assert option("--as") == "user"
    assert option("--command") == "append"
    assert option("--doc-format") == "markdown"
    doc = next(doc for doc in state["docs"] if doc["id"] == option("--doc"))
    content = sys.stdin.read() if option("--content") == "-" else option("--content")
    state["updates"].append({"doc": doc["id"], "content": content})
    if os.environ.get("LARK_TEST_FAILURE") == "append-" + doc["title"]:
        fail()
    doc["content"] += content
    finish({"ok": True, "data": {"result": "success"}})
elif args[:3] == ["drive", "files", "create_folder"] or args[:3] == ["wiki", "nodes", "create"]:
    data = json.loads(option("--data"))
    is_drive = args[0] == "drive"
    assert os.environ["STORAGE_TYPE"] == ("drive" if is_drive else "wiki")
    if not is_drive:
        assert json.loads(option("--params"))["space_id"] == os.environ["SPACE_ID"]
        assert data["obj_type"] == "docx" and data["node_type"] == "origin"
    title = data["name"] if is_drive else data["title"]
    parent = data["folder_token"] if is_drive else data["parent_node_token"]
    token = ("folder-" if is_drive else "node-") + str(len(state["dirs"]) + 1)
    state["dirs"].append({"title": title, "parent": parent, "token": token})
    finish({"data": {"token": token}} if is_drive else {"data": {"node": {"node_token": token}}})
else:
    raise AssertionError(args)
'''

CONFIG_WRAPPER = '''
import os
import runpy
import sys
from unittest.mock import patch

assert sys.argv[1].endswith("/save_config.py"), sys.argv
with patch("os.path.expanduser", return_value=os.environ["LARK_TEST_CONFIG"]):
    runpy.run_path(sys.argv[1], run_name="__main__")
'''


class InitV2Tests(unittest.TestCase):
    def run_init(self, storage_type="drive", raw_mode="create", failure=""):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        directory = Path(temporary.name)
        bin_dir = directory / "bin"
        bin_dir.mkdir()
        for name, source in (("lark-cli", FAKE_CLI), ("python3", CONFIG_WRAPPER)):
            executable = bin_dir / name
            executable.write_text(f"#!{sys.executable}\n" + source)
            executable.chmod(0o755)
        config = directory / "config.json"
        state_file = directory / "state.json"
        environment = {
            **os.environ,
            "PATH": str(bin_dir) + os.pathsep + os.environ["PATH"],
            "STORAGE_TYPE": storage_type,
            "WIKI_NAME": "知识库 & <测试>",
            "PARENT_TOKEN": "test-parent",
            "SPACE_ID": "test-space" if storage_type == "wiki" else "",
            "RAW_MODE": raw_mode,
            "RAW_SUBDIRS": "papers articles" if raw_mode == "create" else "",
            "RAW_SOURCE_TOKEN": "test-raw" if raw_mode == "reference" else "",
            "RAW_SOURCE_SPACE_ID": "test-raw-space" if raw_mode == "reference" and storage_type == "wiki" else "",
            "LARK_TEST_STATE": str(state_file),
            "LARK_TEST_CONFIG": str(config),
            "LARK_TEST_FAILURE": failure,
        }
        result = subprocess.run(["bash", str(INIT_SCRIPT)], env=environment, text=True, capture_output=True)
        return result, json.loads(state_file.read_text()), config

    def test_init_creates_documents_and_saves_v2_ids(self):
        for storage in ("drive", "wiki"):
            for raw_mode in ("create", "reference", "none"):
                with self.subTest(storage=storage, raw_mode=raw_mode):
                    result, state, config_path = self.run_init(storage, raw_mode)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    config = json.loads(config_path.read_text())["wikis"][0]
                    docs = {doc["title"]: doc for doc in state["docs"]}
                    root = state["dirs"][0]
                    wiki = next(item for item in state["dirs"] if item["title"] == "wiki")
                    self.assertEqual(root["title"], "知识库 & <测试>")
                    self.assertEqual(root["parent"], "test-parent")
                    self.assertEqual(docs["AGENTS"]["parent"], root["token"])
                    for title in ("INDEX", "LOG"):
                        self.assertEqual(docs[title]["parent"], wiki["token"])
                    for title in ("AGENTS", "INDEX", "LOG"):
                        self.assertEqual(config[title.lower() + "_doc_id"], docs[title]["id"])
                        self.assertEqual(config[title.lower() + "_doc_url"], "test:doc/" + docs[title]["id"])
                        self.assertTrue(docs[title]["content"].strip())
                    self.assertIn("## 页面类型", docs["AGENTS"]["content"])
                    agents = docs["AGENTS"]["content"]
                    self.assertIn('`<cite type="doc" doc-id="<DOC_ID>"></cite>`', agents)
                    self.assertIn('`<source token="<FILE_TOKEN>" name="<FILENAME>"></source>`', agents)
                    self.assertNotIn("<mention-doc", agents)
                    self.assertEqual(agents.count("## 引用规范"), 1)
                    self.assertIn("## 页面注册表", docs["INDEX"]["content"])
                    self.assertIn("doc-AGENTS", docs["INDEX"]["content"])
                    self.assertIn("doc-LOG", docs["INDEX"]["content"])
                    self.assertIn(" INIT", docs["LOG"]["content"])
                    self.assertEqual(config["storage_type"], storage)
                    self.assertEqual(config["raw_mode"], raw_mode)
                    self.assertEqual(len(state["dirs"]), 10 if raw_mode == "create" else 7)
                    if raw_mode == "reference":
                        self.assertIn("| raw | test-raw |", docs["INDEX"]["content"])
                    if raw_mode == "none":
                        self.assertIn("| raw | - |", docs["INDEX"]["content"])

    def test_cli_failures_stop_before_saving_config(self):
        for storage in ("drive", "wiki"):
            for operation in ("create-AGENTS", "create-INDEX", "create-LOG", "append-AGENTS", "append-INDEX", "append-LOG"):
                with self.subTest(storage=storage, operation=operation):
                    result, state, config_path = self.run_init(storage, failure=operation)
                    self.assertNotEqual(result.returncode, 0, result.stdout)
                    self.assertIn("simulated CLI failure", result.stderr)
                    self.assertNotIn("初始化完成", result.stdout)
                    self.assertFalse(config_path.exists())
                    self.assertEqual(state["docs"][-1]["title"], operation.split("-")[1] if operation != "append-INDEX" else "LOG")

    def test_missing_or_invalid_document_id_stops_init(self):
        for failure in ("missing-id", "invalid-id"):
            with self.subTest(failure=failure):
                result, state, config_path = self.run_init(failure=failure)
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertEqual(len(state["docs"]), 1)
                self.assertEqual(state["updates"], [])
                self.assertFalse(config_path.exists())


if __name__ == "__main__":
    unittest.main()
