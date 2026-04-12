# Ingest — 摄入源文档

## 前置条件

- Wiki 已初始化
- 从 `~/.llm_wiki.setting.json` 读取 index_doc_id、storage_type、space_id（或用户提供）
- **Wiki 确认**：如果本地配置中 wikis ≥ 2，在选择目标 wiki 后，**必须**向用户确认选中的 wiki 名称再继续，此操作不可逆，避免写入错误的知识库
- 用户已将原始素材放入 raw/ 对应子目录（LLM 不写入 raw/）
- 已 fetch AGENTS 文档查看规范

## 步骤

1. **获取 INDEX**
   - 读取 `~/.llm_wiki.setting.json` 获取 INDEX_DOC_ID
   - `lark-cli docs +fetch --as user --doc <INDEX_DOC_ID>`
   - 解析：目录配置 → 获取所有 token（云盘为 folder_token，知识库为 node_token）；Wiki 配置 → 获取 LOG_DOC_ID、storage_type、space_id；页面注册表 → 构建 token_map: {标题 → doc_id}

2. **检查已有 Source 页面是否过时**
   - 从 INDEX 页面注册表中筛选所有 `类型=source` 的条目
   - **范围确定**：
     - 如果用户指定了 ingest 的目标 raw 文档 → 仅检查引用这些 raw 文档的 Source 页面
     - 如果用户未指定范围（如"检查有没有需要更新的"）→ 扫描全部 Source 页面
   - 对范围内的 Source 页面，逐个 fetch 并提取：
     - `原始来源` mention-doc 中的 raw token
     - `最后更新` 中的时间戳
     - raw token 的文档类型（docx / file）
   - 构造 JSON 数组，调用过时检测脚本：
     ```bash
     echo '<JSON_ARRAY>' | bash <skill_base_dir>/scripts/check_staleness.sh
     ```
     输入格式: `[{"source_doc_id":"...","source_title":"...","raw_token":"...","raw_doc_type":"docx","recorded_update":"YYYY-MM-DD HH:mm"}]`
   - 解析脚本输出，向用户报告：
     - **过时的 Source 页面**（raw 文档有更新）：建议重新摄入
     - **缺失的 raw 文档**：标记为异常
     - **新鲜的 Source 页面**：无需处理
   - 用户确认后：
     - 对过时的 Source 页面：重新 fetch raw 文档内容，走后续 ingest 流程更新 Source 及关联页面
     - 跳过无需更新的页面

3. **读取源内容**
   - 飞书文档：`lark-cli docs +fetch --as user --doc <RAW_DOC_ID>`，记录 RAW_DOC_ID
   - 上传文件（PDF、图片等）：`cd /tmp && lark-cli drive +download --file-token <RAW_FILE_TOKEN> --output ./<文件名>`，用 Read 工具读取，记录 RAW_FILE_TOKEN
   - Source 页「原始来源」统一使用 `<mention-doc token="RAW_DOC_ID 或 RAW_FILE_TOKEN" type="docx">标题</mention-doc>`

4. **分析源内容**
   - 提取实体、概念、关键要点
   - 对照 token_map 识别与已有页面的关联

   #### 实体 (Entity) 识别标准
   - 命名实体：具体的人物、组织、产品、工具、系统、地点
   - 必须在源文档中被实质性讨论（非一笔带过的提及）
   - 判断门槛：能从该源文档中提取 **≥3 条关键事实** → 建页；否则仅在 Source 摘要中内联提及
   - 检查 token_map 避免同义词/中英文重复建页

   #### 概念 (Concept) 识别标准
   - 抽象思想：理论、方法论、模式、原则、技术、框架
   - 源文档中有定义或解释（非仅提及名称）
   - 可跨源复用：阅读其他源文档时这个概念页能提供上下文价值
   - 判断门槛：能写出有意义的「定义」+「详细说明」→ 建页；否则仅在 Source 摘要中内联提及

   #### 粒度控制
   - 宁可少而精，不要多而浅 — 一个只有 1 条关键事实的 Entity 页比不上在 Source 中的内联提及
   - 不确定时，在 Source 摘要的提取列表中标注 `(待确认)`，等后续源文档积累更多信息再建页

5. **提取预览**（默认开启，可在 AGENTS.md「领域约定」中配置为关闭）
   - 向用户展示：
     - 源文档摘要（3 句话）
     - 拟提取的实体列表，每项标注：**新建** / **更新已有** + 简要理由
     - 拟提取的概念列表，每项标注：**新建** / **更新已有** + 简要理由
     - 不建页但会内联提及的项（低于建页门槛的实体/概念）
   - 用户可：添加遗漏项 / 移除不需要的项 / 合并相似项 / 直接确认
   - 确认后进入步骤 6

6. **在 wiki/sources/ 创建 Source 摘要页**
   - 参照 `adapter/<STORAGE_TYPE>.md`「创建文档」，使用 SOURCES_TOKEN 作为父文件夹，标题为 "Source: <标题>"，内容为 Source 模板
   - 记录 SOURCE_DOC_ID、SOURCE_DOC_URL
   - 内容过长时改为：+create 仅写标题，再用 +update --mode append 追加内容
   - callout 块中必须使用列表格式（`- ` 前缀），飞书会吞掉 callout 内的空行导致字段合并为单行
   - `最后更新` 填入当前时间，精确到分钟（格式: YYYY-MM-DD HH:mm）

7. **在 wiki/entities/ 处理实体**
   - 已存在：docs +update 追加新来源
   - 新建：参照 `adapter/<STORAGE_TYPE>.md`「创建文档」，使用 ENTITIES_TOKEN 作为父文件夹（内容过长时同步骤 6 分段写入）
   - 禁止重复写入同名段落（如写两次 "## 相关实体"），每个段落标题在页面中只能出现一次

8. **在 wiki/concepts/ 处理概念**
   - 同步骤 7（使用 CONCEPTS_TOKEN），同样注意不要重复段落

9. **补充交叉引用**
   - 回填 Source 页面中的占位引用

10. **更新 INDEX 页面注册表**
    - `docs +update --mode replace_range --selection-by-title "## 页面注册表"`
    - replace_range 会替换从该标题到下一个同级标题之间的全部内容（包括标题本身），所以替换内容必须以 "## 页面注册表" 开头，后跟完整的表头行和所有数据行（已有 + 新增），不要额外 append 新表
    - Doc 列使用 mention-doc 引用格式：`<mention-doc token="<doc_id>" type="docx"><文档标题></mention-doc>`

11. **追加 LOG**
    - `docs +update --mode append`

12. **报告结果**

## 注意事项

- raw/ 由用户维护，LLM 只读不写
- 所有新文档放入对应子目录，token 从 INDEX「目录配置」表获取，具体命令参照 `adapter/<STORAGE_TYPE>.md`「创建文档」
- Source 摘要页的「原始来源」字段统一使用 `<mention-doc>` 引用 raw/ 下的素材，禁止使用原始 URL
- **callout 内使用列表格式**（`- ` 前缀），飞书会吞掉 callout 内空行导致字段合并
- **每个段落标题不得重复**，避免出现两个 "## 相关实体" 等
- **内容过长时分段写入** — `docs +create` 仅写标题，内容用 `docs +update --mode append` 追加
