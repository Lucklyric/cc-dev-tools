#!/usr/bin/env bats
# Tests for codex-tmux.sh. See README.md for setup.

# Tests added per-task below.

SCRIPT="${BATS_TEST_DIRNAME}/../scripts/codex-tmux.sh"

@test "script: --help prints usage and exits 0" {
    run "$SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
    [[ "$output" == *"new"* ]]
    [[ "$output" == *"send"* ]]
    [[ "$output" == *"exec"* ]]
}

@test "script: unknown subcommand exits 2" {
    run "$SCRIPT" not-a-real-command
    [ "$status" -eq 2 ]
    [[ "$output" == *"unknown"* ]] || [[ "$output" == *"Unknown"* ]]
}

@test "claude6: uses CLAUDE_CODE_SESSION_ID prefix when set" {
    CLAUDE_CODE_SESSION_ID="0d61e624-1494-4aec-9b46-31d2a9534099" \
        run "$SCRIPT" _internal claude6
    [ "$status" -eq 0 ]
    [ "$output" = "0d61e6" ]
}

@test "claude6: falls back to PPID+PWD hash when env unset" {
    unset CLAUDE_CODE_SESSION_ID
    run "$SCRIPT" _internal claude6
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[a-f0-9]{6}$ ]]
}

@test "validate_topic: accepts a short slug" {
    run "$SCRIPT" _internal validate_topic "auth"
    [ "$status" -eq 0 ]
}

@test "validate_topic: rejects too short" {
    run "$SCRIPT" _internal validate_topic "a"
    [ "$status" -ne 0 ]
}

@test "validate_topic: rejects too long" {
    run "$SCRIPT" _internal validate_topic "thisisaverylongtopicslug"
    [ "$status" -ne 0 ]
}

@test "validate_topic: rejects uppercase and punctuation" {
    run "$SCRIPT" _internal validate_topic "AuthThing"
    [ "$status" -ne 0 ]
    run "$SCRIPT" _internal validate_topic "auth.foo"
    [ "$status" -ne 0 ]
}

@test "compose_window_name: assembles topic + claude6 + 2 random chars" {
    CLAUDE_CODE_SESSION_ID="0d61e624-1494-4aec-9b46-31d2a9534099" \
        run "$SCRIPT" _internal compose_window_name "auth"
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^codex-auth-0d61e6-[a-z0-9]{2}$ ]]
}

# Tear down any test sessions between tests.
teardown() {
    tmux kill-session -t "$SESSION_NAME_TEST" 2>/dev/null || true
}

setup() {
    SESSION_NAME_TEST="cc-codex-test-$$"
    export CC_CODEX_SESSION_NAME="$SESSION_NAME_TEST"
}

@test "ensure_session: lazy-creates the named tmux session" {
    run "$SCRIPT" _internal ensure_session
    [ "$status" -eq 0 ]
    tmux has-session -t "$SESSION_NAME_TEST"
}

@test "ensure_session: is idempotent (does not error if already exists)" {
    "$SCRIPT" _internal ensure_session
    run "$SCRIPT" _internal ensure_session
    [ "$status" -eq 0 ]
}

@test "window_exists: returns true for live window, false otherwise" {
    "$SCRIPT" _internal ensure_session
    tmux new-window -t "$SESSION_NAME_TEST" -n "codex-test-aaaaaa-xy" -d
    run "$SCRIPT" _internal window_exists "codex-test-aaaaaa-xy"
    [ "$status" -eq 0 ]
    run "$SCRIPT" _internal window_exists "codex-nope-aaaaaa-zz"
    [ "$status" -ne 0 ]
}

@test "capture_pane: prints the full pane buffer" {
    "$SCRIPT" _internal ensure_session
    tmux new-window -t "$SESSION_NAME_TEST" -n "ready-test-aaaaaa-aa" -d \
        "bash -c 'echo hello; echo ▌; sleep 60'"
    sleep 0.5
    run "$SCRIPT" _internal capture_pane "ready-test-aaaaaa-aa"
    [ "$status" -eq 0 ]
    [[ "$output" == *"hello"* ]]
    [[ "$output" == *"▌"* ]]
}

