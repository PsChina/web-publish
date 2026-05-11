#!/usr/bin/env bash
# install.sh — web-publish: 多平台博客发布 skill 安装
#
# 工作原理:
#   - 装 OpenCLI（jackwener/OpenCLI）作为浏览器自动化后端
#   - 引导用户装 Chrome Browser Bridge extension（复用已登录态）
#   - 部署 skill + slash command 到 Claude Code
#
# 跨平台: macOS / Linux / Windows MINGW64

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/.web-publish"
ADAPTERS_DIR="$INSTALL_DIR/adapters"
CLAUDE_SKILLS="$HOME/.claude/skills"
CLAUDE_COMMANDS="$HOME/.claude/commands"
OPENCLI_PACKAGE="@jackwener/opencli"

echo "▶ web-publish installer"
echo "  project: $PROJECT_ROOT"
echo ""

# ===== 平台探测 =====
case "$(uname -s 2>/dev/null)" in
    Linux*)               PLATFORM=linux ;;
    Darwin*)              PLATFORM=darwin ;;
    MINGW*|CYGWIN*|MSYS*) PLATFORM=windows ;;
    *)                    PLATFORM=unknown ;;
esac
echo "  platform: $PLATFORM"
echo ""

# ===== Step 1: Node.js + npm 检测 =====
echo "[1/5] 检测 Node.js (>=21)..."
if ! command -v node >/dev/null 2>&1; then
    echo "✗ 没装 Node.js"
    echo "  装一下:"
    case "$PLATFORM" in
        darwin)  echo "    brew install node" ;;
        linux)   echo "    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - && sudo apt-get install -y nodejs" ;;
        windows) echo "    去 https://nodejs.org 下 LTS 装好后重跑本脚本" ;;
    esac
    echo "  装完重跑 ./install.sh"
    exit 1
fi

NODE_VERSION_MAJOR="$(node --version | sed 's/v//' | cut -d. -f1)"
if [ "$NODE_VERSION_MAJOR" -lt 21 ]; then
    echo "✗ Node.js 版本 $(node --version) 太老，OpenCLI 要 >=21"
    echo "  升级一下:"
    case "$PLATFORM" in
        darwin)  echo "    brew upgrade node" ;;
        *)       echo "    用 nvm: nvm install 21 && nvm use 21" ;;
    esac
    exit 1
fi
echo "  ✓ Node $(node --version)"
echo ""

# ===== Step 2: 装 OpenCLI =====
echo "[2/5] 装 OpenCLI ($OPENCLI_PACKAGE)..."

# 把 npm 全局 bin 加进 PATH (cover 自定义 prefix 如 ~/.npm-global)
npm_global_bin() {
    local prefix
    prefix="$(npm prefix -g 2>/dev/null)" || return 1
    # macOS/Linux: <prefix>/bin    Windows nodist: <prefix> 本身
    if [ -d "$prefix/bin" ]; then echo "$prefix/bin"
    elif [ -d "$prefix" ];   then echo "$prefix"
    fi
}

ensure_npm_bin_in_path() {
    local bin_dir; bin_dir="$(npm_global_bin)" || return 0
    [ -z "$bin_dir" ] && return 0
    case ":$PATH:" in *":$bin_dir:"*) ;; *) export PATH="$bin_dir:$PATH" ;; esac
}

ensure_npm_bin_in_path

if command -v opencli >/dev/null 2>&1; then
    OPENCLI_VERSION="$(opencli --version 2>&1 | head -1)"
    echo "       已装: $OPENCLI_VERSION"
else
    echo "       npm install -g $OPENCLI_PACKAGE ..."
    npm install -g "$OPENCLI_PACKAGE" 2>&1 | tail -3
    ensure_npm_bin_in_path
    if ! command -v opencli >/dev/null 2>&1; then
        BIN_DIR="$(npm_global_bin)"
        echo "✗ OpenCLI 装完但 'opencli' 不在 PATH"
        echo "  npm prefix: $(npm prefix -g)"
        echo "  把 '$BIN_DIR' 加到你的 PATH 后重跑 ./install.sh"
        echo "  zsh: echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> ~/.zshrc && source ~/.zshrc"
        exit 1
    fi
    echo "       ✓ $(opencli --version 2>&1 | head -1)"
