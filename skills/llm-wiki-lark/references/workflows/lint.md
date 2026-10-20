# Lint — 健康检查

核心理念：随着 wiki 增长，定期体检保持知识库健康。LLM 不仅发现问题，还主动建议值得探索的新问题和新源。

## 前置条件

- 已选定 wiki，并 fetch AGENTS 文档查看规范（`lark-cli docs +fetch --doc <AGENTS_DOC_ID> --doc-format markdown`）；按 [存量 AGENTS 引用规范迁移](../wiki-schema.md#存量-agents-引用规范迁移) 检查生效规则，将冲突纳入 D2，不能跳过未登记在页面注册表中的 AGENTS

> **命令约定**：正文检查默认用 `docs +fetch ... --doc-format markdown`（正文在 `.data.document.content`）；定位待修订块和验收资源引用时使用 `--doc-format xml --detail full`。修复按场景选 `--command append` / `--command overwrite` / `--command block_replace`（均加 `--doc-format markdown`）。段落、多块或引用修订按 [命令参考](../../SKILL.md#命令参考) 先 fetch 最新 block ID；`str_replace` 仅用于简单行内文本。INDEX 注册表/配置的写回遵循 [wiki-schema.md](../wiki-schema.md)「索引操作规则」。

## 检查维度

以下 10 项维度**每次 lint 都必须全部检查**，步骤中标注了各维度的检查时机。

| # | 维度 | 说明 | 检查时机 | 严重级别 |
|---|------|------|---------|---------|
| D1 | 空白页面 | 仅有标题或元数据 callout、缺少实质内容 | 全量 fetch | ERROR |
| D2 | 引用格式与断链 | AGENTS 仍要求旧引用语法、实际引用使用旧 `mention-doc`，或引用目标不存在 | AGENTS + INDEX + 全量 fetch | ERROR |
| D3 | 未索引页面 | wiki/ 子目录中实际存在但未在 INDEX 注册表中登记的页面 | 目录扫描 | ERROR |
| D4 | 重复页面 | 标题或内容高度相似的页面，应合并 | INDEX + 全量 fetch | WARNING |
| D5 | 孤立页面 | 无入链的页面，缺乏知识网络连接 | INDEX | WARNING |
| D6 | 矛盾检测 | 不同页面间的事实冲突 | 内容深度检查 | WARNING |
| D7 | 过时声明 | 新源已取代旧页面中的论述 | 内容深度检查 | WARNING |
| D8 | 交叉引用缺失 | 应当互相引用但未链接的页面 | 全量 fetch | INFO |
| D9 | 缺失页面 | 被多次提及但尚未创建独立页面的重要概念/实体 | INDEX + 全量 fetch | SUGGESTION |
| D10 | 源文档更新 | raw/ 原始文档在 Source 页最后更新后被修改过 | 脚本检查 | WARNING |

## 步骤

1. **从 `~/.llm_wiki.setting.json` 读取配置**（含 storage_type、space_id），fetch INDEX → 解析注册表
   ```bash
   lark-cli docs +fetch --doc <INDEX_DOC_ID> --doc-format markdown
   ```

2. **目录扫描**（对比 INDEX 注册表与 wiki/ 子目录的实际内容）
   - **[D3 未索引页面]** 逐个扫描 wiki/sources、wiki/entities、wiki/concepts、wiki/comparisons、wiki/overviews 五个子目录：参照 `adapter/<STORAGE_TYPE>.md`「列出子项」命令获取每个子目录的实际文件列表
   - 将实际文件列表与 INDEX 注册表对比，找出存在于目录中但未在注册表中登记的页面 → 应补充索引或删除

3. **INDEX 级检查**（仅从注册表即可判断，无需 fetch 页面）
   - **[D5 孤立页面]** 扫描所有页面的「关联」列，找出无入链的页面
   - **[D4 重复页面-标题级]** 检查注册表中标题相似的条目（如同名 Entity/Concept、中英文同义词、去掉前缀后相同），记录疑似重复组
   - **[D9 缺失页面-初筛]** 扫描所有页面「关联」列中引用的 doc_id，找出未在注册表中注册的条目

4. **全量 fetch 检查**（逐页 fetch 所有注册页面，确保无遗漏；每页用 `lark-cli docs +fetch --doc <DOC_ID> --doc-format markdown` 取正文）
   - **[D1 空白页面]** 检查页面内容：如果仅有标题、或仅有元数据 callout 而无实质段落内容 → 标记为空白页
   - **[D4 重复页面-内容级]** 对步骤 3 标题相似的疑似重复组，fetch 后对比内容确认是否为真正重复
   - **[D2 引用格式与断链]** 汇总前置检查中的 AGENTS 规范冲突，并检查 INDEX 与页面正文中的实际引用（排除代码示例和历史说明）。旧 `mention-doc` 实际引用标为 ERROR；规范里“禁止旧格式”的说明不报错。对 `<cite type="doc" doc-id="...">` 先查注册表；未登记的目标可能是 AGENTS、LOG 或 raw 文档，须进一步读取目标确认，不能仅凭未登记就判为断链。权限/网络错误报告为无法验证，不冒充目标不存在
     - 旧标签可能已被服务端移除，只留下标题。对 INDEX Doc 列或原始来源等应为引用的位置，用 XML fetch 确认是否存在 `cite` / `source` 资源节点；不能把所有纯文本标题都当成损坏引用。目标 ID 已丢失时，只能依据同一行 Doc ID、注册表中的唯一匹配或原始写入记录恢复，无法唯一确定时报告待确认，不猜测
   - **[D8 交叉引用缺失]** 检查同类型或关联主题的页面之间是否缺少双向引用
   - **[D9 缺失页面-补充]** 统计页面正文中高频提及但无独立页面的实体/概念名称
   - 元数据完整性：callout 字段是否齐全、必须段落是否存在（标题按 [wiki-schema.md](../wiki-schema.md) 中各类型「等价」列做松匹配，如 `## 来源` ≡ `## 相关来源`）

5. **源文档过时检查（脚本辅助）**
   - **[D10 源文档更新]** 从步骤 4 fetch 的所有 Source 类型页面中提取：
     - `原始来源` 中 `<cite type="doc" doc-id="..."></cite>` 或 `<source token="..."></source>` 的 raw token
     - `最后更新` 中的时间戳
     - raw token 的文档类型：飞书文档/外部链接转文档 → `docx`；上传文件 → `file`；不确定时默认 `docx`
   - 构造 JSON 数组，调用检查脚本：
     ```bash
     echo '<JSON_ARRAY>' | bash <skill_base_dir>/scripts/check_staleness.sh
     ```
     输入格式: `[{"source_doc_id":"...","source_title":"...","raw_token":"...","raw_doc_type":"docx","recorded_update":"YYYY-MM-DD HH:mm"}]`
   - 解析脚本输出：
     - `stale` → D10 WARNING（展示源标题、记录时间、实际修改时间、时间差）
     - `missing` → 仅表示 API 成功但 raw meta 未返回，补充 D2 断链引用证据
     - `errors` 或脚本非 0 退出 → stale 检查失败，报告为独立检查错误并中止 D10 判断；不得将本批 raw token 归入 `missing`

   > D7 检查不同源文档之间的内容取代关系，D10 检查同一 raw 文档是否在 Source 页处理后被修改。

6. **内容级深度检查**（在步骤 4 已 fetch 的页面上进行）
   - **[D6 矛盾检测]** 对比不同页面中对同一实体/概念的描述，识别事实冲突
   - **[D7 过时声明]** 按时间排序源文档，检查早期页面中的论述是否已被新源取代

7. **核对检查清单**

   生成报告前，逐项核对 D1–D10 是否全部执行：

   - [ ] D1 空白页面
   - [ ] D2 AGENTS 规范、引用格式与断链
   - [ ] D3 未索引页面
   - [ ] D4 重复页面
   - [ ] D5 孤立页面
   - [ ] D6 矛盾检测
   - [ ] D7 过时声明
   - [ ] D8 交叉引用缺失
   - [ ] D9 缺失页面
   - [ ] D10 源文档更新

8. **生成报告**（按严重级别分组）
   - **ERROR**: D1 空白页面、D2 引用格式与断链、D3 未索引页面、缺失必须段落
   - **WARNING**: D4 重复页面、D5 孤立页面、D6 矛盾声明、D7 过时内容、D10 源文档更新
   - **INFO**: D8 交叉引用缺失
   - **SUGGESTION**: D9 缺失页面、建议探索的新问题、推荐寻找的新源

9. **用户确认后执行修复**（均通过 `lark-cli docs +update --doc <DOC_ID> ... --doc-format markdown`）
   - 用户已明确要求修复引用规范或已确认本次修复范围时，直接执行对应修复，无需重复确认
   - 先按 [存量 AGENTS 引用规范迁移](../wiki-schema.md#存量-agents-引用规范迁移) 局部修复 AGENTS，再处理实际引用；不要把规范示例当成待生成的引用
   - 自动修复: 补充交叉引用、修复断链、将旧 `mention-doc` 实际引用改为 `<cite type="doc" doc-id="<DOC_ID>"></cite>`（文件附件用 `<source token="<FILE_TOKEN>" name="<FILENAME>"></source>`）。先确认目标类型和真实文档 ID；若旧 token 是 wiki 节点，按 Wiki Adapter 解析 `obj_token`，不能直接搬到 `doc-id`。无法确认目标时保留原内容并报告。原标签内有独立说明时移到引用后保留 → 先 `docs +fetch --doc <DOC_ID> --detail full`，再用 `--command block_replace --block-id <BLOCK_ID> --content -` 改写所在块；同父连续多块使用 `--start-block-id <FIRST_BLOCK_ID> --end-block-id <LAST_BLOCK_ID>`，替换内容保留范围内的标题和未改动内容
   - 每次修复后检查 `warnings` 并重新 fetch；实际文档引用用 XML 输出确认存在 `cite` 元素且 `type="doc"`（属性顺序不限），不能只看 Markdown 中出现了 `cite` 字样；规范示例则应保持代码。未通过验证的项仍报告未修复
   - 需确认:
     - 补充空白页内容 → `--command append --content -`（追加缺失段落）
     - 删除空白页 / 合并重复页 / 更新过时内容 / 重新摄入已更新的源文档（re-ingest）→ 整页重写用 `--command overwrite --content -`（markdown 内容须以页面 `# 一级标题` 开头以保留标题），局部段落修订用 `--command block_replace`；仅简单行内文本改动用 `--command str_replace --pattern "<OLD_TEXT>" --content "<NEW_TEXT>"`
     - 创建缺失页面 → 参照 `adapter/<STORAGE_TYPE>.md` 的页面创建命令（`docs +create`）
   - INDEX 注册表 / 配置的同步写回遵循 [wiki-schema.md](../wiki-schema.md)「索引操作规则」（整篇重建 + overwrite 首选）

10. **更新 LOG**
