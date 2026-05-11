# web-publish

[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20Linux%20%7C%20Windows-lightgrey)](https://github.com/PsChina/web-publish)
[![Version](https://img.shields.io/badge/version-v0.3-blue)](docs/V03-DESIGN.md)

> Claude Code 一行命令把 markdown 发布到掘金 / CSDN / 知乎 / 思否 等技术博客平台。
> v0.3 Python SDK + dual backend：`urllib`（默认，简单可靠）+ `opencli-bridge`（可选，零 cookie 配置）。
> 每次发文章 Agent 上下文 ~300 tokens（v0.2 的 1/20）。

```
你: /publish juejin ./article.md
Claude:
  1. Read 文章一次（做内容优化决策：标题字数 / tag / 80 字摘要）
  2. Bash 调 `web-publish publish juejin ./article.md --title X --brief Y ...`
  3. CLI 读 ~/.web-publish/.env → urllib POST 掘金 API
  4. 返回 JSON {article_id, post_url, status}
  5. 给你 URL + 冷启动建议
```

## Quick start

### 1. 一行装好

```bash
curl -sSL https://raw.githubusercontent.com/PsChina/web-publish/main/curl-install.sh | bash
```

脚本自动：
- 检测 / 装 Node.js（>=21）+ `@jackwener/opencli`（opencli-bridge backend 用，可选）
- 装 Python 3 venv + `web-publish` CLI 到 `~/.web-publish/venv/`，软链到 `~/.local/bin/web-publish`
- 部署 skill + `/publish` slash command 到 `~/.claude/`
- 下载并解压 Chrome Browser Bridge extension 到 `~/.web-publish/opencli-extension/`（可选）
- 打开 Chrome 的 `chrome://extensions/` 页面（如果你要用 opencli-bridge）

### 2. 配 cookie（首次必做，~30 秒）

```bash
web-publish setup
```

会自动打开编辑器（`$EDITOR` / nano / vim / notepad），里头模板长这样：

```
JUEJIN_COOKIE=  ← 在 = 后面粘整段 cookie header
JUEJIN_AID=2608
JUEJIN_UUID=   ← 在 = 后面粘 uuid
```

**怎么抓 cookie**（任选其一）：

- **法 A（推荐）**：Chrome 装 [Cookie-Editor](https://chromewebstore.google.com/detail/cookie-editor) → 打开掘金 → 点图标 → Export → 选 "Header String" → 粘到 `JUEJIN_COOKIE=` 后面
- **法 B**：Chrome F12 → Network → 任意 `juejin.cn` 请求 → Request Headers → 复制 `Cookie:` 后面整行

**怎么抓 UUID**：

- Chrome F12 → Network → 任意 `api.juejin.cn` 请求 → 看 URL `?aid=2608&uuid=<这串>`

填完保存退出（nano: Ctrl+O Enter Ctrl+X / vim: `:wq`）。

### 3. 验证

```bash
web-publish health juejin
```

期望输出：

```json
{"platform": "juejin", "backend": "urllib", "ok": true, "first_article_title": "..."}
```

### 4. 发文章

```bash
# Claude Code 里:
> /publish juejin ./我的新文章.md

# 或自然语言:
> 把 ./article.md 发到掘金
```

完事。

## Dual backend：urllib vs opencli-bridge

| Backend | 触发 | 前置 | 稳定性 | 适合场景 |
|---|---|---|---|---|
| **`urllib`**（默认） | 不带 `--backend` 或 `--backend urllib` | `web-publish setup` 写 .env 一次 | ⭐⭐⭐ 强 | 个人 / 服务器 / CI / 头部命令行 |
| `opencli-bridge` | `--backend opencli-bridge` | OpenCLI extension 装好 + Chrome 在跑 + 已登录平台 | ⭐⭐ 中（依赖外部状态） | 不想抓 cookie 的一次性发文章 |

`opencli-bridge` 的好处是零 cookie 配置（浏览器同源 fetch 自动带 HttpOnly），代价是脆 —— Chrome 关、extension 重载、active tab 切走任一都会断。所以 v0.3 把它降为可选，default 是 `urllib`。

## 跨平台

| 平台 | 状态 | 关键点 |
|---|---|---|
| macOS（Intel / Apple Silicon） | ✅ | 默认 zsh 即可 |
| Linux（amd64 / arm64） | ✅ | bash / zsh 都行 |
| Windows | ✅ | **必须用 Git Bash / MINGW64**，**不要在 PowerShell 跑** |

### Windows 用户注意

1. **跑 install.sh 用 Git Bash**（不是 cmd / PowerShell）— bash 语法 PowerShell 不识别
2. **Python ≥3.9 必装**（脚本检测 `python3` 不在就提示去 python.org）
3. **Chrome 只 opencli-bridge 才要**；urllib backend 跑不需要任何浏览器
4. **npm 全局 bin 路径**通常是 `%APPDATA%\npm`，安装脚本自动加 PATH；新开 shell 找不到 opencli 跑一次 `export PATH="$APPDATA/npm:$PATH"`
5. **symlink fallback**：Windows 上 `ln -s` 通常缺权限会失败，脚本自动 fallback 到 `cp -r`（改 skill 源码后要重跑 `install.sh` 同步）

## 工作原理（v0.3）

```
Claude Code (主对话)
    ↓  /publish juejin ./article.md  (Claude Read 一次 markdown 做内容优化)
web-publish skill
    ↓  Bash 调一行 CLI
web-publish CLI (Python, ~/.local/bin/web-publish)
    ↓  --backend 选 backend (默认 urllib)
    │
    ├─ urllib 模式 (默认):
    │   ↓  读 ~/.web-publish/.env (JUEJIN_COOKIE / UUID)
    │   ↓  urllib.request POST + Cookie header
    │
    └─ opencli-bridge 模式 (可选 --backend opencli-bridge):
        ↓  subprocess opencli browser eval "<JS>"
        ↓  Chrome Native Messaging → extension → 在 juejin.cn page 跑
        ↓  fetch(..., credentials:'include')  ← HttpOnly cookie 同源自动带
    │
    └─ 任一 backend → 掘金 API:
       POST /content_api/v1/article_draft/create
       POST /content_api/v1/article/publish
    ↓
CLI 输出 1 行 JSON 给 Claude:
    {"draft_id":"...","article_id":"...","post_url":"https://juejin.cn/post/..."}
```

**Token 经济性**：Claude 上下文只看到 1 行 Bash + 1 行 JSON ≈ **300 tokens / 篇**。markdown 内容 / API response data 都封装在 CLI 内部。

**v0.3 vs 历史版本**：

| 版本 | 模式 | 每次发文 Claude tokens | 配置成本 |
|---|---|---|---|
| v0.1（旧文 Python urllib） | 用户写 Python 调用 SDK | ~1k | 手抓 6 个 credential 写 .env |
| v0.2（Claude 直生成 JS） | Claude 现场拼 fetch JS 塞 opencli eval | 5-14k | 装 extension 一次 |
| **v0.3** | **Python CLI + dual backend** | **~300** | 跑 `web-publish setup` 写 .env 一次（或装 extension） |

## 支持的平台

| 平台 | publish | update | list / health | 备注 |
|---|---|---|---|---|
| 掘金（juejin.cn） | ✅ | ✅ | ✅ | adapter 见 [`adapters/juejin.yaml`](adapters/juejin.yaml) |
| CSDN | 🟡 待 | 🟡 待 | 🟡 待 | endpoint 类似，待实测 |
| 知乎专栏 | 🟡 待 | 🟡 待 | 🟡 待 | |
| 思否 SegmentFault | 🟡 待 | 🟡 待 | 🟡 待 | |
| 博客园 | 🟡 待 | 🟡 待 | 🟡 待 | |

新增平台流程：在已登录平台 page 跑 `opencli browser network --since 30s` 抓真实 endpoint + body schema → 写 `adapters/<platform>.yaml` → 在 `src/web_publish/` 加 `<platform>.py` client 复用现有 backend，**30 分钟 / 平台**。

## CLI 速查

```bash
# 发新文章
web-publish publish juejin ./article.md \
  --title "标题" --brief "摘要 ≤100 字" \
  --tag-ids "AI编程,OpenAI" \
  --category "开发工具"

# 只创建草稿不发
web-publish publish juejin ./article.md ... --draft-only

# 更新文章末尾追加（不读原文进 Claude context）
web-publish update juejin <article_id> --append-file ./supp.md

# 替换全文
web-publish update juejin <article_id> --mark-content-file ./new.md

# 列我的文章
web-publish list juejin --limit 20

# 健康检查（验证 cookie + backend 工作）
web-publish health juejin

# 分类 id 表（不调 API）
web-publish categories juejin

# 首次配 cookie（urllib backend）
web-publish setup

# 显式切 opencli-bridge backend
web-publish publish juejin ... --backend opencli-bridge
```

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

### 一次发到多个平台（待 v0.4 多平台 adapter）
```
把 ./article.md 发到掘金、CSDN、知乎
```

## 为什么选择这个项目

| 现有方案 | 痛点 |
|---|---|
| 浏览器手动复制粘贴 | 每次 3 分钟，重复劳动 |
| ArtiPub（3.2k stars 一文多发） | Docker + Web UI + 数据库，重 |
| juejin-mcp / 各种 deepseek-mcp | 单平台 + 要 API key / cookie / 扫码 |
| **web-publish** | **Python CLI 一行命令，跨平台，跟 Claude Code 深度集成，每次发文章只烧 ~300 Claude tokens** |

## 故障排查

### `setup` 在终端粘 cookie 后回车没反应

Python `input()` 在 readline 默认 buffer 上对 1KB+ 字符串会卡。v0.3 已经改成**自动打开编辑器**，不用 input()，**重跑 `web-publish setup` 即可**。粘贴到编辑器里没限制。

或者用 stdin 模式：

```bash
cat my-cookie.env | web-publish setup --stdin
```

### `BackendError: 找不到 ~/.web-publish/.env`

跑 `web-publish setup` 走编辑器配 cookie，或显式 `--backend opencli-bridge` 走浏览器路径。

### `err_no: 2, err_msg: 参数错误`（urllib backend）

最常见原因：
- **cookie 残缺**：检查 `.env` 里 `JUEJIN_COOKIE` 长度（完整应在 1.5-2KB），含 `sessionid=` 和 `passport_csrf_token=` 两个字段
- **重复内容反垃圾**：刚发过相似标题/内容，掘金短期内拦截；换内容或等几分钟

### `err_no: 2, err_msg: 请求路由不存在`

endpoint 名字过期。在已登录平台 page 跑 `opencli browser network --since 30s`，找到真实 endpoint 更新 `adapters/<platform>.yaml` 的 `endpoints:` 段。

### `opencli doctor` 显示 `Extension: not connected`（opencli-bridge backend）

按这顺序排查：

1. extension 装了吗 — `chrome://extensions/` 看 "OpenCLI Browser Bridge"
2. extension 开了吗 — 卡片右下角开关蓝色
3. 重启 daemon：`opencli daemon restart`
4. 实在不行换 urllib backend：`web-publish setup` + 默认 backend 不变

### Chrome 升级后 extension 失效（opencli-bridge）

`chrome://extensions/` 点该 extension 的刷新图标。或换 urllib backend。

### 换台新机器怎么再装一遍

```bash
curl -sSL https://raw.githubusercontent.com/PsChina/web-publish/main/curl-install.sh | bash
web-publish setup     # 再次配 cookie（cookie 是机器无关的，可以从老机器 .env 复制过来）
```

`~/.web-publish/.env` 直接 scp 过来也行。

## 内容优化（Claude 决策层做）

每次发文章 Claude 会按平台规则过一遍 markdown：

| 项 | 掘金 | CSDN | 知乎 |
|---|---|---|---|
| 标题字数 | 20-30（max 80） | 15-30 | < 50 |
| Tag 数量 | 3-5（max 5） | ≤5 | ≤5 |
| 分类 | 必选 | 必选 | 按话题 |
| 摘要 | ≤100 字 | 任意 | 不需 |

通用：标题有反差 / 数字 / 痛点；首段 100 字说"读者得到什么"；代码块 ≤30 行；多用表格。

详细规则见 [`skills/web-publish/SKILL.md`](skills/web-publish/SKILL.md)。

## 依赖

- **Python** ≥ 3.9（核心 CLI）
- **PyYAML** ≥ 6.0（pyproject.toml 自动装）
- **[jackwener/OpenCLI](https://github.com/jackwener/OpenCLI)**（**可选**，opencli-bridge backend 才用）
- install.sh 自动 npm install + 引导装 Chrome extension

## Uninstall

```bash
./uninstall.sh
```

清掉：
- `~/.claude/skills/web-publish`
- `~/.claude/commands/publish.md`
- `~/.local/bin/web-publish`（CLI 软链）
- `~/.web-publish/`（venv / adapters / extension / .env），**含 cookie，删前确认**

会询问是否卸载全局 OpenCLI npm 包（其他项目可能也在用）。

## 设计文档

- [v0.3 设计与决策记录](docs/V03-DESIGN.md)

## License

MIT
