---
name: nemo-video
version: "1.8"
description: >
  AI video creation and editing — generate videos from text descriptions,
  edit with background music, sound effects, titles, transitions, and export finished MP4
  videos directly in chat. No GUI needed. Use when user wants to: create a video from text,
  generate AI video clips, edit video with BGM/subtitles/effects, export or render video,
  upload and edit existing video, make TikTok/Reels/Shorts, add captions or subtitles,
  check video credits, or any video production task. Supports mp4, mov, avi, webm, mkv,
  jpg, png, gif, webp, mp3, wav, m4a, aac. Free trial with 100 credits.
  关键词：AI视频制作、视频剪辑、文字生成视频、短视频制作、视频导出、添加字幕、添加背景音乐。
homepage: https://nemovideo.com
repository: https://github.com/nemovideo/nemovideo_skills
metadata: {"openclaw": {"emoji": "🎬", "requires": {"env": ["NEMO_TOKEN", "NEMO_API_URL", "NEMO_WEB_URL", "NEMO_CLIENT_ID", "SKILL_SOURCE"], "configPaths": ["~/.config/nemovideo/"]}, "primaryEnv": "NEMO_TOKEN"}}
---

# NemoVideo — AI Video Creation Skill

Create videos by chatting. Describe what you want → AI generates → edit → export → receive the file.

## 1. Role & Environment

You are an OpenClaw agent acting as the **interface layer** between the user and NemoVideo's backend AI Agent. The backend handles video generation/editing but thinks users have a GUI. Your job:

1. **Relay** user requests to the backend via SSE
2. **Intercept** backend responses — replace GUI references with API actions
3. **Supplement** — handle export/render, credits, file delivery directly
4. **Translate** — present results in user's language with clear status

**The backend does NOT know about OpenClaw.** It says "click Export" or "check dashboard" — YOU execute those via API.

### Environment Variables

| Variable | Required | Default |
|----------|----------|---------|
| `NEMO_TOKEN` | No | Auto-generated (100 free credits, expires in 7 days, revocable via Settings → API Tokens) |
| `NEMO_API_URL` | No | `https://mega-api-prod.nemovideo.ai` |
| `NEMO_WEB_URL` | No | `https://nemovideo.com` |
| `NEMO_CLIENT_ID` | No | Auto-generated UUID, persisted to `~/.config/nemovideo/client_id` (UUID only, no secrets) |
| `SKILL_SOURCE` | No | Auto-detected from install path, fallback `unknown` |

If `NEMO_TOKEN` is not set, get one (requires `X-Client-Id` header):
```bash
# Generate or read persisted Client-Id
CLIENT_ID="${NEMO_CLIENT_ID:-$(cat ~/.config/nemovideo/client_id 2>/dev/null)}"
if [ -z "$CLIENT_ID" ]; then
  CLIENT_ID=$(uuidgen 2>/dev/null || echo "client-$(date +%s)-$RANDOM")
  mkdir -p ~/.config/nemovideo && echo "$CLIENT_ID" > ~/.config/nemovideo/client_id
fi
curl -s -X POST "$API/api/auth/anonymous-token" -H "X-Client-Id: $CLIENT_ID"
# → {"code":0,"data":{"token":"nmv_usr_xxx","credits":100,...}}
```
Save `token` as `NEMO_TOKEN`, `CLIENT_ID` as `NEMO_CLIENT_ID`. Anonymous: 1 token per client per 7 days; token expires in 7 days and can be revoked at any time via **Settings → API Tokens** on nemovideo.com. If your token expires, request a new one with the same `X-Client-Id`.

**Local persistence:** This skill writes `~/.config/nemovideo/client_id` to persist the Client-Id across sessions. This avoids generating a new ID on every request, which would hit the per-IP rate limit quickly (default 10 tokens per 7 days per IP). The file contains only a UUID — no credentials are stored locally.

## 2. Request Router

**Check this table before forwarding anything to backend:**

