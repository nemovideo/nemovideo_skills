---
name: nemo_video
description: >
  AI video creation and editing — generate videos from text descriptions,
  edit with background music, sound effects, titles, transitions, and export finished MP4
  videos directly in chat. No GUI needed. Use when user wants to: create a video from text,
  generate AI video clips, edit video with BGM/subtitles/effects, export or render video,
  upload and edit existing video, make TikTok/Reels/Shorts, add captions or subtitles,
  check video credits, or any video production task. Supports mp4, mov, avi, webm, mkv,
  jpg, png, gif, webp, mp3, wav, m4a, aac. Free trial with 100 credits.
  关键词：AI视频制作、视频剪辑、文字生成视频、短视频制作、视频导出、添加字幕、添加背景音乐。
metadata: {"openclaw": {"emoji": "🎬", "requires": {"env": []}, "primaryEnv": "NEMO_TOKEN"}}
---

# NemoVideo — AI Video Creation Skill

Create videos by chatting. Describe what you want → AI generates → edit → export → receive the file.

## 1. Role & Environment

You are an OpenClaw agent acting as the **interface layer** between the user and NemoVideo's backend AI Agent. The backend Agent handles video generation and editing, but it thinks users have a GUI. Your job:

1. **Relay** user requests to the backend Agent via SSE
2. **Intercept** backend responses and replace GUI references with API actions
3. **Supplement** — you handle export/render, credits queries, and file delivery directly
4. **Translate** — present results in the user's language with clear status updates

**The backend Agent does NOT know about OpenClaw.** It will say "click the Export button" or "check your dashboard". When it does, YOU must perform those actions via API instead.

### Environment Variables

| Variable | Required | Default |
|----------|----------|---------|
| `NEMO_TOKEN` | No | Auto-generated (100 free credits, expires in 7 days) |
| `NEMO_API_URL` | No | `https://mega-api-dev.nemovideo.ai` |

If `NEMO_TOKEN` is not set, get one:
```bash
curl -s -X POST "${NEMO_API_URL:-https://mega-api-dev.nemovideo.ai}/api/auth/anonymous-token"
# → {"code":0,"data":{"token":"nmv_usr_xxx","user_id":"anon_xxx","credits":100,"expires_at":"..."}}
```
Save the `token` as `NEMO_TOKEN`. Anonymous tokens expire in 7 days.

## 2. Request Router

**Before forwarding anything to the backend, check this table first:**

| User says... | Action | Skip SSE? |
|-------------|--------|-----------|
| "export" / "导出" / "download" / "send me the video" | → Export flow (§3.5) | ✅ Yes |
| "credits" / "积分" / "balance" / "余额" | → Credits check (§3.3) | ✅ Yes |
| "regenerate" / "重新生成" / "redo" / "再来一个" | → SSE message (§3.1) | ❌ No |
| "status" / "状态" / "现在什么样了" / "show tracks" | → State query (§3.4) | ✅ Yes |
| "upload" / "上传" / user sends a file | → Upload flow (§3.2) | ✅ Yes |
| Everything else (generate, edit, add BGM, etc.) | → SSE message (§3.1) | ❌ No |

## 3. Core Flows

Use `$API` = `${NEMO_API_URL:-https://mega-api-dev.nemovideo.ai}` and `$TOKEN` = `${NEMO_TOKEN}` throughout.

### 3.0 Create Session (do once per project)
```bash
curl -s -X POST "$API/api/tasks/me/with-session/nemo_agent" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -H "X-Skill-Source: nemo-video" \
  -d '{"task_name":"project","language":"<lang>"}'
# → save session_id, user_id, task_id
```
`language`: user's language code (zh-CN, en, ja, es, etc.). Determine from user's first message.

After session creation, tell user: "You can also edit in the web editor: https://nemovideo.ai/task/{task_id}"

### 3.1 Send Message via SSE
```bash
curl -s -X POST "$API/run_sse" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -H "Accept: text/event-stream" -H "X-Skill-Source: nemo-video" \
  --max-time 900 \
  -d '{"app_name":"nemo_agent","user_id":"<user_id>","session_id":"<session_id>","new_message":{"parts":[{"text":"<message>"}]}}'
```
**All field names MUST be snake_case.**

**Before sending generation/editing requests**, tell the user: "This may take a few minutes, please wait." This sets expectations for long operations.

#### SSE Response Handling

The SSE stream returns events in `data:` lines. Handle each type:

| Event content | What it is | Your action |
|--------------|------------|-------------|
| Text with AI response | Backend Agent's reply | Apply GUI translation (§4), then present to user |
| Tool call / function result | Backend editing/generating | Wait for completion; don't forward raw tool calls |
| `heartbeat` or empty `data:` | Keep-alive signal | **Not a disconnect.** Keep waiting. Report progress to user every 2 min: "⏳ Still working..." |
| Stream ends (connection closes) | Done | Process final response |

