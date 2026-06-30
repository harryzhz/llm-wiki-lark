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
lark-cli docs +create --as user --parent-token <PARENT_NODE_TOKEN> --content '<title><TITLE></title>'
```

- 标题从内容自动提取：XML 用 `<title>…</title>`，Markdown 用首个 `# 一级标题`
- 父节点统一用 `--parent-token`，wiki 模式传 `node_token`
- 返回值在 `.data.document.document_id`（即 `doc_id` / `obj_token`）与 `.data.document.url`，同时自动创建对应的 wiki 节点
- 长文档分两步：先 `+create` 只写 `<title>` 骨架拿到 doc_id，正文再用 `docs +update --command append --doc-format markdown` 追加

## 列出子项

```
lark-cli wiki nodes list --as user --params '{"space_id":"<SPACE_ID>","parent_node_token":"<NODE_TOKEN>"}'
```

## 创建快捷方式

```
lark-cli wiki nodes create --as user \
  --params '{"space_id":"<SPACE_ID>"}' \
  --data '{"parent_node_token":"<TARGET_TOKEN>","node_type":"shortcut","obj_type":"docx","obj_token":"<SOURCE_DOC_ID>"}'
```

> 原文档保留在原位置，wiki 树中可见引用。后续 `docs +fetch` 使用原始 doc_id 即可。

## 移动节点

```
lark-cli api --as user POST /open-apis/wiki/v2/spaces/<SPACE_ID>/nodes/<SOURCE_NODE_TOKEN>/move \
  --data '{"target_parent_token":"<TARGET_TOKEN>","target_space_id":"<SPACE_ID>"}'
```

> 路径参数是 `node_token`，不是 doc_id。若源是云盘文档（非知识库节点），需改走快捷方式或提示用户先将文档移入知识库。

## 上传文件

两步操作：

1. 上传到个人云盘根目录，获取 FILE_TOKEN：
   ```
   lark-cli drive +upload --as user --file <文件绝对路径>
   ```

2. 在 wiki 中创建快捷方式指向上传的文件：
   ```
   lark-cli wiki nodes create --as user \
     --params '{"space_id":"<SPACE_ID>"}' \
     --data '{"parent_node_token":"<TARGET_TOKEN>","node_type":"shortcut","obj_type":"file","obj_token":"<FILE_TOKEN>"}'
   ```

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
