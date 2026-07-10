#!/usr/bin/env bats
# Tests for the codex-tmux.sh "bind" subcommand. See README.md for setup.
#
# Naming & identity contract exercised here:
#   claude6           = first 6 chars of $CLAUDE_CODE_SESSION_ID
#   bound window      = codex-<claude6>            (one per Claude session, reused)
#   tmux session name = $CC_CODEX_SESSION_NAME     (test-scoped, see setup())
#
# All tests pin CLAUDE_CODE_SESSION_ID to a fixed value so the bound window is
# deterministically "codex-0d61e6", and point CC_CODEX_BIN at the mock so no
# real codex/tokens are ever used.

SCRIPT="${BATS_TEST_DIRNAME}/../scripts/codex-tmux.sh"

# Fixed Claude session id => claude6 "0d61e6" => bound window "codex-0d61e6".
CLAUDE_ID="0d61e624-1494-4aec-9b46-31d2a9534099"
BOUND_WINDOW="codex-0d61e6"
MOCK_CODEX="${BATS_TEST_DIRNAME}/fixtures/mock-codex.sh"

setup() {
    SESSION_NAME_TEST="cc-codex-test-$$"
    export CC_CODEX_SESSION_NAME="$SESSION_NAME_TEST"
    # Deterministic keep-shell drop-in shell (avoids user zsh rc surprises).
    export CC_CODEX_EXIT_SHELL="/bin/bash"
}

teardown() {
    tmux kill-session -t "$SESSION_NAME_TEST" 2>/dev/null || true
}

# ---------- helpers ----------

# Count codex- prefixed windows in the test session (excludes _placeholder).
count_codex_windows() {
    tmux list-windows -t "$SESSION_NAME_TEST" -F '#{window_name}' 2>/dev/null \
        | grep -c '^codex-' || true
}

# ---------- bind: create-if-absent ----------

@test "bind: creates the bound window codex-<claude6> when absent" {
    CLAUDE_CODE_SESSION_ID="$CLAUDE_ID" \
        CC_CODEX_BIN="$MOCK_CODEX" \
        run "$SCRIPT" bind
    [ "$status" -eq 0 ]
    # Line 1 of stdout is the exact bound window name.
    [ "${lines[0]}" = "$BOUND_WINDOW" ]
    # The window really exists in the session.
    tmux list-windows -t "$SESSION_NAME_TEST" -F '#{window_name}' \
        | grep -Fxq "$BOUND_WINDOW"
}

@test "bind: passes default codex flags (model, effort)" {
    local cwd; cwd="$(mktemp -d)"
    CLAUDE_CODE_SESSION_ID="$CLAUDE_ID" \
        CC_CODEX_BIN="$BATS_TEST_DIRNAME/fixtures/mock-codex-logargs.sh" \
        run "$SCRIPT" bind --cwd "$cwd"
    [ "$status" -eq 0 ]
    sleep 0.3
    local argv; argv="$(cat "$cwd/mock-codex-argv.log")"
    [[ "$argv" == *"-m gpt-5.6-sol"* ]]
    [[ "$argv" == *"model_reasoning_effort=xhigh"* ]]
    rm -rf "$cwd"
}

@test "bind: window name matches ^codex-[a-z0-9]{6}$" {
    CLAUDE_CODE_SESSION_ID="$CLAUDE_ID" \
        CC_CODEX_BIN="$MOCK_CODEX" \
        run "$SCRIPT" bind
    [ "$status" -eq 0 ]
    [[ "${lines[0]}" =~ ^codex-[a-z0-9]{6}$ ]]
}

@test "bind: prints the attach hint on stdout line 2" {
    CLAUDE_CODE_SESSION_ID="$CLAUDE_ID" \
        CC_CODEX_BIN="$MOCK_CODEX" \
        run "$SCRIPT" bind
    [ "$status" -eq 0 ]
    [[ "${lines[1]}" == *"Attach with: tmux attach -t $SESSION_NAME_TEST"* ]]
}