fi
echo ""

# ===== Step 3: 装 Python web-publish CLI (v0.3) =====
echo "[3/5] 装 web-publish Python CLI (v0.3)..."
if ! command -v python3 >/dev/null 2>&1; then
    echo "✗ 没装 python3 (>=3.9)"
    case "$PLATFORM" in
        darwin)  echo "    brew install python@3.12" ;;
        linux)   echo "    sudo apt install python3 python3-venv  # 或 dnf / pacman 等价" ;;
        windows) echo "    去 https://python.org 下 3.12 装好后重跑本脚本" ;;
    esac
    exit 1
fi
PY_VENV="$INSTALL_DIR/venv"
if [ ! -d "$PY_VENV" ]; then
    python3 -m venv "$PY_VENV"
    echo "       ✓ 建 venv: $PY_VENV"
fi
"$PY_VENV/bin/pip" install --quiet --upgrade pip >/dev/null 2>&1 || true
"$PY_VENV/bin/pip" install --quiet -e "$PROJECT_ROOT" 2>&1 | tail -3
WEB_PUBLISH_BIN="$PY_VENV/bin/web-publish"
if [ ! -x "$WEB_PUBLISH_BIN" ]; then
    # Windows: bin → Scripts
    WEB_PUBLISH_BIN="$PY_VENV/Scripts/web-publish"
fi
if [ ! -x "$WEB_PUBLISH_BIN" ] && [ ! -f "$WEB_PUBLISH_BIN" ]; then
    echo "✗ web-publish CLI 装失败"
    exit 1
fi

# 把 web-publish 软链到 ~/.local/bin (PATH 上常见位置)
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"
ln -sf "$WEB_PUBLISH_BIN" "$LOCAL_BIN/web-publish" 2>/dev/null \
    || cp -f "$WEB_PUBLISH_BIN" "$LOCAL_BIN/web-publish"
echo "       ✓ web-publish CLI → $LOCAL_BIN/web-publish"
case ":$PATH:" in
    *":$LOCAL_BIN:"*) ;;
    *) echo "       ⚠ $LOCAL_BIN 不在 PATH; 加 'export PATH=\"\$HOME/.local/bin:\$PATH\"' 到 ~/.zshrc 或 ~/.bashrc" ;;
esac
echo ""

# ===== Step 4: 部署 skill / command / adapters =====
echo "[4/5] 部署 skill / slash command / adapters..."
mkdir -p "$CLAUDE_SKILLS" "$CLAUDE_COMMANDS" "$ADAPTERS_DIR"

deploy_link() {
    local src="$1"; local dst="$2"; local label="$3"
    [ -e "$dst" ] && { echo "       $label 已存在，跳过 (要更新先删 $dst)"; return 0; }
    if ln -s "$src" "$dst" 2>/dev/null; then
        echo "       $label (symlink): $dst"
    elif cp -r "$src" "$dst"; then
        echo "       $label (copy): $dst"
        echo "       ⚠ 用了 copy 不是 symlink — 改源码后需重跑 install.sh"
    else
        echo "       ✗ 部署 $label 失败"
        return 1
    fi
}

deploy_link "$PROJECT_ROOT/skills/web-publish" \
            "$CLAUDE_SKILLS/web-publish" "skill"
deploy_link "$PROJECT_ROOT/commands/publish.md" \
            "$CLAUDE_COMMANDS/publish.md" "command"

