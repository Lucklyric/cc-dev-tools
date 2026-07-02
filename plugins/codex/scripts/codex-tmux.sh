#!/usr/bin/env bash
# codex-tmux.sh — drive interactive codex sessions inside a single tmux session.
# See plugins/codex/skills/codex/references/tmux-mode.md for usage docs.
set -euo pipefail

# ---------- Constants (overridable via env) ----------
readonly SESSION_NAME="${CC_CODEX_SESSION_NAME:-cc-codex}"
readonly CODEX_BIN="${CC_CODEX_BIN:-codex}"

# ---------- Pure helpers (no tmux, no codex) ----------

compute_claude6() {
    # The per-agent isolation token: the first 6 chars of $CLAUDE_CODE_SESSION_ID.
    # This is the ONLY isolation boundary — two agents whose session ids share a
    # 6-char prefix would resolve to the same codex (reuse/kill each other's).
    # Session ids are random UUIDs, so a real collision is ~1 in 16M; if you run
    # synthetic/fixed session ids (e.g. tests), keep their 6-char prefixes unique.
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
    # All post-spawn options are guarded: if codex exits instantly the window may
    # already be gone, and an unguarded failure would abort under `set -e`.
    tmux set-option -w -t "$SESSION_NAME:$window" remain-on-exit on 2>/dev/null || true

    # Record metadata as per-window user options.
    tmux set-option -w -t "$SESSION_NAME:$window" '@cc_codex_cwd' "$cwd" 2>/dev/null || true
    tmux set-option -w -t "$SESSION_NAME:$window" '@cc_codex_created' "$(date '+%Y-%m-%dT%H:%M:%S%z')" 2>/dev/null || true
    tmux set-option -w -t "$SESSION_NAME:$window" '@cc_codex_topic' "$topic" 2>/dev/null || true

    # Output: window name on stdout line 1, attach hint on line 2.
    echo "$window"
    echo "Attach with: tmux attach -t $SESSION_NAME \; select-window -t $window"
}

cmd_bind() {
    # Idempotently bind the current Claude session to a single reused codex
    # window named "codex-<claude6>" (topic-agnostic). Create codex in it if
    # absent, reuse it if alive, respawn it if dead. This is the default entry
    # point; `new` is reserved for explicit extra/parallel windows.
    local cwd="$PWD"
    local sandbox="read-only"
    local approval="on-request"
    local want_sandbox=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --cwd) cwd="$2"; shift 2 ;;
            --full-auto) sandbox="workspace-write"; want_sandbox="workspace-write"; shift ;;
            --read-only) sandbox="read-only"; want_sandbox="read-only"; shift ;;
            -*) echo "codex-tmux bind: unknown flag '$1'" >&2; return 2 ;;
            *) echo "codex-tmux bind: unexpected arg '$1'" >&2; return 2 ;;
        esac
    done

    ensure_session

    local window
    window="codex-$(compute_claude6)"
    if window_exists "$window"; then
        local state
        state="$(window_state "$window")"
        if [[ "$state" == "alive" ]]; then
            # Reuse the live window. Warn (don't fail) on a sandbox mismatch so
            # the skill can decide whether to kill + re-bind.
            local existing
            existing="$(tmux show-option -wqv -t "$SESSION_NAME:$window" '@cc_codex_sandbox' 2>/dev/null)"
            if [[ -n "$want_sandbox" && -n "$existing" && "$want_sandbox" != "$existing" ]]; then
                echo "codex-tmux bind: bound window '$window' is '$existing'; requested '$want_sandbox'. Kill and re-bind to switch (codex-tmux.sh kill $window && codex-tmux.sh bind --$want_sandbox)." >&2
            fi
            echo "$window"
            echo "Attach with: tmux attach -t $SESSION_NAME \; select-window -t $window"
            return 0
        else
            # Dead/orphaned: clear it out and respawn below.
            tmux kill-window -t "$SESSION_NAME:$window" 2>/dev/null || true
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

    # Spawn the bound window detached, then verify codex survived launch; retry
    # once on immediate exit (transient $CODEX_HOME / MCP init hiccups happen),
    # mirroring cmd_pane. Report exit 4 instead of returning a dead window the
    # caller would then drive blindly.
    local attempt=0
    while (( attempt < 2 )); do
        attempt=$(( attempt + 1 ))
        tmux new-window -t "$SESSION_NAME" -n "$window" -d -c "$cwd" \
            "${codex_cmd[@]}"

        # Keep the window alive after codex exits (per FR-014) so the user can
        # attach and read the exit message. Must be set ASAP after new-window.
        # All post-spawn options are guarded: if codex exits instantly the
        # window may already be gone, and an unguarded failure would abort
        # under `set -e`.
        tmux set-option -w -t "$SESSION_NAME:$window" remain-on-exit on 2>/dev/null || true
        tmux set-option -w -t "$SESSION_NAME:$window" '@cc_codex_cwd' "$cwd" 2>/dev/null || true
        tmux set-option -w -t "$SESSION_NAME:$window" '@cc_codex_created' "$(date '+%Y-%m-%dT%H:%M:%S%z')" 2>/dev/null || true
        tmux set-option -w -t "$SESSION_NAME:$window" '@cc_codex_sandbox' "$sandbox" 2>/dev/null || true

        sleep 0.4
        if [[ "$(window_state "$window")" == "alive" ]]; then
            # Output: window name on stdout line 1, attach hint on line 2.
            echo "$window"
            echo "Attach with: tmux attach -t $SESSION_NAME \; select-window -t $window"
            return 0
        fi
        echo "codex-tmux bind: codex exited immediately in $window (attempt $attempt):" >&2
        tmux capture-pane -t "$SESSION_NAME:$window" -p -S -20 2>/dev/null | sed 's/^/  | /' >&2 || true
        tmux kill-window -t "$SESSION_NAME:$window" 2>/dev/null || true
        sleep 0.5
    done
    echo "codex-tmux bind: codex exited immediately twice; aborting. Check 'codex login', then re-run." >&2
    return 4
}

