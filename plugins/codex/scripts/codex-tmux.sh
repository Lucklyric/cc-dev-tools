#!/usr/bin/env bash
# codex-tmux.sh — drive interactive codex sessions inside a single tmux session.
# See plugins/codex/skills/codex/references/tmux-mode.md for usage docs.
set -euo pipefail

# ---------- Constants (overridable via env) ----------
readonly SESSION_NAME="${CC_CODEX_SESSION_NAME:-cc-codex}"
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

# Compute the state of a window: alive | dead | unknown.
# Determined entirely from tmux/process state (no pane buffer parsing).
window_state() {
    local window="$1"
    if ! window_exists "$window"; then
        echo "unknown"
        return
    fi
    if window_codex_alive "$window"; then
        echo "alive"
    else
        echo "dead"
    fi
}

cmd_find() {
    # Locate codex windows matching a topic (and optionally a cwd) within the
    # current Claude session's claude6 namespace. Prints one match per line in
    # the form "<window>\t<state>\t<cwd>". Exits 0 if any matches were printed,
    # 1 otherwise.
    local topic=""
    local cwd_filter=""
    local include_dead=0
    local any_session=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --cwd) cwd_filter="$2"; shift 2 ;;
            --include-dead) include_dead=1; shift ;;
            --any-session) any_session=1; shift ;;
            -*) echo "codex-tmux find: unknown flag '$1'" >&2; return 2 ;;
            *) topic="$1"; shift ;;
        esac
    done

    [[ -z "$topic" ]] && { echo "codex-tmux find: <topic> required" >&2; return 2; }
    validate_topic "$topic" || return 2

    ensure_session
    local my_token=""
    (( any_session )) || my_token="$(compute_claude6)"

    local found=0
    while IFS= read -r win; do
        [[ "$win" == "_placeholder" ]] && continue
        [[ "$win" != codex-* ]] && continue
        # Filter by current claude6 unless --any-session.
        if [[ -n "$my_token" && "$win" != *"-$my_token-"* ]]; then
            continue
        fi
        local win_topic win_cwd state
        win_topic="$(tmux show-option -wqv -t "$SESSION_NAME:$win" '@cc_codex_topic' 2>/dev/null)"
        [[ "$win_topic" != "$topic" ]] && continue
        if [[ -n "$cwd_filter" ]]; then
            win_cwd="$(tmux show-option -wqv -t "$SESSION_NAME:$win" '@cc_codex_cwd' 2>/dev/null)"
            [[ "$win_cwd" != "$cwd_filter" ]] && continue
        else
            win_cwd="$(tmux show-option -wqv -t "$SESSION_NAME:$win" '@cc_codex_cwd' 2>/dev/null)"
        fi
        state="$(window_state "$win")"
        if (( ! include_dead )) && [[ "$state" != "alive" ]]; then
            continue
        fi
        printf '%s\t%s\t%s\n' "$win" "$state" "${win_cwd:--}"
        found=$(( found + 1 ))
    done < <(tmux list-windows -t "$SESSION_NAME" -F '#{window_name}' 2>/dev/null)

    (( found > 0 ))
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

    if [[ "${1:-}" == "--mine" ]]; then
        ensure_session
        local my_token removed=0
        my_token="$(compute_claude6)"
        while IFS= read -r win; do
            [[ "$win" == "_placeholder" ]] && continue
            [[ "$win" != codex-* ]] && continue
            [[ "$win" != *"-$my_token-"* ]] && continue
            tmux kill-window -t "$SESSION_NAME:$win"
            removed=$(( removed + 1 ))
        done < <(tmux list-windows -t "$SESSION_NAME" -F '#{window_name}' 2>/dev/null)
        echo "removed $removed window(s) for claude6=$my_token"
        return 0
    fi

    local window="$1"
    [[ -z "$window" ]] && { echo "codex-tmux kill: window, --mine, or --orphaned required" >&2; return 2; }
    ensure_session
    window_exists "$window" || { echo "codex-tmux kill: window '$window' not found" >&2; return 6; }
    tmux kill-window -t "$SESSION_NAME:$window"
}

