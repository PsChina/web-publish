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

### 1. 一行装好

```bash
curl -sSL https://raw.githubusercontent.com/PsChina/web-publish/main/curl-install.sh | bash
```

脚本会自动：
- 检测 / 装 Node.js（>=21）+ `@jackwener/opencli`
- 部署 skill + `/publish` slash command 到 `~/.claude/`
- **下载并解压**最新的 Chrome Browser Bridge extension 到 `~/.web-publish/opencli-extension/`
- **打开** Chrome 的 `chrome://extensions/` 页面

### 2. 装 Chrome Browser Bridge extension（30 秒，一次性）

Chrome 已经被脚本帮你打开 `chrome://extensions/`，做 3 件事：

1. 右上角开 **Developer mode**
2. 点 **Load unpacked**
3. 选目录：`~/.web-publish/opencli-extension`

装完看到 "OpenCLI Browser Bridge" 在列表里就 OK。

### 3. 验证连通

```bash
opencli doctor
```

期望输出：

```
[OK] Daemon: running
[OK] Extension: connected
[OK] Connectivity: passed
```

> 如果 Extension 显示 not connected，pin 一下 extension 图标 → 看到亮绿点表示 daemon 已连上。

### 4. 发文章

```bash
# 用法 1: 浏览器登录掘金 (juejin.cn)，然后在 Claude Code 里:
> /publish juejin ./我的新文章.md

# 用法 2: 自然语言
> 把 ./article.md 发到掘金
```

完事。

## 跨平台

| 平台 | 状态 | 关键点 |
|---|---|---|
| macOS（Intel / Apple Silicon） | ✅ | 默认 zsh 即可 |
| Linux（amd64 / arm64） | ✅ | bash / zsh 都行 |
| Windows | ✅ | **必须用 Git Bash / MINGW64**，**不要在 PowerShell 跑** |

### Windows 用户注意

1. **跑 install.sh 用 Git Bash**（不是 cmd / PowerShell）— `base64`、`heredoc` 这些 bash 语法 PowerShell 没有
2. **必须装 Chrome**（不支持 Edge / Firefox — Browser Bridge extension 走 Chrome Native Messaging）
3. **npm 全局 bin 路径**通常是 `%APPDATA%\npm`，安装脚本自动检测加入当前会话 PATH；新开 Git Bash 如果 `opencli` 找不到，跑一次 `export PATH="$APPDATA/npm:$PATH"` 或永久加到 `~/.bashrc`
4. **symlink fallback**：Windows 上 `ln -s` 通常缺 SeCreateSymbolicLinkPrivilege 权限会失败，脚本自动 fallback 到 `cp -r`（功能一样，但改 skill 源码后要重跑 `install.sh` 同步）
5. **gh CLI 可选**：脚本下载 extension 优先用 `gh release download`，没装 gh 会自动 fallback 到 `curl`

## 工作原理（v0.2）

```
Claude Code (主对话)
    ↓  /publish juejin ./article.md
web-publish skill
    ↓  Read markdown + 内容优化（标题字数 / tag / 摘要）
    ↓  opencli browser eval（在 juejin.cn page 里跑同源 fetch）
OpenCLI daemon (npm 包)
    ↓  Chrome Native Messaging
Chrome Browser Bridge extension
    ↓  你的 Chrome 已登录 session
POST /content_api/v1/article_draft/create
POST /content_api/v1/article/publish
```

**关键**：`fetch(..., {credentials: 'include'})` + 同源请求 = HttpOnly sessionid 浏览器自动带，credential 全程不离开浏览器，不需要 API key / cookie 复制 / 扫码。

v0.1 走 DOM click 操作（fill 标题 / setValue 内容 / click 发布），v0.2 直接 API（2 个 fetch 一气发完，零 DOM）。v0.2 默认，DOM 降级为 fallback。

## 支持的平台

| 平台 | API 路线 | DOM fallback | 备注 |
|---|---|---|---|
| 掘金（juejin.cn） | ✅ 发新文章 + update 已发文 | ✅ | adapter 见 `adapters/juejin.yaml` |
| CSDN | 🟡 待实测 | 🟡 | 类似流程，endpoint 不同 |
| 知乎专栏 | 🟡 待实测 | 🟡 | OpenCLI zhihu adapter 只含读操作 |
| 思否 SegmentFault | 🟡 待评估 | 🟡 | |
| 博客园 | 🟡 待评估 | 🟡 | |

新增平台流程：在已登录平台的 page 跑 `opencli browser network --since 30s` 抓真实 publish endpoint → 写一份 `adapters/<platform>.yaml`，30 分钟搞定一个平台。

## 为什么选择这个项目

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

## 故障排查

### `opencli doctor` 显示 `Extension: not connected`

按这顺序排查：

1. **extension 真的装好了吗** — `chrome://extensions/` 看有没有 "OpenCLI Browser Bridge"
2. **extension 开了吗** — 该 extension 卡片右下角开关是蓝色
3. **重启 daemon**：`opencli daemon restart`
4. **重载 extension**：extensions 页面点该 extension 的刷新图标

### `err_no: 2, err_msg: 请求路由不存在`

endpoint 名字过期。在已登录平台 page 跑 `opencli browser network --since 30s`，找到真实 endpoint 名字更新 `adapters/<platform>.yaml`。

### `err_no: 2, err_msg: 参数错误`

多半撞上签名墙（掘金的 `msToken` + `a_bogus` 反爬签名）。这类 endpoint 标记在 yaml 里 ✗，**写**接口（create / update / publish）实测不需要签名，**读已发布文章原文**需要。要绕开就用 `list_by_user` + `article_draft/detail` 组合，跳过 `article/detail`。

### `unmarshal number into Go struct field tag_ids of type string`

平台后端要 string 数组，前端 detail 返回 number 数组。`.map(String)` 转一下。

### "发布失败 — 找不到编辑器元素"（DOM fallback）

API 路线全废时才走 DOM。平台前端改版选择器失效 → 临时方案：手动登录后保持浏览器打开，把控制台错误贴出来，AI 用 `opencli browser state` 重新定位元素 → 沉淀回 yaml 的 `dom_fallback` 段。

### Chrome 升级后 extension 失效

`chrome://extensions/` 点 extension 的刷新图标，或重新 Load unpacked。

### 换台新机器怎么再装一遍

```bash
curl -sSL https://raw.githubusercontent.com/PsChina/web-publish/main/curl-install.sh | bash
```

跟首次安装一样。skill / command / extension 都进 `~/.claude/` 和 `~/.web-publish/`，跟项目仓库本身解耦。

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
