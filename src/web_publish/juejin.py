"""掘金 client — 用 Backend 协议跑 endpoint，不感知 backend 实现细节."""
from __future__ import annotations

from .backends import BackendError  # noqa: F401  (re-exported for callers)


class JuejinClient:
    def __init__(self, backend):
        self.backend = backend

    # ---- write endpoints (不需要签名, 经实测) ----

    def create_draft(
        self,
        title: str,
        mark_content: str,
        brief_content: str,
        category_id: str,
        tag_ids: list[str],
        cover_image: str = "",
        edit_type: int = 10,
    ) -> dict:
        return self.backend.post(
            "/content_api/v1/article_draft/create",
            {
                "title": title,
                "mark_content": mark_content,
                "brief_content": brief_content,
                "category_id": str(category_id),
                "tag_ids": [str(t) for t in tag_ids],
                "cover_image": cover_image,
                "edit_type": edit_type,
                "html_content": "deprecated",
            },
        )

    def update_draft(
        self,
        draft_id: str,
        title: str,
        mark_content: str,
        brief_content: str,
        category_id: str,
        tag_ids: list[str],
        cover_image: str = "",
        edit_type: int = 10,
    ) -> dict:
        return self.backend.post(
            "/content_api/v1/article_draft/update",
            {
                "id": str(draft_id),
                "title": title,
                "mark_content": mark_content,
                "brief_content": brief_content,
                "category_id": str(category_id),
                "tag_ids": [str(t) for t in tag_ids],
                "cover_image": cover_image,
                "edit_type": edit_type,
                "html_content": "deprecated",
            },
        )

    def publish(self, draft_id: str) -> dict:
        return self.backend.post(
            "/content_api/v1/article/publish",
            {
                "draft_id": str(draft_id),
                "sync_to_org": False,
                "column_ids": [],
                "theme_ids": [],
            },
        )

    # ---- read endpoints ----

    def get_draft(self, draft_id: str) -> dict:
        data = self.backend.post(
            "/content_api/v1/article_draft/detail",
            {"draft_id": str(draft_id)},
        )
        return data.get("article_draft", {})

    def list_by_user(self, page_no: int = 1, page_size: int = 50) -> list[dict]:
        """注意: audit_status/status 必须 None，否则掘金返回空."""
        data = self.backend.post(
            "/content_api/v1/article/list_by_user",
            {"page_no": page_no, "page_size": page_size, "audit_status": None, "status": None},
        )
        # backend 返回的 'data' 已经剥掉外层; list_by_user 的 data 本身是 list
        return data if isinstance(data, list) else []

    def find_draft_id(self, article_id: str) -> str | None:
        for entry in self.list_by_user(page_size=100):
            info = entry.get("article_info", {})
            if str(info.get("article_id")) == str(article_id):
                return info.get("draft_id")
        return None