@test "wait_for_ready: returns 0 when ready marker appears" {
    "$SCRIPT" _internal ensure_session
    # Start a window that prints stuff and then the ready marker
    tmux new-window -t "$SESSION_NAME_TEST" -n "ready-wait-aaaaaa-bb" -d \
        "bash -c '(sleep 0.5; echo working; sleep 0.5; echo ▌; sleep 60)'"
    CC_CODEX_TIMEOUT=10 run "$SCRIPT" _internal wait_for_ready "ready-wait-aaaaaa-bb"
    [ "$status" -eq 0 ]
}

@test "wait_for_ready: exits 124 on timeout with last lines + marker" {
    "$SCRIPT" _internal ensure_session
    tmux new-window -t "$SESSION_NAME_TEST" -n "ready-stuck-aaaaaa-cc" -d \
        "bash -c 'echo still-thinking; sleep 60'"
    CC_CODEX_TIMEOUT=2 run "$SCRIPT" _internal wait_for_ready "ready-stuck-aaaaaa-cc"
    [ "$status" -eq 124 ]
    [[ "$output" == *"still-thinking"* ]] || [[ "$stderr" == *"still-thinking"* ]]
    [[ "$output" == *"READY_REGEX_MISMATCH"* ]] || [[ "$stderr" == *"READY_REGEX_MISMATCH"* ]]
}

@test "new: spawns a window with the expected name pattern" {
    CLAUDE_CODE_SESSION_ID="0d61e624-..." \
        CC_CODEX_BIN="$BATS_TEST_DIRNAME/fixtures/mock-codex.sh" \
        CC_CODEX_TIMEOUT=10 \
        run "$SCRIPT" new auth
    [ "$status" -eq 0 ]
    [[ "$output" =~ codex-auth-0d61e6-[a-z0-9]{2} ]]
    local win
    win="$(echo "$output" | grep -oE 'codex-auth-0d61e6-[a-z0-9]{2}' | head -n1)"
    tmux list-windows -t "$SESSION_NAME_TEST" -F '#{window_name}' | grep -Fxq "$win"
}

@test "new: prints the attach hint on stdout" {
    CLAUDE_CODE_SESSION_ID="0d61e624-..." \
        CC_CODEX_BIN="$BATS_TEST_DIRNAME/fixtures/mock-codex.sh" \
        CC_CODEX_TIMEOUT=10 \
        run "$SCRIPT" new auth
    [ "$status" -eq 0 ]
    [[ "$output" == *"tmux attach -t $SESSION_NAME_TEST"* ]]
    [[ "$output" == *"select-window -t codex-auth-"* ]]
}

@test "new: records cwd and created tmux user options" {
    CLAUDE_CODE_SESSION_ID="0d61e624-..." \
        CC_CODEX_BIN="$BATS_TEST_DIRNAME/fixtures/mock-codex.sh" \
        CC_CODEX_TIMEOUT=10 \
        run "$SCRIPT" new auth --cwd /tmp/test-cwd
    [ "$status" -eq 0 ]
    local win
    win="$(echo "$output" | grep -oE 'codex-auth-0d61e6-[a-z0-9]{2}' | head -n1)"
    [ "$(tmux show-option -wqv -t "$SESSION_NAME_TEST:$win" '@cc_codex_cwd')" = "/tmp/test-cwd" ]
    [ -n "$(tmux show-option -wqv -t "$SESSION_NAME_TEST:$win" '@cc_codex_created')" ]
}

@test "new: invalid topic exits non-zero" {
    CC_CODEX_BIN="$BATS_TEST_DIRNAME/fixtures/mock-codex.sh" \
        run "$SCRIPT" new InvalidTopic
    [ "$status" -ne 0 ]
}

