import os
from pathlib import Path

try:
    import yaml
except ImportError as e:
    raise SystemExit("缺 PyYAML — pip install pyyaml 或重跑 install.sh") from e


def _candidate_paths(platform: str):
    return [
        Path(os.path.expanduser(f"~/.web-publish/adapters/{platform}.yaml")),
        Path(__file__).resolve().parents[2].parent / "adapters" / f"{platform}.yaml",
        Path(__file__).resolve().parents[2] / "adapters" / f"{platform}.yaml",
    ]


def load_adapter(platform: str) -> dict:
    for p in _candidate_paths(platform):
        if p.is_file():
            return yaml.safe_load(p.read_text(encoding="utf-8"))
    raise FileNotFoundError(
        f"adapter not found for '{platform}'. 候选路径:\n  "
        + "\n  ".join(str(p) for p in _candidate_paths(platform))
    )


def resolve_category(adapter: dict, name_or_id: str) -> str:
    cats = adapter.get("categories", {})
    if name_or_id in cats:
        return cats[name_or_id]
    if name_or_id in cats.values():
        return name_or_id
    raise SystemExit(
        f"未知分类: {name_or_id}\n可选: {list(cats.keys())}"
    )


def resolve_tag_ids(adapter: dict, tag_spec: str) -> list[str]:
    """tag_spec: comma-separated names or ids. Names resolved via known_tags."""
    known = adapter.get("known_tags", {})
    out = []
    for tok in tag_spec.split(","):
        tok = tok.strip()
        if not tok:
            continue
        if tok.isdigit():
            out.append(tok)
        elif tok in known:
            out.append(str(known[tok]))
        else:
            raise SystemExit(
                f"未知 tag: {tok}\n已知 tag: {list(known.keys())}\n"
                f"未知 tag 请用 id（数字），或先在 adapter yaml 添加"
            )
    return out
