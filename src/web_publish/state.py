"""~/.web-publish/state.json — 持久化用户互动状态 (cookie setup / publish count).

让 Claude 在 skill 层做"首次引导 cookie / 10 分钟超时降级 / skip 3 次后不再问"决策。
"""
from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from pathlib import Path

STATE_VERSION = 1
DEFAULT_PATH = Path(os.path.expanduser("~/.web-publish/state.json"))

# 状态机参数
COOKIE_SETUP_TIMEOUT_SECONDS = 600  # 10 分钟
COOKIE_SKIP_MAX = 3  # 最多温和问 3 次

DEFAULTS: dict = {
    "version": STATE_VERSION,
    "publish_count": 0,
    "setup_completed": False,
    "cookie_setup_started_at": None,  # ISO 8601 UTC, set 时表示已引导用户去 setup
    "cookie_skip_count": 0,
    "cookie_dismissed": False,
    "last_publish_at": None,
    "last_backend_used": None,
}


def _now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _parse_iso(s: str | None) -> datetime | None:
    if not s:
        return None
    try:
        return datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    except (ValueError, TypeError):
        return None


def load(path: Path = DEFAULT_PATH) -> dict:
    """读 state.json, 缺字段用 DEFAULTS 填 (forward-compatible)."""
    if not path.is_file():
        return dict(DEFAULTS)
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        merged = dict(DEFAULTS)
        if isinstance(data, dict):
            merged.update(data)
        return merged
    except (json.JSONDecodeError, OSError):
        return dict(DEFAULTS)


def save(state: dict, path: Path = DEFAULT_PATH) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(state, indent=2, ensure_ascii=False), encoding="utf-8")
    try:
        os.chmod(path, 0o600)
    except OSError:
        pass


def reset(path: Path = DEFAULT_PATH) -> None:
    if path.is_file():
        path.unlink()


# ---- mutators ----

def record_publish(backend_name: str, path: Path = DEFAULT_PATH) -> dict:
    s = load(path)
    s["publish_count"] = int(s.get("publish_count", 0)) + 1
    s["last_publish_at"] = _now_iso()
    s["last_backend_used"] = backend_name
    save(s, path)
    return s


def record_setup_started(path: Path = DEFAULT_PATH) -> dict:
    s = load(path)
    if not s.get("cookie_setup_started_at"):
        s["cookie_setup_started_at"] = _now_iso()
    save(s, path)
    return s


def record_setup_completed(path: Path = DEFAULT_PATH) -> dict:
    s = load(path)
    s["setup_completed"] = True
    s["cookie_setup_started_at"] = None
    s["cookie_dismissed"] = False
    s["cookie_skip_count"] = 0
    save(s, path)
    return s


def record_skip(path: Path = DEFAULT_PATH) -> dict:
    s = load(path)
    s["cookie_skip_count"] = int(s.get("cookie_skip_count", 0)) + 1
    if s["cookie_skip_count"] >= COOKIE_SKIP_MAX:
        s["cookie_dismissed"] = True
    save(s, path)
    return s


# ---- derived properties (供 Claude 决策) ----

def setup_timeout_elapsed(state: dict) -> bool:
    """已引导用户去 setup, 但超过 10 分钟还没完成?"""
    t = _parse_iso(state.get("cookie_setup_started_at"))
    if not t:
        return False
    elapsed = (datetime.now(timezone.utc) - t).total_seconds()
    return elapsed > COOKIE_SETUP_TIMEOUT_SECONDS


def recommend(state: dict, env_exists: bool) -> dict:
    """给 Claude 一个"现在该怎么做"的推荐。

    返回 {action, reason}:
      action ∈ {
        "use_urllib",                # .env 在 + setup_completed
        "guide_setup_first_time",    # 首次, 引导用户
        "use_opencli_after_timeout", # 引导过但超时, 自动降级
        "use_opencli_dismissed",     # 用户已 dismiss
        "use_opencli_skipped",       # 跑过 skip 但没满 3 次, 仍走 opencli
        "ask_after_publish",         # 走 opencli 发完后, 温和问一次 (skip < 3)
      }
    """
    if env_exists and state.get("setup_completed"):
        return {"action": "use_urllib", "reason": ".env 在且 setup 完成"}
    if env_exists and not state.get("setup_completed"):
        # 用户手动写了 .env 没经过 setup 命令, 也算完成
        return {"action": "use_urllib", "reason": ".env 在 (旁路 setup)"}
    if state.get("cookie_dismissed"):
        return {"action": "use_opencli_dismissed", "reason": f"skip_count={state.get('cookie_skip_count', 0)} 已达上限"}
    if state.get("cookie_setup_started_at") and setup_timeout_elapsed(state):
        return {"action": "use_opencli_after_timeout", "reason": "引导过 setup 超 10 分钟未完成"}
    if not state.get("cookie_setup_started_at"):
        return {"action": "guide_setup_first_time", "reason": "首次发文章, 还没引导过"}
    # 引导过但 .env 仍没生成, 用户回到对话: 给 opencli 兜底, 之后再温和问
    return {"action": "use_opencli_skipped", "reason": "上次引导未完成, 这次用 opencli 兜底"}