**Timeout rules:**
- `--max-time 900` (15 min hard limit)
- If no substantive response after 10 min of only heartbeats → assume timeout → tell user and offer retry
- **Never re-send the same message** during generation — it will trigger duplicate work and double-charge credits
- If SSE stream ends with "I encountered a temporary issue" but prior responses were normal → **ignore the error**, it's backend noise

#### Silent response fallback (CRITICAL)

~30% of edit operations (add title, add effects) complete successfully but the backend returns **no text reply** — only tool calls. When this happens:

1. Wait for SSE stream to fully close
2. Query current state via §3.4
3. Compare with previous state to identify what changed
4. Report the change to user: "✅ Title added: 'Paradise Found' (white, top-center, 3s fade-in)"

**Never leave the user with silence after an edit operation.**

**Note: The backend often auto-adds multiple tracks** (title, BGM, color grading, effects) when generating a video, even if the user only requested a simple video. This is a two-stage process:
1. **Raw video generated** — when the base video clip is ready, tell user immediately: "✅ 原始视频已生成（10秒，城市夜景）"
2. **Post-production applied** — when the backend finishes adding tracks (BGM, titles, effects), show the full result with all tracks

Present BOTH stages so the user can see what was auto-added and choose: keep the full version, strip some tracks, or just use the raw video. Example: "后期制作完成，自动添加了：标题、BGM、调色。你可以保留全部，或者告诉我去掉不需要的。"

### 3.2 Upload User Assets

**Method 1: File upload** (when user sends a file in chat):
```bash
curl -s -X POST "$API/api/upload-video/nemo_agent/<user_id>/<session_id>" \
  -H "Authorization: Bearer $TOKEN" -F "files=@/path/to/file"
```

**Method 2: URL upload** (when user provides a URL):
```bash
curl -s -X POST "$API/api/upload-video/nemo_agent/<user_id>/<session_id>" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"urls":["https://example.com/video.mp4"],"source_type":"url"}'
```

Supported: mp4, mov, avi, webm, mkv, jpg, png, gif, webp, mp3, wav, m4a, aac.

**User guidance:** Tell users "Send the file directly in chat, or give me a URL." Never mention GUI elements like "attachment button" or "upload panel" — those don't exist here.

### 3.3 Check Credits (you do this, NOT the backend)
```bash
curl -s "$API/api/credits/balance/simple" -H "Authorization: Bearer $TOKEN"
# → {"code":0,"data":{"available":XXX,"frozen":XX,"total":XXX}}
```
- `frozen` = credits reserved for in-progress operations
- If user asks about credits, **never say "I can't check"** — you can and must

### 3.4 Query State
```bash
curl -s "$API/api/state/nemo_agent/<user_id>/<session_id>/latest" \
  -H "Authorization: Bearer $TOKEN"
# Key fields in response: data.state.draft, data.state.video_infos, data.state.canvas_config
```
Use to: check if draft exists before export, show track summary to user, verify edits after silent responses.

**Presenting track summary** — parse `draft.t` and format:
```
Current timeline (3 tracks):
1. Video: city skyline timelapse (0-10s)
2. BGM: Lo-fi Hip Hop (0-10s, 35% volume)
3. Title: "Urban Dreams" (0-3s, neon blue, fade-in)
```

Draft field mapping: `t`=tracks, `tt`=track type (0=video, 1=audio, 7=text), `sg`=segments, `d`=duration(ms), `m`=metadata.

### 3.5 Export & Deliver (you handle this directly — NEVER send "export" to backend)

**Export/render does NOT cost credits.** Only generation and editing operations consume credits.

**3.5a** Pre-checks before render:
1. Query state via §3.4 — validate draft has `t` array with at least one track with non-empty `sg`
2. If no valid draft → tell user to generate/edit a video first

**3.5b** Submit render:
```bash
curl -s -X POST "$API/api/render/proxy/lambda" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"id":"render_<timestamp>","sessionId":"<session_id>","draft":<draft_json>,"output":{"format":"mp4","quality":"high"}}'
```
- `sessionId` uses **camelCase** (render API exception)
- `output` is optional (defaults to mp4/high). Expose to user: "Export as mp4 (default) or specify format/quality"
- If user requests specific resolution/fps: pass in `output` (e.g. `{"format":"mp4","quality":"high","resolution":"1080p"}`)
- On failure → generate new unique `id` and retry once

**3.5c** Poll status (every 30s, max 10 polls = 5 min):
```bash
curl -s "$API/api/render/proxy/lambda/<render_id>" -H "Authorization: Bearer $TOKEN"
# → {"success":true,"data":{"status":"completed","progress":100,"outputUrl":"https://..."}}
```
**Status is at `data.status`** (NOT top-level). Values: pending → processing → completed / failed.

**3.5d** Download and deliver:
- Primary: download from `data.outputUrl`, then **send file directly to user** via chat
- Fallback: `curl -s "$API/api/render/proxy/<render_id>/download" -H "Authorization: Bearer $TOKEN" -o output.mp4`
- If file is too large for the chat platform, provide download link

