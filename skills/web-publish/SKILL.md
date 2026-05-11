---
name: web-publish
description: 通过 `web-publish` Python CLI 把 markdown 发布或更新到掘金 / CSDN / 知乎等技术博客平台。当用户说"发到掘金"、"发 CSDN"、"更新我的掘金文章"、给一个 .md 文件并问怎么发、或显式 /publish <platform> <path> 命令时触发。**v0.3 默认走 Python CLI**（Bash 调一行命令，看 JSON stdout 即可）—— **不要在 Claude 上下文里现场生成 fetch JS 或读整篇 markdown**，那会烧 5-14k tokens；用 CLI 烧 ~300 tokens。CLI 内部两个 backend：`opencli-bridge`（默认，浏览器同源 fetch，零 cookie 配置）和 `urllib`（服务器友好，.env cookie）。前置：已跑过本仓 install.sh（装 opencli + web-publish CLI + Chrome extension），用户已在浏览器登录目标平台（opencli-bridge 模式）或 `web-publish setup` 已写 ~/.web-publish/.env（urllib 模式）。跨平台 macOS / Linux / Windows MINGW64（Windows 在 git bash 跑，不在 PowerShell）。不读源 markdown 就推 tag / 写摘要属于错误用法。
---

# web-publish v0.3 — 用 Python CLI 发文章（省 token）

## 核心规则

**Claude 不直接调 platform API**，调 `web-publish` CLI。CLI 内部用 opencli-bridge 或 urllib backend 发 API。Claude 上下文只看到 1 行 Bash + 1 行 JSON stdout（~300 tokens / 篇）。

**Claude 不读整篇 markdown 进 context** —— 文件路径传给 CLI 即可，CLI 自己读盘。

## 触发场景

| 用户说 | 行为 |
|---|---|
| "把 article.md 发到掘金" | 流程 A (publish) |
| `/publish juejin <path>` | 流程 A，强制 |
| "更新我的掘金文章 X / 给文章 X 加一段" | 流程 B (update --append-file) |
| "重写文章 X" | 流程 B (update --mark-content-file) |
| "我的掘金文章列表" | `web-publish list juejin` |
| "怎么发到 Y" | 引导走流程 A |

## 平台 adapter 状态 (2026-05)

| 平台 | API 路线 | 备注 |
|---|---|---|
| 掘金 | ✅ 实测 (publish + update) | `adapters/juejin.yaml` |
| CSDN | 🟡 待 | endpoint 不同 |
| 知乎专栏 | 🟡 待 | OpenCLI zhihu adapter 只含读操作 |

## 前置检查

```bash
command -v web-publish || echo "重跑 install.sh"
web-publish health juejin    # opencli-bridge 模式; 返回 ok:true 即过
```

| 失败信号 | 处理 |
|---|---|
| `command not found: web-publish` | 重跑 install.sh，或 `$HOME/.local/bin` 不在 PATH |
| `BackendError: 找不到 opencli` | `npm install -g @jackwener/opencli` |
| `err_no=...请重新登录` | 浏览器去 juejin.cn 重新登录 |
| `BackendError: 找不到 .env`（urllib 模式） | 跑 `web-publish setup` 引导写 .env |

## 流程 A：发新文章

### 1. Read markdown（**只读一次，用于内容优化决策**）

```
Read(用户指定的 .md 文件)
```

读完做决策（标题字数 / tag 推荐 / 摘要 80-100 字）。读完之后**不再把内容拷给后续命令** —— 文件路径传给 CLI。

### 2. 调 CLI

```bash
web-publish publish juejin <markdown_path> \
  --title "<优化后标题, ≤80 字>" \
  --brief "<摘要, ≤100 字>" \
  --tag-ids "AI编程,OpenAI,AIGC" \
  --category "开发工具" \
  [--cover-image <url>] \
  [--draft-only]                    # 测试 / 用户说"先存草稿"时
```

字段约定：
- `--tag-ids` 接受**已知 tag 名**（adapter yaml 的 `known_tags` 里有）或纯数字 id；逗号分隔；最多 5 个
- `--category` 接受中文分类名；CLI 自己从 yaml 查 id
- 未知 tag → CLI 报错列出已知列表；用户加新 tag 用 `web-publish tags-search juejin <kw>`（v0.4 计划）暂时无 → 让用户在掘金后台先创建

### 3. 解析 CLI 返回

CLI 输出单行 JSON：

```json
{"platform": "juejin", "draft_id": "...", "article_id": "...", "status": "published_pending_review", "spost_url": "https://juejin.cn/spost/...", "post_url": "https://juejin.cn/post/..."}
```

掘金审核中临时是 `/spost/`，过审跳 `/post/`。

### 4. 报告 + 冷启动提示

```
✅ 已发布到 juejin (审核中)
URL: <post_url>
冷启动 (前 24h):
- 自己点 1 个赞 + 加 1 个收藏
- 朋友圈 / 微信群分享 5-10 次
- 回复每条评论
```

