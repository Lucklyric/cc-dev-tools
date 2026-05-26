---
name: telegram
description: This skill should be used when the user asks to send a file, artifact, image, document, PDF, video, audio, or text message to their Telegram chat. Triggers include "use asun:telegram to send …", "send this to telegram", "telegram this file", "post to telegram", "share via telegram", or any phrase that asks Claude to push content through the user's personal Telegram channel. The skill is one-way (Claude → Telegram); it does not read incoming Telegram messages.
---

# Telegram: Send Artifacts to the User's Channel

Use the configured Telegram bot to push files or text messages to the user's chat. The same `CC_TELEGRAM_BOT_TOKEN` / `CC_TELEGRAM_CHAT_ID` that power the notification hooks also drive this skill — no extra setup.

## When to use

Trigger on phrases that explicitly mention Telegram as the destination:

- "use asun:telegram to send <file>"
- "telegram this PDF / image / video"
- "send <path> to telegram"
- "post <path> to my telegram"
- "share these artifacts via telegram"

Do NOT trigger when the user just mentions Telegram in passing (e.g., "the telegram bot is working"). Trigger only when Telegram is the requested destination for a specific artifact or message.

## How to call the helper

```bash
$CLAUDE_PLUGIN_ROOT/scripts/send-artifact.sh [--caption "<text>"] [--type <endpoint>] <file-path>
$CLAUDE_PLUGIN_ROOT/scripts/send-artifact.sh --text "<message>"
```

The helper auto-detects the right Telegram endpoint from the file extension and falls back to `sendDocument` for anything unknown, so a single call works for most files.

## File path resolution

1. If the user gives an absolute path, use it as-is.
2. If the user gives a relative path or a bare filename, resolve against `$PWD` first.
3. If the file doesn't exist at the resolved path, list candidate matches via `find . -maxdepth 3 -iname "<basename>"` and ask the user to confirm before sending.
4. Never invent a path. If you cannot find the file, say so.

## Extension → endpoint mapping

| Extension | Endpoint | Notes |
|---|---|---|
| `.jpg` `.jpeg` `.png` `.webp` | `sendPhoto` | Inline preview in Telegram. 10MB limit. |
| `.gif` | `sendAnimation` | Animated, no audio. |
| `.mp4` `.mov` `.mkv` `.webm` | `sendVideo` | Up to 50MB via bot API. |
| `.mp3` `.m4a` `.aac` `.flac` `.wav` | `sendAudio` | Music-style player. |
| `.ogg` `.opus` | `sendVoice` | Voice-note style. |
| `.tgs` | `sendSticker` | Telegram animated sticker format. |
| anything else | `sendDocument` | Generic file, filename preserved, up to 50MB. |

Override with `--type <endpoint>` if the auto-detection picks the wrong one (e.g., `.gif` you want as a static image: `--type document`).

## Caption handling

- The helper always prepends a `[hostname:project]` tag so the user can see which session sent the file.
- If the user supplies extra text ("send foo.pdf with note: this is the v2 draft"), pass it via `--caption "this is the v2 draft"`.
- If the user does not supply a note, omit `--caption` — the tag alone is sent.
- Stickers, voice notes, and video notes do not accept captions; the helper drops the caption silently for those endpoints.

## Multiple files

Telegram's bot API has no batch upload for arbitrary documents, so loop one call per file. Surface successes and failures per file:

```bash
for f in report.pdf chart.png notes.md; do
    $CLAUDE_PLUGIN_ROOT/scripts/send-artifact.sh --caption "v2 review pack" "$f" || echo "failed: $f"
done
```

For an image album (multiple photos in one Telegram message), the bot API supports `sendMediaGroup` — not implemented in v0.4.0. If the user asks for an album, send individually and note the limitation.

## Size limits

| Endpoint | Limit |
|---|---|
| `sendPhoto` | 10 MB |
| `sendDocument` and most others | 50 MB |
| Local Bot API server | up to 2 GB (not configured by default) |

If a file exceeds the limit, the API returns an error; surface it verbatim. Common workaround: tar/zip the file, or split, then resend.

## Error handling

The helper exits non-zero on every failure with a clear stderr message:

| Exit | Meaning |
|---|---|
| 2 | Usage error (bad flags, missing file arg). Recheck the invocation. |
| 3 | File not readable. Confirm path with the user. |
| 4 | `CC_TELEGRAM_BOT_TOKEN` or `CC_TELEGRAM_CHAT_ID` not set. Ask the user to export them. |
| 5 | Telegram API returned an error. Surface the API response so the user sees the reason (often size limit, wrong file type for endpoint, or auth issue). |

Always surface the helper's output verbatim — do not paraphrase API errors.

## Dry-run

Set `CC_TELEGRAM_DRY_RUN=true` to print the planned call without hitting the API. Useful for verifying which endpoint will be chosen before actually sending.

## Reference index

- `scripts/send-artifact.sh` — the helper script (single file, fully self-contained).
- `hooks/notify.sh` — the legacy notification helper, unchanged.
- `hooks/hooks.json` — Stop / SubagentStop / Notification hook definitions, unchanged.
