"""引导用户首次写 ~/.web-publish/.env (urllib backend 用).

input() 对超长字符串 (掘金 cookie 经常 1-2KB) 会在 macOS Terminal readline
buffer 上卡住. 改用"生成模板 + 自动打开编辑器"方式, 用户在编辑器里粘贴 cookie
保存即可, 不受输入长度限制.
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path


TEMPLATE = """\
# web-publish v0.3 — urllib backend cookie (chmod 600)
#
# 填法 (用编辑器粘贴, 不要用 echo 命令避免暴露到 shell history):
#
# JUEJIN_COOKIE  = 整段 Cookie header
#   - 法 1 (推荐): Chrome 装 Cookie-Editor extension → 点图标 → Export → Header String → 粘到下面
#   - 法 2: Chrome F12 → Network → 任意 juejin.cn 请求 → Request Headers → 复制整行 "Cookie: ..." 后面的部分
#
# JUEJIN_UUID = 用户标识
#   - Chrome 任意 juejin api 请求 URL 里的 query: ?aid=2608&uuid=<这串>
#
# 填完保存退出, web-publish 会自动 chmod 600.

JUEJIN_COOKIE=
JUEJIN_AID=2608
JUEJIN_UUID=
"""


def _detect_editor() -> list[str]:
    """挑一个可用编辑器, 跨平台.

    Linux/macOS: $EDITOR / $VISUAL / nano / vim
    Windows: $EDITOR / notepad
    """
    env_choice = os.environ.get("EDITOR") or os.environ.get("VISUAL")
    if env_choice:
        return [env_choice]

    if sys.platform.startswith("win"):
        for cand in ("notepad",):
            if shutil.which(cand):
                return [cand]
    else:
        for cand in ("nano", "vim", "vi"):
            if shutil.which(cand):
                return [cand]
    return []


def _file_filled(env_path: Path) -> tuple[bool, str]:
    """检测 .env 是否两个必填字段都填了 (非空 / 非模板)."""
    if not env_path.is_file():
        return False, "文件不存在"
    text = env_path.read_text(encoding="utf-8")
    have = {}
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("#") or "=" not in line:
            continue
        k, _, v = line.partition("=")
        have[k.strip()] = v.strip()
    cookie = have.get("JUEJIN_COOKIE", "")
    uuid = have.get("JUEJIN_UUID", "")
    if not cookie:
        return False, "JUEJIN_COOKIE 还是空"
    if not uuid:
        return False, "JUEJIN_UUID 还是空"
    if len(cookie) < 50:
        return False, f"JUEJIN_COOKIE 太短 ({len(cookie)} 字符), 是不是没贴完?"
    return True, "ok"


def run_setup(platform: str = "juejin", mode: str = "edit") -> None:
    """mode: 'edit' (默认, 开编辑器) / 'stdin' (从 stdin 读到 EOF)."""
    if platform != "juejin":
        raise SystemExit(f"v0.3 只支持 juejin setup, {platform} 待后续 adapter")

    env_path = Path(os.path.expanduser("~/.web-publish/.env"))
    env_path.parent.mkdir(parents=True, exist_ok=True)

    # 已有文件就直接打开编辑, 不覆盖
    if not env_path.is_file():
        env_path.write_text(TEMPLATE, encoding="utf-8")
        print(f"已生成模板: {env_path}")
    else:
        print(f"已存在: {env_path} (打开编辑, 不会覆盖现有值)")

    try:
        os.chmod(env_path, 0o600)
    except OSError:
        pass  # Windows 跳过

    if mode == "stdin":
        # 不开编辑器, 从 stdin 读到 EOF (适合 cat cookie.txt | web-publish setup --stdin)
        print(
            "stdin 模式: 粘贴 'JUEJIN_COOKIE=xxx\\nJUEJIN_UUID=yyy\\n' 到下面, "
            "结束按 Ctrl-D (Linux/macOS) 或 Ctrl-Z+Enter (Windows):",
            file=sys.stderr,
        )
        payload = sys.stdin.read()
        # append 而不是覆盖, 保留模板注释
        with env_path.open("a", encoding="utf-8") as f:
            f.write("\n# === injected via --stdin ===\n")
            f.write(payload)
    else:
        editor = _detect_editor()
        if not editor:
            print(
                f"⚠ 找不到编辑器 (没 $EDITOR / nano / vim / notepad).\n"
                f"请用任意编辑器手动编辑: {env_path}\n"
                f"或重跑: web-publish setup --stdin 走 stdin 模式",
                file=sys.stderr,
            )
            print(f"模板位置: {env_path}")
            return
        print(f"用 {editor[0]} 打开 {env_path}, 填完保存退出...")
        try:
            subprocess.run([*editor, str(env_path)], check=False)
        except FileNotFoundError as e:
            raise SystemExit(f"编辑器启动失败: {e}")

    # 验证填了
    ok, msg = _file_filled(env_path)
    if not ok:
        print(f"⚠ .env 还没填完: {msg}", file=sys.stderr)
        print(f"  再编辑一次: web-publish setup  (或直接编辑 {env_path})", file=sys.stderr)
        sys.exit(1)
    try:
        os.chmod(env_path, 0o600)
    except OSError:
        pass
    print(f"✓ {env_path} 已就绪 (权限 600)")
    print("跑 `web-publish health juejin` 验证")
