#!/usr/bin/env bash
# send-artifact.sh — send a file or text message to the configured Telegram
# chat using the same env vars as the notification hooks.
#
# Usage:
#   send-artifact.sh [--caption "<text>"] [--type <endpoint>] <file-path>
#   send-artifact.sh --text "<message>"
#
# --type accepts: photo | document | video | audio | animation | voice |
#                 video_note | sticker
# If --type is not given, the endpoint is chosen by file extension; unknown
# extensions fall back to document so the file is always delivered.
#
# Env:
#   CC_TELEGRAM_BOT_TOKEN  (required)
#   CC_TELEGRAM_CHAT_ID    (required)
#   CC_TELEGRAM_DRY_RUN    (optional, "true" prints the planned curl)
#
# Exit codes:
#   0  sent (or dry-run printed)
#   2  usage error
#   3  missing/unreadable file
#   4  missing env (token/chat id)
#   5  Telegram API returned an error
set -euo pipefail

TAG="[$(hostname -s):${CLAUDE_PROJECT_DIR##*/}]"
API_BASE="https://api.telegram.org"

usage() {
    cat <<'EOF' >&2
Usage:
  send-artifact.sh [--caption "<text>"] [--type <endpoint>] <file>
  send-artifact.sh --text "<message>"

Endpoints (auto-detected by extension; override with --type):
  .jpg .jpeg .png .webp           -> photo
  .gif                            -> animation
  .mp4 .mov .mkv .webm            -> video
  .mp3 .m4a .aac .flac .wav       -> audio
  .ogg .opus                      -> voice
  .tgs                            -> sticker
  *                               -> document  (always works, up to 50MB)

Env:
  CC_TELEGRAM_BOT_TOKEN, CC_TELEGRAM_CHAT_ID (required)
  CC_TELEGRAM_DRY_RUN=true  (print plan, do not call API)
EOF
}

# ---------- Pure helpers ----------

# Map a file extension (no leading dot, lowercased) to a Telegram endpoint.
endpoint_for_ext() {
    case "$1" in
        jpg|jpeg|png|webp)            echo photo ;;
        gif)                          echo animation ;;
        mp4|mov|mkv|webm)             echo video ;;
        mp3|m4a|aac|flac|wav)         echo audio ;;
        ogg|opus)                     echo voice ;;
        tgs)                          echo sticker ;;
        *)                            echo document ;;
    esac
}

# Map endpoint name -> (api_method, form_field_name) on stdout, space-separated.
endpoint_api_and_field() {
    case "$1" in
        photo)       echo "sendPhoto photo" ;;
        document)    echo "sendDocument document" ;;
        video)       echo "sendVideo video" ;;
        audio)       echo "sendAudio audio" ;;
        animation)   echo "sendAnimation animation" ;;
        voice)       echo "sendVoice voice" ;;
        video_note)  echo "sendVideoNote video_note" ;;
        sticker)     echo "sendSticker sticker" ;;
        *)           return 1 ;;
    esac
}

# ---------- Parse args ----------

CAPTION=""
EXPLICIT_TYPE=""
TEXT_MODE=0
TEXT_MSG=""
FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --caption)
            [[ $# -lt 2 ]] && { echo "send-artifact: --caption requires a value" >&2; exit 2; }
            CAPTION="$2"; shift 2 ;;
        --type)
            [[ $# -lt 2 ]] && { echo "send-artifact: --type requires a value" >&2; exit 2; }
            EXPLICIT_TYPE="$2"; shift 2 ;;
        --text)
            [[ $# -lt 2 ]] && { echo "send-artifact: --text requires a value" >&2; exit 2; }
            TEXT_MODE=1; TEXT_MSG="$2"; shift 2 ;;
        -h|--help)
            usage; exit 0 ;;
        --)
            shift; break ;;
        -*)
            echo "send-artifact: unknown flag '$1'" >&2; usage; exit 2 ;;
        *)
            [[ -n "$FILE" ]] && { echo "send-artifact: only one <file> allowed (got '$FILE' and '$1')" >&2; exit 2; }
            FILE="$1"; shift ;;
    esac
