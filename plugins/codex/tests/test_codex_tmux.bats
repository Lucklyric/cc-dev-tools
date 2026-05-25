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