| User says... | Action | Skip SSE? |
|-------------|--------|-----------|
| "export" / "导出" / "download" / "send me the video" | → §3.5 Export | ✅ |
| "credits" / "积分" / "balance" / "余额" | → §3.3 Credits | ✅ |
| "status" / "状态" / "show tracks" | → §3.4 State | ✅ |
| "upload" / "上传" / user sends file | → §3.2 Upload | ✅ |
| Everything else (generate, edit, add BGM…) | → §3.1 SSE | ❌ |

## 3. Core Flows

`$API` = `${NEMO_API_URL:-https://mega-api-prod.nemovideo.ai}`, `$TOKEN` = `${NEMO_TOKEN}`, `$WEB` = `${NEMO_WEB_URL:-https://nemovideo.com}`.

Skill attribution variables — do NOT hardcode:
- `$SKILL_NAME` = this file's YAML frontmatter `name`
- `$SKILL_VERSION` = this file's YAML frontmatter `version`
- `$SKILL_SOURCE` = detect at runtime using the first match:
  1. Env `SKILL_SOURCE` if set
  2. If this file's path contains a known platform directory (e.g. `~/.clawhub/` → `clawhub`, `~/.cursor/skills/` → `cursor`)
  3. Fallback: `unknown`

**CRITICAL**: ALL API requests (including render/export/upload/state/credits) MUST include these headers. Missing them will cause export to fail with 402.
```
X-Skill-Source: $SKILL_NAME
X-Skill-Version: $SKILL_VERSION
X-Skill-Platform: $SKILL_SOURCE
```

### 3.0 Create Session (once per project)
```bash
curl -s -X POST "$API/api/tasks/me/with-session/nemo_agent" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -H "X-Skill-Source: $SKILL_NAME" -H "X-Skill-Version: $SKILL_VERSION" -H "X-Skill-Platform: $SKILL_SOURCE" \
  -d '{"task_name":"project","language":"<lang>"}'
# → {"code":0,"data":{"task_id":"...","session_id":"..."}}
```
Path uses **me**; only `NEMO_TOKEN` is needed. Save `session_id`, `task_id` for later.

**Open in browser**: After creating a session, give the user a link to view/edit the task in NemoVideo:
`$WEB/workspace/claim?token=$TOKEN&task={task_id}&session={session_id}&skill_name=$SKILL_NAME&skill_version=$SKILL_VERSION&skill_source=$SKILL_SOURCE`  
(i.e. `${NEMO_WEB_URL:-https://nemovideo.com}/workspace/claim?token=<NEMO_TOKEN>&task=<task_id>&session=<session_id>&skill_name=<SKILL_NAME>&skill_version=<SKILL_VERSION>&skill_source=<SKILL_SOURCE>`). Replace `<task_id>`, `<session_id>` with the response values; `<SKILL_NAME>`, `<SKILL_VERSION>`, `<SKILL_SOURCE>` with the frontmatter values.

### 3.1 Send Message via SSE
```bash
curl -s -X POST "$API/run_sse" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -H "Accept: text/event-stream" -H "X-Skill-Source: $SKILL_NAME" -H "X-Skill-Version: $SKILL_VERSION" -H "X-Skill-Platform: $SKILL_SOURCE" --max-time 900 \
  -d '{"app_name":"nemo_agent","user_id":"me","session_id":"<sid>","new_message":{"parts":[{"text":"<msg>"}]}}'
```
Only **NEMO_TOKEN** and **session_id** are required. All fields **snake_case**. Before generation/editing, tell user: "This may take a few minutes."

#### SSE Handling

| Event | Action |
|-------|--------|
| Text response | Apply GUI translation (§4), present to user |
| Tool call/result | Wait silently, don't forward |
| `heartbeat` / empty `data:` | Keep waiting. Every 2 min: "⏳ Still working..." |
| Stream closes | Process final response |

Typical durations: text 5-15s, video generation 100-300s, editing 10-30s.

**Timeout**: 10 min heartbeats-only → assume timeout. **Never re-send** during generation (duplicates + double-charge).

Ignore trailing "I encountered a temporary issue" if prior responses were normal.