# 把 adapters/ 目录里所有平台 adapter 复制到 ~/.web-publish/adapters/
if [ -d "$PROJECT_ROOT/adapters" ]; then
    for adapter in "$PROJECT_ROOT/adapters"/*.yaml; do
        [ -e "$adapter" ] || continue
        cp -n "$adapter" "$ADAPTERS_DIR/"
    done
    ADAPTER_COUNT="$(ls "$ADAPTERS_DIR" 2>/dev/null | wc -l | tr -d ' ')"
    echo "       adapters: $ADAPTER_COUNT 个 → $ADAPTERS_DIR"
fi
echo ""

# ===== Step 5: 自动下载 + 解压 Chrome Browser Bridge extension =====
echo "[5/5] Chrome Browser Bridge extension"
EXT_DIR="$INSTALL_DIR/opencli-extension"
EXT_ZIP_GLOB="$INSTALL_DIR/opencli-extension-*.zip"

# 已解压 + 有 manifest.json 视为已就绪
if [ -f "$EXT_DIR/manifest.json" ]; then
    echo "       ✓ extension 已解压: $EXT_DIR"
else
    if command -v gh >/dev/null 2>&1; then
        echo "       下载最新 extension (via gh release)..."
        ( cd "$INSTALL_DIR" && gh release download -R jackwener/opencli \
            -p "opencli-extension-*.zip" --clobber 2>&1 ) | tail -3 || true
    elif command -v curl >/dev/null 2>&1; then
        echo "       下载最新 extension (via curl)..."
        EXT_URL="$(curl -s https://api.github.com/repos/jackwener/opencli/releases/latest \
                   | grep browser_download_url | grep opencli-extension | head -1 \
                   | sed -E 's/.*"(https[^"]+)".*/\1/')"
        if [ -n "$EXT_URL" ]; then
            curl -fsSL "$EXT_URL" -o "$INSTALL_DIR/$(basename "$EXT_URL")"
        fi
    fi

    # 解压最新的 zip
    LATEST_ZIP="$(ls -t $EXT_ZIP_GLOB 2>/dev/null | head -1)"
    if [ -n "$LATEST_ZIP" ] && command -v unzip >/dev/null 2>&1; then
        rm -rf "$EXT_DIR"
        unzip -q "$LATEST_ZIP" -d "$EXT_DIR"
        echo "       ✓ extension 解压到: $EXT_DIR"
    else
        echo "       ⚠ 无法自动下载 extension，请手动："
        echo "         1. 下 https://github.com/jackwener/opencli/releases/latest 的 opencli-extension-*.zip"
        echo "         2. 解压到任意目录"
    fi
fi
echo ""

# 平台相关：尝试帮用户开 Chrome 的 extensions 页面
echo "       下面把 Chrome 的 extensions 页面打开，你只要做 3 件事:"
echo "         1. 右上角开 'Developer mode'"
echo "         2. 点 'Load unpacked'"
echo "         3. 选目录: $EXT_DIR"
echo ""
case "$PLATFORM" in
    darwin)  open -a "Google Chrome" "chrome://extensions/" 2>/dev/null || true ;;
    linux)   ( google-chrome "chrome://extensions/" 2>/dev/null \
              || chromium "chrome://extensions/" 2>/dev/null \
              || xdg-open "chrome://extensions/" 2>/dev/null ) & ;;
    windows) start chrome "chrome://extensions/" 2>/dev/null || true ;;
esac
echo "       (如果 Chrome 没自动开，地址栏粘 chrome://extensions/)"
echo ""

echo "✅ 安装完成"
echo ""
echo "下一步:"
echo "  1. 在 Chrome 里 Load unpacked → $EXT_DIR"
echo "  2. 验证连通: opencli doctor && web-publish health juejin"
echo "  3. 浏览器登录目标平台 (juejin.cn / csdn.net / zhihu.com)"
echo "  4. 跑 claude，输入: /publish juejin path/to/article.md"
echo "     或直接说: '把 ./article.md 发到掘金'"
echo ""
echo "  服务器 / 无浏览器场景: 跑 'web-publish setup' 走 urllib backend (用 .env cookie)"
echo ""
echo "卸载: ./uninstall.sh"
