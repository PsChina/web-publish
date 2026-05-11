# web-publish

[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20Linux%20%7C%20Windows-lightgrey)](https://github.com/PsChina/web-publish)

> Claude Code 一行命令把 markdown 发布到掘金 / CSDN / 知乎 / 思否 等技术博客平台。
> 复用你已登录的 Chrome session — 不要 API key / 不要 cookie 复制 / 不要扫码。

```
你: /publish juejin ./article.md
Claude:
  1. Read 文章
  2. 优化（标题字数 / SEO 首段 / 推 tag / 80 字摘要 / 分类）
  3. 通过 OpenCLI 调你 Chrome 浏览器的已登录 session 操作平台编辑器
  4. WebFetch 验证文章上线
  5. 给你 URL + 冷启动建议
```

## Quick start

```bash
curl -sSL https://raw.githubusercontent.com/PsChina/web-publish/main/curl-install.sh | bash
```

一行装好：
- 检测 Node.js（>=21），缺了引导你装
- `npm install -g @jackwener/opencli`（浏览器自动化引擎）
- 部署 skill + `/publish` slash command 到 Claude Code
- 引导你装 Chrome Browser Bridge extension（一次性，30 秒）

装完：

```bash
# 1. 浏览器登录目标平台（你已登录 juejin.cn / csdn.net 等）
# 2. 跑 claude
> /publish juejin ./我的新文章.md
```

完事。

## 跨平台

- macOS（Intel / Apple Silicon） ✅
- Linux（amd64 / arm64） ✅
- Windows MINGW64 / Git Bash ✅

## 工作原理

```
┌──────────────────────────────────────────────┐
│  Claude Code (主对话)                          │
│    ↓ /publish juejin ./article.md             │
│  web-publish skill                            │
│    ↓ Read + 平台特定优化                       │
│    ↓ 调 opencli browser exec ...              │
│  OpenCLI (本地 npm 包)                         │
│    ↓ Chrome Native Messaging                  │
│  Chrome Browser Bridge extension              │
│    ↓ 你的 Chrome 已登录 session                │
│  juejin.cn / csdn.net / zhihu.com 编辑器页面  │
└──────────────────────────────────────────────┘

credential 不离开浏览器。
cookie / sessionid 永远在 Chrome 本地。
```

## 支持的平台

| 平台 | 状态 | 备注 |
|---|---|---|
| 掘金（juejin.cn） | 🚧 v0.1 | 重点平台 |
| CSDN | 🟡 v0.2 | 类似流程 |
| 知乎专栏 | 🟡 v0.2 | OpenCLI 基础 adapter |
| 思否 SegmentFault | 🟡 v0.3 | 待评估 |
| 博客园 | 🟡 v0.3 | 待评估 |

新增平台：用 OpenCLI 的 `opencli-adapter-author` skill 半自动生成 adapter，约 30-60 分钟。

## 为什么这个项目

| 现有方案 | 痛点 |
|---|---|
| 浏览器手动复制粘贴 | 每次 3 分钟，重复劳动 |
| ArtiPub（3.2k stars 一文多发） | Docker + Web UI + 数据库，重 |
| juejin-mcp / 各种 deepseek-mcp | 单平台 + 要 API key / cookie / 扫码 |
| **web-publish** | **复用 Chrome 已登录态，跨平台，跟 Claude Code 深度集成** |

## 用法 cookbook

### 强制发布
```
/publish juejin ./article.md
```

### 只创建草稿不发
```
/publish juejin ./article.md 先存草稿不要发布
```

### 跳过优化（保留原文）
```
/publish juejin ./article.md 不要优化我的文章
```

### 手动选 tag
```
/publish juejin ./article.md 我要手动选 tag
```

### 一次发到多个平台
```
把 ./article.md 发到掘金、CSDN、知乎
```

## 内容优化做了什么

Claude 派工前会按以下清单过一遍（不同平台规则不同）：

| 项 | 掘金 | CSDN | 知乎 |
|---|---|---|---|
| 标题字数 | 20-25 | 15-30 | < 50 |
| Tag 数量 | 3-5 | ≤5 | ≤5 |
| 分类 | 必选 | 必选 | 按话题 |
| 封面 | +30% 转化 | 可选 | 不需 |

详细规则见 `skills/web-publish/SKILL.md`。

## 依赖

- 底层：[jackwener/OpenCLI](https://github.com/jackwener/OpenCLI)（浏览器自动化引擎）
- install.sh 自动 npm install + 引导装 Chrome extension

## Uninstall

```bash
./uninstall.sh
```

清掉：
- `~/.claude/skills/web-publish`
- `~/.claude/commands/publish.md`
- `~/.web-publish/`（含 adapter 配置）

会询问是否卸载全局 OpenCLI npm 包（其他项目可能在用）。

## License

MIT