# ---------- Pane mode (codex as a pane in the current Claude window) ----------

# Reference pane = the pane Claude Code itself runs in. Overridable for tests.
current_ref_pane() {
    printf '%s' "${CC_CODEX_REF_PANE:-${TMUX_PANE:-}}"
}

# Resolve the window target ("session:window_index") that contains a pane.
pane_window_target() {
    local pane="$1"
    tmux display-message -p -t "$pane" '#{session_name}:#{window_index}' 2>/dev/null
}

# True (0) if the pane exists AND its process is still running; false (1) if the
# pane is gone OR dead (process exited; kept around by remain-on-exit).
# NOTE: `display-message -t <stale-id>` silently falls back to the active pane
# (returning a bogus "alive"), so we must exact-match the pane id in the live
# pane list instead of trusting display-message.
pane_alive() {
    local pane="$1" state
    state="$(tmux list-panes -a -F '#{pane_id} #{pane_dead}' 2>/dev/null \
        | awk -v p="$pane" '$1==p { print ($2=="1" ? "dead" : "alive"); f=1 }
                            END   { if (!f) print "gone" }')"
    [[ "$state" == "alive" ]]
}

# Find THIS Claude session's codex pane for a topic anywhere on the server
# (matched by the @cc_codex_claude6 + @cc_codex_topic markers). Server-wide
# (`list-panes -a`) so reuse survives Claude moving the pane to another window.
# The claude6 marker is unique per Claude session and is NOT inherited by
# splits, so there is no false-match risk. Legacy panes without a topic option
# are treated as topic "main".
# NOTE on parsing: IFS=$'\t' treats tab as IFS whitespace, so consecutive tabs
# COLLAPSE and empty fields would shift. Every possibly-empty field is made
# non-empty at the source via tmux conditionals ('-' sentinel / 'main' default).
# Prints "<pane_id>\t<pane_dead>" for the first match and returns 0; else 1.
find_codex_pane() {
    local my_token="$1" want_topic="${2:-main}"
    local pid mark topic dead
    while IFS=$'\t' read -r pid mark topic dead; do
        [[ "$mark" == "$my_token" ]] || continue
        [[ "$topic" == "$want_topic" ]] || continue
        printf '%s\t%s\n' "$pid" "${dead:-0}"
        return 0
    done < <(tmux list-panes -a \
        -F '#{pane_id}'$'\t''#{?@cc_codex_claude6,#{@cc_codex_claude6},-}'$'\t''#{?@cc_codex_topic,#{@cc_codex_topic},main}'$'\t''#{pane_dead}' 2>/dev/null)
    return 1
}

