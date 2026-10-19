#!/usr/bin/env python3
"""Validate skill command contracts with the installed CLI; never write to Lark."""

import argparse
import base64
import json
import os
from pathlib import Path
import subprocess
import tempfile


MARKDOWN = "## 测试正文\n\n中文、引号 ' 与字面量 `code`、$()。\n"


def command_cases():
    doc = ["--doc", "test-doc"]
    markdown = ["--doc-format", "markdown"]
    parent = ["--parent-token", "test-parent"]
    update = ["docs", "+update", *doc]
    create = ["docs", "+create", "--title", "中文 & <v2>", *parent, *markdown]
    fetch = ["docs", "+fetch", *doc]
    wiki_params = json.dumps({"space_id": "123456789", "parent_node_token": "test-parent"})
    cases = [
        ("create-markdown", [*create, "--content", MARKDOWN]),
        ("create-title-only", [*create, "--content", ""]),
        ("create-stdin", [*create, "--content", "-"]),
        ("create-file", [*create, "--content", "@./content.md"]),
        ("create-xml", ["docs", "+create", *parent, "--doc-format", "xml", "--content", "<title>测试</title><p>正文</p>"]),
        ("fetch-markdown", [*fetch, *markdown]),
        ("fetch-block-ids", [*fetch, "--detail", "with-ids"]),
        ("fetch-outline", [*fetch, "--scope", "outline", "--max-depth", "3"]),
        ("fetch-section", [*fetch, "--scope", "section", "--start-block-id", "test-heading", "--detail", "with-ids"]),
        ("fetch-range", [*fetch, "--scope", "range", "--start-block-id", "test-first", "--end-block-id", "test-last"]),
        ("fetch-keyword", [*fetch, "--scope", "keyword", "--keyword", "测试|正文"]),
        ("append-stdin", [*update, "--command", "append", *markdown, "--content", "-"]),
        ("overwrite", [*update, "--command", "overwrite", *markdown, "--content", "# INDEX\n\n完整索引"]),
        ("replace-block", [*update, "--command", "block_replace", "--block-id", "test-block", *markdown, "--content", MARKDOWN]),
        ("replace-range", [*update, "--command", "block_replace", "--start-block-id", "test-first", "--end-block-id", "test-last", *markdown, "--content", MARKDOWN]),
        ("replace-inline", [*update, "--command", "str_replace", "--pattern", "旧文本", *markdown, "--content", "新文本"]),
        ("search", ["docs", "+search", "--query", "测试"]),
        ("media-image", ["docs", "+media-insert", *doc, "--file", "./pixel.png", "--caption", "测试图片"]),
        ("media-file", ["docs", "+media-insert", *doc, "--file", "./content.md", "--type", "file"]),
        ("drive-create-folder", ["drive", "files", "create_folder", "--data", json.dumps({"name": "测试目录", "folder_token": "test-parent"})]),
        ("drive-list", ["drive", "files", "list", "--params", json.dumps({"folder_token": "test-parent"})]),
        ("drive-shortcut", ["drive", "+create-shortcut", "--file-token", "test-doc", "--type", "docx", "--folder-token", "test-parent"]),
        ("drive-move", ["drive", "+move", "--file-token", "test-doc", "--type", "docx", "--folder-token", "test-parent"]),
        ("drive-upload", ["drive", "+upload", "--file", "./content.md", "--folder-token", "test-parent"]),
        ("drive-upload-root", ["drive", "+upload", "--file", "./content.md"]),
        ("drive-upload-wiki", ["drive", "+upload", "--file", "./content.md", "--wiki-token", "test-parent"]),
        ("drive-download", ["drive", "+download", "--file-token", "test-file", "--output", "./download.md"]),
        ("wiki-create-node", ["wiki", "nodes", "create", "--params", wiki_params, "--data", json.dumps({"parent_node_token": "test-parent", "obj_type": "docx", "node_type": "origin", "title": "测试目录"})]),
        ("wiki-list", ["wiki", "nodes", "list", "--params", wiki_params]),
        ("wiki-get-node", ["wiki", "spaces", "get_node", "--params", json.dumps({"token": "test-node"})]),
        ("wiki-shortcut", ["wiki", "nodes", "create", "--params", wiki_params, "--data", json.dumps({"parent_node_token": "test-parent", "node_type": "shortcut", "obj_type": "docx", "origin_node_token": "test-source-node"})]),
        ("drive-doc-to-wiki", ["wiki", "+move", "--obj-type", "docx", "--obj-token", "test-doc", "--target-space-id", "123456789", "--target-parent-token", "test-parent"]),
        ("wiki-move", ["api", "POST", "/open-apis/wiki/v2/spaces/123456789/nodes/test-node/move", "--data", json.dumps({"target_parent_token": "test-parent", "target_space_id": "123456789"})]),
        ("raw-metadata", ["api", "POST", "/open-apis/drive/v1/metas/batch_query", "--data", json.dumps({"request_docs": [{"doc_token": "test-doc", "doc_type": "docx"}]})]),
    ]
    rejected = [
        ("reject-create-v1", ["docs", "+create", "--title", "测试", "--folder-token", "test-parent", "--markdown", MARKDOWN]),
        ("reject-create-wiki-v1", ["docs", "+create", "--title", "测试", "--wiki-node", "test-parent", "--markdown", MARKDOWN]),
        ("reject-update-v1", [*update, "--mode", "append", "--markdown", MARKDOWN]),
        ("reject-range-v1", [*update, "--mode", "replace_range", "--selection-by-title", "## 测试", "--markdown", MARKDOWN]),
        ("reject-block-without-id", [*update, "--command", "block_replace", *markdown, "--content", MARKDOWN]),
    ]
    return [(name, args, True) for name, args in cases] + [(name, args, False) for name, args in rejected]


