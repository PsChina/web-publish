# /juejin — 强制把指定 markdown 发布到掘金

跳过 Claude 的自动判断，直接走 `publish-to-juejin` skill 的完整流程。

## 用法

```
/juejin <markdown 文件路径>
```

例：
```
/juejin ./posts/my-article.md
/juejin /tmp/穷鬼大救星.md
```

## 你（Claude）要做的

1. 按 `publish-to-juejin` SKILL.md 的准则走流程：
   - Read 文件
   - 探测 juejin-mcp daemon 是否在跑（127.0.0.1:18080）
   - 自动模式 / 半自动模式分流
   - 内容优化（标题 / 首段 / tag / 摘要 / 封面建议）
   - 发布 or 输出 clipboard 块 + 清单

2. **不要**问用户"你确定要发吗" —— 敲 `/juejin` 已经是确认

3. **完成后必须验证**：
   - 自动模式：WebFetch 文章 URL 看 200 + 标题正确
   - 半自动模式：给清晰的"打开 URL → 粘贴 → 选 tag → 发布"清单

## 不要做的

- ❌ 不读源 markdown 就开始推 tag / 写摘要
- ❌ 在 juejin-mcp 报 4xx 时直接放弃 —— 走 fallback（拉 categories / retry）
- ❌ 把 API key / cookie 等敏感信息写到对话里
