#!/usr/bin/env bash
# codex-tmux.sh — drive interactive codex sessions inside a single tmux session.
# See plugins/codex/skills/codex/references/tmux-mode.md for usage docs.
set -euo pipefail

# ---------- Constants (overridable via env) ----------
readonly SESSION_NAME="${CC_CODEX_SESSION_NAME:-cc-codex}"
readonly READY_REGEX_DEFAULT='▌'
READY_REGEX="${CC_CODEX_READY_REGEX:-$READY_REGEX_DEFAULT}"
readonly DEFAULT_TIMEOUT="${CC_CODEX_TIMEOUT:-600}"
readonly LOCK_DIR="${CC_CODEX_LOCK_DIR:-$HOME/.cache/cc-codex/locks}"
readonly CODEX_BIN="${CC_CODEX_BIN:-codex}"

# ---------- Pure helpers (no tmux, no codex) ----------

compute_claude6() {
    if [[ -n "${CLAUDE_CODE_SESSION_ID:-}" ]]; then
        printf '%s' "${CLAUDE_CODE_SESSION_ID:0:6}"
        return
    fi
    # Fallback: deterministic for the duration of a parent shell session.
    printf '%s' "$PPID:$PWD" | shasum -a 256 | cut -c1-6
}

validate_topic() {
    local topic="$1"
    if [[ ! "$topic" =~ ^[a-z0-9-]{2,15}$ ]]; then
        echo "codex-tmux: invalid topic '$topic' (must be 2-15 chars, [a-z0-9-])" >&2
        return 1
    fi
}

rand_suffix() {
    # Two random chars from [a-z0-9].
    local chars='abcdefghijklmnopqrstuvwxyz0123456789'
    printf '%s%s' \
        "${chars:RANDOM%36:1}" \
        "${chars:RANDOM%36:1}"
}

compose_window_name() {
    local topic="$1"
    validate_topic "$topic" || return 1
    printf 'codex-%s-%s-%s' "$topic" "$(compute_claude6)" "$(rand_suffix)"
}

# ---------- tmux primitives ----------

ensure_tmux_or_die() {
    if ! command -v tmux >/dev/null 2>&1; then
        echo "codex-tmux: 'tmux' is not installed. Install with: brew install tmux" >&2
        exit 127
    fi
}

ensure_session() {
    ensure_tmux_or_die
    if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        # Create detached, with a placeholder first window we'll never use.
        tmux new-session -d -s "$SESSION_NAME" -n "_placeholder" -x 200 -y 50
        # Optionally: set the placeholder to do nothing useful.
        tmux send-keys -t "$SESSION_NAME:_placeholder" "echo 'cc-codex placeholder — do not use'" Enter
    fi
}

window_exists() {
    local window="$1"
    ensure_tmux_or_die
    tmux list-windows -t "$SESSION_NAME" -F '#{window_name}' 2>/dev/null \
        | grep -Fxq "$window"
}

window_pane_pid() {
    # Print the pid of the first pane in the named window.
    local window="$1"
    tmux list-panes -t "$SESSION_NAME:$window" -F '#{pane_pid}' 2>/dev/null | head -n1
}

# ---------- Ready-state polling ----------

capture_pane() {
    local window="$1"
    local lines="${2:-200}"
    tmux capture-pane -t "$SESSION_NAME:$window" -p -S -"$lines" 2>/dev/null
}