# Split a codex pane, finalize its options (all guarded — the pane may already
# be gone if codex exited instantly), and echo the new pane id. Returns 1 if the
# split itself failed.
# Args: ref_pane orient size cwd sandbox my_token topic  [codex argv...]
_split_codex_pane() {
    local ref_pane="$1" orient="$2" size="$3" cwd="$4" sandbox="$5" my_token="$6" topic="$7"
    shift 7
    local title="codex-$my_token"
    [[ "$topic" != "main" ]] && title="codex-$topic-$my_token"
    local new_pane
    new_pane="$(tmux split-window -t "$ref_pane" "$orient" -l "${size}%" -d -c "$cwd" \
        -P -F '#{pane_id}' "$@" 2>/dev/null)" || return 1
    [[ -z "$new_pane" ]] && return 1
    tmux set-option -p -t "$new_pane" remain-on-exit on 2>/dev/null || true
    tmux set-option -p -t "$new_pane" '@cc_codex_claude6' "$my_token" 2>/dev/null || true
    tmux set-option -p -t "$new_pane" '@cc_codex_topic' "$topic" 2>/dev/null || true
    tmux set-option -p -t "$new_pane" '@cc_codex_cwd' "$cwd" 2>/dev/null || true
    tmux set-option -p -t "$new_pane" '@cc_codex_created' "$(date '+%Y-%m-%dT%H:%M:%S%z')" 2>/dev/null || true
    tmux set-option -p -t "$new_pane" '@cc_codex_sandbox' "$sandbox" 2>/dev/null || true
    tmux select-pane -t "$new_pane" -T "$title" 2>/dev/null || true
    printf '%s' "$new_pane"
}

