---
name: web-publish
description: 通过 OpenCLI Browser Bridge 在用户已登录的浏览器 page context 里跑同源 fetch，自动把 markdown 发布或更新到掘金 / CSDN / 知乎等技术博客平台。当用户说"发到掘金"、"发 CSDN"、"更新我的掘金文章"、给一个 .md 文件并问怎么发、或显式 /publish <platform> <path> 命令时触发。**v0.2 默认走 API 路线**（fetch with credentials:include 同源带 cookie），不操作 DOM；DOM 路线降级为 fallback。前置：本机已 npm install -g @jackwener/opencli，已装 Chrome Browser Bridge extension，用户已在浏览器登录目标平台。跨平台 macOS / Linux / Windows MINGW64（Windows 在 git bash 跑，不在 PowerShell）。不读源 markdown 就推 tag / 写摘要属于错误用法。核心优势：不需要平台 API key / 不需要 cookie 复制 / 不需要扫码 — credential 全在浏览器，同源 fetch 自动带。
---

# web-publish v0.2 — 用同源 fetch 把文章发到博客平台

## 核心架构

```
~/article.md
  ↓ Claude Read + 内容优化（标题字数 / tag / 摘要）
  ↓ opencli browser eval (在 <platform>.com 页面里跑 JS)
  ↓ fetch('/content_api/.../create', {credentials:'include', ...})    ← 1
  ↓ fetch('/content_api/.../publish', {credentials:'include', ...})   ← 2
  ↓ opencli browser open <article_url> 验证
```

**关键**：`credentials: 'include'` + 同源请求 = HttpOnly sessionid 浏览器自动带，无需手抓 cookie / token / csrf。

## 跨平台命令规范

| 平台 | 跑命令的 shell |
|---|---|
| macOS / Linux | 终端默认 bash / zsh ✓ |
| Windows | **git bash / MINGW64**（**不要**在 PowerShell 跑，base64 / heredoc 语法不同）|

所有命令模板用 bash 语法。如果用户在 PowerShell，要求他切到 git bash。

## 触发场景

| 用户说 | 行为 |
|---|---|
| "把 article.md 发到掘金" | flow_new_article |
| "发 CSDN 这篇" + 给文件路径 | flow_new_article (csdn) |
| `/publish juejin <path>` | 强制 flow_new_article |
| "更新我的掘金文章 X / 给文章 X 加一段" | flow_update_article |
| "怎么发到 Y" | 引导走 flow_new_article |

## 平台 adapter 状态 (2026-05)

| 平台 | API 路线 | DOM fallback | adapter 文件 |
|---|---|---|---|
| 掘金 | ✓ 实测 (新文 + update) | ✓ | `~/.web-publish/adapters/juejin.yaml` |
| CSDN | 🟡 待实测 | 🟡 | TBD |
| 知乎专栏 | 🟡 待实测（zhihu OpenCLI adapter 只含读操作） | 🟡 | TBD |
| 思否 / 博客园 | 🟡 待评估 | 🟡 | TBD |

## 前置检查

```bash
command -v opencli || echo "用 install.sh 装"
opencli doctor                                # 期望全 [OK]
opencli browser open https://juejin.cn        # 没跳登录 = 已登录
```

| 失败信号 | 处理 |
|---|---|
| `opencli` not found | `~/.web-publish/install.sh` 重跑 |
| Extension: not connected | 用户去 `chrome://extensions/` 装 / 重载（路径 `~/.web-publish/opencli-extension`） |
| 跳到登录页 | 用户在浏览器登录目标平台 |

## 流程 A：发新文章 (flow_new_article)

### 1. Read markdown
```
Read(用户指定的 .md 文件路径)
```
没指定 → 问"你的 markdown 在哪"，不要瞎猜。

### 2. 内容优化
读 `~/.web-publish/adapters/<platform>.yaml` 的 `content_rules`，按平台规则改：
- 标题字数（掘金 20-30 / CSDN 15-30 / 知乎 < 50）
- 首段 100 字抓人
- Tag 推荐（从 `known_tags` 或调 platform 的 tag search endpoint）
- 摘要 ≤ 100 字

### 3. 用 base64 把 markdown 注入 page eval
```bash
# bash (mac/linux/git-bash)
B64=$(base64 < "$MARKDOWN_PATH" | tr -d '\n')

opencli browser eval "
(async () => {
  const bytes = atob('$B64');
  const md = new TextDecoder('utf-8').decode(Uint8Array.from(bytes, c => c.charCodeAt(0)));
  const r = await fetch('<draft_create endpoint>', {
    method: 'POST', credentials: 'include',
    headers: {'content-type': 'application/json'},
    body: JSON.stringify({
      title: '<优化后标题>',
      mark_content: md,
      brief_content: '<80字摘要>',
      category_id: '<从 yaml categories 查>',
      tag_ids: ['<id1>', '<id2>'],
      cover_image: '',
      edit_type: 10,
      html_content: 'deprecated'
    })
  });
  return JSON.stringify(await r.json());
})()
"
```

返回的 `data.id` 就是 draft_id。

### 4. Publish
```bash
opencli browser eval "
(async () => {
  const r = await fetch('<publish endpoint>', {
    method:'POST', credentials:'include',
    headers:{'content-type':'application/json'},
    body: JSON.stringify({draft_id: '<上一步的 id>', sync_to_org: false, column_ids: [], theme_ids: []})
  });
  return JSON.stringify(await r.json());
})()
"
```

返回 `data.article_id`。

### 5. 验证 + 报告
```bash
opencli browser open https://<platform>.com/post/<article_id>
# 或对掘金: https://juejin.cn/spost/<article_id>  (审核中临时路径)
```