@test "send: returns the delta of new pane output" {
    export CC_CODEX_BIN="$BATS_TEST_DIRNAME/fixtures/mock-codex.sh"
    export CC_CODEX_TIMEOUT=10
    export CLAUDE_CODE_SESSION_ID="0d61e624-..."
    win="$("$SCRIPT" new auth | head -n1)"

    run "$SCRIPT" send "$win" "hello there"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[mock-response] you said: hello there"* ]]
    # The startup banner from mock-codex should NOT appear in the send delta.
    [[ "$output" != *"mock-codex v0.0.0 ready"* ]]
}

@test "send: missing window exits 6 (ENXIO)" {
    "$SCRIPT" _internal ensure_session
    run "$SCRIPT" send "codex-nope-aaaaaa-zz" "hi"
    [ "$status" -eq 6 ]
}

@test "send: codex process dead → exit non-zero with CODEX_DEAD marker" {
    "$SCRIPT" _internal ensure_session
    # Spawn a window whose 'codex' sleeps briefly then exits. We need a tiny
    # delay so we can set remain-on-exit *before* it dies — otherwise tmux
    # closes the window the instant the command returns.
    tmux new-window -t "$SESSION_NAME_TEST" -n "codex-dead-aaaaaa-dd" -d \
        "bash -c 'sleep 0.3; exit 0'"
    tmux set-option -w -t "$SESSION_NAME_TEST:codex-dead-aaaaaa-dd" remain-on-exit on
    sleep 1  # let it exit
    run "$SCRIPT" send "codex-dead-aaaaaa-dd" "hi"
    [ "$status" -ne 0 ]
    [[ "$output" == *"CODEX_DEAD"* ]] || [[ "$stderr" == *"CODEX_DEAD"* ]]
}

@test "capture: prints the pane buffer without sending anything" {
    "$SCRIPT" _internal ensure_session
    tmux new-window -t "$SESSION_NAME_TEST" -n "cap-test-aaaaaa-ee" -d \
        "bash -c 'echo line1; echo line2; sleep 60'"
    sleep 0.3
    run "$SCRIPT" capture "cap-test-aaaaaa-ee"
    [ "$status" -eq 0 ]
    [[ "$output" == *"line1"* ]]
    [[ "$output" == *"line2"* ]]
}

@test "ls: prints header row and one row per window" {
    "$SCRIPT" _internal ensure_session
    tmux new-window -t "$SESSION_NAME_TEST" -n "codex-foo-aaaaaa-aa" -d \
        "bash -c 'echo ▌; sleep 60'"
    tmux set-option -w -t "$SESSION_NAME_TEST:codex-foo-aaaaaa-aa" '@cc_codex_cwd' "/tmp/foo"
    tmux set-option -w -t "$SESSION_NAME_TEST:codex-foo-aaaaaa-aa" '@cc_codex_created' "2026-05-24T10:00:00+0000"
    tmux set-option -w -t "$SESSION_NAME_TEST:codex-foo-aaaaaa-aa" '@cc_codex_topic' "foo"
    sleep 0.4
    run "$SCRIPT" ls
    [ "$status" -eq 0 ]
    [[ "$output" == *"WINDOW"* ]]
    [[ "$output" == *"TOPIC"* ]]
    [[ "$output" == *"STATE"* ]]
    [[ "$output" == *"codex-foo-aaaaaa-aa"* ]]
    [[ "$output" == *"foo"* ]]
    [[ "$output" == *"/tmp/foo"* ]]
}

@test "ls --mine: filters by current CLAUDE_CODE_SESSION_ID claude6 prefix" {
    "$SCRIPT" _internal ensure_session
    tmux new-window -t "$SESSION_NAME_TEST" -n "codex-foo-aaaaaa-aa" -d \
        "bash -c 'echo ▌; sleep 60'"
    tmux new-window -t "$SESSION_NAME_TEST" -n "codex-bar-bbbbbb-bb" -d \
        "bash -c 'echo ▌; sleep 60'"
    CLAUDE_CODE_SESSION_ID="aaaaaa-1234-5678-9abc-deadbeefcafe" \
        run "$SCRIPT" ls --mine
    [ "$status" -eq 0 ]
    [[ "$output" == *"codex-foo-aaaaaa-aa"* ]]
    [[ "$output" != *"codex-bar-bbbbbb-bb"* ]]
}