@test "bind: spawns codex (window is alive shortly after bind)" {
    CLAUDE_CODE_SESSION_ID="$CLAUDE_ID" \
        CC_CODEX_BIN="$MOCK_CODEX" \
        "$SCRIPT" bind
    sleep 0.3
    CLAUDE_CODE_SESSION_ID="$CLAUDE_ID" run "$SCRIPT" ls
    [ "$status" -eq 0 ]
    [[ "$output" == *"$BOUND_WINDOW"* ]]
    [[ "$output" == *"alive"* ]]
}

# ---------- bind: idempotent reuse ----------

@test "bind: is idempotent — same name and no second window" {
    CLAUDE_CODE_SESSION_ID="$CLAUDE_ID" \
        CC_CODEX_BIN="$MOCK_CODEX" \
        run "$SCRIPT" bind
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "$BOUND_WINDOW" ]
    local count_after_first
    count_after_first="$(count_codex_windows)"
    [ "$count_after_first" -eq 1 ]

    sleep 0.3

    CLAUDE_CODE_SESSION_ID="$CLAUDE_ID" \
        CC_CODEX_BIN="$MOCK_CODEX" \
        run "$SCRIPT" bind
    [ "$status" -eq 0 ]
    # Same window name returned on the second bind.
    [ "${lines[0]}" = "$BOUND_WINDOW" ]
    # Window count is unchanged — no duplicate window was created.
    local count_after_second
    count_after_second="$(count_codex_windows)"
    [ "$count_after_second" -eq 1 ]
}

# ---------- bind: tmux user-option metadata ----------

@test "bind: records @cc_codex_cwd and default @cc_codex_sandbox=read-only" {
    CLAUDE_CODE_SESSION_ID="$CLAUDE_ID" \
        CC_CODEX_BIN="$MOCK_CODEX" \
        run "$SCRIPT" bind
    [ "$status" -eq 0 ]
    # cwd is recorded (non-empty by default — defaults to the invocation PWD).
    [ -n "$(tmux show-option -wqv -t "$SESSION_NAME_TEST:$BOUND_WINDOW" '@cc_codex_cwd')" ]
    # Default sandbox is read-only.
    [ "$(tmux show-option -wqv -t "$SESSION_NAME_TEST:$BOUND_WINDOW" '@cc_codex_sandbox')" = "read-only" ]
}

@test "bind --full-auto: sets @cc_codex_sandbox=workspace-write" {
    CLAUDE_CODE_SESSION_ID="$CLAUDE_ID" \
        CC_CODEX_BIN="$MOCK_CODEX" \
        run "$SCRIPT" bind --full-auto
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "$BOUND_WINDOW" ]
    [ "$(tmux show-option -wqv -t "$SESSION_NAME_TEST:$BOUND_WINDOW" '@cc_codex_sandbox')" = "workspace-write" ]
}

@test "bind --cwd DIR: sets @cc_codex_cwd to DIR" {
    CLAUDE_CODE_SESSION_ID="$CLAUDE_ID" \
        CC_CODEX_BIN="$MOCK_CODEX" \
        run "$SCRIPT" bind --cwd /tmp/test-bind-cwd
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "$BOUND_WINDOW" ]
    [ "$(tmux show-option -wqv -t "$SESSION_NAME_TEST:$BOUND_WINDOW" '@cc_codex_cwd')" = "/tmp/test-bind-cwd" ]
}

# ---------- bind: visibility to --mine matchers ----------

@test "bind: bound window appears in 'ls --mine'" {
    CLAUDE_CODE_SESSION_ID="$CLAUDE_ID" \
        CC_CODEX_BIN="$MOCK_CODEX" \
        "$SCRIPT" bind
    sleep 0.3
    CLAUDE_CODE_SESSION_ID="$CLAUDE_ID" run "$SCRIPT" ls --mine
    [ "$status" -eq 0 ]
    [[ "$output" == *"$BOUND_WINDOW"* ]]
}

@test "bind: bound window is removed by 'kill --mine' (removed >= 1)" {
    CLAUDE_CODE_SESSION_ID="$CLAUDE_ID" \
        CC_CODEX_BIN="$MOCK_CODEX" \
        "$SCRIPT" bind
    sleep 0.3
    # Sanity: the bound window exists before kill.
    tmux list-windows -t "$SESSION_NAME_TEST" -F '#{window_name}' \
        | grep -Fxq "$BOUND_WINDOW"

    CLAUDE_CODE_SESSION_ID="$CLAUDE_ID" run "$SCRIPT" kill --mine
    [ "$status" -eq 0 ]
    # Reports at least one removal.
    [[ "$output" =~ removed\ [1-9] ]]
    # Bound window is gone.
    ! tmux list-windows -t "$SESSION_NAME_TEST" -F '#{window_name}' \
        | grep -Fxq "$BOUND_WINDOW"
}

