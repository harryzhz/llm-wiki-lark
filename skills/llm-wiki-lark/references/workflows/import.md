# Import — 导入原始素材

核心理念：raw/ 是知识库的输入层，素材质量决定知识层深度。LLM 协助用户将分散的素材（飞书文档、本地文件、外部链接）统一归档到 raw/ 对应子目录，保持原始内容不加工，为后续 ingest 做准备。

## 前置条件

- Wiki 已初始化
- 从 `~/.llm_wiki.setting.json` 读取 index_doc_id、storage_type、space_id（或用户提供）
- **Wiki 确认**：如果本地配置中 wikis ≥ 2，在选择目标 wiki 后，**必须**向用户确认选中的 wiki 名称再继续，避免写入错误的知识库
- 已 fetch AGENTS 文档查看规范
- 用户提供以下之一：飞书文档链接/token、本地文件路径、外部 URL

## 素材类型识别

| 用户输入形式 | 识别类型 | 处理分支 |
|------------|---------|---------|
| 飞书文档 URL（含 `/docx/`, `/wiki/`）或纯 doc_id | 飞书文档 | → 分支 A |
| 本地文件路径（以 `/` 或 `~/` 开头，或用户明确说"本地文件"） | 本地文件 | → 分支 B |
| arXiv / GitHub / HTTP(S) URL | 外部链接 | → 分支 C |

## 目录分类规则

raw/ 子目录由 init 时用户自定义，从 INDEX 目录配置表动态读取。根据子目录名称做智能匹配：

| 子目录名称 | 自动匹配条件（按优先级） |
|-----------|----------------------|
| `papers` | arXiv 链接；`.pdf` 文件；标题含"论文"、"paper"、"survey" |
| `repos` / `code` | GitHub repo URL；代码文件（.py、.ts、.go 等） |
| `articles` | Medium、Substack、博客、新闻 URL；飞书文档（默认）；`.md`、`.txt` |
| `datasets` / `data` | `.csv`、`.json`、`.parquet`、`.jsonl` |
| `images` / `media` | `.jpg`、`.jpeg`、`.png`、`.svg`、`.gif`、`.webp` |
| `assets` | 以上均不匹配的兜底目录 |

> - 以上为常见子目录名称的匹配规则。对于用户自定义的非标准名称（如 `notes`、`references`），LLM 根据名称语义和素材内容智能判断。
> - 如有歧义或无法确定目标子目录，向用户确认后再继续。
> - 若只有一个 raw/ 子目录，直接使用无需匹配。

## 步骤

### 步骤 1：获取 INDEX，读取目录配置

- 读取 `~/.llm_wiki.setting.json` 获取 INDEX_DOC_ID、STORAGE_TYPE、SPACE_ID
- `lark-cli docs +fetch --as user --doc <INDEX_DOC_ID>`
- 解析「目录配置」表，提取所有 raw/ 子目录的 token → 构建映射 `{子目录名 → token}`
- 解析「Wiki 配置」获取 LOG_DOC_ID、确认 storage_type

### 步骤 2：识别素材类型和目标目录

- 根据「素材类型识别」表确定处理分支（A / B / C）
- 根据「目录分类规则」和 INDEX 中的 raw/ 子目录列表确定目标子目录，记录 TARGET_TOKEN（对应 token）和 TARGET_SUBDIR（如 `raw/papers/`）
- 如有歧义，向用户确认

### 步骤 3：执行导入操作（按分支执行）

**分支 A — 飞书文档**

- 从用户输入中提取 doc_id：
  - URL 格式：取 `/docx/` 后的路径段
  - 纯 token 格式：直接使用
- 记录 SOURCE_DOC_ID
- 验证文档可访问：`lark-cli docs +fetch --as user --doc <SOURCE_DOC_ID>`（读取标题，确认存在）
- 记录 TITLE
- **！！！阻断操作️：执行前必须向用户确认导入方式（默认快捷方式）**：

  > 检测到飞书文档「**<TITLE>**」，请确认导入方式：
  >
  > - **[默认] 快捷方式**：在 `<TARGET_SUBDIR>` 中创建快捷方式，原文档保留在原位，双方同步内容
  > - **直接移动**：将文档从当前位置移动到 `<TARGET_SUBDIR>`，原有链接仍有效但文档位置会改变
  >
  > 请回复 **1（快捷方式）** 或 **2（直接移动）**，直接回车默认选 1：

- 根据用户选择执行：
  - **选择 1（快捷方式，默认）**：参照 `adapter/<STORAGE_TYPE>.md`「创建快捷方式」执行对应命令；若为 `drive` 模式，优先使用 `lark-cli drive +create-shortcut`
  - **选择 2（直接移动）**：参照 `adapter/<STORAGE_TYPE>.md`「移动文档」/「移动节点」执行对应命令
- 记录 RAW_REFERENCE = `<mention-doc token="<SOURCE_DOC_ID>" type="docx"><TITLE></mention-doc>`

**分支 B — 本地文件**

- 展开路径（`~` → 绝对路径），确认文件可读
- 从路径提取 FILENAME，默认 TITLE = 去掉扩展名的文件名（用户可覆盖）
- 上传文件：参照 `adapter/<STORAGE_TYPE>.md`「上传文件」执行对应命令
- 从返回结果中提取 FILE_TOKEN，记录 FILE_TOKEN
- 记录 RAW_REFERENCE = `<mention-doc token="<FILE_TOKEN>" type="docx"><FILENAME></mention-doc>`

