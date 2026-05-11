# /publish — 强制把指定 markdown 发布到目标博客平台

跳过 Claude 的自动判断，直接走 `web-publish` skill 的完整流程。

## 用法

```
/publish <platform> <markdown 路径>
```

例：

```
/publish juejin ./posts/my-article.md
/publish csdn /tmp/穷鬼大救星.md       # v0.4 支持
/publish zhihu ./blog/思考.md          # v0.4 支持
```

## 支持的平台（v0.3）

| platform | publish | update |
|---|---|---|
| `juejin` | ✅ | ✅ |
| `csdn` | 🟡 待 | 🟡 待 |
| `zhihu` | 🟡 待 | 🟡 待 |
| `segmentfault` | 🟡 待 | 🟡 待 |
| `cnblogs` | 🟡 待 | 🟡 待 |

## 你（Claude）要做的

1. 按 `web-publish` SKILL.md 的准则走流程：
   - 解析 platform 和 markdown 路径
   - 检查 `web-publish health <platform>` 通（CLI + cookie 就位）
   - Read markdown **一次**（做内容优化决策，**不要进 context 二次**）
   - 平台特定的内容优化：标题字数 / tag 推荐 / 摘要 / 分类
   - Bash 调一行：`web-publish publish <platform> <path> --title ... --brief ... --tag-ids ... --category ...`
   - 解析 CLI 输出的 JSON（含 article_id / post_url）
   - 给用户报告 URL + 冷启动互动建议

2. 不要问"你确定要发吗" —— 敲 `/publish` 已经是确认

3. **绝对不要**在 Claude 上下文里现场生成 fetch JS 或 urllib 调用代码 —— 那是 CLI 内部的事。Claude 只调 CLI 看 stdout。

## 不要做的

- ❌ 不读源 markdown 就开始推 tag / 写摘要
- ❌ 把 markdown 内容传给 CLI 时复制进 Bash 命令字符串 —— 文件路径传给 `--` 后位置参数，CLI 自己读盘
- ❌ Backend 报 `BackendError: 找不到 .env` 时直接放弃 —— 引导用户跑 `web-publish setup`
- ❌ 把 cookie / 任何登录态写到对话里
- ❌ 在 SKILL.md / 本文件 / README 等位置硬编码 cookie 或 article_id 示例
