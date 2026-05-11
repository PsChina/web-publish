---
name: web-publish
description: 通过 OpenCLI（jackwener/OpenCLI）+ Chrome Browser Bridge 复用你已登录的浏览器 session，自动把 markdown 发布到掘金 / CSDN / 知乎 / 思否 等技术博客平台。当用户说"发到掘金"、"发 CSDN"、"发到 X 平台"、给一个 .md 文件并问怎么发、或显式 /publish <platform> <path> 命令时触发。流程：Read markdown → 内容优化（标题 / 首段 / tag / 摘要） → 通过 OpenCLI 的 browser adapter 调用 navigate / fill / click / submit 操作目标平台的编辑器页面 → 完成发布后 WebFetch 文章 URL 验证。前置条件：本机已 npm install -g @jackwener/opencli，已装 Chrome Browser Bridge extension，用户已在浏览器登录目标平台。不读源 markdown 就推 tag / 写摘要属于错误用法。核心优势：不需要平台 API key / 不需要 cookie 复制 / 不需要扫码 —— OpenCLI 复用 Chrome 已登录态，credential 不离开浏览器。
---

# web-publish — 用 OpenCLI 把文章发到任意博客平台

## 触发场景

| 用户说 | 行为 |
|---|---|
| "把 article.md 发到掘金" | 走完整流程（platform=juejin） |
| "发 CSDN 这篇" + 给文件路径 | 同上（platform=csdn） |
| `/publish juejin <path>` | 强制走流程 |
| `/publish csdn <path>` | 同上 |
| "怎么发到 X" | 引导走流程 |

## 支持的平台（v0.1 范围）

| 平台 | adapter 状态 | 备注 |
|---|---|---|
| 掘金（juejin.cn） | 🚧 v0.1 重点 | 通过 OpenCLI browser adapter 实现 |
| CSDN | 🟡 v0.2 | 类似流程，编辑器 DOM 不同 |
| 知乎专栏 | 🟡 v0.2 | OpenCLI 有内置基础 adapter |
| 思否 SegmentFault | 🟡 v0.3 | 待评估 |
| 博客园 | 🟡 v0.3 | 待评估 |

平台 adapter 在 `~/.web-publish/adapters/<platform>.yaml` 下，可由用户用 OpenCLI 的 `opencli-adapter-author` skill 扩展。

## 前置检查

派工开始前先探测 OpenCLI 是否就位：

```bash
# OpenCLI CLI 是否在 PATH
command -v opencli

# Browser Bridge extension 状态
opencli doctor

# 浏览器是否登录目标平台
opencli browser exec <platform>.checkLogin
```

3 种情况：

| 信号 | 处理 |
|---|---|
| `opencli` not found | 提示用户跑 `npm install -g @jackwener/opencli` 或重跑 install.sh |
| Browser Bridge 未装 | 提示用户去 `chrome://extensions` Load unpacked（install.sh 应该已经引导过） |
| 平台未登录 | 提示用户打开 `https://<platform>` 登录一次，OpenCLI 会自动识别 |

## 发布流程（6 步）

### 1. 解析用户意图
- 用户指定的 platform（掘金 / csdn / 等）
- 用户指定的 markdown 文件路径
- 任何额外指令（先存草稿 / 不要优化 / 手动选 tag 等）

### 2. Read markdown
```
Read(用户指定的 .md 文件路径)
```
没指定路径 → 问一句"你的 markdown 文件在哪"，不要瞎猜。

### 3. 内容优化（按下面"优化清单"做）
- 标题（按平台规则调整字数）
- 首段（前 100 字抓人）
- Tag 推荐（按平台 tag 库匹配）
- 摘要（80 字内）
- 分类

### 4. 调 OpenCLI 走平台 adapter

```bash
opencli browser exec <platform>.publishArticle --input <(cat <<EOF
{
  "title": "<优化后标题>",
  "markdown": "<文章内容>",
  "tags": ["tag1", "tag2"],
  "category": "<分类>",
  "brief": "<80字摘要>",
  "draft_only": false
}
EOF
)
```

OpenCLI 会：
1. navigate 到平台编辑器页（已登录态自动用）
2. fill 标题输入框
3. 切换 markdown 模式 → paste 内容
4. select tag / 分类
5. click 发布按钮
6. 等待跳转到文章 URL，返回 URL

### 5. WebFetch 验证
```
WebFetch(article_url, "标题应该是 <优化后标题>，确认文章可访问")
```

返回 200 + 标题正确 → 成功。否则报警告。

### 6. 报告 + 冷启动提示
```
✅ 已发布到 <platform>
URL: <article_url>
标题: <title>
Tag: <list>

冷启动提示（前 24h）:
- 自己点 1 个赞 + 加 1 个收藏
- 朋友圈 / 微信群分享 5-10 次
- 回复每条评论
```

## 内容优化清单

派工前 Claude 必须把 markdown 过一遍。不同平台规则不同：

### 掘金（juejin.cn）
- 标题：20-25 字（不超 30）
- Tag：3-5 个，从掘金 tag 库匹配
- 分类必选（前端 / 后端 / 移动 / AI / 开发工具 / 阅读）
- 封面图可选但 +30% 转化

### CSDN
- 标题：15-30 字
- Tag：≤5 个，自由文本
- 分类必选
- 标签格式：英文逗号分隔

### 知乎专栏
- 标题：自由长度（建议 < 50 字）
- 话题：≤5 个
- 无分类（按话题）

### 通用规则（所有平台）
- 标题有"反差 / 数字 / 痛点"任一
- 首段 100 字内说"读者得到什么"
- 不要"今天给大家分享..."废话开场
- 代码块 ≤ 30 行（长代码折叠）
- 多用表格

## 本 skill 不派给 DeepSeek

任务由 Claude 自己干，不调 `delegate_to_deepseek`：
1. 需要 Claude 已有的"中文 SEO 直觉"
2. 内容优化 token 量小，DS overhead 不划算
3. 要 WebFetch 验证，DS 不能联网

## Fallback 策略

| 症状 | 处理 |
|---|---|
| `opencli: command not found` | 提示装 OpenCLI，或重跑 `web-publish` install.sh |
| Chrome Browser Bridge 未连接 | 提示用户在 Chrome 装 extension 并打开 |
| `<platform>.checkLogin` 返回 false | 提示用户去 `https://<platform>` 登录一次 |
| adapter 报 selector not found | 平台前端改了，需要更新 adapter（用 `opencli-adapter-author` skill 重新生成 selector） |
| 发布按钮点击后无跳转 | 检查 captcha / 内容审核中（有些平台需要 1-N 分钟过审） |
| WebFetch 验证标题不对 | 警告但不算失败（平台可能 SEO 改写） |

## 用户显式控制

| 用户说 | Claude 行为 |
|---|---|
| `/publish <platform> <path>` | 强制走流程 |
| "先存草稿不要发布" | 走 adapter 但 draft_only=true，跳过 publish 按钮点击 |
| "不要优化我的文章" | 直接发原文，跳过内容优化清单 |
| "我要手动选 tag" | 优化后给推荐但不自动选，让用户决定 |
| "重新发一遍" | 重新走流程（注意：可能产生重复文章） |
| "发到所有支持的平台" | 循环 platforms，每个跑一次（先掘金 → CSDN → 知乎） |
