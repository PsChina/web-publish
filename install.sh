#!/usr/bin/env bash
# install.sh — 一键把 publish-to-juejin 装到 Claude Code。
#
# 自动处理：
#   - 检测 Go；没有就用官方 release binary 装到 ~/.publish-to-juejin/go/
#     （不污染系统，无需 brew / sudo）
#   - clone + go build androidZzT/juejin-mcp 到 ~/.publish-to-juejin/juejin-mcp/
#   - 启动 juejin-mcp daemon（端口 18080）
#   - 部署 skill + slash command 到 ~/.claude/
#   - 引导用户扫码登录掘金
#
# 跨平台：macOS / Linux / Windows MINGW64。

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/.publish-to-juejin"
GO_DIR="$INSTALL_DIR/go"
MCP_DIR="$INSTALL_DIR/juejin-mcp"
GO_VERSION="1.22.0"
CLAUDE_SKILLS="$HOME/.claude/skills"
CLAUDE_COMMANDS="$HOME/.claude/commands"
JUEJIN_MCP_REPO="https://github.com/androidZzT/juejin-mcp.git"

echo "▶ publish-to-juejin installer"
echo "  project: $PROJECT_ROOT"
echo "  install dir: $INSTALL_DIR"
echo ""

# ===== 平台 / 架构探测 =====
case "$(uname -s 2>/dev/null)" in
    Linux*)               PLATFORM=linux ;;
    Darwin*)              PLATFORM=darwin ;;
    MINGW*|CYGWIN*|MSYS*) PLATFORM=windows ;;
    *)                    PLATFORM=unknown ;;
esac
case "$(uname -m 2>/dev/null)" in
    x86_64|amd64)  ARCH=amd64 ;;
    arm64|aarch64) ARCH=arm64 ;;
    *)             ARCH=unknown ;;
esac
echo "  platform: $PLATFORM/$ARCH"
echo ""

# ===== Step 1: 准备 Go 工具链 =====
GO_BIN=""
detect_go() {
    if command -v go >/dev/null 2>&1; then
        GO_BIN="$(command -v go)"
        return 0
    fi
    if [ -x "$GO_DIR/bin/go" ]; then
        GO_BIN="$GO_DIR/bin/go"
        export PATH="$GO_DIR/bin:$PATH"
        return 0
    fi
    return 1
}

install_go() {
    if [ "$PLATFORM" = "unknown" ] || [ "$ARCH" = "unknown" ]; then
        echo "✗ 不支持的平台/架构 ($PLATFORM/$ARCH)"
        echo "  请手动从 https://go.dev/dl/ 下载 Go 后重跑本脚本"
        exit 1
    fi

    if [ "$PLATFORM" = "windows" ]; then
        local archive="go${GO_VERSION}.windows-${ARCH}.zip"
    else
        local archive="go${GO_VERSION}.${PLATFORM}-${ARCH}.tar.gz"
    fi
    local url="https://go.dev/dl/${archive}"

    echo "  下载 Go ${GO_VERSION} ($PLATFORM/$ARCH)..."
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"

    if ! curl -fsSL "$url" -o "$archive"; then
        echo "✗ 下载失败: $url"
        echo "  检查网络后重试。如果在中国大陆可能需要代理。"
        exit 1
    fi

    echo "  解压..."
    rm -rf "$GO_DIR"
    if [ "$PLATFORM" = "windows" ]; then
        unzip -q "$archive"
    else
        tar -xzf "$archive"
    fi
    rm -f "$archive"

    if [ ! -x "$GO_DIR/bin/go" ]; then
        echo "✗ Go 解压完但 $GO_DIR/bin/go 不存在"
        exit 1
    fi
    export PATH="$GO_DIR/bin:$PATH"
    GO_BIN="$GO_DIR/bin/go"
    echo "  ✓ Go ${GO_VERSION} 装到 $GO_DIR (不污染系统 PATH)"
}

if detect_go; then
    echo "[1/5] Go 已存在: $($GO_BIN version)"
else
    echo "[1/5] Go 不在 PATH，开始自动下载..."
    install_go
fi
echo ""

