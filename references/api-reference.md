# NemoVideo API Reference

## Base URL

`${NEMO_API_URL:-https://mega-api-dev.nemovideo.ai}`

## Authentication

All requests require `Authorization: Bearer <NEMO_TOKEN>` header.

## Endpoints

### POST /api/auth/anonymous-token

Get a free anonymous token with 100 credits.

Request: No body needed.

Response:
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

Anonymous tokens expire in 7 days. Users can upgrade to permanent accounts at nemovideo.ai.

### POST /api/tasks/me/with-session/nemo_agent

Create a new video project session.

Request:
```json
{
  "task_name": "My Video Project",
  "language": "en"
}
```

`language`: ISO code matching the user's language (zh-CN, en, ja, es, etc.).

Response:
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

### POST /run_sse

Send a message to the AI agent. Returns Server-Sent Events stream.

**IMPORTANT**: Use snake_case for all fields.

Request:
```json
{
  "app_name": "nemo_agent",
  "user_id": "<user_id>",
  "session_id": "<session_id>",
  "new_message": {
    "parts": [{"text": "your message here"}]
  }
}
```

Headers:
- `Content-Type: application/json`
- `Accept: text/event-stream`
- `Authorization: Bearer <token>`

Recommended: `--max-time 600` (10 min hard timeout).

#### SSE Stream Format

The response is a standard SSE stream. Each event is a `data:` line followed by a blank line:

```
data: {"type":"text","content":"I'll generate your video now..."}

data: {"type":"tool_call","name":"generate_video_with_seedance","args":{...}}

data: {"type":"tool_result","name":"generate_video_with_seedance","result":{...}}

data: {"type":"heartbeat"}

```

**Event types in the stream:**

| Type | Description | How to handle |
|------|-------------|---------------|
| Text content | AI agent's text response | Extract and present to user (after GUI translation) |
| Tool call | Backend is calling a tool (generate, edit, search, etc.) | Wait silently; do not forward to user |
| Tool result | Tool execution result | Wait for subsequent text response |
| Heartbeat / empty data | Keep-alive signal during long operations | **Not a disconnect.** Continue waiting. |

**Stream completion:** The SSE connection closes when the backend finishes processing. There is no explicit `event: done` signal — treat connection close as stream end.

**Silent completions (~30% of edit operations):** Some tool calls (especially `edit_multitrack` for titles, effects) complete successfully but produce **no text response** — the stream closes after tool_result with no text. When this happens, query the state endpoint to verify what changed and report to the user.

**Typical durations:**

| Operation | Duration |
|-----------|----------|
| Text-only response | 5-15 seconds |
| Video generation (Seedance) | 100-300 seconds |
| Post-production editing | 10-30 seconds |

### GET /api/state/nemo_agent/{user_id}/{session_id}/latest

Get the current project state including draft timeline.

Response `data.state` key fields:

| Field | Description |
|-------|-------------|
| `video_infos` | List of uploaded/generated video assets |
| `draft` | Timeline data with tracks, segments, transitions |
| `canvas_config` | Canvas dimensions (width, height, aspect ratio) |
| `video_analyses` | AI analysis results for videos |
| `generated_media` | AI-generated media assets |

The `draft` object uses **short field names** for compactness:

| Short name | Meaning | Example values |
|-----------|---------|----------------|
| `t` | tracks array | Array of track objects |
| `tt` | track type | 0=video, 1=audio/BGM, 7=text/title |
| `sg` | segments array | Array of clip objects within a track |
| `d` | duration | Milliseconds (e.g. 10000 = 10s) |
| `m` | metadata | `{"title":"...", "width":1920, "height":1080}` |

**Draft is ready for export when**: `draft.t` exists and at least one track has non-empty `sg`.

### GET /api/credits/balance/simple

Check credit balance.

Response:
```json
{
  "code": 0,
  "data": {
    "available": 25000,
    "frozen": 40,
    "total": 25040
  }
}
```

