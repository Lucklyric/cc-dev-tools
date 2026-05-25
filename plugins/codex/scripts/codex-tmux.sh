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

# ---------- Subcommands ----------

cmd_new() {
    local topic=""
    local cwd="$PWD"
    local sandbox="read-only"
    local approval="on-request"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --cwd) cwd="$2"; shift 2 ;;
            --full-auto) sandbox="workspace-write"; shift ;;
            --read-only) sandbox="read-only"; shift ;;
            -*) echo "codex-tmux new: unknown flag '$1'" >&2; return 2 ;;
            *) topic="$1"; shift ;;
        esac
    done

    if [[ -z "$topic" ]]; then
        echo "codex-tmux new: topic required (e.g., 'codex-tmux.sh new auth')" >&2
        return 2
    fi
    validate_topic "$topic" || return 2

    ensure_session

    # Compose unique window name (retry once on extremely unlikely collision).
    local window
    window="$(compose_window_name "$topic")"
    if window_exists "$window"; then
        window="$(compose_window_name "$topic")"
        if window_exists "$window"; then
            echo "codex-tmux new: name collision for topic '$topic' (retry failed)" >&2
            return 17
        fi
    fi

    # Build the codex command with network access if writing.
    local codex_cmd=(
        "$CODEX_BIN"
        -c "approval_policy=$approval"
        -c "model_reasoning_effort=xhigh"
        -s "$sandbox"
    )
    if [[ "$sandbox" == "workspace-write" ]]; then
        codex_cmd+=( -c "sandbox_workspace_write.network_access=true" )
    fi

    # Spawn the window detached.
    tmux new-window -t "$SESSION_NAME" -n "$window" -d -c "$cwd" \
        "${codex_cmd[@]}"

    # CRITICAL: keep the window alive after codex exits (per FR-014) so the user
    # can attach and read the exit message. Must be set ASAP after new-window.
    tmux set-option -w -t "$SESSION_NAME:$window" remain-on-exit on

    # Record metadata as per-window user options.
    tmux set-option -w -t "$SESSION_NAME:$window" '@cc_codex_cwd' "$cwd"
    tmux set-option -w -t "$SESSION_NAME:$window" '@cc_codex_created' "$(date '+%Y-%m-%dT%H:%M:%S%z')"
    tmux set-option -w -t "$SESSION_NAME:$window" '@cc_codex_topic' "$topic"

    # Wait for codex to be ready.
    if ! wait_for_ready "$window" "$DEFAULT_TIMEOUT"; then
        echo "codex-tmux new: codex did not become ready in time (window left in place for diagnosis)" >&2
        return 124
    fi

    # Output: window name on stdout line 1, attach hint on line 2.
    echo "$window"
    echo "Attach with: tmux attach -t $SESSION_NAME \; select-window -t $window"
}

# Detect whether the codex process inside a window is still alive.
window_codex_alive() {
    local window="$1"
    local pane_pid
    pane_pid="$(window_pane_pid "$window")"
    [[ -z "$pane_pid" ]] && return 1
    # Check if the pane process itself is still running.
    # Also accept if it has live children (nested shell case).
    kill -0 "$pane_pid" 2>/dev/null || pgrep -P "$pane_pid" >/dev/null
}

cmd_send() {
    local window=""
    local prompt=""
    local timeout="$DEFAULT_TIMEOUT"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --timeout) timeout="$2"; shift 2 ;;
            -*) echo "codex-tmux send: unknown flag '$1'" >&2; return 2 ;;
            *)
                if [[ -z "$window" ]]; then window="$1"
                elif [[ -z "$prompt" ]]; then prompt="$1"
                else echo "codex-tmux send: too many positional args" >&2; return 2
                fi
                shift ;;
        esac
    done

    [[ -z "$window" || -z "$prompt" ]] && { echo "codex-tmux send: window and prompt required" >&2; return 2; }
    ensure_session

    if ! window_exists "$window"; then
        echo "codex-tmux send: window '$window' not found (ENXIO)" >&2
        return 6
    fi
    if ! window_codex_alive "$window"; then
        echo "codex-tmux send: codex process in '$window' has exited — marker: CODEX_DEAD" >&2
        return 1
    fi

    mkdir -p "$LOCK_DIR"
    local lockfile="$LOCK_DIR/$window.lock"

    # Acquire lock FIRST so the baseline reflects the pane AFTER any in-flight
    # send finishes (otherwise the next send's delta would include both runs).
    # Wrap in a subshell so fd 9 is scoped here; bash 3.2 lacks {var}>file.
    (
        flock -w "$timeout" 9 || {
            echo "codex-tmux send: lock contention on '$window' (EAGAIN)" >&2
            exit 11
        }

        # Now safe to snapshot the baseline.
        local baseline
        baseline="$(capture_pane "$window")"

        # Send the prompt literally, then Enter.
        tmux send-keys -t "$SESSION_NAME:$window" -l -- "$prompt"
        tmux send-keys -t "$SESSION_NAME:$window" Enter

        # Wait for ready.
        if ! wait_for_ready "$window" "$timeout"; then
            exit 124
        fi

        # Compute delta: capture again, diff against baseline.
        local after
        after="$(capture_pane "$window")"

        # Print only new lines (those past the baseline length).
        local base_count after_count
        base_count="$(printf '%s\n' "$baseline" | wc -l)"
        after_count="$(printf '%s\n' "$after" | wc -l)"
        if (( after_count > base_count )); then
            printf '%s\n' "$after" | tail -n "$(( after_count - base_count ))"
        fi
    ) 9>"$lockfile"
}

