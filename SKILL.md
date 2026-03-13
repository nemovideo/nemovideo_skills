---
name: nemo_video
description: Chat with Nemo Video AI Agent for video creation - create sessions, send messages, upload assets, and export videos
metadata: {"openclaw": {"emoji": "🎬", "requires": {"env": []}, "primaryEnv": "NEMO_TOKEN"}}
---

# Nemo Video Chat Skill

与 Nemo Video AI 视频创作助手进行对话，支持上传素材、生成视频、导出成品。

## 环境变量

| 变量 | 必填 | 说明 |
|------|------|------|
| `NEMO_TOKEN` | 否 | User Access Token，首次使用时自动生成 |
| `NEMO_API_URL` | 否 | API 地址，默认 `https://mega-api-dev.nemovideo.ai` |

**首次使用无需配置**：Skill 会自动为你创建匿名账号并下发试用 Token（100 积分）。

## 获取 Token

### 自动获取（推荐）

首次使用时，如果 `NEMO_TOKEN` 未配置，自动调用以下接口获取：

```bash
curl -X POST "${NEMO_API_URL:-https://mega-api-dev.nemovideo.ai}/api/auth/anonymous-token"
```

响应示例：
```json
{
  "code": 0,
  "data": {
    "token": "nmv_usr_xxxxxx",
    "user_id": "anon_abc123",
    "expires_at": "2026-03-18T00:00:00Z",
    "credits": 100
  }
}
```

获取后将 `token` 保存到 `NEMO_TOKEN` 环境变量供后续使用。

### 手动获取

