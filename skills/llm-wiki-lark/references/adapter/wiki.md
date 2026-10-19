# 知识库模式 (Wiki) 命令参考

## 模式标识

- `storage_type`: `wiki`
- 需额外提供 `space_id`（从 `~/.llm_wiki.setting.json` 读取）

## 创建文件夹

```
lark-cli wiki nodes create --as user \
  --params '{"space_id":"<SPACE_ID>"}' \
  --data '{"parent_node_token":"<PARENT>","obj_type":"docx","node_type":"origin","title":"<NAME>"}'
```

- 返回值：`node.node_token` + `node.obj_token`，INDEX 存 `node_token`

## 创建文档

```
lark-cli docs +create --as user --title "<TITLE>" --parent-token <PARENT_NODE_TOKEN> \
  --content "<MARKDOWN>" --doc-format markdown
```

- `--title` 显式指定标题；正文通过 `--content` 传入，Markdown 必须加 `--doc-format markdown`
- 父节点统一用 `--parent-token`，wiki 模式传 `node_token`
- 返回值在 `.data.document.document_id`（即 `doc_id` / `obj_token`）与 `.data.document.url`，同时自动创建对应的 wiki 节点
- 长文档分两步：先按上例传 `--content ""` 创建标题骨架拿到 doc_id，再用 `lark-cli docs +update --as user --doc <DOC_ID> --command append --doc-format markdown --content -` 从 stdin 分段追加正文

## 列出子项

```
lark-cli wiki nodes list --as user --params '{"space_id":"<SPACE_ID>","parent_node_token":"<NODE_TOKEN>"}'
```

## 创建快捷方式

```
lark-cli wiki nodes create --as user \
  --params '{"space_id":"<SPACE_ID>"}' \
  --data '{"parent_node_token":"<TARGET_TOKEN>","node_type":"shortcut","obj_type":"docx","origin_node_token":"<SOURCE_NODE_TOKEN>"}'
```

> `origin_node_token` 必须传源 Wiki 节点的 `node_token`。如果只有 doc_id，先用 `lark-cli wiki +node-get --as user --node-token <SOURCE_DOC_ID>` 获取 `data.node_token`。原文档保留在原位置，后续 `docs +fetch` 使用原始 doc_id 即可。
>
> 尚未挂载到 Wiki 的 Drive 文档没有源 Wiki 节点，不能直接使用此命令创建快捷方式；请用户选择改存 Drive 快捷方式，或确认将原文档移入 Wiki，不自动改为移动。

## 移动节点

```
lark-cli api --as user POST /open-apis/wiki/v2/spaces/<SPACE_ID>/nodes/<SOURCE_NODE_TOKEN>/move \
  --data '{"target_parent_token":"<TARGET_TOKEN>","target_space_id":"<SPACE_ID>"}'
```

> 路径参数是 `node_token`，不是 doc_id。若源是 Drive 文档，用户已选择直接移动时使用：
>
> `lark-cli wiki +move --as user --obj-type docx --obj-token <SOURCE_DOC_ID> --target-space-id <SPACE_ID> --target-parent-token <TARGET_TOKEN>`

## 上传文件

直接上传到目标 Wiki 节点：

```
lark-cli drive +upload --as user --file ./<文件名> --wiki-token <TARGET_TOKEN>
```

- `--wiki-token` 传目标 `node_token`，返回 `.data.file_token`

## 初始化脚本

create 模式（默认）：

```bash
STORAGE_TYPE="wiki" WIKI_NAME="<WIKI_NAME>" SPACE_ID="<SPACE_ID>" PARENT_TOKEN="<PARENT_TOKEN>" \
  RAW_SUBDIRS="<子目录列表空格分隔>" bash <skill_base_dir>/scripts/init.sh
```

reference 模式（引用现有节点树为 raw 层）：

```bash
STORAGE_TYPE="wiki" WIKI_NAME="<WIKI_NAME>" SPACE_ID="<SPACE_ID>" PARENT_TOKEN="<PARENT_TOKEN>" \
  RAW_MODE="reference" RAW_SOURCE_TOKEN="<原节点node_token>" \
  RAW_SOURCE_SPACE_ID="<原树space_id>" bash <skill_base_dir>/scripts/init.sh
```

其中 `<skill_base_dir>` 为 skill 所在目录。
> `RAW_SOURCE_TOKEN` 用原节点的 **node_token**（树导航 token），不是 obj_token，也不要建快捷方式当 raw。
> `RAW_SOURCE_SPACE_ID` 是**原树所在 space**，可能与新 root 的 `SPACE_ID` 不同；下游枚举必须用原树的 space_id。

## 递归枚举 raw 子树（reference 模式）

下游 ingest/import 用本脚本实时枚举被引用节点的整棵子树（感知后续新增）：

```bash
STORAGE_TYPE="wiki" SPACE_ID="<原树space_id>" RAW_TOKEN="<原节点node_token>" \
  bash <skill_base_dir>/scripts/list_raw_tree.sh
```

输出 `{nodes:[{token,obj_token,type,title,path,is_container,depth}],errors:[]}`；用返回项的 `has_child` 判定容器并递归（脚本已内置），叶子的 `obj_token` 即可 fetch 的 doc_id。**SPACE_ID 必须是原树的 space_id（INDEX 里的 `raw_source_space_id`）**。

## 不支持的操作

- `drive +move` 不适用于知识库节点
- `drive +upload --folder-token` 不适用于知识库节点
- 以上操作须使用本文档中的替代方案

## Token 类型

| INDEX 目录配置存储 | 创建文档时使用 |
|-------------------|--------------|
| `node_token`（wikcn...） | `--parent-token <node_token>` |

## 语义说明

- 文件夹是 **docx 节点**，拥有 `node_token`（树导航用）和 `obj_token`（即 doc_id，可 fetch/update）
- 作为文件夹使用时，其文档内容通常为空
- 创建文档返回 `doc_id`（即 `obj_token`），同时自动创建对应的 wiki 节点