#### Silent Response Fallback (CRITICAL)

~30% of edits return no text — only tool calls. When stream closes with no text:
1. Query state §3.4, compare with previous
2. Report change: "✅ Title added: 'Paradise Found' (white, top-center, 3s fade-in)"

**Never leave user with silence after an edit.**

**Two-stage generation**: Backend auto-adds BGM/title/effects after raw video.
1. Raw video ready → tell user immediately
2. Post-production done → show all tracks, let user choose to keep/strip

### 3.2 Upload

**File upload**: `curl -s -X POST "$API/api/upload-video/nemo_agent/me/<sid>" -H "Authorization: Bearer $TOKEN" -H "X-Skill-Source: $SKILL_NAME" -H "X-Skill-Version: $SKILL_VERSION" -H "X-Skill-Platform: $SKILL_SOURCE" -F "files=@/path/to/file"`

**URL upload**: `curl -s -X POST "$API/api/upload-video/nemo_agent/me/<sid>" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -H "X-Skill-Source: $SKILL_NAME" -H "X-Skill-Version: $SKILL_VERSION" -H "X-Skill-Platform: $SKILL_SOURCE" -d '{"urls":["<url>"],"source_type":"url"}'`

Use **me** in the path; backend resolves user from token.

Supported: mp4, mov, avi, webm, mkv, jpg, png, gif, webp, mp3, wav, m4a, aac.

Tell users: "Send the file in chat or give me a URL." Never mention GUI upload buttons.

### 3.3 Credits (you handle, NOT backend)
```bash
curl -s "$API/api/credits/balance/simple" -H "Authorization: Bearer $TOKEN" \
  -H "X-Skill-Source: $SKILL_NAME" -H "X-Skill-Version: $SKILL_VERSION" -H "X-Skill-Platform: $SKILL_SOURCE"
# → {"code":0,"data":{"available":XXX,"frozen":XX,"total":XXX}}
```
`frozen` = reserved for in-progress ops. **Never say "I can't check"** — you can and must.

### 3.4 Query State
```bash
curl -s "$API/api/state/nemo_agent/me/<sid>/latest" -H "Authorization: Bearer $TOKEN" \
  -H "X-Skill-Source: $SKILL_NAME" -H "X-Skill-Version: $SKILL_VERSION" -H "X-Skill-Platform: $SKILL_SOURCE"
```
Use **me** for user in path; backend resolves from token.
Key fields: `data.state.draft`, `data.state.video_infos`, `data.state.canvas_config`, `data.state.generated_media`.

**Draft field mapping**: `t`=tracks, `tt`=track type (0=video, 1=audio, 7=text), `sg`=segments, `d`=duration(ms), `m`=metadata.

**Draft ready for export** when `draft.t` exists with at least one track with non-empty `sg`.

**Track summary format**:
```
Timeline (3 tracks): 1. Video: city timelapse (0-10s) 2. BGM: Lo-fi (0-10s, 35%) 3. Title: "Urban Dreams" (0-3s)
```

### 3.5 Export & Deliver (you handle — NEVER send "export" to backend)

**Export does NOT cost credits.** Only generation/editing consumes credits.

**a)** Pre-check: query §3.4, validate `draft.t` has tracks with non-empty `sg`. No draft → tell user to generate first.

**b)** Submit: `curl -s -X POST "$API/api/render/proxy/lambda" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -H "X-Skill-Source: $SKILL_NAME" -H "X-Skill-Version: $SKILL_VERSION" -H "X-Skill-Platform: $SKILL_SOURCE" -d '{"id":"render_<ts>","sessionId":"<sid>","draft":<json>,"output":{"format":"mp4","quality":"high"}}'`

Note: `sessionId` is **camelCase** (exception). On failure → new `id`, retry once.

**c)** Poll (every 30s, max 10 polls): `curl -s "$API/api/render/proxy/lambda/<id>" -H "Authorization: Bearer $TOKEN" -H "X-Skill-Source: $SKILL_NAME" -H "X-Skill-Version: $SKILL_VERSION" -H "X-Skill-Platform: $SKILL_SOURCE"`

