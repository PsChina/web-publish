# /publish — 强制把指定 markdown 发布到目标博客平台

跳过 Claude 的自动判断，直接走 `web-publish` skill 的完整流程。

## 用法

```
/publish <platform> <markdown 路径>
```

例：

```
/publish juejin ./posts/my-article.md
/publish csdn /tmp/穷鬼大救星.md
/publish zhihu ./blog/思考.md
```

## 支持的平台

| platform | 状态 |
|---|---|
| `juejin` | v0.1 重点 |
| `csdn` | v0.2 |
| `zhihu` | v0.2 |
| `segmentfault` | v0.3 |
| `cnblogs` | v0.3 |

## 你（Claude）要做的

1. 按 `web-publish` SKILL.md 的准则走流程：
   - 解析 platform 和 markdown 路径
   - 检测 OpenCLI + Chrome Browser Bridge 就位
   - Read markdown
   - 平台特定的内容优化（标题字数 / tag / 分类）
   - 调 `opencli browser exec <platform>.publishArticle`
   - WebFetch 验证文章 URL 上线

2. 不要问"你确定要发吗" —— 敲 `/publish` 已经是确认

3. 完成后必须验证：
   - WebFetch 文章 URL 看 200 + 标题正确
   - 给出 URL + 冷启动互动建议

## 不要做的

- ❌ 不读源 markdown 就开始推 tag / 写摘要
- ❌ 在 adapter 报 selector not found 时直接放弃 → 引导用户更新 adapter
- ❌ 把 cookie / 任何登录态写到对话里
