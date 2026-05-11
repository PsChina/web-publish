---
name: publish-to-juejin
description: 全自动把 markdown 文章发布到掘金（juejin.cn）。当用户说"发到掘金"、"发掘金"、"publish to juejin"、给一个 .md 文件并问怎么发到掘金、或显式 /juejin 命令时触发。流程：Read 用户指定的 markdown → 自动优化（标题 / 首段 / tag / 摘要 / 封面建议） → 调本地 juejin-mcp daemon REST API（127.0.0.1:18080）创建草稿 + 发布 → WebFetch 文章 URL 验证上线。所有任务前必须先 Read 用户指定的 markdown 文件；不读源文件无法做 tag 推荐、字数检查、SEO 优化。掘金 SEO 关键点：标题 20-25 字（不超 30）、首段抓住读者 100 字内、3-5 个 tag、有 cover image 转化率 +30%。前置条件：本机已跑 install.sh，juejin-mcp daemon 已启动且用户已扫码登录掘金（首次用要引导用户调 get_login_qrcode 工具）。
---

# publish-to-juejin — 全自动发布博客到掘金

## 触发场景

| 用户说 | 行为 |
|---|---|
| "把 article.md 发到掘金" | 走完整流程 |
| "发掘金这篇" + 给文件路径 | 同上 |
| `/juejin <path>` | 强制走完整流程 |
| "怎么发到掘金" | 引导走流程 |

## 前置检查

派工开始前**先探测 juejin-mcp daemon 状态**：

```bash
# 健康检查
curl -fsS http://127.0.0.1:18080/health
```

3 种情况：

| 响应 | 处理 |
|---|---|
| 200 + `logged_in: true` | ✅ 直接走发布流程 |
| 200 + `logged_in: false` | 调 `get_login_qrcode` 引导用户扫码（用 juejin App 扫） |
| 拒绝连接 / 找不到 | daemon 没起来，告诉用户 `cd ~/.local/share/publish-to-juejin && ./install.sh` 或手动跑 daemon |

## 发布流程（6 步）

### 1. Read markdown
```
Read(用户指定的 .md 文件路径)
```
如果用户没指定路径，问一句"你的 markdown 文件在哪"，**不要瞎猜**。

### 2. 内容优化（按下面"优化清单"做）
- 标题
- 首段
- Tag 选择
- 摘要生成
- 分类

### 3. 创建草稿
```bash
POST http://127.0.0.1:18080/api/v1/article/draft
Content-Type: application/json

{
  "title": "<优化后标题>",
  "markdown": "<文章 markdown>",
  "tags": [<tag_id1>, <tag_id2>, <tag_id3>],
  "category_id": <category_id>,
  "brief_content": "<80 字摘要>",
  "cover_image": "<可选，markdown 里第一张图>"
}
```

拿到响应里的 `draft_id`。

### 4. 发布草稿
```bash
POST http://127.0.0.1:18080/api/v1/article/publish
{ "draft_id": "<from step 3>" }
```

拿到响应里的 `article_url`。

### 5. 验证
```
WebFetch(article_url, "标题应该是 <step 2 优化后的标题>，确认文章可访问")
```

返回 200 + 标题正确 → 成功。否则报警告。

### 6. 报告
```
✅ 已发布到掘金
URL: https://juejin.cn/post/<id>
标题: <title>
Tag: <list>

冷启动提示：发布 24h 内
- 自己点 1 个赞 + 加 1 个收藏
- 朋友圈 / 微信群分享
- 回复每条评论
（前 5-10 个互动决定推荐池入选）
```

## 内容优化清单

派工前 Claude 必须把 markdown 过一遍：

### 标题
- ✅ 字数 20-25（不超 30，掘金推荐位会截断）
- ✅ 有"反差 / 数字 / 痛点"中至少一个
- ✅ 没有 "如何" "教程" 等老套词开头
- ❌ "我开发了一个 X" → ✅ "X：让 Y 不再 Z 的工具"

### 首段（前 100 字）
- ✅ 直接说"读者会得到什么"
- ✅ 痛点引入（先共鸣）
- ❌ "今天给大家分享..." 这种废话开场

### 内容
- ✅ 多用表格（掘金对表格渲染好）
- ✅ 代码块 ≤ 30 行（长代码折叠或拆 step）
- ✅ 加 emoji 但不滥用（章节标题 1 个就够）
- ✅ 适当**加粗**关键句

### 摘要（brief_content，80 字）
- 全文最有价值的 1-2 句
- 含数字 / 反差 / 结果

### Tag 选择（3-5 个）
按用户文章主题从掘金常见 tag 里挑：
- 技术栈：`AI` `Claude` `OpenAI` `DeepSeek` `React` `Vue` `TypeScript` `Python` `Go` `Rust`
- 主题：`效率工具` `开源` `MCP` `Agent` `Web开发` `前端` `后端` `运维`
- 软话题：`程序员` `经验分享` `踩坑` `开发工具`

**判断**：先 Read 文章主体 → 提取 3-5 个高频技术词 → 匹配掘金 tag 库 → 推荐 → 调 `/api/v1/tags/search?q=<term>` 拿到 tag_id

### 分类（category_id，必选 1 个）
调 `GET http://127.0.0.1:18080/api/v1/categories` 拿到 ID 列表。常用：

| 分类 | 用于 |
|---|---|
| 前端 | React / Vue / CSS / TypeScript |
| 后端 | Python / Go / Java / Node.js / 数据库 |
| Android / iOS | 移动开发 |
| 人工智能 | AI / LLM / Agent |
| 开发工具 | CLI / IDE / 效率 |
| 阅读 / 职场 | 经验 / 学习 / 反思 |

## 本 skill 不派给 DeepSeek

本任务由 Claude 自己干，**不**调 `delegate_to_deepseek`：
1. 需要 Claude 已有的"中文 SEO 直觉"和写作判断
2. 任务 token 量小（一篇文章 + 推 tag），DS overhead 不划算
3. 要调用 WebFetch 验证产物，DS 拿不到 Anthropic 的 web 工具

## Fallback 策略

| 症状 | 处理 |
|---|---|
| `curl: connection refused` | daemon 没启动 → 提示用户 `cd ~/.local/share/publish-to-juejin && nohup ~/.publish-to-juejin/juejin-mcp > /dev/null 2>&1 &` |
| `{logged_in: false}` | 调 `get_login_qrcode` → 二维码用 base64 image / ASCII 显示给用户扫 |
| `POST article/draft` 返回 4xx | 通常是 tag_id / category_id 错误 → 重新调 `/api/v1/categories` 和 `/api/v1/tags/search` 拉正确 ID 重试 |
| `POST article/publish` 返回 5xx | 重试一次；仍失败 → 告诉用户 draft_id，让他去 juejin.cn 后台手动发布草稿 |
| WebFetch 验证标题不对 | 警告用户但不算失败（可能掘金做了 SEO 改写） |

## 用户显式控制

| 用户说 | Claude 行为 |
|---|---|
| `/juejin <path>` | 强制走流程 |
| "先存草稿不要发布" | 只调 draft API，跳过 publish |
| "我要手动选 tag" | 输出推荐但不自动选，让用户决定 |
| "不要优化我的文章" | 直接发原文，跳过内容优化清单 |
| "重新发一遍" | 创建新草稿 + 发布（不复用上次 draft_id） |