# ===== Step 2: clone + build juejin-mcp =====
if [ ! -d "$MCP_DIR/.git" ]; then
    echo "[2/5] clone juejin-mcp 到 $MCP_DIR..."
    mkdir -p "$(dirname "$MCP_DIR")"
    git clone --depth=1 "$JUEJIN_MCP_REPO" "$MCP_DIR" 2>&1 | tail -3
else
    echo "[2/5] juejin-mcp 已 clone，pull 最新..."
    cd "$MCP_DIR" && git pull --ff-only 2>&1 | tail -2
fi
echo ""

echo "[3/5] go build juejin-mcp..."
cd "$MCP_DIR"
# GOPATH 用项目内目录，避免污染用户 ~/go
export GOPATH="$INSTALL_DIR/gopath"
export GOCACHE="$INSTALL_DIR/gocache"
mkdir -p "$GOPATH" "$GOCACHE"

# Windows binary 要带 .exe 后缀
if [ "$PLATFORM" = "windows" ]; then
    MCP_BIN="$INSTALL_DIR/juejin-mcp.exe"
else
    MCP_BIN="$INSTALL_DIR/juejin-mcp"
fi

"$GO_BIN" build -o "$MCP_BIN" . 2>&1 | tail -5
[ -x "$MCP_BIN" ] || { echo "✗ build 失败，没生成 binary: $MCP_BIN"; exit 1; }
echo "  ✓ binary: $MCP_BIN"
echo ""

# ===== Step 4: 部署 skill + command =====
echo "[4/5] 部署 skill + slash command 到 ~/.claude/..."
mkdir -p "$CLAUDE_SKILLS" "$CLAUDE_COMMANDS"

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

deploy_link "$PROJECT_ROOT/skills/publish-to-juejin" \
            "$CLAUDE_SKILLS/publish-to-juejin" "skill"
deploy_link "$PROJECT_ROOT/commands/juejin.md" \
            "$CLAUDE_COMMANDS/juejin.md" "command"
echo ""

# ===== Step 5: 启动 juejin-mcp daemon + 引导登录 =====
echo "[5/5] 启动 juejin-mcp daemon (端口 18080)..."

LOG_FILE="$INSTALL_DIR/juejin-mcp.log"

start_daemon() {
    case "$PLATFORM" in
        windows)
            # MINGW64 上 nohup 行为诡异，用 start 后台启动更稳
            # cmd /c start /B 把进程脱离当前 bash session
            if command -v start >/dev/null 2>&1; then
                cmd //c "start /B \"\" \"$MCP_BIN\" > \"$LOG_FILE\" 2>&1"
            else
                # 退路：用 & 后台
                "$MCP_BIN" > "$LOG_FILE" 2>&1 &
                disown 2>/dev/null || true
            fi
            ;;
        *)
            # macOS / Linux: nohup + & 经典方案
            nohup "$MCP_BIN" > "$LOG_FILE" 2>&1 &
            disown 2>/dev/null || true
            ;;
    esac
}

# 检测是否已经在跑（跨平台用 curl）
if curl -fsS --max-time 2 http://127.0.0.1:18080/health 2>/dev/null | grep -q "."; then
    echo "       daemon 已在跑，跳过启动"
else
    start_daemon
    echo "       已后台启动，日志: $LOG_FILE"
    sleep 3
    if curl -fsS --max-time 2 http://127.0.0.1:18080/health 2>/dev/null | grep -q "."; then
        echo "       ✓ daemon 健康检查通过"
    else
        echo "       ⚠ daemon 启动可能失败，看 $LOG_FILE 或手动跑:"
        echo "         $MCP_BIN"
    fi
fi
echo ""

echo "✅ 安装完成"
echo ""
echo "下一步: 登录掘金"
echo "  1. 跑 claude，输入: 帮我用 publish-to-juejin 登录掘金"
echo "  2. Claude 会调 juejin-mcp 的 get_login_qrcode 工具拿到二维码"
echo "  3. 用掘金 App 扫码完成登录"
echo ""
echo "之后用法:"
echo "  /juejin path/to/article.md                  # 强制发"
echo "  发掘金这篇 ./blog.md                        # 自动派工"
echo ""
echo "卸载: ./uninstall.sh"