@test "ls: STATE is 'dead' for windows whose codex exited" {
    "$SCRIPT" _internal ensure_session
    tmux new-window -t "$SESSION_NAME_TEST" -n "codex-dead-aaaaaa-aa" -d \
        "bash -c 'sleep 0.3; exit 0'"
    tmux set-option -w -t "$SESSION_NAME_TEST:codex-dead-aaaaaa-aa" remain-on-exit on
    sleep 1
    run "$SCRIPT" ls
    [ "$status" -eq 0 ]
    [[ "$output" == *"codex-dead-aaaaaa-aa"* ]]
    [[ "$output" == *"dead"* ]]
}

@test "attach: prints the tmux attach command without execing it" {
    "$SCRIPT" _internal ensure_session
    tmux new-window -t "$SESSION_NAME_TEST" -n "codex-att-aaaaaa-aa" -d "sleep 60"
    run "$SCRIPT" attach "codex-att-aaaaaa-aa"
    [ "$status" -eq 0 ]
    [[ "$output" == *"tmux attach -t $SESSION_NAME_TEST"* ]]
    [[ "$output" == *"select-window -t codex-att-aaaaaa-aa"* ]]
}

@test "attach: missing window exits 6" {
    "$SCRIPT" _internal ensure_session
    run "$SCRIPT" attach "codex-nope-aaaaaa-zz"
    [ "$status" -eq 6 ]
}

@test "rename: replaces only the topic portion, keeps suffix" {
    "$SCRIPT" _internal ensure_session
    tmux new-window -t "$SESSION_NAME_TEST" -n "codex-old-aaaaaa-aa" -d "sleep 60"
    run "$SCRIPT" rename "codex-old-aaaaaa-aa" "newtopic"
    [ "$status" -eq 0 ]
    [[ "$output" == "codex-newtopic-aaaaaa-aa" ]]
    tmux list-windows -t "$SESSION_NAME_TEST" -F '#{window_name}' \
        | grep -Fxq "codex-newtopic-aaaaaa-aa"
}

@test "rename: invalid new topic exits non-zero" {
    "$SCRIPT" _internal ensure_session
    tmux new-window -t "$SESSION_NAME_TEST" -n "codex-old-aaaaaa-aa" -d "sleep 60"
    run "$SCRIPT" rename "codex-old-aaaaaa-aa" "BadTopic"
    [ "$status" -ne 0 ]
}

@test "kill: removes a single named window" {
    "$SCRIPT" _internal ensure_session
    tmux new-window -t "$SESSION_NAME_TEST" -n "codex-kill-aaaaaa-aa" -d "sleep 60"
    run "$SCRIPT" kill "codex-kill-aaaaaa-aa"
    [ "$status" -eq 0 ]
    ! tmux list-windows -t "$SESSION_NAME_TEST" -F '#{window_name}' \
        | grep -Fxq "codex-kill-aaaaaa-aa"
}

@test "kill --orphaned: removes only dead codex windows" {
    "$SCRIPT" _internal ensure_session
    tmux new-window -t "$SESSION_NAME_TEST" -n "codex-alive-aaaaaa-aa" -d "sleep 60"
    tmux new-window -t "$SESSION_NAME_TEST" -n "codex-dead-aaaaaa-bb" -d \
        "bash -c 'sleep 0.3; exit 0'"
    tmux set-option -w -t "$SESSION_NAME_TEST:codex-dead-aaaaaa-bb" remain-on-exit on
    sleep 1
    run "$SCRIPT" kill --orphaned
    [ "$status" -eq 0 ]
    tmux list-windows -t "$SESSION_NAME_TEST" -F '#{window_name}' \
        | grep -Fxq "codex-alive-aaaaaa-aa"
    ! tmux list-windows -t "$SESSION_NAME_TEST" -F '#{window_name}' \
        | grep -Fxq "codex-dead-aaaaaa-bb"
}
