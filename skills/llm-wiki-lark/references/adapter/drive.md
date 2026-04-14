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
lark-cli docs +create --as user --title "<TITLE>" --folder-token <PARENT_TOKEN> --markdown "..."
```

- 返回值：`doc_id`

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

```bash
STORAGE_TYPE="drive" WIKI_NAME="<WIKI_NAME>" PARENT_TOKEN="<PARENT_TOKEN>" \
  RAW_SUBDIRS="<子目录列表空格分隔>" bash <skill_base_dir>/scripts/init.sh
```

其中 `<skill_base_dir>` 为 skill 所在目录。

## Token 类型

| INDEX 目录配置存储 | 创建文档时使用 |
|-------------------|--------------|
| `folder_token`（fldcn...） | `--folder-token <folder_token>` |

## 语义说明

- 文件夹（folder）是纯目录，无文档内容
- 创建文档返回 `doc_id`，用于后续 `docs +fetch/+update`
