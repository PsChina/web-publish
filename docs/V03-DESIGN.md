# v0.3 Design — Python SDK + Dual Backend

## 出发点

v0.2 用 OpenCLI eval + 现场生成 JS 来发文章。**Agent token 烧得猛**：每次 publish/update 烧 5-14k Claude tokens（markdown / response data 反复进出 context）。

v0.1（用户旧文）用 Python urllib + `.env`，每次 publish ~1k tokens（Claude 只看 1 行 stdout）。**但要用户手抓 6 个 credential 写 .env**。

v0.3 把两者的优点都拿过来：Python CLI 包业务逻辑（token 经济性 = v0.1），dual backend 给用户选（cookie 配置成本可降到 0）。

## v0.3 设计

**Python CLI 当唯一对 Agent 暴露的接口**，对 Agent 永远只是 `Bash("web-publish publish ...")` + 几行 stdout。

**底层支持两个 backend**：

```
web-publish CLI (Python, Agent 视角)
   │
   ├─ backend=urllib                ← DEFAULT (实测决策, 见下"决策记录")
   │     ├─ 读 ~/.web-publish/.env
   │     └─ urllib.request POST 平台 API
   │
   └─ backend=opencli-bridge        ← 可选
         ├─ subprocess opencli browser eval
         ├─ 在已登录平台 page 内跑 fetch (credentials:include)
         └─ same-origin cookie 自动带，零 .env
```

## 决策记录：为什么 default = urllib 而非 opencli-bridge

v0.3 初版选 `opencli-bridge` 当 default（思路：零 cookie 配置最爽）。**实测打脸**：

| 失效场景 | urllib | opencli-bridge |
|---|---|---|
| Chrome 没开 | ✓ work | ✗ extension not connected |
| Chrome 开着但用户切去别的 tab | ✓ work | ⚠ 要 backend 自动 open background tab，但 `--window background` 在 opencli v1.7.16 超时 |
| Chrome 重启后 extension service worker 睡了 | ✓ work | ✗ doctor reports not connected，需要用户重 load extension |
| 服务器 / CI / headless | ✓ work | ✗ 完全跑不了 |
| Active tab 在 about:blank / chrome:// | ✓ work | ✗ 相对 URL fetch 解析失败 |
| 长期可移植性（OpenCLI 升级 / Chrome 升级 / extension API 变化） | ✓ urllib 是 Python stdlib 没依赖 | ⚠ 多层依赖链，单点失败概率叠加 |

urllib 唯一额外成本：用户跑一次 `web-publish setup` 用编辑器粘 cookie（30 秒）。值得。

`opencli-bridge` 保留作 `--backend opencli-bridge` 显式选项，适合"不想抓 cookie 的一次性发文章"。

## 用户场景

| 场景 | 默认 backend | 配置 |
|---|---|---|
| 个人桌面 / 服务器 / CI | **urllib** | `web-publish setup` 写 .env 一次 |
| 偶尔发文 / 不想抓 cookie | `opencli-bridge` 显式 | OpenCLI extension + Chrome 已登录 |

## CLI 接口

```bash
web-publish publish <platform> <markdown-file> \
    --title "标题" \
    --brief "摘要 ≤100 字" \
    --tag-ids 7467857238494020000,6809641073527226000 \
    --category 开发工具 \
    [--cover-image url] \
    [--draft-only] \
    [--backend urllib|opencli-bridge]      # default: urllib

web-publish update <platform> <article-id> \
    [--append-file supplement.md] \
    [--mark-content-file full-replace.md] \
    [--title "新标题"] \
    [--tag-ids ...] \
    [--draft-only] \
    [--backend ...]

web-publish list <platform> [--limit 20]
web-publish setup [--platform juejin] [--stdin]   # 默认开 $EDITOR 编辑模板
web-publish health <platform>                     # 验证 backend 工作
web-publish categories <platform>                 # dump category 表（无网络）
```

## Token 经济性

| 路径 | Claude 每次 publish 烧 | Agent 看到的 |
|---|---|---|
| v0.1（用户旧文 raw urllib） | ~1k | 用户 Python lib 调用 |
| v0.2（Claude 直生成 JS） | 5-14k | Read markdown + eval JS + response data |
| **v0.3（Python CLI 包装）** | **~300** | 1 行 Bash + JSON stdout |

v0.3 = v0.1 的 token 经济性 + 比 v0.1 更简单的安装（一行 curl）+ 双 backend 弹性。

## 文件布局

```
web-publish/
├── adapters/juejin.yaml          # 平台 endpoint + schema 配置
├── src/web_publish/
│   ├── __init__.py               # __version__
│   ├── cli.py                    # argparse CLI 入口
│   ├── backends.py               # UrllibBackend + OpenCLIBridgeBackend
│   ├── juejin.py                 # JuejinClient（用 backend 跑 endpoint）
│   ├── adapters.py               # yaml 加载 + category/tag 解析
│   └── setup_wizard.py           # 首次 cookie 引导（编辑器模式 + --stdin 模式）
├── pyproject.toml                # setuptools + PyYAML dep + console_script
├── install.sh                    # 5 steps: node / opencli / python venv / skill / extension
├── uninstall.sh
├── skills/web-publish/SKILL.md   # Agent 调 web-publish CLI 的规则，禁止生成 JS
├── commands/publish.md           # /publish slash command
└── README.md
```

## Backend 接口

```python
class Backend(Protocol):
    name: str
    def post(self, path: str, payload: dict, query_params: dict = None) -> dict:
        """POST to platform api endpoint, return data dict (raises BackendError on err_no != 0)"""
```

两个实现都遵守同协议，JuejinClient 不感知差异。

- **UrllibBackend**：urllib + Cookie header from .env，自动注入 aid/uuid/spider 到 query string
- **OpenCLIBridgeBackend**：subprocess `opencli browser eval` 在 page 内跑 fetch；`_ensure_page()` 首次 post 前确保 active tab 在目标 origin

## 实测验证（2026-05-11）

| 测试 | backend | 结果 |
|---|---|---|
| `web-publish --version` | n/a | 0.3.0 ✓ |
| `web-publish health juejin` | urllib | ok:true ✓ |
| `web-publish list juejin --limit 5` | urllib | 返回真实文章列表 ✓ |
| `web-publish categories juejin` | n/a | 8 个分类 id ✓ |
| `web-publish publish juejin /tmp/test.md --draft-only` | opencli-bridge | draft_id 返回 ✓ |
| `web-publish publish juejin /tmp/test.md`（完整 publish） | urllib | article_id + post_url 返回 ✓（实测 2 次成功） |
| `web-publish setup`（编辑器模式） | n/a | 模板生成 + nano 打开 + 保存验证 ✓ |

## 已知边界

- **`opencli-bridge` 跨 origin 接口要签名（msToken/a_bogus）** —— 影响 `article/detail` 等"读已发布文章原文"接口。绕开：用 `list_by_user` + `article_draft/detail` 组合。
- **掘金反垃圾**：同账号短时间发"高度相似内容"会被拦 `err_no=2 参数错误`。换内容或等几分钟。
- **掘金审核**：发布后 `/spost/` 是临时路径，过审跳 `/post/`。

## 不做（v0.3 范围之外）

- 内容优化（标题字数 / tag / 摘要）—— **由 Claude 在 skill 层做**，CLI 只接收已优化好的参数
- CSDN / 知乎 adapter（schema 待逆向，v0.4 / v0.5）
- multi-platform 单命令发布
- Web UI / GUI
- 异步 / 多账号调度（urllib backend 已经能撑这个，需要的话上层加调度即可）