```
✅ 已发布到 <platform>
草稿: <draft_id>
文章: <article_url>
标题: <title>
Tag: <list>
状态: 审核中 (掘金 /spost/) 或已公开 (/post/)

冷启动提示（前 24h）：
- 自己点 1 个赞 + 加 1 个收藏
- 朋友圈 / 微信群分享 5-10 次
- 回复每条评论
```

## 流程 B：Update 已发布文章 (flow_update_article)

掘金 update 流程 = 4 个 fetch，0 DOM：

### 1. 找 draft_id (因为 article_id ≠ draft_id)
```bash
opencli browser eval "
(async () => {
  const r = await fetch('/content_api/v1/article/list_by_user?aid=2608&uuid=<UUID>&spider=0', {
    method:'POST', credentials:'include', headers:{'content-type':'application/json'},
    body: JSON.stringify({page_no: 1, page_size: 50, audit_status: null, status: null})
  });
  const j = await r.json();
  const t = (j.data || []).find(a => a.article_info?.article_id === '<TARGET_ARTICLE_ID>');
  return JSON.stringify({draft_id: t?.article_info?.draft_id, category_id: t?.article_info?.category_id, tag_ids: t?.article_info?.tag_ids});
})()
"
```

⚠ **必须** `audit_status: null` + `status: null`，否则返回空数组。

⚠ uuid 从 page 任意请求 URL 抠（或 `opencli browser network --since 30s` 看捕获请求的 URL）。

### 2. 拿原 mark_content
```bash
opencli browser eval "
(async () => {
  const r = await fetch('/content_api/v1/article_draft/detail?aid=2608&uuid=<UUID>', {
    method:'POST', credentials:'include', headers:{'content-type':'application/json'},
    body: JSON.stringify({draft_id: '<DRAFT_ID>'})
  });
  const j = await r.json();
  return JSON.stringify({mark_len: j.data.article_draft.mark_content.length});
})()
"
```

### 3. 在 page 内拼新内容 → update_draft

```bash
SUPP_B64=$(base64 < /path/to/append-block.md | tr -d '\n')

opencli browser eval "
(async () => {
  // 拿旧 draft
  const r1 = await fetch('/content_api/v1/article_draft/detail?aid=2608&uuid=<UUID>', {
    method:'POST', credentials:'include', headers:{'content-type':'application/json'},
    body: JSON.stringify({draft_id: '<DRAFT_ID>'})
  });
  const d = (await r1.json()).data.article_draft;
  // 解码补遗 + 拼接
  const bytes = atob('$SUPP_B64');
  const supplement = new TextDecoder('utf-8').decode(Uint8Array.from(bytes, c => c.charCodeAt(0)));
  // update
  const r2 = await fetch('/content_api/v1/article_draft/update', {
    method:'POST', credentials:'include', headers:{'content-type':'application/json'},
    body: JSON.stringify({
      id: d.id,
      title: d.title,
      mark_content: d.mark_content + supplement,
      brief_content: d.brief_content,
      category_id: d.category_id,
      tag_ids: (d.tag_ids || []).map(String),  // ⚠ 必须 string array
      cover_image: d.cover_image || '',
      edit_type: d.edit_type,
      html_content: 'deprecated'
    })
  });
  return JSON.stringify(await r2.json());
})()
"
```

### 4. Republish
同 flow_new_article 第 4 步。返回相同 article_id（不是新建文章，是更新现有的）。

**注意**：republish 触发审核，期间公开版显示旧版，过审后切换。

## 派工归属 (谁干这个)

任务由 **Claude 自己干**，不调 `delegate_to_deepseek`：
1. 需要中文 SEO / 标题感觉直觉
2. 内容优化 token 量小，DS overhead 不划算
3. 要 WebFetch / opencli 验证，DS 不能联网

## Fallback 策略

| 症状 | 处理 |
|---|---|
| `opencli` not found | `~/.web-publish/install.sh` |
| Extension not connected | 让用户去 `chrome://extensions/` 装 / 重载 |
| `err_no: 2 请求路由不存在` | endpoint 名字过期，用 `opencli browser network --since 30s` 抓真实 endpoint |
| `err_no: 2 参数错误` | 多半是签名墙（msToken/a_bogus），看 yaml 里这个 endpoint 是不是标注 ✗ 需签名 |
| `unmarshal number into Go struct field tag_ids of type string` | `tag_ids` 要 string，`.map(String)` 转一下 |
| 公开版没更新 | republish 在审核中，等几分钟到几十分钟 |
| 发布按钮点击后无跳转（DOM 路线） | 多半 captcha / 内容审核中 |

## 用户显式控制

| 用户说 | Claude 行为 |
|---|---|
| `/publish <platform> <path>` | 强制 flow_new_article |
| "更新 / 加段 / 改文章 X" | flow_update_article |
| "先存草稿不要发布" | 走 draft_create 但跳过 publish 这一步 |
| "不要优化我的文章" | 跳过内容优化清单，原文照发 |
| "我要手动选 tag" | 优化后给推荐但不自动选 |
| "重新发一遍" | 重新走流程（提示可能重复发文） |
| "发到所有支持的平台" | 循环 platforms |

## 内容优化清单

派工前 Claude 必须把 markdown 过一遍。读 `~/.web-publish/adapters/<platform>.yaml` 的 `content_rules`：

**通用**（所有平台）：
- 标题：反差 / 数字 / 痛点 任一
- 首段 100 字内说"读者得到什么"，不要"今天给大家分享..."
- 代码块 ≤ 30 行（长代码折叠）
- 多用表格 + 列表