cmd_pane() {
    # Spawn / locate / reuse a codex instance as a PANE in the CURRENT Claude
    # window (the window holding Claude Code's own pane). This is the default
    # when running inside tmux; it returns exit 3 (with a hint) when not inside
    # tmux so the skill can fall back to `bind` (dedicated-window mode).
    # --topic (default "main" = the primary pane) resolves/reuses/spawns an
    # EXTRA topic-named pane in the same window, with identical semantics
    # applied per-topic.
    local cwd="$PWD"
    local sandbox="read-only"
    local approval="on-request"
    local want_sandbox=""
    local orient="-h"          # horizontal split (codex to the right)
    local size="45"            # percent of the reference pane
    local topic="main"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --cwd) cwd="$2"; shift 2 ;;
            --topic) topic="$2"; shift 2 ;;
            --full-auto) sandbox="workspace-write"; want_sandbox="workspace-write"; shift ;;
            --read-only) sandbox="read-only"; want_sandbox="read-only"; shift ;;
            --vertical) orient="-v"; shift ;;
            --horizontal) orient="-h"; shift ;;
            --size) size="$2"; shift 2 ;;
            -*) echo "codex-tmux pane: unknown flag '$1'" >&2; return 2 ;;
            *) echo "codex-tmux pane: unexpected arg '$1'" >&2; return 2 ;;
        esac
    done

    if [[ ! "$size" =~ ^[0-9]+$ ]] || (( size < 10 || size > 90 )); then
        echo "codex-tmux pane: --size must be an integer 10-90 (got '$size')" >&2
        return 2
    fi
    validate_topic "$topic" || return 2

    ensure_tmux_or_die

    local ref_pane window my_token
    ref_pane="$(current_ref_pane)"
    if [[ -z "$ref_pane" ]]; then
        echo "codex-tmux pane: not inside tmux (TMUX_PANE unset). Use 'bind' for dedicated-window mode." >&2
        return 3
    fi
    window="$(pane_window_target "$ref_pane" 2>/dev/null || true)"
    if [[ -z "$window" ]]; then
        echo "codex-tmux pane: cannot resolve current window from pane '$ref_pane'. Use 'bind'." >&2
        return 3
    fi
    my_token="$(compute_claude6)"
    local title="codex-$my_token"
    [[ "$topic" != "main" ]] && title="codex-$topic-$my_token"
    local topic_flag=""
    [[ "$topic" != "main" ]] && topic_flag=" --topic $topic"

    # Locate this Claude's existing codex pane for this topic anywhere on the
    # server.
    local match pane dead
    if match="$(find_codex_pane "$my_token" "$topic")"; then
        pane="${match%%$'\t'*}"
        dead="${match##*$'\t'}"
        if [[ "$dead" != "1" ]]; then
            # Keep codex in the agent's CURRENT window. If the live pane is in a
            # different window, relocate it here (join-pane) so it always sits
            # beside Claude and is never duplicated. If the relocate fails, drop
            # the stray and spawn fresh below.
            local pane_win
            pane_win="$(tmux display-message -p -t "$pane" '#{session_name}:#{window_index}' 2>/dev/null || true)"
            if [[ -n "$pane_win" && "$pane_win" != "$window" ]]; then
                if tmux join-pane -h -s "$pane" -t "$ref_pane" 2>/dev/null; then
                    tmux select-pane -t "$pane" -T "$title" 2>/dev/null || true
                else
                    tmux kill-pane -t "$pane" 2>/dev/null || true
                    pane=""
                fi
            fi
            # Final liveness re-check closes a TOCTOU race: the pane found above
            # could die/vanish before we return it (then the caller would drive a
            # dead target). If so, fall through and spawn fresh.
            if [[ -n "$pane" ]] && pane_alive "$pane"; then
                # Reuse; warn (don't fail) on a sandbox mismatch.
                local existing
                existing="$(tmux show-option -p -qv -t "$pane" '@cc_codex_sandbox' 2>/dev/null || true)"
                if [[ -n "$want_sandbox" && -n "$existing" && "$want_sandbox" != "$existing" ]]; then
                    echo "codex-tmux pane: codex pane '$pane' is '$existing'; requested '$want_sandbox'. Kill and re-create to switch (codex-tmux.sh kill $pane && codex-tmux.sh pane --$want_sandbox$topic_flag)." >&2
                fi
                echo "$pane"
                if [[ "$topic" == "main" ]]; then
                    echo "Reusing codex pane $pane (in your current window)."
                else
                    echo "Reusing codex pane $pane for topic '$topic' (in your current window)."
                fi
                return 0
            fi
        else
            # Dead pane: remove it and respawn below.
            tmux kill-pane -t "$pane" 2>/dev/null || true
        fi
    fi

    # Build the codex command (network access when writing).
    local codex_cmd=(
        "$CODEX_BIN"
        -c "approval_policy=$approval"
        -c "model_reasoning_effort=xhigh"
        -s "$sandbox"
    )
    [[ "$sandbox" == "workspace-write" ]] && codex_cmd+=( -c "sandbox_workspace_write.network_access=true" )

    # Width floor: codex's TUI wants >= ~80 cols. If a horizontal split would
    # leave codex too narrow, fall back to a vertical (full-width) split.
    if [[ "$orient" == "-h" ]]; then
        local ref_w
        ref_w="$(tmux display-message -p -t "$ref_pane" '#{pane_width}' 2>/dev/null || echo 0)"
        if (( ref_w > 0 && ref_w * size / 100 < 80 )); then
            orient="-v"
            echo "codex-tmux pane: horizontal split would be <80 cols; using a vertical (full-width) split." >&2
        fi
    fi

    # Spawn, then verify codex survived launch; retry once on immediate exit
    # (transient $CODEX_HOME / MCP init hiccups happen). Without this, a
    # dead-on-arrival pane id would be returned and driven blindly.
    local new_pane attempt=0
    while (( attempt < 2 )); do
        attempt=$(( attempt + 1 ))
        new_pane="$(_split_codex_pane "$ref_pane" "$orient" "$size" "$cwd" "$sandbox" "$my_token" "$topic" "${codex_cmd[@]}")" \
            || { echo "codex-tmux pane: split-window failed (window too small? try --vertical or 'bind')" >&2; return 1; }
        sleep 0.4
        if pane_alive "$new_pane"; then
            echo "$new_pane"
            if [[ "$topic" == "main" ]]; then
                echo "Codex pane $new_pane in window $window (visible next to Claude)."
            else
                echo "Codex pane $new_pane for topic '$topic' in window $window (visible next to Claude)."
            fi
            return 0
        fi
        echo "codex-tmux pane: codex exited immediately in $new_pane (attempt $attempt):" >&2
        tmux capture-pane -t "$new_pane" -p -S -20 2>/dev/null | sed 's/^/  | /' >&2 || true
        tmux kill-pane -t "$new_pane" 2>/dev/null || true
        sleep 0.5
    done
    echo "codex-tmux pane: codex exited immediately twice; aborting. Re-run, or use 'bind'." >&2
    return 4
}

