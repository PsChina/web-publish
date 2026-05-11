#!/usr/bin/env bash
# uninstall.sh — 拆掉 publish-to-juejin。

set -euo pipefail

echo "▶ publish-to-juejin uninstaller"

INSTALL_DIR="$HOME/.publish-to-juejin"
GO_DIR="$INSTALL_DIR/go"
MCP_BIN_UNIX="$INSTALL_DIR/juejin-mcp"
MCP_BIN_WIN="$INSTALL_DIR/juejin-mcp.exe"
CLAUDE_SKILLS="$HOME/.claude/skills"
CLAUDE_COMMANDS="$HOME/.claude/commands"

case "$(uname -s 2>/dev/null)" in
    MINGW*|CYGWIN*|MSYS*) PLATFORM=windows ;;
    *) PLATFORM=unix ;;
esac

# 1. 杀 daemon
echo "[1/4] 停止 juejin-mcp daemon..."
if [ "$PLATFORM" = "windows" ]; then
    taskkill //IM juejin-mcp.exe //F 2>/dev/null || echo "       未在跑"
else
    pkill -f "juejin-mcp$" 2>/dev/null || echo "       未在跑"
fi

# 2. 删 skill / command
echo "[2/4] 删 skill / slash command..."
rm -rf "$CLAUDE_SKILLS/publish-to-juejin"
rm -f "$CLAUDE_COMMANDS/juejin.md"
echo "       ✓ 已删"

# 3. 询问要不要卸载我们自己下载的 Go
echo ""
echo "[3/4] 我们安装时自动下载的 Go 工具链:"
if [ -d "$GO_DIR" ]; then
    GO_SIZE="$(du -sh "$GO_DIR" 2>/dev/null | cut -f1 || echo '?')"
    echo "       位置: $GO_DIR ($GO_SIZE)"
    echo "       (这是 install.sh 装到 ~/.publish-to-juejin/go/ 的本地 Go，不影响系统 Go)"
    echo ""

    REMOVE_GO=""
    # 支持 curl|bash 场景从 /dev/tty 读
    if [ -e /dev/tty ] && [ -r /dev/tty ]; then
        read -r -p "       要卸载这份 Go 吗? [y/N]: " REMOVE_GO < /dev/tty || true
    elif [ -t 0 ]; then
        read -r -p "       要卸载这份 Go 吗? [y/N]: " REMOVE_GO || true
    fi

    case "${REMOVE_GO:-n}" in
        [yY]|[yY][eE][sS])
            rm -rf "$GO_DIR"
            # GOPATH / GOCACHE 也是我们装的，一起清
            rm -rf "$INSTALL_DIR/gopath" "$INSTALL_DIR/gocache"
            echo "       ✓ 已卸载 Go"
            ;;
        *)
            echo "       保留 Go（要手动删: rm -rf $GO_DIR）"
            ;;
    esac
else
    echo "       未检测到本地 Go（可能 install 时用了系统 Go），跳过"
fi

# 4. 提示剩余文件
echo ""
echo "[4/4] 剩余数据:"
if [ -d "$INSTALL_DIR" ]; then
    REMAINING="$(ls "$INSTALL_DIR" 2>/dev/null || echo '(空)')"
    if [ -n "$REMAINING" ] && [ "$REMAINING" != "(空)" ]; then
        echo "       $INSTALL_DIR 仍含:"
        ls -la "$INSTALL_DIR" 2>/dev/null | tail -n +4 | awk '{print "         " $NF}'
        echo ""
        echo "       (含掘金登录 cookie / juejin-mcp 源码 / 日志)"
        echo "       要彻底清: rm -rf $INSTALL_DIR"
    else
        rmdir "$INSTALL_DIR" 2>/dev/null && echo "       ✓ 数据目录已空，已删"
    fi
fi

echo ""
echo "✅ Claude Code 本身完全不受影响"