cmd_exec() {
    # Pass through all args to `codex exec`, but inject defaults if the caller
    # didn't specify them.
    local has_m=0 has_s=0 has_effort=0
    for a in "$@"; do
        case "$a" in
            -m|--model|-m=*|--model=*) has_m=1 ;;
            -s|--sandbox|-s=*|--sandbox=*) has_s=1 ;;
            model_reasoning_effort=*|*model_reasoning_effort=*) has_effort=1 ;;
        esac
    done

    local cmd=( "$CODEX_BIN" exec )
    (( has_m )) || cmd+=( -m gpt-5.5 )
    (( has_s )) || cmd+=( -s read-only )
    (( has_effort )) || cmd+=( -c model_reasoning_effort=xhigh )
    cmd+=( "$@" )

    exec "${cmd[@]}"
}

# ---------- Usage ----------
usage() {
    cat <<'EOF'
Usage: codex-tmux.sh <subcommand> [args...]

Subcommands:
  new <topic> [--cwd DIR] [--full-auto|--read-only]
      Create a new codex window in the cc-codex tmux session.
      Prints the full window name on stdout plus an attach hint.

  send | capture
      Removed in v3.1.0 — see references/tmux-mode.md for the skill recipes
      that replace them.

  ls [--mine]
      List codex windows. --mine filters to the current Claude session id.

  find <topic> [--cwd DIR] [--include-dead] [--any-session]
      Look up matching codex windows in the current Claude session's
      claude6 namespace. Prints "<window>\t<state>\t<cwd>" lines for
      matches; exits 0 if anything matched, 1 otherwise. Use BEFORE
      `new` to decide whether to reuse an existing window.

  attach <window>
      Print the shell command the user can run to attach to a window.

  rename <old-window> <new-topic>
      Rename a window's topic portion; preserves the suffix.

  kill <window> | kill --mine | kill --orphaned
      Kill a specific window, or all windows for the current Claude session
      (--mine, matched by claude6 prefix), or all windows whose codex
      process has exited (--orphaned).

  exec [codex-exec flags...] <prompt>
      Run codex exec one-shot outside tmux (escape hatch).

Environment:
  CC_CODEX_SESSION_NAME (default: cc-codex)
  CC_CODEX_BIN          (default: codex)
EOF
}

# ---------- Dispatch ----------
main() {
    if [[ $# -eq 0 ]]; then
        usage >&2
        exit 2
    fi

    # Note: named `subcmd` (not `cmd`) to avoid shellcheck SC2128 — `cmd_exec`
    # uses a local array variable `cmd`, and shellcheck does not track
    # function-local scopes precisely.
    local subcmd="$1"
    shift || true

    case "$subcmd" in
        -h|--help|help)
            usage
            ;;
        new) cmd_new "$@" ;;
        send|capture)
            cat <<EOF >&2
codex-tmux: '$subcmd' was removed in v3.1.0.

Interaction is now driven by the codex skill directly. See:
  plugins/codex/skills/codex/references/tmux-mode.md  (recipes)

Quick replacements:
  send    → tmux send-keys -t $SESSION_NAME:<window> -l -- "<prompt>"
            sleep 0.3
            tmux send-keys -t $SESSION_NAME:<window> Enter
            (then capture-pane and read the delta yourself)
  capture → tmux capture-pane -t $SESSION_NAME:<window> -p
EOF
            exit 64
            ;;
        ls) cmd_ls "$@" ;;
        find) cmd_find "$@" ;;
        attach) cmd_attach "$@" ;;
        rename) cmd_rename "$@" ;;
        kill) cmd_kill "$@" ;;
        exec) cmd_exec "$@" ;;
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
                *) echo "codex-tmux: unknown _internal subcommand '$sub'" >&2; exit 2 ;;
            esac
            ;;
        *)
            echo "codex-tmux: unknown subcommand '$subcmd'" >&2
            usage >&2
            exit 2
            ;;
    esac
}

main "$@"