cmd_panes() {
    # Read-only detection: list codex PANES server-wide (matched by the
    # @cc_codex_claude6 marker), filtered to the current Claude session's
    # claude6 unless --all. Prints one TSV line per pane:
    #   <pane_id>\t<topic>\t<state>\t<session:window_index>\t<cwd>
    # (state = alive|dead). Exits 0 if anything was printed, 1 otherwise.
    # Never creates the cc-codex session (ensure_tmux_or_die only).
    local all=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --all) all=1; shift ;;
            *) echo "codex-tmux panes: unknown arg '$1'" >&2; return 2 ;;
        esac
    done

    ensure_tmux_or_die
    local my_token=""
    (( all )) || my_token="$(compute_claude6)"

    # Every possibly-empty field is made non-empty at the source via tmux
    # conditionals so tab-IFS parsing never collapses/shifts fields (see
    # find_codex_pane). Rows whose marker is the '-' sentinel are not codex
    # panes and are skipped.
    local found=0
    local pid mark topic dead win cwd state
    while IFS=$'\t' read -r pid mark topic dead win cwd; do
        [[ "$mark" == "-" ]] && continue
        [[ -n "$my_token" && "$mark" != "$my_token" ]] && continue
        state="alive"
        [[ "$dead" == "1" ]] && state="dead"
        printf '%s\t%s\t%s\t%s\t%s\n' "$pid" "$topic" "$state" "$win" "$cwd"
        found=$(( found + 1 ))
    done < <(tmux list-panes -a \
        -F '#{pane_id}'$'\t''#{?@cc_codex_claude6,#{@cc_codex_claude6},-}'$'\t''#{?@cc_codex_topic,#{@cc_codex_topic},main}'$'\t''#{pane_dead}'$'\t''#{session_name}:#{window_index}'$'\t''#{?@cc_codex_cwd,#{@cc_codex_cwd},-}' 2>/dev/null)

    (( found > 0 ))
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

    # Read-only: don't auto-create the cc-codex session (avoids leaving an empty
    # session behind). An absent session simply yields no matches.
    ensure_tmux_or_die
    local my_token=""
    (( any_session )) || my_token="$(compute_claude6)"

    local found=0
    while IFS= read -r win; do
        [[ "$win" == "_placeholder" ]] && continue
        [[ "$win" != codex-* ]] && continue
        # Filter by current claude6 unless --any-session. Accept both extra
        # windows (codex-<topic>-<claude6>-<rand2>) and the bound window
        # (codex-<claude6>).
        if [[ -n "$my_token" && "$win" != *"-$my_token-"* && "$win" != "codex-$my_token" ]]; then
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

    # Read-only: don't auto-create the cc-codex session; absent = no rows.
    ensure_tmux_or_die
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
        if (( mine_only )) && [[ "$win" != *"-$my_token-"* && "$win" != "codex-$my_token" ]]; then
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
    ensure_tmux_or_die
    window_exists "$window" || { echo "codex-tmux attach: window '$window' not found" >&2; return 6; }
    echo "tmux attach -t $SESSION_NAME \\; select-window -t $window"
}