# wait_for_ready <window> [timeout]
# Blocks until the bottom of the pane matches READY_REGEX AND the buffer has
# been stable (unchanged) for two consecutive 500ms polls.
# Exit codes: 0 ready, 124 timeout (with last 20 lines + READY_REGEX_MISMATCH on stderr).
wait_for_ready() {
    local window="$1"
    local timeout="${2:-$DEFAULT_TIMEOUT}"
    local poll_ms=500
    local stable_required=2
    local prev_capture=""
    local stable_count=0
    local elapsed=0
    local capture

    while (( elapsed < timeout * 1000 )); do
        capture="$(capture_pane "$window")"
        if [[ -z "$capture" ]]; then
            # Buffer is empty — check if window still exists before giving up.
            if ! window_exists "$window"; then
                echo "codex-tmux: window '$window' has no pane buffer (ENXIO)" >&2
                return 6
            fi
            # Window exists but buffer not yet populated; keep polling.
            sleep 0.5
            elapsed=$(( elapsed + poll_ms ))
            continue
        fi
        # Did it stabilize?
        if [[ "$capture" == "$prev_capture" ]]; then
            stable_count=$(( stable_count + 1 ))
        else
            stable_count=0
        fi
        prev_capture="$capture"
        # Ready marker present at/near bottom?
        if echo "$capture" | tail -n5 | grep -qE "$READY_REGEX"; then
            if (( stable_count >= stable_required )); then
                return 0
            fi
        fi
        sleep 0.5
        elapsed=$(( elapsed + poll_ms ))
    done

    # Timeout
    {
        echo "codex-tmux: timeout after ${timeout}s waiting for ready prompt"
        echo "Marker: READY_REGEX_MISMATCH"
        echo "Override the ready regex with: export CC_CODEX_READY_REGEX='...'"
        echo "Last 20 lines of pane:"
        echo "$capture" | tail -n20 | sed 's/^/  | /'
    } >&2
    return 124
}

# ---------- Usage ----------
usage() {
    cat <<'EOF'
Usage: codex-tmux.sh <subcommand> [args...]

Subcommands:
  new <topic> [--cwd DIR] [--full-auto|--read-only]
      Create a new codex window in the cc-codex tmux session.
      Prints the full window name on stdout plus an attach hint.

  send <window> <prompt> [--timeout SECS]
      Send a prompt to a window, wait for codex to be idle, return the delta.

  capture <window> [--lines N]
      Print the current pane buffer for inspection (does not send anything).

  ls [--mine]
      List codex windows. --mine filters to the current Claude session id.

  attach <window>
      Print the shell command the user can run to attach to a window.

  rename <old-window> <new-topic>
      Rename a window's topic portion; preserves the suffix.

  kill <window> | kill --orphaned
      Kill a specific window, or all windows whose codex process has exited.

  exec [codex-exec flags...] <prompt>
      Run codex exec one-shot outside tmux (escape hatch).

Environment:
  CC_CODEX_SESSION_NAME (default: cc-codex)
  CC_CODEX_READY_REGEX  (default: ▌)
  CC_CODEX_TIMEOUT      (default: 600)
  CC_CODEX_BIN          (default: codex)
EOF
}

# ---------- Dispatch ----------
main() {
    if [[ $# -eq 0 ]]; then
        usage >&2
        exit 2
    fi

    local cmd="$1"
    shift || true

    case "$cmd" in
        -h|--help|help)
            usage
            ;;
        new|send|capture|ls|attach|rename|kill|exec)
            # Subcommand implementations are added in later tasks.
            echo "codex-tmux: subcommand '$cmd' not yet implemented" >&2
            exit 99
            ;;
        _internal)
            local sub="${1:-}"
            shift || true
            case "$sub" in
                claude6) compute_claude6; echo ;;
                validate_topic) validate_topic "$@" ;;
                rand_suffix) rand_suffix; echo ;;
                compose_window_name) compose_window_name "$@" ;;
                ensure_session) ensure_session ;;
                window_exists) window_exists "$@" ;;
                window_pane_pid) window_pane_pid "$@" ;;
                capture_pane) capture_pane "$@" ;;
                wait_for_ready) wait_for_ready "$@" "${CC_CODEX_TIMEOUT:-$DEFAULT_TIMEOUT}" ;;
                *) echo "codex-tmux: unknown _internal subcommand '$sub'" >&2; exit 2 ;;
            esac
            ;;
        *)
            echo "codex-tmux: unknown subcommand '$cmd'" >&2
            usage >&2
            exit 2
            ;;
    esac
}

main "$@"
