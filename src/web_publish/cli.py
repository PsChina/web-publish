"""web-publish CLI — 给 Agent 调的稳定接口."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from . import __version__
from .adapters import load_adapter, resolve_category, resolve_tag_ids
from .backends import BackendError, make_backend
from .juejin import JuejinClient
from .setup_wizard import run_setup


# ---- 通用 helper ----

def _build_juejin_client(args) -> JuejinClient:
    adapter = load_adapter("juejin")
    backend = make_backend(args.backend, base=adapter["api_base"])
    return JuejinClient(backend)


def _emit(obj: dict) -> None:
    """对 Agent 友好的 JSON 输出: 单行, 不转义中文."""
    print(json.dumps(obj, ensure_ascii=False))


# ---- 子命令 ----

def cmd_publish(args) -> int:
    adapter = load_adapter(args.platform)
    md_path = Path(args.markdown)
    if not md_path.is_file():
        raise SystemExit(f"找不到 markdown 文件: {md_path}")
    mark_content = md_path.read_text(encoding="utf-8")

    category_id = resolve_category(adapter, args.category)
    tag_ids = resolve_tag_ids(adapter, args.tag_ids)

    client = JuejinClient(make_backend(args.backend, base=adapter["api_base"]))

    draft = client.create_draft(
        title=args.title,
        mark_content=mark_content,
        brief_content=args.brief,
        category_id=category_id,
        tag_ids=tag_ids,
        cover_image=args.cover_image or "",
    )
    draft_id = draft.get("id")
    if not draft_id:
        raise SystemExit(f"create_draft 没返回 id: {draft}")

    out = {
        "platform": args.platform,
        "draft_id": draft_id,
        "title": args.title,
        "category_id": category_id,
        "tag_ids": tag_ids,
    }

    if args.draft_only:
        out["status"] = "draft_only"
        out["preview_url"] = f"https://juejin.cn/editor/drafts/{draft_id}"
    else:
        pub = client.publish(draft_id)
        article_id = pub.get("article_id")
        out["status"] = "published_pending_review"
        out["article_id"] = article_id
        out["spost_url"] = f"https://juejin.cn/spost/{article_id}"
        out["post_url"] = f"https://juejin.cn/post/{article_id}"
    _emit(out)
    return 0


def cmd_update(args) -> int:
    adapter = load_adapter(args.platform)
    client = JuejinClient(make_backend(args.backend, base=adapter["api_base"]))

    # 1. find draft_id from article_id
    draft_id = client.find_draft_id(args.article_id)
    if not draft_id:
        raise SystemExit(
            f"找不到 article_id={args.article_id} 对应的 draft "
            f"(list_by_user 返回里没有). 是不是写错了 id?"
        )

    # 2. fetch current draft (拿原 mark_content / title / category / tags)
    cur = client.get_draft(draft_id)

    # 3. 决定新 mark_content
    if args.mark_content_file:
        mark_content = Path(args.mark_content_file).read_text(encoding="utf-8")
    elif args.append_file:
        supplement = Path(args.append_file).read_text(encoding="utf-8")
        mark_content = cur.get("mark_content", "") + supplement
    else:
        raise SystemExit("update 需要 --append-file <path> 或 --mark-content-file <path>")

    title = args.title or cur.get("title", "")
    brief = cur.get("brief_content", "")
    category_id = (
        resolve_category(adapter, args.category) if args.category else cur.get("category_id")
    )
    if args.tag_ids:
        tag_ids = resolve_tag_ids(adapter, args.tag_ids)
    else:
        tag_ids = [str(t) for t in cur.get("tag_ids", [])]

    client.update_draft(
        draft_id=draft_id,
        title=title,
        mark_content=mark_content,
        brief_content=brief,
        category_id=category_id,
        tag_ids=tag_ids,
        cover_image=cur.get("cover_image", ""),
        edit_type=cur.get("edit_type", 10),
    )

    out = {
        "platform": args.platform,
        "article_id": args.article_id,
        "draft_id": draft_id,
        "old_len": len(cur.get("mark_content", "")),
        "new_len": len(mark_content),
    }

    if args.draft_only:
        out["status"] = "draft_updated_not_published"
    else:
        pub = client.publish(draft_id)
        out["status"] = "republished_pending_review"
        out["article_id"] = pub.get("article_id", args.article_id)
        out["post_url"] = f"https://juejin.cn/post/{out['article_id']}"
    _emit(out)
    return 0


def cmd_list(args) -> int:
    adapter = load_adapter(args.platform)
    client = JuejinClient(make_backend(args.backend, base=adapter["api_base"]))
    items = client.list_by_user(page_no=1, page_size=args.limit)
    out = [
        {
            "article_id": (e.get("article_info") or {}).get("article_id"),
            "draft_id": (e.get("article_info") or {}).get("draft_id"),
            "title": (e.get("article_info") or {}).get("title"),
            "ctime": (e.get("article_info") or {}).get("ctime"),
            "status": (e.get("article_info") or {}).get("status"),
        }
        for e in items
    ]
    _emit({"platform": args.platform, "count": len(out), "articles": out})
    return 0


def cmd_health(args) -> int:
    adapter = load_adapter(args.platform)
    client = JuejinClient(make_backend(args.backend, base=adapter["api_base"]))
    items = client.list_by_user(page_no=1, page_size=1)
    _emit({
        "platform": args.platform,
        "backend": args.backend,
        "ok": True,
        "first_article_title": (items[0].get("article_info", {}).get("title") if items else None),
    })
    return 0


def cmd_categories(args) -> int:
    adapter = load_adapter(args.platform)
    _emit({"platform": args.platform, "categories": adapter.get("categories", {})})
    return 0


def cmd_setup(args) -> int:
    run_setup(platform=args.platform)
    return 0


# ---- main ----

def _add_common(p: argparse.ArgumentParser) -> None:
    p.add_argument(
        "--backend",
        choices=["opencli-bridge", "urllib"],
        default="opencli-bridge",
        help="opencli-bridge (默认, 零 cookie 配置) / urllib (.env 模式, 服务器友好)",
    )


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="web-publish",
        description="发布 markdown 到掘金 / CSDN / 知乎. v0.3 Python SDK + dual backend.",
    )
    p.add_argument("--version", action="version", version=f"web-publish {__version__}")

    sub = p.add_subparsers(dest="cmd", required=True)

    pp = sub.add_parser("publish", help="发新文章")
    pp.add_argument("platform", choices=["juejin"])  # v0.3 只支持 juejin
    pp.add_argument("markdown", help="markdown 文件路径")
    pp.add_argument("--title", required=True)
    pp.add_argument("--brief", required=True, help="摘要 ≤100 字")
    pp.add_argument("--tag-ids", required=True, help="逗号分隔; 可用 tag 名 (yaml known_tags) 或 id")
    pp.add_argument("--category", required=True, help="分类名 (中文)")
    pp.add_argument("--cover-image", default="")
    pp.add_argument("--draft-only", action="store_true")
    _add_common(pp)
    pp.set_defaults(func=cmd_publish)

    pu = sub.add_parser("update", help="更新已发布文章")
    pu.add_argument("platform", choices=["juejin"])
    pu.add_argument("article_id")
    pu.add_argument("--append-file", help="把这个文件内容追加到原文末尾")
    pu.add_argument("--mark-content-file", help="完全替换 mark_content (与 --append-file 互斥)")
    pu.add_argument("--title")
    pu.add_argument("--tag-ids")
    pu.add_argument("--category")
    pu.add_argument("--draft-only", action="store_true", help="只 update 草稿, 不重发布")
    _add_common(pu)
    pu.set_defaults(func=cmd_update)

    pl = sub.add_parser("list", help="列出自己的文章")
    pl.add_argument("platform", choices=["juejin"])
    pl.add_argument("--limit", type=int, default=20)
    _add_common(pl)
    pl.set_defaults(func=cmd_list)

    ph = sub.add_parser("health", help="验证 backend + cookie 工作")
    ph.add_argument("platform", choices=["juejin"])
    _add_common(ph)
    ph.set_defaults(func=cmd_health)

    pc = sub.add_parser("categories", help="dump 平台分类表 (无网络调用)")
    pc.add_argument("platform", choices=["juejin"])
    pc.set_defaults(func=cmd_categories)

    ps = sub.add_parser("setup", help="引导首次写 .env (urllib backend 用)")
    ps.add_argument("--platform", default="juejin", choices=["juejin"])
    ps.set_defaults(func=cmd_setup)

    return p


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return args.func(args) or 0
    except BackendError as e:
        print(f"backend error: {e}", file=sys.stderr)
        return 2
    except SystemExit:
        raise
    except Exception as e:
        print(f"unexpected: {type(e).__name__}: {e}", file=sys.stderr)
        return 3


if __name__ == "__main__":
    sys.exit(main())