def validate_case(case, directory, environment):
    name, args, expected_success = case
    result = subprocess.run(
        ["lark-cli", *args, "--as", "user", "--dry-run"],
        input=MARKDOWN, text=True, capture_output=True, cwd=directory,
        env=environment, timeout=30,
    )
    response = json.loads(result.stdout or result.stderr)
    succeeded = result.returncode == 0 and response.get("ok") is True
    if expected_success:
        assert succeeded and response.get("dry_run") is True, response
        requests = response["data"].get("api", [response["data"]])
        if name in ("create-stdin", "create-file", "append-stdin"):
            assert MARKDOWN in requests[0]["body"]["content"], response
        if name.startswith("create-") and name != "create-xml":
            assert requests[0]["body"]["parent_token"] == "test-parent", response
            assert requests[0]["body"]["format"] == "markdown", response
        if name == "replace-range":
            assert requests[0]["body"]["command"] == "block_replace", response
        if name == "wiki-shortcut":
            assert requests[0]["body"]["origin_node_token"] == "test-source-node", response
    else:
        assert not succeeded, "obsolete or invalid arguments unexpectedly accepted"
        assert response.get("error", {}).get("type") == "validation", response
    return {"name": name, "passed": True, "expected_success": expected_success}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path)
    options = parser.parse_args()
    version = subprocess.check_output(["lark-cli", "--version"], text=True).strip()
    environment = {**os.environ, "LARKSUITE_CLI_NO_UPDATE_NOTIFIER": "1", "LARKSUITE_CLI_NO_SKILLS_NOTIFIER": "1"}
    results = []
    with tempfile.TemporaryDirectory() as directory:
        Path(directory, "content.md").write_text(MARKDOWN)
        Path(directory, "pixel.png").write_bytes(base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aXioAAAAASUVORK5CYII="))
        for case in command_cases():
            try:
                outcome = validate_case(case, directory, environment)
            except (AssertionError, ValueError, subprocess.TimeoutExpired) as error:
                outcome = {"name": case[0], "passed": False, "error": str(error)}
            results.append(outcome)
            print(("PASS" if outcome["passed"] else "FAIL"), outcome["name"], flush=True)
            if not outcome["passed"]:
                print(outcome["error"], flush=True)
    report = {"version": version, "cases": results}
    if options.report:
        options.report.parent.mkdir(parents=True, exist_ok=True)
        options.report.write_text(json.dumps(report, ensure_ascii=False, indent=2))
    failed = sum(not item["passed"] for item in results)
    print(f"{version}: {len(results) - failed}/{len(results)} passed")
    return bool(failed)


if __name__ == "__main__":
    raise SystemExit(main())