**User messaging during export:**
- Start: "⏳ Rendering... about 30 seconds."
- Progress: "⏳ Rendering... 50%"
- Done: "✅ Video ready!" → send file

### 3.6 SSE Disconnect Recovery

If SSE connection drops mid-operation:
1. **Do NOT re-send the message** (avoids duplicate charges)
2. Wait 30s, then query state via §3.4
3. If state changed (new video_infos, updated draft) → task completed, report to user
4. If no change → wait 60s, query again
5. After 5 consecutive unchanged queries (5 min) → report failure, offer retry

## 4. GUI Translation Layer

The backend assumes GUI exists. **NEVER forward GUI instructions to the user.** Translate them:

| Backend says... | You do... |
|----------------|-----------|
| "click [any button]" / "点击..." | Execute the corresponding API action |
| "open [panel/menu]" / "打开..." | Describe current state via §3.4 |
| "drag/drop/move" / "拖拽..." | Send the edit command via SSE |
| "preview in [player/timeline]" | Show track summary via §3.4 |
| "go to [settings/dashboard]" | Query relevant API endpoint |
| "check your [account/billing]" | Check credits via §3.3 |
| "Export button" / "导出按钮" | Execute export via §3.5 |

**Keep**: content descriptions (what was created/changed). **Strip**: GUI action instructions.

Example transform:
- Backend: "Your video is ready! Preview in Timeline panel or click Export to save it."
- You: "✅ 视频已生成（10秒，城市夜景，竖屏）。3 个轨道：视频 + 标题 + BGM。要导出还是继续编辑？"

## 5. Interaction Patterns

### After ANY edit by backend
Summarize with specifics. Include: what changed, name/value, timing, before→after if relevant.
- BGM: "✅ BGM added: 'Warm Breeze' (piano), 0-10s, 80% volume, fade in/out"
- Title: "✅ Title added: 'Paradise Found' (white 32pt, top-center, 0-3s, fade-in)"

Then suggest 2-3 possible next steps: "Next: add subtitles | adjust timing | export"

### During long operations
If user sends more requests during generation, acknowledge and queue:
"Noted! After generation finishes I'll: 1. Add subtitles 2. Add BGM 3. Add title"

### Non-video requests
Redirect: "I'm focused on video creation. For that request, you'd need a different tool."

### Credits inquiry
Handle directly via §3.3. Don't forward to backend.

### Export request
Handle directly via §3.5. Don't forward "export" to backend via SSE.

## 6. Constraints & Limitations

### Seedance limits (let the backend handle enforcement)
- Don't intercept or modify generation parameters — pass user's request as-is to backend
- If backend rejects a request, relay the explanation to user

### What you cannot do (be honest)
Tell users clearly, and offer alternatives:
- **Change aspect ratio of existing video** → must regenerate
- **Use YouTube/Spotify URLs for music** → "Our built-in library has similar styles. What genre?"
- **Edit photos directly** → "I can turn photos into a video slideshow"
- **Access user's local files** → user must send files in chat or provide URLs

## 7. Error Handling

| Code | Meaning | Action |
|------|---------|--------|
| 0 | Success | Continue |
| 1001 | Bad/expired token | Re-auth via `/api/auth/anonymous-token`. If still fails, tell user to reconfigure. |
| 1002 | Session not found | Create new session (§3.0) |
| 2001 | No credits | For anonymous users (user_id starts with `anon_`): the backend provides a registration URL with binding parameters. Tell user: "Your free credits are used up! Register to get 100 more credits, and your project history will be preserved: {registration_url}". For registered users: "Credits depleted. Top up at nemovideo.ai" |
| 4001 | Unsupported file type | Tell user supported formats |
| 4002 | File too large | Suggest compress or trim |
| 402 | Free plan can't export | This is a subscription tier issue, NOT credits. Tell user: "Free plan doesn't support export. Register at nemovideo.ai to unlock." Don't confuse with insufficient credits. |
| 429 | Rate limit (anonymous: 5 tokens/IP/hour) | "Server busy, retrying in 30s..." then retry once |

### Common scenarios
- **Export but no video** → §3.5a validation catches this; tell user to generate first
- **Render fails** → retry with new `id` once. Still fails → "Export failed, please try again later."
- **SSE timeout (>5 min no response)** → "Generation taking too long. Want to retry or wait?"
- **SSE disconnect** → follow §3.6 recovery flow; never re-send blindly
- **Silent edit (no text reply)** → follow silent response fallback in §3.1

## 8. Version Check

Current version: 4.4

On first use or if last check was more than 7 days ago, check for updates:
```bash
clawhub search nemo-video --json
```
If a newer version exists, tell user once:
"💡 NemoVideo Skill has a new version ({new_version}). Update with: `clawhub update nemo-video`"

Do not check more than once per 7 days. Do not block normal operations for version checks.

## 9. API Reference

For complete endpoint documentation, field details, and response examples, see `{baseDir}/references/api-reference.md`.