cmd_rename() {
    local old="$1"
    local new_topic="$2"
    [[ -z "$old" || -z "$new_topic" ]] && {
        echo "codex-tmux rename: old-window and new-topic required" >&2; return 2; }
    validate_topic "$new_topic" || return 2
    ensure_tmux_or_die
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
        ensure_tmux_or_die
        local removed=0
        # Dead codex windows in the cc-codex session.
        while IFS= read -r win; do
            [[ "$win" == "_placeholder" ]] && continue
            [[ "$win" != codex-* ]] && continue
            if [[ "$(window_state "$win")" == "dead" ]]; then
                tmux kill-window -t "$SESSION_NAME:$win" 2>/dev/null || true
                removed=$(( removed + 1 ))
            fi
        done < <(tmux list-windows -t "$SESSION_NAME" -F '#{window_name}' 2>/dev/null)
        # Dead codex PANES anywhere on the server (any Claude session). The
        # marker field is made non-empty via a tmux conditional ('-' sentinel
        # = unmarked) so tab-IFS parsing never collapses/shifts fields.
        local pid mark dead
        while IFS=$'\t' read -r pid mark dead; do
            [[ "$mark" != "-" && "$dead" == "1" ]] || continue
            tmux kill-pane -t "$pid" 2>/dev/null || true
            removed=$(( removed + 1 ))
        done < <(tmux list-panes -a -F '#{pane_id}'$'\t''#{?@cc_codex_claude6,#{@cc_codex_claude6},-}'$'\t''#{pane_dead}' 2>/dev/null)
        echo "removed $removed orphan window(s)/pane(s)"
        return 0
    fi

    if [[ "${1:-}" == "--mine" ]]; then
        ensure_tmux_or_die
        local my_token removed=0
        my_token="$(compute_claude6)"
        # This Claude's codex windows.
        while IFS= read -r win; do
            [[ "$win" == "_placeholder" ]] && continue
            [[ "$win" != codex-* ]] && continue
            [[ "$win" != *"-$my_token-"* && "$win" != "codex-$my_token" ]] && continue
            tmux kill-window -t "$SESSION_NAME:$win" 2>/dev/null || true
            removed=$(( removed + 1 ))
        done < <(tmux list-windows -t "$SESSION_NAME" -F '#{window_name}' 2>/dev/null)
        # This Claude's codex PANES anywhere on the server (alive or dead,
        # ALL topics). The marker field is made non-empty via a tmux
        # conditional ('-' sentinel = unmarked) so tab-IFS parsing never
        # collapses/shifts fields.
        local pid mark
        while IFS=$'\t' read -r pid mark; do
            [[ "$mark" == "$my_token" ]] || continue
            tmux kill-pane -t "$pid" 2>/dev/null || true
            removed=$(( removed + 1 ))
        done < <(tmux list-panes -a -F '#{pane_id}'$'\t''#{?@cc_codex_claude6,#{@cc_codex_claude6},-}' 2>/dev/null)
        echo "removed $removed window(s)/pane(s) for claude6=$my_token"
        return 0
    fi

    local window="$1"
    [[ -z "$window" ]] && { echo "codex-tmux kill: window, pane-id, --mine, or --orphaned required" >&2; return 2; }
    # Pane-id target (e.g. %53): kill the codex pane directly (pane mode).
    if [[ "$window" == %* ]]; then
        ensure_tmux_or_die
        tmux kill-pane -t "$window" 2>/dev/null \
            || { echo "codex-tmux kill: pane '$window' not found" >&2; return 6; }
        return 0
    fi
    ensure_tmux_or_die
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
  pane [--topic SLUG] [--cwd DIR] [--full-auto|--read-only] [--horizontal|--vertical] [--size PCT]
      DEFAULT when Claude runs inside tmux. Spawn / locate / reuse a single
      codex instance as a PANE split into the CURRENT Claude window (right
      next to Claude, so progress is visible with no separate attach).
      Idempotent per Claude session (reuse is server-wide, surviving window
      moves): reuses the live codex pane if present, respawns it if dead, else
      splits a new one. Prints the pane id (e.g. %53) on stdout line 1.
      --topic SLUG (2-15 chars, [a-z0-9-]; default: main) addresses an EXTRA
      topic-named pane in the same window; each topic gets its own pane with
      the same per-topic reuse/relocate/respawn semantics.
      Exits 3 (use `bind`) when not inside tmux; exits 4 if codex dies on
      launch (after one retry; codex output on stderr). Default split:
      horizontal, 45% (--size 10-90); auto-switches to vertical if a
      horizontal split would leave codex <80 cols.

  panes [--all]
      Read-only detection: list codex PANES server-wide, one TSV line per
      pane: "<pane_id>\t<topic>\t<state>\t<session:window_index>\t<cwd>"
      (state = alive|dead). Filtered to the current Claude session's claude6
      by default; --all lists every agent's codex panes. Exits 0 if at least
      one line was printed, 1 otherwise. Never creates the cc-codex session.

  bind [--cwd DIR] [--full-auto|--read-only]
      Dedicated-window mode / fallback when NOT inside tmux. Bind this Claude
      session to its single reused codex window (codex-<claude6>) in the
      cc-codex session and print it. Idempotent: creates codex if absent,
      reuses if alive, respawns if dead. Prints the window name on stdout
      line 1 plus an attach hint on line 2.

  new <topic> [--cwd DIR] [--full-auto|--read-only]
      Create a new codex window in the cc-codex tmux session. Use ONLY when a
      SEPARATE WINDOW is explicitly requested; the default is `pane` (extra
      panes via `pane --topic`), with `bind` as the outside-tmux fallback.
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

  kill <window> | kill <%pane-id> | kill --mine | kill --orphaned
      Kill a specific window, a codex PANE by its pane id (e.g. %53, pane
      mode), all of the current Claude session's codex windows AND panes
      (--mine, matched by claude6), or every dead codex window/pane on the
      server (--orphaned). --mine and --orphaned are pane-aware.

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
        pane) cmd_pane "$@" ;;
        panes) cmd_panes "$@" ;;
        bind) cmd_bind "$@" ;;
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
