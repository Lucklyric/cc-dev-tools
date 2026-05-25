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