cmd_capture() {
    local window=""
    local lines=200
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --lines) lines="$2"; shift 2 ;;
            *) window="$1"; shift ;;
        esac
    done
    [[ -z "$window" ]] && { echo "codex-tmux capture: window required" >&2; return 2; }
    ensure_session
    window_exists "$window" || { echo "codex-tmux capture: window '$window' not found" >&2; return 6; }
    capture_pane "$window" "$lines"
}

# Compute the state of a window: idle | busy | dead | unknown
window_state() {
    local window="$1"
    if ! window_exists "$window"; then
        echo "unknown"
        return
    fi
    if ! window_codex_alive "$window"; then
        echo "dead"
        return
    fi
    # Check ready regex against bottom of pane.
    local buf
    buf="$(capture_pane "$window" 50)"
    if echo "$buf" | tail -n5 | grep -qE "$READY_REGEX"; then
        echo "idle"
    else
        echo "busy"
    fi
}

cmd_ls() {
    local mine_only=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --mine) mine_only=1; shift ;;
            *) echo "codex-tmux ls: unknown arg '$1'" >&2; return 2 ;;
        esac
    done

    ensure_session
    local my_token=""
    if (( mine_only )); then
        my_token="$(compute_claude6)"
    fi

    printf '%-32s %-12s %-7s %-30s %s\n' "WINDOW" "TOPIC" "STATE" "CWD" "CREATED"
    while IFS= read -r win; do
        # Skip the internal placeholder window.
        [[ "$win" == "_placeholder" ]] && continue
        # Only codex- prefixed windows.
        [[ "$win" != codex-* ]] && continue
        if (( mine_only )) && [[ "$win" != *"-$my_token-"* ]]; then
            continue
        fi
        local topic cwd created state
        topic="$(tmux show-option -wqv -t "$SESSION_NAME:$win" '@cc_codex_topic' 2>/dev/null)"
        cwd="$(tmux show-option -wqv -t "$SESSION_NAME:$win" '@cc_codex_cwd' 2>/dev/null)"
        created="$(tmux show-option -wqv -t "$SESSION_NAME:$win" '@cc_codex_created' 2>/dev/null)"
        state="$(window_state "$win")"
        printf '%-32s %-12s %-7s %-30s %s\n' "$win" "${topic:--}" "$state" "${cwd:--}" "${created:--}"
    done < <(tmux list-windows -t "$SESSION_NAME" -F '#{window_name}' 2>/dev/null)
}

cmd_attach() {
    local window="$1"
    [[ -z "$window" ]] && { echo "codex-tmux attach: window required" >&2; return 2; }
    ensure_session
    window_exists "$window" || { echo "codex-tmux attach: window '$window' not found" >&2; return 6; }
    echo "tmux attach -t $SESSION_NAME \\; select-window -t $window"
}

cmd_rename() {
    local old="$1"
    local new_topic="$2"
    [[ -z "$old" || -z "$new_topic" ]] && {
        echo "codex-tmux rename: old-window and new-topic required" >&2; return 2; }
    validate_topic "$new_topic" || return 2
    ensure_session
    window_exists "$old" || { echo "codex-tmux rename: window '$old' not found" >&2; return 6; }

    # Pattern: codex-<topic>-<claude6>-<rand2>
    # Preserve the trailing '-<claude6>-<rand2>'.
    if [[ ! "$old" =~ ^codex-[a-z0-9-]+-([a-z0-9]{6})-([a-z0-9]{2})$ ]]; then
        echo "codex-tmux rename: window '$old' does not follow naming convention" >&2
        return 2
    fi
    local claude6="${BASH_REMATCH[1]}"
    local rand2="${BASH_REMATCH[2]}"
    local new_name="codex-${new_topic}-${claude6}-${rand2}"

    tmux rename-window -t "$SESSION_NAME:$old" "$new_name"
    tmux set-option -w -t "$SESSION_NAME:$new_name" '@cc_codex_topic' "$new_topic"
    echo "$new_name"
}

cmd_kill() {
    if [[ "${1:-}" == "--orphaned" ]]; then
        ensure_session
        local removed=0
        while IFS= read -r win; do
            [[ "$win" == "_placeholder" ]] && continue
            [[ "$win" != codex-* ]] && continue
            if [[ "$(window_state "$win")" == "dead" ]]; then
                tmux kill-window -t "$SESSION_NAME:$win"
                removed=$(( removed + 1 ))
            fi
        done < <(tmux list-windows -t "$SESSION_NAME" -F '#{window_name}' 2>/dev/null)
        echo "removed $removed orphan window(s)"
        return 0
    fi

    local window="$1"
    [[ -z "$window" ]] && { echo "codex-tmux kill: window or --orphaned required" >&2; return 2; }
    ensure_session
    window_exists "$window" || { echo "codex-tmux kill: window '$window' not found" >&2; return 6; }
    tmux kill-window -t "$SESSION_NAME:$window"
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
        new) cmd_new "$@" ;;
        send) cmd_send "$@" ;;
        capture) cmd_capture "$@" ;;
        ls) cmd_ls "$@" ;;
        attach) cmd_attach "$@" ;;
        rename) cmd_rename "$@" ;;
        kill) cmd_kill "$@" ;;
        exec)
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