## 流程 B：Update 已发布文章

```bash
# 在原文末尾追加
web-publish update juejin <article_id> --append-file <supplement.md>

# 完全替换全文
web-publish update juejin <article_id> --mark-content-file <new_full.md>

# 改标题 / tag
web-publish update juejin <article_id> --append-file x.md --title "新标题" --tag-ids "...,..."

# 只 update 草稿不重新发布（适合 review）
web-publish update juejin <article_id> --append-file x.md --draft-only
```

CLI 内部：
1. `list_by_user` 拿 article_id 对应的 draft_id
2. `article_draft/detail` 拿原 mark_content (不进 Claude context!)
3. 拼接 / 替换
4. `article_draft/update`
5. `article/publish` republish（除非 --draft-only）

注意：republish 触发审核，期间公开版显示旧版，过审切换。

## 写补遗段的工作流

用户说"给文章 X 加一段讲 Y"：
1. Write 一个临时 markdown 文件 `/tmp/append.md` 装补遗内容（这一步**只把补遗段进 context，不进原文**）
2. 跑 `web-publish update juejin <id> --append-file /tmp/append.md`
3. 删 `/tmp/append.md`

## list / health / categories（无破坏性）

```bash
web-publish list juejin --limit 20         # 自己的文章列表
web-publish health juejin                  # backend 连通性测试
web-publish categories juejin              # 分类 id 表 (不调 API)
```

## Backend 切换

默认 `opencli-bridge`（同源 fetch / 零配置）。如果用户在 headless 服务器或想用 .env：

```bash
web-publish publish juejin /tmp/a.md ... --backend urllib
web-publish health juejin --backend urllib
```

urllib 需要先 `web-publish setup` 写 ~/.web-publish/.env。

## 派工归属

任务由 **Claude 自己干**，不调 `delegate_to_deepseek`：
1. 内容优化（标题 / tag / 摘要）需要中文 SEO 直觉
2. CLI 输出已经是 JSON 一行，DS 没价值

## Fallback 策略

| 症状 | 处理 |
|---|---|
| CLI 不在 PATH | `$HOME/.local/bin` 加进 PATH，或重跑 install.sh |
| opencli-bridge 报 cookie 过期 / 401 | 浏览器去目标平台重新登录 |
| urllib 报 cookie 过期 | 重跑 `web-publish setup` 更新 .env |
| `err_no:2, 请求路由不存在` | adapter yaml 的 endpoint 过期；`opencli browser network --since 30s` 抓真实 endpoint 更新 yaml |
| `err_no:2, 参数错误` | 撞签名墙（yaml 里 ✗ 标的 endpoint，如 article/detail）；改用 list_by_user + draft_detail 组合 |
| `请检查文章内容` | 平台审核拦了（敏感词 / 营销词），让用户改内容 |
| 平台改版要写新 adapter | 在已登录平台 page 跑 `opencli browser network --since 30s` 抓 endpoint，写一份 `adapters/<platform>.yaml`，CLI 自动加载 |

## 用户显式控制

| 用户说 | Claude 行为 |
|---|---|
| `/publish <platform> <path>` | 流程 A |
| "先存草稿不要发布" | 加 `--draft-only` |
| "不要优化我的文章" | 跳过优化清单，原文标题/tag 由用户提供 |
| "我要手动选 tag" | 优化后给推荐但等用户拍板 |
| "用 urllib 模式" / "用我的 .env" | 加 `--backend urllib` |
| "更新文章 X 加一段 Y" | 流程 B + 临时 supplement.md |
| "看看我的文章" | `web-publish list juejin` |

## 内容优化清单（Claude 决策层做）

| 项 | 掘金 | CSDN | 知乎 |
|---|---|---|---|
| 标题字数 | 20-30 (max 80) | 15-30 | < 50 |
| Tag 数量 | 3-5 (max 5) | ≤5 | ≤5 |
| 分类 | 必选 | 必选 | 按话题 |
| 摘要 | ≤100 字 | 任意 | 不需 |

**通用**：标题有反差 / 数字 / 痛点；首段 100 字说"读者得到什么"；代码块 ≤30 行（长代码折叠）；多用表格。

## 为什么 v0.3 比 v0.2 省 token

v0.2 让 Claude 现场生成 fetch JS 字符串塞给 opencli eval：
- markdown base64 进 prompt ≈ 5k tokens
- response data（含 mark_content）回 context ≈ 7k tokens
- 一次 publish ≈ 7-14k Claude tokens

v0.3 用 Python CLI 把这些都封装：
- Claude 写 1 行 Bash 调用 ≈ 100 tokens
- CLI stdout 1 行 JSON ≈ 200 tokens
- 一次 publish ≈ 300 tokens

**Read markdown 那次仍然进 context** —— 但 Claude 只是为了**做优化决策**读一次，不再为了"传给 publish API"读第二次。文件路径传给 CLI 后 CLI 自己 read。