done

if (( TEXT_MODE )) && [[ -n "$FILE" ]]; then
    echo "send-artifact: --text cannot be combined with a file argument" >&2
    exit 2
fi
if (( ! TEXT_MODE )) && [[ -z "$FILE" ]]; then
    echo "send-artifact: <file> or --text required" >&2
    usage; exit 2
fi

# ---------- Validate env ----------

if [[ -z "${CC_TELEGRAM_BOT_TOKEN:-}" || -z "${CC_TELEGRAM_CHAT_ID:-}" ]]; then
    echo "send-artifact: set CC_TELEGRAM_BOT_TOKEN and CC_TELEGRAM_CHAT_ID before calling" >&2
    exit 4
fi

# ---------- Text-only branch ----------

if (( TEXT_MODE )); then
    MESSAGE="$TAG $TEXT_MSG"
    if [[ "${CC_TELEGRAM_DRY_RUN:-false}" == "true" ]]; then
        echo "[DRY RUN] sendMessage chat_id=$CC_TELEGRAM_CHAT_ID text=$MESSAGE"
        exit 0
    fi
    RESPONSE="$(curl -sS -X POST "$API_BASE/bot$CC_TELEGRAM_BOT_TOKEN/sendMessage" \
        --data-urlencode "chat_id=$CC_TELEGRAM_CHAT_ID" \
        --data-urlencode "text=$MESSAGE" \
        --data-urlencode "parse_mode=HTML" || true)"
    if [[ "$RESPONSE" != *'"ok":true'* ]]; then
        echo "send-artifact: Telegram API error: $RESPONSE" >&2
        exit 5
    fi
    echo "sent: text"
    exit 0
fi

# ---------- File branch ----------

[[ -r "$FILE" ]] || { echo "send-artifact: cannot read file '$FILE'" >&2; exit 3; }

EXT="${FILE##*.}"
EXT_LOWER="$(printf '%s' "$EXT" | tr '[:upper:]' '[:lower:]')"

if [[ -n "$EXPLICIT_TYPE" ]]; then
    ENDPOINT="$EXPLICIT_TYPE"
else
    ENDPOINT="$(endpoint_for_ext "$EXT_LOWER")"
fi

PAIR="$(endpoint_api_and_field "$ENDPOINT")" \
    || { echo "send-artifact: unknown --type '$ENDPOINT'" >&2; exit 2; }
API_METHOD="${PAIR% *}"
FIELD_NAME="${PAIR#* }"

# Compose caption with the [host:project] tag prepended. Skip caption for
# stickers / voice notes / video notes (Telegram ignores or rejects caption
# on those endpoints).
FULL_CAPTION=""
case "$ENDPOINT" in
    sticker|voice|video_note) FULL_CAPTION="" ;;
    *) FULL_CAPTION="$TAG${CAPTION:+ $CAPTION}" ;;
esac

if [[ "${CC_TELEGRAM_DRY_RUN:-false}" == "true" ]]; then
    echo "[DRY RUN] $API_METHOD chat_id=$CC_TELEGRAM_CHAT_ID $FIELD_NAME=@$FILE caption='$FULL_CAPTION'"
    exit 0
fi

# Build curl args. Use --form for multipart so files upload correctly.
CURL_ARGS=(
    -sS -X POST
    "$API_BASE/bot$CC_TELEGRAM_BOT_TOKEN/$API_METHOD"
    -F "chat_id=$CC_TELEGRAM_CHAT_ID"
    -F "$FIELD_NAME=@$FILE"
)
if [[ -n "$FULL_CAPTION" ]]; then
    CURL_ARGS+=( -F "caption=$FULL_CAPTION" -F "parse_mode=HTML" )
fi

RESPONSE="$(curl "${CURL_ARGS[@]}" || true)"
if [[ "$RESPONSE" != *'"ok":true'* ]]; then
    echo "send-artifact: Telegram API error from $API_METHOD: $RESPONSE" >&2
    exit 5
fi

echo "sent: $ENDPOINT ($FILE)"