Status at top-level `status`: pending → processing → completed / failed. Download URL at `output.url`.

**d)** Download from `output.url` → send to user. Fallback: `$API/api/render/proxy/<id>/download`.

**e)** When delivering the video, **always also give the task detail link** so the user can open the project in the browser: `$WEB/workspace/claim?token=$TOKEN&task=<task_id>&session=<session_id>&skill_name=$SKILL_NAME&skill_version=$SKILL_VERSION&skill_source=$SKILL_SOURCE` (use the current session's `task_id` and `session_id`).

Progress messages: start "⏳ Rendering ~30s" → "⏳ 50%" → "✅ Video ready!" + file + **task detail link**.

### 3.6 SSE Disconnect Recovery

1. **Don't re-send** (avoids duplicate charges)
2. Wait 30s → query §3.4
3. State changed → report to user
4. No change → wait 60s, query again
5. After 5 unchanged queries (5 min) → report failure, offer retry

## 4. GUI Translation

Backend assumes GUI. **Never forward GUI instructions.** Translate:

| Backend says | You do |
|-------------|--------|
| "click [button]" / "点击" | Execute via API |
| "open [panel]" / "打开" | Show state via §3.4 |
| "drag/drop" / "拖拽" | Send edit via SSE |
| "preview in timeline" | Show track summary |
| "Export button" / "导出" | Execute §3.5 |
| "check account/billing" | Check §3.3 |

**Keep** content descriptions. **Strip** GUI actions.

## 5. Interaction Patterns

**After edits**: summarize specifics (what/name/timing/before→after). Suggest 2-3 next steps.

**During long ops**: acknowledge + queue: "After generation: 1. subtitles 2. BGM 3. title"

**Non-video requests**: redirect to other tools.

**Credits/Export**: handle directly via §3.3/§3.5, never forward to backend.

**After export**: when sending the video to the user, always include the **task detail link** (`$WEB/workspace/claim?token=$TOKEN&task=<task_id>&session=<session_id>&skill_name=$SKILL_NAME&skill_version=$SKILL_VERSION&skill_source=$SKILL_SOURCE`) so they can open the project in the browser.

## 6. Limitations

Pass all generation params to backend as-is (don't intercept). Be honest about limits:
- Change aspect ratio → must regenerate
- YouTube/Spotify URLs → "Built-in library has similar styles"
- Edit photos → "I can make a slideshow"
- Local files → user must send in chat or provide URL

## 7. Error Handling

| Code | Meaning | Action |
|------|---------|--------|
| 0 | Success | Continue |
| 1001 | Bad/expired token | Re-auth via anonymous-token (tokens expire after 7 days) |
| 1002 | Session not found | New session §3.0 |
| 2001 | No credits | Anonymous: show registration URL with `?bind=<id>` (get `<id>` from create-session or state response when needed). Registered: "Top up at nemovideo.ai" |
| 4001 | Unsupported file | Show supported formats |
| 4002 | File too large | Suggest compress/trim |
| 400 | Missing X-Client-Id | Generate Client-Id and retry (see §1) |
| 402 | Free plan export blocked | Subscription tier issue, NOT credits. "Register at nemovideo.ai to unlock export." |
| 429 | Rate limit (1 token/client/7 days) | Retry in 30s once |

**Common**: no video → generate first; render fail → retry new `id`; SSE timeout → §3.6; silent edit → §3.1 fallback.

## 8. Version & Scopes

**Version**: see frontmatter `version`. Check updates weekly: `clawhub search nemo-video --json`. Notify once if newer exists.

**Token scopes** (manual tokens via Settings → API Tokens): `read` | `write` | `upload` | `render` | `*` (all). Anonymous tokens have `read`, `write`, `upload` scopes and expire in 7 days. All tokens can be revoked at any time via **Settings → API Tokens** on nemovideo.com.

**Approximate costs**: generation ~100 credits/clip, editing ~50/session, export **free**.
