#!/usr/bin/env bash
# uninstall.sh — 拆掉 web-publish。

set -euo pipefail

echo "▶ web-publish uninstaller"

INSTALL_DIR="$HOME/.web-publish"
CLAUDE_SKILLS="$HOME/.claude/skills"
CLAUDE_COMMANDS="$HOME/.claude/commands"
LOCAL_BIN="$HOME/.local/bin"

# 1. 删 skill / command + web-publish CLI 软链
echo "[1/3] 删 skill / slash command / CLI 软链..."
rm -rf "$CLAUDE_SKILLS/web-publish"
rm -f "$CLAUDE_COMMANDS/publish.md"
rm -f "$LOCAL_BIN/web-publish"
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

# 3. 提示剩余文件 + Chrome extension
echo ""
echo "[3/3] 数据目录 + Chrome extension:"
if [ -d "$INSTALL_DIR" ]; then
    echo "       $INSTALL_DIR 仍含:"
    echo "         - adapters/           (平台 endpoint 配置)"
    echo "         - opencli-extension/  (Chrome extension 解压文件)"
    echo "         - venv/               (Python venv: web-publish CLI 实体)"
    echo "         - .env                (urllib backend cookie, 如跑过 setup)"
    echo "         - state.json          (publish 计数 / cookie 引导互动状态)"
    echo "       要彻底清: rm -rf $INSTALL_DIR"
fi
echo ""
echo "       Chrome Browser Bridge extension 要手动卸:"
echo "         1. 打开 chrome://extensions/"
echo "         2. 找到 'OpenCLI Browser Bridge' 卡片"
echo "         3. 点 'Remove' / 移除"
echo "         （只删本地文件 Chrome 里 extension 还在 — Load unpacked 是引用路径，"
echo "          文件没了 extension 会报错但 Chrome 不会自动清掉它）"
echo ""
echo "       npm prefix 变更（如果是 install.sh 配的 ~/.npm-global）:"
echo "         install.sh 可能改过你 npm 全局 prefix 到 ~/.npm-global 并加到 ~/.zshrc / ~/.bashrc"
echo "         要还原: npm config delete prefix; 并手动删 shell rc 里那行 PATH"
echo ""

echo "✅ Claude Code 本身完全不受影响"
