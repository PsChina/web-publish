"""Backend abstraction: POST to platform API and return parsed data dict.

Two implementations:
- UrllibBackend       : .env + urllib (传统模式, 服务器友好)
- OpenCLIBridgeBackend: opencli browser eval + same-origin fetch (零 cookie 配置)
"""
from __future__ import annotations

import json
import os
import shlex
import shutil
import ssl
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path


class BackendError(RuntimeError):
    pass


def _err_msg_for_api(data: dict) -> str:
    return f"err_no={data.get('err_no')} err_msg={data.get('err_msg')!r}"


# ---------- UrllibBackend ----------

class UrllibBackend:
    name = "urllib"

    def __init__(self, base: str, env_file: str | None = None):
        self.base = base.rstrip("/")
        self.env = self._load_env(env_file or os.path.expanduser("~/.web-publish/.env"))

    @staticmethod
    def _load_env(path: str) -> dict:
        p = Path(path)
        if not p.is_file():
            raise BackendError(
                f"找不到 {path}; 跑 `web-publish setup` 引导写一份，或换 --backend opencli-bridge"
            )
        env: dict[str, str] = {}
        for line in p.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, _, v = line.partition("=")
            env[k.strip()] = v.strip().strip('"').strip("'")
        for required in ("JUEJIN_COOKIE", "JUEJIN_UUID"):
            if not env.get(required):
                raise BackendError(f"{path} 缺 {required}; 重跑 `web-publish setup`")
        env.setdefault("JUEJIN_AID", "2608")
        return env

    def _headers(self) -> dict:
        return {
            "Cookie": self.env["JUEJIN_COOKIE"],
            "Content-Type": "application/json; charset=utf-8",
            "Accept": "*/*",
            "Origin": "https://juejin.cn",
            "Referer": "https://juejin.cn/",
            "User-Agent": (
                "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
                "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
            ),
        }

    def post(self, path: str, payload: dict, query_params: dict | None = None) -> dict:
        params = {"aid": self.env["JUEJIN_AID"], "uuid": self.env["JUEJIN_UUID"], "spider": "0"}
        if query_params:
            params.update({k: str(v) for k, v in query_params.items()})
        qs = "&".join(f"{k}={v}" for k, v in params.items())
        url = f"{self.base}{path}?{qs}"

        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        req = urllib.request.Request(url, data=body, headers=self._headers(), method="POST")
        try:
            with urllib.request.urlopen(req, timeout=30, context=ssl.create_default_context()) as resp:
                data = json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            detail = e.read().decode("utf-8", errors="replace")
            raise BackendError(f"HTTP {e.code} on {path}: {detail}") from e
        except urllib.error.URLError as e:
            raise BackendError(f"URL error on {path}: {e}") from e

        if data.get("err_no") != 0:
            raise BackendError(f"{path}: {_err_msg_for_api(data)}")
        return data.get("data", {})


# ---------- OpenCLIBridgeBackend ----------

class OpenCLIBridgeBackend:
    """跑 opencli browser eval 让浏览器在已登录 page 内做同源 fetch.

    前置: opencli 在 PATH; Chrome Browser Bridge extension 已装且 doctor 通.
    cookie 不离开浏览器, 用户不需要写 .env.
    """

    name = "opencli-bridge"

    def __init__(self, base: str, opencli_path: str | None = None):
        self.base = base.rstrip("/")
        self.opencli = opencli_path or self._find_opencli()
        if not self.opencli:
            raise BackendError(
                "找不到 opencli; 装一份 (npm install -g @jackwener/opencli) "
                "或重跑 install.sh; 也可以换 --backend urllib"
            )

    @staticmethod
    def _find_opencli() -> str | None:
        which = shutil.which("opencli")
        if which:
            return which
        # 用户级常见安装位置
        for cand in (
            os.path.expanduser("~/.npm-global/bin/opencli"),
            os.path.expanduser("~/.npm-global/opencli"),
            "/usr/local/bin/opencli",
        ):
            if Path(cand).is_file() and os.access(cand, os.X_OK):
                return cand
        return None

    def post(self, path: str, payload: dict, query_params: dict | None = None) -> dict:
        # 在 page 上下文里跑同源 fetch; 不需要 aid/uuid (cookie 同源带)
        # 但路径上加 aid/uuid 有些 endpoint 要 — 用 yaml 里 query_params 默认值
        params = dict(query_params or {})
        params.setdefault("spider", "0")
        qs = "&".join(f"{k}={v}" for k, v in params.items())
        full_path = f"{path}?{qs}" if qs else path

        payload_json = json.dumps(payload, ensure_ascii=False)
        # JS 注入: 用 JSON 自身做引号 safe; payload 通过 JSON.parse 拿回
        js = (
            "(async () => {"
            f"  const payload = JSON.parse({json.dumps(payload_json)});"
            f"  const r = await fetch({json.dumps(full_path)}, {{"
            "    method:'POST', credentials:'include',"
            "    headers:{'content-type':'application/json'},"
            "    body: JSON.stringify(payload)"
            "  });"
            "  return JSON.stringify(await r.json());"
            "})()"
        )

        try:
            proc = subprocess.run(
                [self.opencli, "browser", "eval", js],
                capture_output=True, text=True, timeout=60,
            )
        except subprocess.TimeoutExpired as e:
            raise BackendError(f"opencli eval 超时: {e}") from e
        if proc.returncode != 0:
            raise BackendError(
                f"opencli eval 失败 (rc={proc.returncode}):\nstdout: {proc.stdout}\nstderr: {proc.stderr}"
            )

        # opencli 输出是 page 内 JS 返回值 (JSON string) — eval 命令把它包了一层
        # 实测: opencli 直接输出 JSON 串 (我们的 JS return 的就是 JSON.stringify(...))
        raw = proc.stdout.strip()
        if not raw:
            raise BackendError(f"opencli eval 返回空; stderr: {proc.stderr}")
        # opencli 可能输出带引号的 JSON-string (双重 stringify), 或直接 JSON 对象
        # 试 robust 解析:
        try:
            data = json.loads(raw)
        except json.JSONDecodeError as e:
            raise BackendError(f"opencli 输出不是 JSON: {raw[:500]}") from e
        if isinstance(data, str):
            # opencli 把我们的 JSON.stringify 又当字符串输出了, 再解一层
            try:
                data = json.loads(data)
            except json.JSONDecodeError as e:
                raise BackendError(f"opencli 二次 JSON 解析失败: {data[:500]}") from e

        if not isinstance(data, dict):
            raise BackendError(f"opencli 返回非 dict: {type(data).__name__}: {data!r}"[:500])

        if data.get("err_no") != 0:
            raise BackendError(f"{path}: {_err_msg_for_api(data)}")
        return data.get("data", {})


def make_backend(name: str, base: str, **kwargs):
    if name in ("opencli-bridge", "opencli", "bridge"):
        return OpenCLIBridgeBackend(base, **{k: v for k, v in kwargs.items() if k == "opencli_path"})
    if name in ("urllib", "env", "direct"):
        return UrllibBackend(base, **{k: v for k, v in kwargs.items() if k == "env_file"})
    raise SystemExit(f"未知 backend: {name}; 可选: opencli-bridge / urllib")
