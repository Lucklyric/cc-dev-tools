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