**分支 C — 外部链接**

- 记录原始 URL，记录 SOURCE_URL
- **使用 webclip-cli 工具抓取页面全文和媒体文件**：
  ```
  npx github:harryzhz/webclip-cli "<SOURCE_URL>"
  ```
  - `npx` 会自动下载并缓存 webclip-cli 包（首次使用约 10s）
  - 若命令不存在，提示用户全局安装：`npm install -g github:harryzhz/webclip-cli`
  - 工具自动处理 JS 渲染页面（先尝试静态抓取，内容不足时自动升级为 Playwright 浏览器渲染）
  - 若需 JS 渲染但 Playwright 未安装，工具会提示安装：`npm install playwright && npx playwright install chromium`
  - 工具输出 JSON 到 stdout，日志输出到 stderr
  - 解析 JSON 输出，提取：
    - `title` → 记录 TITLE（用户可覆盖）
    - `markdown` → 完整 Markdown 正文（已含媒体占位）
    - `media` → MEDIA_LIST，每项含 `{ type, index, alt, originalUrl, localPath, success }`（type 为 `image`/`video`/`audio`）
    - `stats` → `{ charCount, paragraphCount, imageCount, videoCount, audioCount }`
    - `outputDir` → 媒体文件本地保存目录（默认 `./output/webclips/<slug>/`）
  - 若工具退出码非 0 或 `stats.charCount < 200`，提示用户手动复制内容后另存为本地 .md 文件，再改走分支 B
  - 若需要强制浏览器渲染（如已知为 SPA 页面），可加 `--js` 参数
  - 若不需要下载媒体文件，可加 `--no-images` 跳过
- **向用户展示内容预览**（标题 + 字符数/段落数统计 + 媒体数量 + 前 3 段），确认抓取内容符合预期后再创建文档
  - 若抓取内容明显不完整（字符数异常少、缺少预期章节），提示用户考虑手动复制后走分支 B
- 从 webclip-cli 输出的 `markdown` 中，将图片 `![alt](images/img_NNN.ext)` 替换为行内占位符 `[图N: alt]`，将视频/音频标签替换为 `[视频N]` / `[音频N]`，标记媒体在原文的位置
- 在 raw/ 对应子目录创建飞书文档：参照 `adapter/<STORAGE_TYPE>.md`「创建文档」执行对应命令，markdown 内容为来源注释 + 正文前 N 字符
  - `+create` 先写入来源注释和尽量多的正文（单次 markdown 参数有长度限制）
  - 剩余文本内容按 **≤ 4000 字符/块** 分块，循环用 `+update --mode append` 追加，直到全部内容写入完毕
  - **不得因内容过长而截断或省略——必须全部写入**
- 来源注释格式（置于文档最顶部）：
  ```markdown
  > **原始来源**: <SOURCE_URL>
  > **抓取时间**: <ISO_DATE>
  ```
- 从返回结果中提取 doc_id，记录 RAW_DOC_ID
- **媒体写入**（文本全部写入后，逐项处理 MEDIA_LIST 中 `success: true` 的媒体）：
  - 图片（`type: "image"`）：
    ```
    lark-cli docs +media-insert --doc <RAW_DOC_ID> \
      --file <localPath> --caption "图N: <alt text>"
    ```
  - 视频/音频（`type: "video"` / `type: "audio"`）：
    ```
    lark-cli docs +media-insert --doc <RAW_DOC_ID> \
      --file <localPath> --type file
    ```
  - **禁止用 `drive +upload` + `mention-doc` 处理媒体**——那只会创建文件附件卡片，无法内嵌显示
  - 对 MEDIA_LIST 中 `success: false` 的项，在文档末尾追加文本兜底：
    ```markdown
    **[图N/视频N/音频N 下载失败]** alt: <alt text> | 原始地址: <originalUrl>
    ```
  - 所有媒体处理完后删除 webclip-cli 输出目录：`rm -rf <outputDir>`
- 记录 RAW_REFERENCE = `<mention-doc token="<RAW_DOC_ID>" type="docx"><TITLE></mention-doc>`

### 步骤 4：向用户展示操作结果

操作完成后，展示确认摘要：

```
素材类型：[飞书文档 / 本地文件 / 外部链接]
标题：<TITLE>
目标目录：<TARGET_SUBDIR>
飞书链接：<DOC_URL>
```

> 分支 C 在步骤 3 内已向用户确认抓取内容，此处直接展示创建结果即可。

### 步骤 5：追加 LOG

```
lark-cli docs +update --as user --doc <LOG_DOC_ID> --mode append --markdown "<IMPORT 日志条目>"
```

日志条目格式参见 [pages.md](../templates/pages.md) 中的 IMPORT 模板。

### 步骤 6：报告结果，询问是否 ingest

- 输出素材标题、存入目录、飞书链接（<DOC_URL>）
- 询问用户：

  > 素材已存入 `<TARGET_SUBDIR>`。是否立即执行 **ingest**，将其摄入到 wiki 知识层？

## 注意事项

- raw/ 内容存入后**不做任何修改**（分支 C 的来源注释除外，属于元数据补充）
- 分支 A 移动文档会改变文档所在目录，但不影响 doc_id，原有链接仍有效
- 分支 C 的飞书文档标题即为抓取的页面标题，**不加 "Source:" 前缀**（raw/ 层不使用 wiki/ 层的命名约定）
- 批量导入多个素材时：逐条执行步骤 2-5，最后统一追加一条汇总 LOG（列出每个 mention-doc 及目标目录）
