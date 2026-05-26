# Telegram Notifier Plugin

A two-way-light, one-way-strong Telegram bridge for Claude Code. The plugin started as a notification-only hook bundle (v0.3.0 and earlier) and now also exposes a **skill** for on-demand artifact sending (v0.4.0+).

## Features

- **Stop Hook**: Notifies when Claude Code completes a response
- **SubagentStop Hook**: Notifies when subagent tasks complete
- **Notification Hook**: Forwards Claude Code system notifications
- **Telegram Skill (v0.4.0+)**: On-demand artifact sending — say "use asun:telegram to send foo.pdf" or "telegram this image" and Claude routes it to your chat. Auto-detects file kind (photo, video, audio, voice, animation, sticker, document) and falls back to `sendDocument` for anything unknown.
- **Custom Messages**: Customize notification messages via environment variables
- **Dry-Run Mode**: Test configuration without sending real notifications

## Quick Setup

### 1. Create a Telegram Bot

1. Open Telegram and search for `@BotFather`
2. Send `/newbot` command
3. Follow prompts to name your bot
4. Copy the **bot token** (looks like `123456789:ABCdefGHIjklMNOpqrsTUVwxyz`)

### 2. Get Your Chat ID

1. Start a conversation with your new bot (send any message)
2. Open this URL in browser (replace TOKEN with your bot token):
   ```
   https://api.telegram.org/bot<TOKEN>/getUpdates
   ```
3. Find `"chat":{"id":123456789}` in the response - that's your chat ID

### 3. Set Environment Variables

Add to your shell profile (`~/.zshrc`, `~/.bashrc`, etc.):

```bash
export CC_TELEGRAM_BOT_TOKEN="your-bot-token-here"
export CC_TELEGRAM_CHAT_ID="your-chat-id-here"
```

Reload your shell:
```bash
source ~/.zshrc  # or ~/.bashrc
```

### 4. Install the Plugin

```bash
claude plugins add cc-dev-tools/telegram-notifier
```

### 5. Verify Setup

Test your credentials:
```bash
curl -s -X POST "https://api.telegram.org/bot$CC_TELEGRAM_BOT_TOKEN/sendMessage" \
  -d "chat_id=$CC_TELEGRAM_CHAT_ID" \
  -d "text=Test from Claude Code setup"
```

## Environment Variables

### Required

| Variable | Description |
|----------|-------------|
| `CC_TELEGRAM_BOT_TOKEN` | Bot API token from BotFather |
| `CC_TELEGRAM_CHAT_ID` | Target chat ID for notifications |

### Optional (Custom Messages)

| Variable | Default | Description |
|----------|---------|-------------|
| `CC_TELEGRAM_STOP_MSG` | `[{host}:{project}] Claude Code response completed at {timestamp}` | Custom message for Stop events |
| `CC_TELEGRAM_SUBAGENT_MSG` | `[{host}:{project}] Claude Code subagent completed at {timestamp}` | Custom message for SubagentStop events |
| `CC_TELEGRAM_NOTIFY_MSG` | `[{host}:{project}] Claude Code notification` | Custom message for Notification events |

### Optional (Control)

| Variable | Default | Description |
|----------|---------|-------------|
| `CC_TELEGRAM_DRY_RUN` | `false` | Set to `true` to log messages without sending |

## Custom Message Examples

```bash
# Simple custom messages
export CC_TELEGRAM_STOP_MSG="Claude session finished"
export CC_TELEGRAM_SUBAGENT_MSG="Background task done"
export CC_TELEGRAM_NOTIFY_MSG="Alert from Claude"

# With timestamp (default behavior)
export CC_TELEGRAM_STOP_MSG="Claude Code response completed at $(date '+%Y-%m-%d %H:%M:%S')"

# With project info
export CC_TELEGRAM_STOP_MSG="Done working on $(basename $(pwd))"
```

**Tip**: Use `$()` for shell expansions that should evaluate at notification time.

## Dry-Run Mode

Test your configuration without sending real notifications:

```bash
export CC_TELEGRAM_DRY_RUN="true"
```

When enabled, the plugin prints `[DRY RUN] <message>` to the terminal instead of sending to Telegram.

## Events That Trigger Notifications

| Event | Default Message | When |
|-------|-----------------|------|
| Stop | [host:project] Claude Code response completed at {time} | Claude Code completes a response |
| SubagentStop | [host:project] Claude Code subagent completed at {time} | Background agent finishes |
| Notification | [host:project] Claude Code notification | System notification |

## Sending Artifacts (v0.4.0+)

The telegram skill activates whenever you tell Claude to push something to Telegram:

```
You: use asun:telegram to send ~/Downloads/report.pdf
You: telegram this image: docs/architecture.png
You: send these to telegram: chart.png, notes.md, demo.mp4
You: post to telegram with note "v2 review pack", file: report.pdf
```

Claude calls the helper script:

```bash
$CLAUDE_PLUGIN_ROOT/scripts/send-artifact.sh [--caption "<text>"] [--type <endpoint>] <file>
$CLAUDE_PLUGIN_ROOT/scripts/send-artifact.sh --text "<message>"
```

### Endpoint auto-detection

| Extension | Endpoint | Notes |
|---|---|---|
| `.jpg` `.jpeg` `.png` `.webp` | `sendPhoto` | Inline preview, 10MB limit |
| `.gif` | `sendAnimation` | Animated, no audio |
| `.mp4` `.mov` `.mkv` `.webm` | `sendVideo` | 50MB bot-API limit |
| `.mp3` `.m4a` `.aac` `.flac` `.wav` | `sendAudio` | Music-style player |
| `.ogg` `.opus` | `sendVoice` | Voice-note style |
| `.tgs` | `sendSticker` | Animated sticker |
| anything else | `sendDocument` | Generic, filename preserved, 50MB |

Override with `--type` if needed: `--type document` forces document mode even for images.

### Captions

If you say "send foo.pdf with note: v2 draft", the note becomes the Telegram caption. The script always prepends a `[hostname:project]` tag so you can tell which session sent which file.

### Exit codes

| Exit | Meaning |
|---|---|
| 0 | Sent (or dry-run printed) |
| 2 | Usage error |
| 3 | File not readable |
| 4 | Token or chat ID env var unset |
| 5 | Telegram API returned an error (size limit, auth, etc.) — full response shown on stderr |

### Try it in dry-run

```bash
CC_TELEGRAM_DRY_RUN=true $CLAUDE_PLUGIN_ROOT/scripts/send-artifact.sh ~/Downloads/report.pdf
# [DRY RUN] sendDocument chat_id=... document=@/Users/.../report.pdf caption='[host:project]'
```

## Troubleshooting

### No notifications received

1. Verify environment variables are set:
   ```bash
   echo $CC_TELEGRAM_BOT_TOKEN
   echo $CC_TELEGRAM_CHAT_ID
   ```

2. Test manually:
   ```bash
   curl -s -X POST "https://api.telegram.org/bot$CC_TELEGRAM_BOT_TOKEN/sendMessage" \
     -d "chat_id=$CC_TELEGRAM_CHAT_ID" \
     -d "text=Test message"
   ```

3. Check if bot is blocked - ensure you've sent at least one message to your bot

### "Failed to send Telegram notification" error

- Network connectivity issue
- Invalid bot token or chat ID
- Bot was deleted or disabled

## License

Apache-2.0
