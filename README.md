# publish-to-juejin

[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20Linux%20%7C%20Windows-lightgrey)](https://github.com/PsChina/publish-to-juejin)

> Claude Code 一行命令把 markdown 文章发布到掘金（juejin.cn）。
> 自动优化标题 / 首段 / tag / 摘要，调本地 daemon 直接发，不用手动复制粘贴。

```
你: /juejin ./article.md
Claude:
  1. Read 文章
  2. 优化（标题字数 / SEO 首段 / 推 3-5 个 tag / 80 字摘要）
  3. 调本地 juejin-mcp daemon 创建草稿 + 发布
  4. WebFetch 验证文章已上线
  5. 给你 URL + 冷启动建议
```

## Quick start

```bash
curl -sSL https://raw.githubusercontent.com/PsChina/publish-to-juejin/main/curl-install.sh | bash
```

一行装好：
- 检测 Go；没装就**自动下载** Go 工具链到 `~/.publish-to-juejin/go/`（不污染系统）
- clone + build `androidZzT/juejin-mcp` 作为后端
- 启动 daemon（端口 18080）
- 部署 skill + `/juejin` slash command 到 Claude Code

装完跑 `claude`，第一次输入：

```
帮我用 publish-to-juejin 登录掘金
```

Claude 会调 `get_login_qrcode` 工具，你掘金 App 扫码即可。之后写文章：

```
/juejin ./我的新文章.md
```

完事。

## 跨平台

- macOS (Intel / Apple Silicon) ✅
- Linux (amd64 / arm64) ✅
- Windows MINGW64 / Git Bash ✅（install.sh 检测平台用 cmd start 启 daemon）

## 工作原理

```
┌──────────────────────────────────────────┐
│  Claude Code (主对话)                    │
│    ↓ /juejin path/to/article.md          │
│  publish-to-juejin skill                 │
│    ↓ Read + 优化                         │
│    ↓ HTTP POST                           │
│  juejin-mcp daemon (本地 127.0.0.1:18080)│
│    ↓ HTTPS                               │
│  api.juejin.cn (你的登录态)              │
└──────────────────────────────────────────┘

所有信息留在你机器。掘金账号 cookie 存在 ~/.publish-to-juejin/
```

## Configuration

不需要配置文件。掘金登录走 QR code，cookie 自动持久化到 `~/.publish-to-juejin/`。

如果想用 cookie 模式（不扫码），看 juejin-mcp 文档：https://github.com/androidZzT/juejin-mcp

## 用法 cookbook

### 强制发布
```
/juejin ./article.md
```

### 只创建草稿不发
```
/juejin ./article.md 先存草稿不要发布
```

### 跳过优化（保留原文）
```
/juejin ./article.md 不要优化我的文章
```

### 手动选 tag
```
/juejin ./article.md 我要手动选 tag
```

## 内容优化做了什么

Claude 派工前会按以下清单过一遍：

| 项 | 规则 |
|---|---|
| 标题 | 20-25 字，反差 / 数字 / 痛点 任一 |
| 首段 | 100 字内说清"读者得到什么" |
| 摘要 | 80 字，含数字 / 反差 / 结果 |
| Tag | 3-5 个，从掘金 tag 库匹配 |
| 分类 | 1 个，按内容主题映射 |
| 封面 | markdown 第一张图自动用作 cover |

详细规则见 `skills/publish-to-juejin/SKILL.md`。

## 依赖

- 底层：[androidZzT/juejin-mcp](https://github.com/androidZzT/juejin-mcp)（Go MCP server，提供 18 个掘金 API 工具）
- install.sh 自动 clone + build + 起 daemon

## Uninstall

```bash
./uninstall.sh
```

清掉：
- `~/.claude/skills/publish-to-juejin`
- `~/.claude/commands/juejin.md`
- 杀掉 juejin-mcp daemon
- 保留 `~/.publish-to-juejin/`（含登录 cookie），要彻底删请手动 `rm -rf ~/.publish-to-juejin`

## License

MIT
