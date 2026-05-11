#!/usr/bin/env bash
# curl-install.sh — 远程一键安装入口
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/PsChina/publish-to-juejin/main/curl-install.sh | bash

set -euo pipefail

REPO_URL="https://github.com/PsChina/publish-to-juejin.git"
INSTALL_DIR="${PUBLISH_JUEJIN_DIR:-$HOME/.local/share/publish-to-juejin}"

echo "▶ publish-to-juejin 远程安装器"
echo "  目标: $INSTALL_DIR"
echo ""

if ! command -v git >/dev/null 2>&1; then
    echo "✗ git 未安装"
    case "$(uname -s 2>/dev/null)" in
        Darwin*) echo "  Mac: 跑 'xcode-select --install' 或 'brew install git'" ;;
        Linux*)  echo "  Linux: apt install git / dnf install git / pacman -S git" ;;
        MINGW*|CYGWIN*|MSYS*) echo "  Windows: Git Bash 应该自带 git，请重装 Git for Windows" ;;
    esac
    exit 1
fi

mkdir -p "$(dirname "$INSTALL_DIR")"
if [ -d "$INSTALL_DIR/.git" ]; then
    echo "▶ 已 clone，pull 最新..."
    cd "$INSTALL_DIR" && git pull --ff-only
else
    echo "▶ clone 到 $INSTALL_DIR..."
    git clone --depth=1 "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi
echo ""

exec ./install.sh
