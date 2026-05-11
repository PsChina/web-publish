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
echo "[1/4] 检测 Node.js (>=21)..."
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
echo "[2/4] 装 OpenCLI ($OPENCLI_PACKAGE)..."
if command -v opencli >/dev/null 2>&1; then
    OPENCLI_VERSION="$(opencli --version 2>&1 | head -1)"
    echo "       已装: $OPENCLI_VERSION"
else
    echo "       npm install -g $OPENCLI_PACKAGE ..."
    npm install -g "$OPENCLI_PACKAGE" 2>&1 | tail -3
    if ! command -v opencli >/dev/null 2>&1; then
        echo "✗ OpenCLI 装完但 'opencli' 不在 PATH"
        echo "  可能是 npm prefix 没在 PATH，try: export PATH=\"\$(npm prefix -g)/bin:\$PATH\""
        exit 1
    fi
    echo "       ✓ $(opencli --version 2>&1 | head -1)"
fi
echo ""

# ===== Step 3: 部署 skill / command / adapters =====
echo "[3/4] 部署 skill / slash command / adapters..."
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

# ===== Step 4: 引导用户装 Chrome Browser Bridge extension =====
echo "[4/4] Chrome Browser Bridge extension"
echo ""
echo "       OpenCLI 用 Chrome extension 跟你的浏览器通信，复用已登录态。"
echo "       这是一次性操作（换机才需要重做）。"
echo ""
echo "       方式 A — Chrome Web Store (推荐):"
echo "         1. https://chrome.google.com/webstore"
echo "         2. 搜 'OpenCLI Browser Bridge'"
echo "         3. 点 'Add to Chrome' 并授权"
echo ""
echo "       方式 B — Load unpacked (商店还没上架时):"
echo "         1. 从 https://github.com/jackwener/OpenCLI/releases 下 extension.zip"
echo "         2. 解压"
echo "         3. Chrome 地址栏: chrome://extensions"
echo "         4. 开 'Developer mode'"
echo "         5. 'Load unpacked' → 选解压目录"
echo ""
echo "       装好后跑 'opencli doctor' 验证连通"
echo ""

echo "✅ 安装完成"
echo ""
echo "下一步:"
echo "  1. 装 Chrome Browser Bridge extension (上面)"
echo "  2. 浏览器登录目标平台 (juejin.cn / csdn.net / zhihu.com)"
echo "  3. 跑 claude，输入: /publish juejin path/to/article.md"
echo "     或直接说: '把 ./article.md 发到掘金'"
echo ""
echo "卸载: ./uninstall.sh"
