# 云盘模式 (Drive) 命令参考

## 模式标识

- `storage_type`: `drive`
- 无需额外字段（无 space_id）
- 缺省行为：`~/.llm_wiki.setting.json` 中 `storage_type` 字段缺失时默认为 drive

## 创建文件夹

```
lark-cli drive files create_folder --as user --data '{"name":"<NAME>","folder_token":"<PARENT>"}'
```

- 返回值：`token`（即 folder_token），存入 INDEX 目录配置

## 创建文档

```
lark-cli docs +create --as user --parent-token <PARENT_TOKEN> --content '<title><TITLE></title>'
```

- 标题从内容自动提取：XML 用 `<title>…</title>`，Markdown 用首个 `# 一级标题`
- 父节点统一用 `--parent-token`，drive 模式传 `folder_token`
- 返回值在 `.data.document.document_id`（即 `doc_id`）与 `.data.document.url`
- 长文档分两步：先 `+create` 只写 `<title>` 骨架拿到 doc_id，正文再用 `docs +update --command append --doc-format markdown` 追加

## 列出子项

```
lark-cli drive files list --as user --params '{"folder_token":"<TOKEN>"}'
```

## 创建快捷方式

```
lark-cli drive +create-shortcut --as user \
  --file-token <SOURCE_DOC_ID> --type docx --folder-token <TARGET_TOKEN>
```

## 移动文档

```
lark-cli drive +move --as user --file-token <SOURCE_DOC_ID> --type docx --folder-token <TARGET_TOKEN>
```

## 上传文件

```
lark-cli drive +upload --as user --file <文件绝对路径> --folder-token <TARGET_TOKEN>
```

## 初始化脚本

create 模式（默认）：

```bash
STORAGE_TYPE="drive" WIKI_NAME="<WIKI_NAME>" PARENT_TOKEN="<PARENT_TOKEN>" \
  RAW_SUBDIRS="<子目录列表空格分隔>" bash <skill_base_dir>/scripts/init.sh
```

reference 模式（引用现有文件夹树为 raw 层）：

```bash
STORAGE_TYPE="drive" WIKI_NAME="<WIKI_NAME>" PARENT_TOKEN="<PARENT_TOKEN>" \
  RAW_MODE="reference" RAW_SOURCE_TOKEN="<原文件夹folder_token>" \
  bash <skill_base_dir>/scripts/init.sh
```

其中 `<skill_base_dir>` 为 skill 所在目录。drive 模式无 space 概念，reference 不需要 `RAW_SOURCE_SPACE_ID`。

## 递归枚举 raw 子树（reference 模式）

下游 ingest/import 用本脚本实时枚举被引用文件夹的整棵子树（感知后续新增）：

```bash
STORAGE_TYPE="drive" RAW_TOKEN="<原文件夹folder_token>" \
  bash <skill_base_dir>/scripts/list_raw_tree.sh
```

输出 `{nodes:[{token,obj_token,type,title,path,is_container,depth}],errors:[]}`；`type=="folder"` 为容器并递归，其余为叶子文档（`obj_token` 即可 fetch 的 token）。

## Token 类型

| INDEX 目录配置存储 | 创建文档时使用 |
|-------------------|--------------|
| `folder_token`（fldcn...） | `--parent-token <folder_token>` |

## 语义说明

- 文件夹（folder）是纯目录，无文档内容
- 创建文档返回 `doc_id`，用于后续 `docs +fetch/+update`
