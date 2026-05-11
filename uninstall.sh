#!/usr/bin/env bash
# uninstall.sh — 拆掉 web-publish。

set -euo pipefail

echo "▶ web-publish uninstaller"

INSTALL_DIR="$HOME/.web-publish"
CLAUDE_SKILLS="$HOME/.claude/skills"
CLAUDE_COMMANDS="$HOME/.claude/commands"

# 1. 删 skill / command
echo "[1/3] 删 skill / slash command..."
rm -rf "$CLAUDE_SKILLS/web-publish"
rm -f "$CLAUDE_COMMANDS/publish.md"
echo "       ✓ 已删"

# 2. 询问要不要卸载 OpenCLI 全局 npm 包
echo ""
echo "[2/3] OpenCLI 全局 npm 包 (@jackwener/opencli):"
if command -v opencli >/dev/null 2>&1; then
    OPENCLI_PATH="$(command -v opencli)"
    echo "       位置: $OPENCLI_PATH"
    echo "       (其他项目可能也在用，卸了它们会受影响)"
    echo ""

    REMOVE_OPENCLI=""
    if [ -e /dev/tty ] && [ -r /dev/tty ]; then
        read -r -p "       要 npm uninstall -g @jackwener/opencli 吗? [y/N]: " REMOVE_OPENCLI < /dev/tty || true
    elif [ -t 0 ]; then
        read -r -p "       要 npm uninstall -g @jackwener/opencli 吗? [y/N]: " REMOVE_OPENCLI || true
    fi

    case "${REMOVE_OPENCLI:-n}" in
        [yY]|[yY][eE][sS])
            npm uninstall -g @jackwener/opencli 2>&1 | tail -3
            echo "       ✓ 已卸载 OpenCLI"
            ;;
        *)
            echo "       保留 OpenCLI（手动卸: npm uninstall -g @jackwener/opencli）"
            ;;
    esac
else
    echo "       未检测到 opencli 全局包，跳过"
fi

# 3. 提示剩余文件
echo ""
echo "[3/3] 数据目录:"
if [ -d "$INSTALL_DIR" ]; then
    echo "       $INSTALL_DIR 仍含 adapter 配置 / 日志"
    echo "       要彻底清: rm -rf $INSTALL_DIR"
fi
echo ""
echo "       Chrome Browser Bridge extension 要在 chrome://extensions 手动卸"
echo ""

echo "✅ Claude Code 本身完全不受影响"
