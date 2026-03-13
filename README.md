# Nemo Video OpenClaw Skill

OpenClaw Skill for interacting with Nemo Video AI video creation platform.

## Features

- Create video creation sessions
- Chat with Nemo Video AI Agent via SSE streaming
- Upload media assets (video, image, audio)
- Get session state (uploaded assets, timeline tracks, AI analysis results)
- Export video (render draft to final video file)
- **Auto-provisioning**: No registration required, get started immediately
- **Secure authentication with User Access Token**

## Quick Start

### Zero Configuration (Recommended)

Just use the skill - it will automatically create an anonymous account with 100 trial credits:

```bash
# Start a new video project (token auto-generated)
openclaw agent --message "use nemo_video to create a 30-second intro video"
```

### Manual Token Configuration

For long-term use or more control:

1. Log in to [Nemo Video](https://app.nemovideo.ai)
2. Go to **Settings → API Tokens**
3. Click **Create Token**, select scopes
4. Add to `~/.openclaw/openclaw.json`:

```json5
{
  skills: {
    load: {
      extraDirs: ["/path/to/mega-skill"]
    },
    entries: {
      "nemo_video": {
        enabled: true,
        env: {
          NEMO_TOKEN: "nmv_usr_xxxxxxxxxxxxxxxx"
        }
      }
    }
  }
}
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `NEMO_TOKEN` | No | User Access Token (auto-generated if not set) |
| `NEMO_API_URL` | No | API URL (default: `https://mega-api-dev.nemovideo.ai`) |

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/auth/anonymous-token` | POST | Get anonymous token (no auth required) |
| `/api/tasks/me/with-session/nemo_agent` | POST | Create session |
| `/run_sse` | POST | Chat with AI Agent (SSE) |
| `/api/upload-video/nemo_agent/{user_id}/{session_id}` | POST | Upload assets |
| `/api/state/nemo_agent/{user_id}/{session_id}/latest` | GET | Get session state |
| `/api/render/proxy/draft` | POST | Create render task |
| `/api/render/proxy/{task_id}` | GET | Query render status |
| `/api/render/proxy/{task_id}/download` | GET | Download video |

## Authentication

### Anonymous Token (Auto-provisioning)

For first-time users without a token:

```bash
# Get anonymous token (no authentication required)
curl -X POST "https://mega-api-dev.nemovideo.ai/api/auth/anonymous-token"

# Response:
# {
#   "code": 0,
#   "data": {
#     "token": "nmv_usr_xxxxxx",
#     "user_id": "anon_abc123",
#     "expires_at": "2026-03-18T00:00:00Z",
#     "credits": 100
#   }
# }
```

### Bearer Token

All subsequent requests use Bearer Token:

```bash
curl -H "Authorization: Bearer ${NEMO_TOKEN}" ...
```

### Token Scopes

| Scope | Description |
|-------|-------------|
| `read` | Read sessions and state |
| `write` | Create sessions, send messages |
| `upload` | Upload media assets |
| `render` | Export videos |
| `*` | All permissions |

## Anonymous User Limits

- Token expires in 7 days
- 100 trial credits included
- Rate limit: 5 anonymous tokens per IP per hour
- Can upgrade to registered user anytime (data preserved)

## Token Management API

Manage tokens programmatically:

```bash
# Create token (requires existing token)
curl -X POST "https://mega-api-dev.nemovideo.ai/api/tokens" \
  -H "Authorization: Bearer <existing_token>" \
  -H "Content-Type: application/json" \
  -d '{"name": "My API Token", "scopes": ["*"], "expires_in_days": 90}'

# List tokens
curl "https://mega-api-dev.nemovideo.ai/api/tokens" \
  -H "Authorization: Bearer <token>"

# Revoke token
curl -X POST "https://mega-api-dev.nemovideo.ai/api/tokens/{token_id}/revoke" \
  -H "Authorization: Bearer <token>"
```

## Migration from API Key

If you were using the old `X-API-Key` + `X-User-Id` authentication:

**Before (deprecated):**
```bash
curl -H "X-API-Key: ${MEGA_API_KEY}" -H "X-User-Id: ${MEGA_USER_ID}" ...
```

**After (recommended):**
```bash
curl -H "Authorization: Bearer ${NEMO_TOKEN}" ...
```

The old method still works but is deprecated. Please migrate to User Access Token.

## License

MIT
