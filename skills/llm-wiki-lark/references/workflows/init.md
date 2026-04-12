# Init — 初始化知识库

## 前置条件

- `lark-cli` 已配置认证
- 询问用户知识库名称（默认 `my-wiki`），用户可自定义

## 步骤

### 1. 确定存储模式和根文件夹

询问用户存储模式：

**云盘模式**（默认）：
- 用户可选提供一个父目录的 `folder_token`，否则在个人空间根目录下创建
- 如果用户未指定：`lark-cli drive files list --as user`，从返回的任意文件中取 `parent_token` → 即个人空间根目录 token
- 记录 PARENT_TOKEN、STORAGE_TYPE = `drive`

**知识库模式**：
- 用户提供知识库节点 URL 或 `space_id` + `parent_node_token`
- 若用户提供 wiki URL（含 `/wiki/`），提取 token 后查询节点信息：
  ```
  lark-cli wiki spaces get_node --as user --params '{"token":"<WIKI_TOKEN>"}'
  ```
  从返回结果中获取 `space_id` 和 `node_token`
- 验证节点可访问后，记录 SPACE_ID、PARENT_TOKEN = node_token、STORAGE_TYPE = `wiki`

### 2. 确定 raw/ 子目录列表（**必须等待用户确认后才能继续**）

> **⚠️ 阻断步骤**：必须向用户展示配置摘要并等待明确确认，**禁止跳过或自动使用默认值**。

向用户展示以下初始化配置摘要，等待确认：

```
📋 初始化配置确认：
  - 知识库名称：<WIKI_NAME>
  - 存储模式：<STORAGE_TYPE>
  - raw/ 子目录：papers, articles, repos, datasets, images, assets

以上 raw/ 子目录为默认配置，你可以：
  - 直接确认 → 使用默认列表
  - 修改 → 增加、删除、重命名子目录（如删除 datasets，添加 notes）
  - 留空 → 不创建任何 raw/ 子目录

请确认或修改后继续。
```

**收到用户确认后**，记录最终的 RAW_SUBDIRS 列表，然后进入步骤 3。

### 3. 调用初始化脚本

> 脚本已内置所有创建逻辑（文件夹、文档、INDEX 更新、LOG 追加、本地配置保存），串行执行避免触发频控。

参照 `adapter/<STORAGE_TYPE>.md`「初始化脚本」，通过 Bash 工具调用对应脚本。

脚本将依次完成：
1. 创建根目录
2. 创建 raw/ 和 wiki/
3. 创建 raw/ 子目录（串行遍历 RAW_SUBDIRS）
4. 创建 wiki/ 子目录（sources/entities/concepts/comparisons/overviews）
5. 创建 AGENTS.md、INDEX、LOG 文档
6. 用所有 token 覆写 INDEX
7. 追加初始化日志到 LOG
8. 保存本地配置到 `~/.llm_wiki.setting.json`
9. 输出 JSON 摘要

### 4. 向用户报告

读取脚本输出末尾的 JSON 摘要，向用户报告：
- 根目录 URL
- INDEX 文档 URL
- 目录结构总结（含存储模式和 raw/ 子目录列表）
- 配置已保存提示

## 注意事项

- 目录创建顺序：根目录 → 一级子目录 → 二级子目录 → 文档
- 共创建 `2 + len(RAW_SUBDIRS) + 5` 个文件夹 + 3 个文档（默认 RAW_SUBDIRS=6 时为 13 个文件夹）
- INDEX 的 doc_id 是后续所有操作的入口
- 知识库模式下，文件夹节点是 docx 文档，在飞书中显示为空文档（这是正常的）