# ---------- bind: respawn a dead bound window ----------

@test "bind: respawns the bound window when its codex process is dead" {
    # First bind: create the bound window with a live mock codex.
    CLAUDE_CODE_SESSION_ID="$CLAUDE_ID" \
        CC_CODEX_BIN="$MOCK_CODEX" \
        "$SCRIPT" bind
    sleep 0.3

    # Kill the codex process inside the window so it goes "dead".
    # remain-on-exit (set by bind) keeps the now-dead window present.
    local pane_pid
    pane_pid="$(tmux list-panes -t "$SESSION_NAME_TEST:$BOUND_WINDOW" -F '#{pane_pid}' | head -n1)"
    kill -KILL "$pane_pid" 2>/dev/null || true
    sleep 0.5

    # Confirm it is now dead.
    CLAUDE_CODE_SESSION_ID="$CLAUDE_ID" run "$SCRIPT" ls
    [ "$status" -eq 0 ]
    [[ "$output" == *"$BOUND_WINDOW"* ]]
    [[ "$output" == *"dead"* ]]

    # Re-bind: should respawn into the SAME window (no duplicate).
    CLAUDE_CODE_SESSION_ID="$CLAUDE_ID" \
        CC_CODEX_BIN="$MOCK_CODEX" \
        run "$SCRIPT" bind
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "$BOUND_WINDOW" ]
    local count_after_rebind
    count_after_rebind="$(count_codex_windows)"
    [ "$count_after_rebind" -eq 1 ]

    sleep 0.3

    # The bound window is alive again.
    CLAUDE_CODE_SESSION_ID="$CLAUDE_ID" run "$SCRIPT" ls
    [ "$status" -eq 0 ]
    [[ "$output" == *"$BOUND_WINDOW"* ]]
    [[ "$output" == *"alive"* ]]
}

@test "bind: codex dying on launch returns exit 4 (no crash)" {
    CLAUDE_CODE_SESSION_ID="$CLAUDE_ID" \
        CC_CODEX_BIN="${BATS_TEST_DIRNAME}/fixtures/mock-codex-instant-exit.sh" \
        run "$SCRIPT" bind
    [ "$status" -eq 4 ]
    [[ "$output" == *"exited immediately"* ]]
}

# ---------- bind: keep-shell (codex exit keeps the window; re-bind relaunches) ----------

@test "bind: codex exit keeps the window at a shell; re-bind relaunches in the SAME window" {
    CLAUDE_CODE_SESSION_ID="$CLAUDE_ID" \
        CC_CODEX_BIN="$MOCK_CODEX" \
        "$SCRIPT" bind
    sleep 0.3

    # Cleanly exit the mock codex → the window must STAY, at a shell.
    tmux send-keys -t "$SESSION_NAME_TEST:$BOUND_WINDOW" "/exit" Enter
    sleep 1.0
    tmux list-windows -t "$SESSION_NAME_TEST" -F '#{window_name}' \
        | grep -Fxq "$BOUND_WINDOW"
    CLAUDE_CODE_SESSION_ID="$CLAUDE_ID" run "$SCRIPT" ls
    [ "$status" -eq 0 ]
    [[ "$output" == *"shell"* ]]

    # Re-bind: relaunches codex inside the SAME kept window (no duplicate).
    CLAUDE_CODE_SESSION_ID="$CLAUDE_ID" \
        CC_CODEX_BIN="$MOCK_CODEX" \
        run "$SCRIPT" bind
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "$BOUND_WINDOW" ]
    [ "$(count_codex_windows)" -eq 1 ]
    CLAUDE_CODE_SESSION_ID="$CLAUDE_ID" run "$SCRIPT" ls
    [ "$status" -eq 0 ]
    [[ "$output" == *"alive"* ]]
}