- `available`: credits ready to use
- `frozen`: credits reserved for in-progress operations
- `total`: available + frozen

### POST /api/upload-video/nemo_agent/{user_id}/{session_id}

Upload files to a session.

**Method 1: Multipart form upload** (for local files):
```bash
curl -s -X POST "$API/api/upload-video/nemo_agent/{user_id}/{session_id}" \
  -H "Authorization: Bearer $TOKEN" \
  -F "files=@/path/to/video.mp4" \
  -F "files=@/path/to/image.png"
```

**Method 2: URL upload** (for remote files):
```bash
curl -s -X POST "$API/api/upload-video/nemo_agent/{user_id}/{session_id}" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"urls":["https://example.com/video.mp4"],"source_type":"url"}'
```

Multiple files can be uploaded in one request.

Response:
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
        "height": 1080,
        "fps": 30,
        "hash": "abc123"
      }
    ],
    "session_state_applied": true
  }
}
```

Supported formats:
- Video: mp4, mov, avi, webm, mkv
- Image: jpg, png, gif, webp
- Audio: mp3, wav, m4a, aac

### POST /api/render/proxy/lambda

Submit an async render job (recommended for all exports).

Request:
```json
{
  "id": "render_<unique_id>",
  "sessionId": "<session_id>",
  "draft": "<draft object from state API>",
  "output": {
    "format": "mp4",
    "quality": "high"
  }
}
```

- `sessionId` uses **camelCase** (this is an exception; all other endpoints use snake_case)
- `output` is optional. Defaults to `{"format":"mp4","quality":"high"}`. Can specify resolution/fps if supported.
- `id` must be unique per render. Use `render_<timestamp>` or `render_<uuid>`. If a render fails with duplicate id error, generate a new id and retry.

Response:
```json
{
  "success": true,
  "data": {
    "id": "render_xxx",
    "status": "pending",
    "progress": 5
  }
}
```

### GET /api/render/proxy/lambda/{render_id}

Poll render status.

Response:
```json
{
  "success": true,
  "data": {
    "id": "render_xxx",
    "status": "completed",
    "progress": 100,
    "outputUrl": "https://static1.nemovideo.ai/render-result/render_xxx.mp4",
    "createdAt": 1773423613616,
    "completedAt": 1773423641222
  }
}
```

**Important**: `status` and `outputUrl` are inside `data` object, NOT top-level.

Status values: `pending` → `processing` → `completed` / `failed`

Poll every 10 seconds until `data.status` is `completed` or `failed`. Max 30 polls (5 minutes).

### POST /api/render/proxy/lambda/{render_id}/cancel

Cancel a pending render job. No request body needed.

### GET /api/render/proxy/{render_id}/download

Direct file download for a completed render. Use as fallback when `outputUrl` is not accessible.

```bash
curl -s "$API/api/render/proxy/<render_id>/download" \
  -H "Authorization: Bearer $TOKEN" -o output.mp4
```

## Token Scopes

When creating tokens manually (Settings → API Tokens), available permission scopes:

| Scope | Description |
|-------|-------------|
| `read` | Read sessions and state |
| `write` | Create sessions, send messages |
| `upload` | Upload assets |
| `render` | Export/render videos |
| `*` | All permissions |

Anonymous tokens always have `*` (full access) with 100 credits.

## Error Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 402 | HTTP 402 — Export not available on free plan (subscription tier issue, NOT credits) |
| 1001 | Unauthorized (token invalid/expired) |
| 1002 | Session not found |
| 2001 | Insufficient credits |
| 4001 | Unsupported file type |
| 4002 | File too large |
| 429 | Rate limited |

## Credit Costs (Approximate)

| Operation | Cost |
|-----------|------|
| Video generation (Seedance) | ~100 credits per clip |
| Post-production editing | ~50 credits per session |
| Render/export | **Free** (does NOT cost credits) |

Anonymous users get 100 credits (enough for 1 video generation). Rate limit: 5 anonymous tokens per IP per hour.
