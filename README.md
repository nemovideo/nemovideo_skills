# Nemo Video Skill

Nemo Video AI 视频创作平台的 Agent Skill。

## 功能

- 与 Nemo Video AI Agent 对话，自动创作视频
- 上传素材（视频、图片、音频）
- 获取会话状态（素材、轨道、AI 分析结果）
- 导出视频
- **零配置**：首次使用自动获取匿名 Token，无需注册

## 快速开始

直接使用即可，Skill 会自动创建匿名账号并下发 100 试用积分：

```
帮我用 nemo_video 创建一个 30 秒的产品介绍视频
```

## 环境变量

| 变量 | 必填 | 说明 |
|------|------|------|
| `NEMO_TOKEN` | 否 | User Access Token，首次使用时自动生成 |
| `NEMO_API_URL` | 否 | API 地址，默认 `https://mega-api-dev.nemovideo.ai` |

## 匿名用户限制

- Token 有效期 7 天
- 试用积分 100 点
- 每人每 7 天 1 个匿名 Token（请求必须带 `X-Client-Id` 头）

## 积分不足

- **匿名用户**：注册正式账号，链接须带当前匿名用户 ID 以绑定新账号：`https://nemovideo.com/register?bind=<user_id>`（`user_id` 为 anon_xxx）
- **正式用户**：购买更多积分 → https://nemovideo.com

## License

MIT
