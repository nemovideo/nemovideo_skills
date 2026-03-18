# 🎬 NemoVideo — AI Video Creation Skill

Create videos by chatting. Describe what you want → AI generates → edit → export → receive the file.

> An [OpenClaw](https://openclaw.ai) Skill that connects any AI agent to NemoVideo's video creation engine.

## What It Does

- **Text to Video** — describe a scene, get a video clip
- **AI Editing** — add BGM, titles, subtitles, transitions, effects by chatting
- **Export** — render and download finished MP4 directly in chat
- **Upload & Edit** — bring your own footage, let AI remix it
- **Zero Config** — works out of the box with free 100 credits, no signup needed

## Quick Start

### Install via ClawHub

```bash
clawhub install nemo-video
```

### Or install manually

Copy the `SKILL.md` to your OpenClaw skills directory:

```bash
# Clone the repo
git clone https://github.com/nemovideo/nemovideo_skills.git

# Copy to your OpenClaw skills directory
cp -r nemovideo_skills ~/.openclaw/skills/nemo-video
```

### Use it

Just talk to your agent:

```
"Make me a 10-second sunset timelapse video"
"Add lo-fi background music"
"Put a title 'Golden Hour' at the beginning"
"Export it"
```

## How It Works

```
You ↔ OpenClaw Agent ↔ [SKILL.md] ↔ NemoVideo Backend AI Agent
                           ↕
                    API (SSE + REST)
```

The Skill acts as an **interface layer** between OpenClaw and NemoVideo's backend:

1. **Relay** — forwards your requests to NemoVideo's AI agent
2. **Translate** — converts GUI-oriented responses into chat-friendly actions
3. **Supplement** — handles export, credits, and file delivery directly via API
4. **Recover** — manages SSE timeouts, silent responses, and disconnects

## Configuration

| Environment Variable | Required | Default |
|---------------------|----------|---------|
| `NEMO_TOKEN` | No | Auto-generated (100 free credits) |
| `NEMO_API_URL` | No | `https://mega-api-dev.nemovideo.ai` |
| `NEMO_CLIENT_ID` | No | Auto-generated UUID, persisted locally |

**No config needed for first use.** The Skill auto-creates an anonymous account with 100 trial credits (1 token per client per 7 days; token does not expire).

### Getting More Credits

When free credits run out, the Skill provides a registration link that preserves your project history. Register at [nemovideo.ai](https://nemovideo.ai) for more credits.

## Supported Formats

| Type | Formats |
|------|---------|
| Video | mp4, mov, avi, webm, mkv |
| Image | jpg, png, gif, webp |
| Audio | mp3, wav, m4a, aac |

## Version

Current: **v1.6** — see [CHANGELOG.md](CHANGELOG.md) for full release history.

### Version management

- **Single source**: `VERSION` (root) and `version` in SKILL.md frontmatter. Keep them equal.
- **When releasing**: run `./scripts/bump-version.sh <new_version>` (e.g. `4.7` or `4.6.0`), update `CHANGELOG.md`, then commit and optionally `git tag v$(cat VERSION)`.

## Links

- 🌐 [NemoVideo](https://nemovideo.ai) — Product website
- 📦 [ClawHub](https://clawhub.com) — Skill marketplace
- 🐙 [OpenClaw](https://openclaw.ai) — Agent framework

## License

MIT