如需更多权限或长期使用，可在 Nemo Video 后台创建 Token：
1. 登录 [Nemo Video](https://nemovideo.ai)
2. 进入 设置 → API Tokens
3. 点击 "Create Token"，选择权限范围
4. 复制生成的 Token（仅显示一次）

## 工作流程

### Step 0: 获取 Token（首次使用）

如果 `NEMO_TOKEN` 未配置，先获取匿名 Token：

```bash
# 获取匿名 Token
response=$(curl -s -X POST "${NEMO_API_URL:-https://mega-api-dev.nemovideo.ai}/api/auth/anonymous-token")
NEMO_TOKEN=$(echo $response | jq -r '.data.token')
NEMO_USER_ID=$(echo $response | jq -r '.data.user_id')

# 保存供后续使用
export NEMO_TOKEN
export NEMO_USER_ID
```

### Step 1: 创建会话

创建会话获取 session_id：

```bash
curl -X POST "${NEMO_API_URL:-https://mega-api-dev.nemovideo.ai}/api/tasks/me/with-session/nemo_agent" \
  -H "Authorization: Bearer ${NEMO_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "task_name": "Video Project",
    "language": "zh-CN"
  }'
```

响应示例：
```json
{
  "code": 0,
  "data": {
    "task_id": "task_xxx",
    "session_id": "5529798706024415232",
    "user_id": "anon_abc123"
  }
}
```

**重要**：记住返回的 `session_id` 和 `user_id`，后续所有接口都需要使用这两个值。

### Step 2: 发送消息

使用获取的 session_id 发送消息：

```bash
curl -X POST "${NEMO_API_URL:-https://mega-api-dev.nemovideo.ai}/run_sse" \
  -H "Authorization: Bearer ${NEMO_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "Accept: text/event-stream" \
  -d '{
    "app_name": "nemo_agent",
    "user_id": "<user_id>",
    "session_id": "<session_id>",
    "new_message": {
      "parts": [{"text": "你的消息内容"}]
    }
  }'
```

响应为 SSE (Server-Sent Events) 流式格式。

### Step 3: 上传素材（可选）

如果用户需要上传视频、图片、音频等素材：

#### 方式一：直接上传文件

```bash
curl -X POST "${NEMO_API_URL:-https://mega-api-dev.nemovideo.ai}/api/upload-video/nemo_agent/<user_id>/<session_id>" \
  -H "Authorization: Bearer ${NEMO_TOKEN}" \
  -F "files=@/path/to/video.mp4" \
  -F "files=@/path/to/image.png"
```

#### 方式二：通过 URL 上传

```bash
curl -X POST "${NEMO_API_URL:-https://mega-api-dev.nemovideo.ai}/api/upload-video/nemo_agent/<user_id>/<session_id>" \
  -H "Authorization: Bearer ${NEMO_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "urls": ["https://example.com/video.mp4"],
    "source_type": "url"
  }'
```

响应示例：
```json
{
  "code": 0,
  "data": {
    "files": [
      {
        "filename": "video.mp4",
        "file_type": "video",
        "cdn_url": "https://cdn.example.com/videos/xxx/video.mp4",
        "duration": 30.5,
        "width": 1920,
        "height": 1080
      }
    ],
    "session_state_applied": true
  }
}
```

支持的文件类型：
- **视频**: mp4, mov, avi, webm, mkv
- **图片**: jpg, png, gif, webp
- **音频**: mp3, wav, m4a, aac

### Step 4: 获取会话状态

获取当前会话的完整状态：

```bash
curl -X GET "${NEMO_API_URL:-https://mega-api-dev.nemovideo.ai}/api/state/nemo_agent/<user_id>/<session_id>/latest" \
  -H "Authorization: Bearer ${NEMO_TOKEN}"
```

响应示例：
```json
{
  "code": 0,
  "data": {
    "session_id": "session_xxx",
    "task_id": "task_yyy",
    "task_name": "My Video Project",
    "state": {
      "video_infos": [...],
      "draft": {...},
      "canvas_config": {...},
      "video_analyses": {...}
    }
  }
}
```

#### State 关键字段

| 字段 | 说明 |
|------|------|
| `video_infos` | 用户上传的素材列表 |
| `draft` | 视频轨道数据（时间线、片段、转场） |
| `canvas_config` | 画布配置（尺寸、比例） |
| `video_analyses` | AI 对视频的分析结果 |
| `generated_media` | AI 生成的媒体 |

#### 判断项目进度

- **素材已上传**: `video_infos.length > 0`
- **已生成轨道**: `draft` 非空
- **项目可导出**: `draft` 非空且包含 tracks

### Step 5: 导出视频

当 `draft` 非空时，可以渲染为最终视频。

#### 5.1 创建渲染任务

```bash
curl -X POST "${NEMO_API_URL:-https://mega-api-dev.nemovideo.ai}/api/render/proxy/draft" \
  -H "Authorization: Bearer ${NEMO_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "render_<timestamp>",
    "sessionId": "<session_id>",
    "draft": <从state获取的draft对象>,
    "output": {"format": "mp4", "quality": "high"}
  }'
```

#### 5.2 查询渲染状态

```bash
curl -X GET "${NEMO_API_URL:-https://mega-api-dev.nemovideo.ai}/api/render/proxy/<render_task_id>" \
  -H "Authorization: Bearer ${NEMO_TOKEN}"
```

响应示例：
```json
{
  "taskId": "render_xxx",
  "status": "completed",
  "progress": 100,
  "output": {
    "url": "https://cdn.example.com/renders/xxx/output.mp4",
    "duration": 30.5,
    "size": 15728640
  }
}
```

| 状态 | 说明 |
|------|------|
| `pending` | 等待处理 |
| `processing` | 正在渲染 |
| `completed` | 渲染完成，`output.url` 包含下载链接 |
| `failed` | 渲染失败 |

#### 5.3 下载视频

```bash
curl -X GET "${NEMO_API_URL:-https://mega-api-dev.nemovideo.ai}/api/render/proxy/<render_task_id>/download" \
  -H "Authorization: Bearer ${NEMO_TOKEN}" \
  -o output.mp4
```

## 错误处理

| 错误码 | 说明 |
|--------|------|
| `0` | 成功 |
| `1001` | 未授权（Token 无效或过期） |
| `1002` | 会话不存在 |
| `2001` | 积分不足 |
| `4001` | 文件类型不支持 |
| `4002` | 文件过大 |
| `429` | 请求频率过高（匿名 Token 每 IP 每小时限 5 个） |

## Token 权限范围

创建 Token 时可选择权限范围：

| Scope | 说明 |
|-------|------|
| `read` | 读取会话和状态 |
| `write` | 创建会话、发送消息 |
| `upload` | 上传素材 |
| `render` | 导出视频 |
| `*` | 全部权限 |

## 匿名用户说明

- 匿名 Token 有效期 7 天
- 试用积分 100 点
- 匿名用户可随时升级为正式用户（保留已有数据）

## 积分不足处理

当收到错误码 `2001`（积分不足）时：

- **匿名用户**（`user_id` 以 `anon_` 开头）：需注册正式账号
  - 注册地址：https://nemovideo.com
  
- **正式用户**：需购买更多积分
  - 续费地址：https://nemovideo.com
