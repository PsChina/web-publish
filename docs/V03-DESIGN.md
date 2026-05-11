# v0.3 Design — Python SDK + Dual Backend

## 出发点

v0.2 用 OpenCLI eval + 现场生成 JS 来发文章。**Agent token 烧得很猛**：每次 publish/update 烧 5-14k Claude tokens（markdown / response data 反复进出 context）。

v0.1（用户旧文）用 Python urllib + `.env`，每次 publish 烧 ~1k tokens（Claude 只看 1 行 stdout）。**但要用户手抓 6 个 credential 写 .env**。

## v0.3 设计

**Python CLI 当唯一对 Agent 暴露的接口**，对 Agent 永远只是 `Bash("web-publish publish ...")` + 几行 stdout。Token 经济性回到 v0.1 水平。

**底层支持两个 backend**：

```
web-publish CLI (Python, Agent 视角)
   │
   ├─ backend=urllib (传统模式)
   │     ├─ 读 ~/.web-publish/.env
   │     └─ urllib.request POST juejin API
   │
   └─ backend=opencli-bridge (零配置模式) ← default
         ├─ subprocess opencli browser eval
         ├─ 在已登录 juejin.cn page 内跑 fetch (credentials:include)
         └─ same-origin cookie 自动带，零 .env
```

## 用户场景

| 场景 | backend | 配置 |
|---|---|---|
| 个人桌面 / Mac / Win / Linux 跑 Claude Code | **opencli-bridge** (default) | 装 OpenCLI extension 1 次（与 v0.2 同）|
| 服务器 headless / 团队批量 / 多账号 | **urllib** | `web-publish setup` 引导首次写 .env |
| 工程师不喜欢 extension | **urllib** | 同上 |

## CLI 接口

```bash
web-publish publish <platform> <markdown-file> \
    --title "标题" \
    --brief "摘要 ≤100 字" \
    --tag-ids 7467857238494020000,6809641073527226000 \
    --category 开发工具 \
    [--cover-image url] \
    [--draft-only] \
    [--backend opencli-bridge|urllib]

web-publish update <platform> <article-id> \
    [--append-file supplement.md] \
    [--mark-content-file full-replace.md] \
    [--title "新标题"] \
    [--tag-ids ...] \
    [--backend ...]

web-publish list <platform> [--limit 20]
web-publish setup [--platform juejin]         # 引导 .env 配置
web-publish health <platform>                 # 验证 backend 工作
web-publish categories <platform>             # dump category 表
```

## 核心 Token 经济性对比

| 路径 | Claude 每次 publish 烧 | Agent 看到的 |
|---|---|---|
| v0.1 (raw urllib) | ~1k | 1 行 Bash + JSON stdout |
| v0.2 (Claude 直生成 JS) | 5-14k | Read markdown + eval JS + response data |
| **v0.3 (Python CLI 包装)** | **~1k** | 1 行 Bash + JSON stdout |

v0.3 = v0.1 的 token 经济性 + v0.2 的零配置（opencli-bridge backend）。

## 文件布局

```
web-publish/
├── adapters/juejin.yaml          # 共享 endpoint + schema 配置
├── src/web_publish/
│   ├── __init__.py
│   ├── cli.py                    # argparse CLI 入口
│   ├── backends.py               # UrllibBackend + OpenCLIBridgeBackend
│   ├── juejin.py                 # JuejinClient（用 backend 跑 endpoint）
│   ├── adapters.py               # yaml 加载
│   └── setup.py                  # 首次 cookie 引导
├── pyproject.toml
├── install.sh                    # 加 Python venv install
├── uninstall.sh                  # 加清 venv
├── skills/web-publish/SKILL.md   # 改：调 web-publish CLI，不让 Claude 写 JS
├── commands/publish.md           # 同步
└── README.md                     # 加 v0.3 章节
```

## Backend 接口

```python
class Backend(Protocol):
    def post(self, path: str, payload: dict, query_params: dict = None) -> dict:
        """POST to juejin api endpoint, return data dict (raises on err_no != 0)"""
```

实现：

- **UrllibBackend**：经典 urllib + cookie header from .env
- **OpenCLIBridgeBackend**：subprocess `opencli browser eval "$(generate_fetch_js)"`，在 page 内跑同源 fetch

两者都遵守同样的 Backend 协议，JuejinClient 不感知差异。

## 自测计划

1. `pip install -e .` 在 venv
2. `web-publish --help` / `web-publish publish --help` ergonomic check
3. `web-publish health juejin` → opencli-bridge 模式，验证 cookie + endpoint
4. `web-publish publish juejin /tmp/test.md --title ... --draft-only` → 创建草稿，**不发布**，创作者中心能看到草稿就算 PASS
5. `web-publish categories juejin` → dump category id 表（无副作用 / 不调 API）

不破坏用户已发布文章。

## 不做（v0.3 范围之外）

- 内容优化（标题字数 / tag / 摘要）—— **由 Claude 在 skill 层做**，CLI 只接收已优化好的参数
- CSDN / 知乎 adapter（schema 待逆向）
- multi-platform 单命令发布（先单平台跑稳）
- Web UI / GUI
- 异步 / 多账号调度
