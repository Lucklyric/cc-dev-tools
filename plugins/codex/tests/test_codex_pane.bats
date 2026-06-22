#!/usr/bin/env bats
# Tests for codex-tmux.sh `pane` mode (codex as a pane in the current Claude
# window). Each test runs against a DEDICATED detached test session so the
# split-window never touches the real window. See README.md.

SCRIPT="${BATS_TEST_DIRNAME}/../scripts/codex-tmux.sh"

pane_count() {
    tmux list-panes -t "$PANE_SESSION" -F '#{pane_id}' 2>/dev/null | wc -l | tr -d ' '
}

setup() {
    PANE_SESSION="cc-codex-pane-test-$$"
    tmux kill-session -t "$PANE_SESSION" 2>/dev/null || true
    tmux new-session -d -s "$PANE_SESSION" -x 220 -y 50
    REF_PANE="$(tmux list-panes -t "$PANE_SESSION" -F '#{pane_id}' | head -n1)"
    # The reference pane = where "Claude" notionally runs; cmd_pane splits here.
    export CC_CODEX_REF_PANE="$REF_PANE"
    export CC_CODEX_BIN="$BATS_TEST_DIRNAME/fixtures/mock-codex.sh"
    export CLAUDE_CODE_SESSION_ID="0d61e624-1494-4aec-9b46-31d2a9534099"  # claude6=0d61e6
    # Throwaway cc-codex session name so pane-aware `kill --mine/--orphaned`
    # (which call ensure_session) never touch the real cc-codex session.
    export CC_CODEX_SESSION_NAME="cc-codex-panetest-$$"
}

teardown() {
    tmux kill-session -t "$PANE_SESSION" 2>/dev/null || true
    tmux kill-session -t "$CC_CODEX_SESSION_NAME" 2>/dev/null || true
}

@test "pane: prints a pane id on stdout line 1" {
    run "$SCRIPT" pane --cwd /tmp
    [ "$status" -eq 0 ]
    [[ "${lines[0]}" =~ ^%[0-9]+$ ]]
}

@test "pane: splits a new codex pane into the current window" {
    local before after
    before="$(pane_count)"
    run "$SCRIPT" pane --cwd /tmp
    [ "$status" -eq 0 ]
    after="$(pane_count)"
    [ "$after" -eq "$(( before + 1 ))" ]
}

@test "pane: marks the new pane with the claude6 identity option" {
    run "$SCRIPT" pane --cwd /tmp
    [ "$status" -eq 0 ]
    local pane="${lines[0]}"
    [ "$(tmux show-option -p -qv -t "$pane" '@cc_codex_claude6')" = "0d61e6" ]
}

@test "pane: is idempotent — same pane id and no extra pane" {
    run "$SCRIPT" pane --cwd /tmp
    [ "$status" -eq 0 ]
    local first="${lines[0]}"
    sleep 0.3
    local count1; count1="$(pane_count)"
    run "$SCRIPT" pane --cwd /tmp
    [ "$status" -eq 0 ]
    local second="${lines[0]}"
    local count2; count2="$(pane_count)"
    [ "$first" = "$second" ]
    [ "$count1" -eq "$count2" ]
}

@test "pane: records @cc_codex_cwd and default @cc_codex_sandbox=read-only" {
    run "$SCRIPT" pane --cwd /tmp/pane-cwd
    [ "$status" -eq 0 ]
    local pane="${lines[0]}"
    [ "$(tmux show-option -p -qv -t "$pane" '@cc_codex_cwd')" = "/tmp/pane-cwd" ]
    [ "$(tmux show-option -p -qv -t "$pane" '@cc_codex_sandbox')" = "read-only" ]
}

@test "pane --full-auto: sets @cc_codex_sandbox=workspace-write" {
    run "$SCRIPT" pane --full-auto --cwd /tmp
    [ "$status" -eq 0 ]
    local pane="${lines[0]}"
    [ "$(tmux show-option -p -qv -t "$pane" '@cc_codex_sandbox')" = "workspace-write" ]
}

@test "pane --vertical --size: creates a pane (smoke)" {
    run "$SCRIPT" pane --vertical --size 30 --cwd /tmp
    [ "$status" -eq 0 ]
    [[ "${lines[0]}" =~ ^%[0-9]+$ ]]
}

@test "pane: respawns the codex pane when its process is dead" {
    run "$SCRIPT" pane --cwd /tmp
    [ "$status" -eq 0 ]
    local first="${lines[0]}"
    # Make the mock exit; remain-on-exit keeps the pane around as dead.
    tmux send-keys -t "$first" "/exit" Enter
    sleep 0.7
    [ "$(tmux display-message -p -t "$first" '#{pane_dead}')" = "1" ]
    run "$SCRIPT" pane --cwd /tmp
    [ "$status" -eq 0 ]
    local second="${lines[0]}"
    [ "$first" != "$second" ]
    [ "$(tmux display-message -p -t "$second" '#{pane_dead}')" = "0" ]
}

@test "pane: exits 3 when not inside tmux (no reference pane)" {
    CC_CODEX_REF_PANE="" TMUX="" TMUX_PANE="" run "$SCRIPT" pane --cwd /tmp
    [ "$status" -eq 3 ]
    [[ "$output" == *"bind"* ]]
}

@test "kill <%pane-id>: removes a codex pane" {
    run "$SCRIPT" pane --cwd /tmp
    [ "$status" -eq 0 ]
    local pane="${lines[0]}"
    tmux list-panes -t "$PANE_SESSION" -F '#{pane_id}' | grep -Fxq "$pane"
    run "$SCRIPT" kill "$pane"
    [ "$status" -eq 0 ]
    ! tmux list-panes -t "$PANE_SESSION" -F '#{pane_id}' | grep -Fxq "$pane"
}

@test "kill <%bad-pane-id> exits 6" {
    run "$SCRIPT" kill "%999999"
    [ "$status" -eq 6 ]
}

@test "pane: codex dying on launch returns exit 4 (no crash)" {
    CC_CODEX_BIN="$BATS_TEST_DIRNAME/fixtures/mock-codex-instant-exit.sh" \
        run "$SCRIPT" pane --cwd /tmp
    [ "$status" -eq 4 ]
    [[ "$output" == *"exited immediately"* ]]
}

@test "pane: passes default codex flags (read-only sandbox, policy, effort)" {
    local cwd; cwd="$(mktemp -d)"
    CC_CODEX_BIN="$BATS_TEST_DIRNAME/fixtures/mock-codex-logargs.sh" \
        run "$SCRIPT" pane --cwd "$cwd"
    [ "$status" -eq 0 ]
    sleep 0.3
    local argv; argv="$(cat "$cwd/mock-codex-argv.log")"
    [[ "$argv" == *"-s read-only"* ]]
    [[ "$argv" == *"approval_policy=on-request"* ]]
    [[ "$argv" == *"model_reasoning_effort=xhigh"* ]]
    [[ "$argv" != *"network_access=true"* ]]
    rm -rf "$cwd"
}

@test "pane --full-auto: passes workspace-write sandbox and network access" {
    local cwd; cwd="$(mktemp -d)"
    CC_CODEX_BIN="$BATS_TEST_DIRNAME/fixtures/mock-codex-logargs.sh" \
        run "$SCRIPT" pane --full-auto --cwd "$cwd"
    [ "$status" -eq 0 ]
    sleep 0.3
    local argv; argv="$(cat "$cwd/mock-codex-argv.log")"
    [[ "$argv" == *"-s workspace-write"* ]]
    [[ "$argv" == *"sandbox_workspace_write.network_access=true"* ]]
    rm -rf "$cwd"
}

@test "pane: does not adopt another claude6's codex pane" {
    local foreign
    foreign="$(tmux split-window -t "$REF_PANE" -d -P -F '#{pane_id}' "sleep 60")"
    tmux set-option -p -t "$foreign" '@cc_codex_claude6' "ffffff"
    run "$SCRIPT" pane --cwd /tmp
    [ "$status" -eq 0 ]
    local mine="${lines[0]}"
    [ "$mine" != "$foreign" ]
    [ "$(tmux show-option -p -qv -t "$mine" '@cc_codex_claude6')" = "0d61e6" ]
}

@test "pane: reuses this Claude's pane from another window (session-wide)" {
    run "$SCRIPT" pane --cwd /tmp
    [ "$status" -eq 0 ]
    local first="${lines[0]}"
    sleep 0.3
    # Move "Claude" to a brand-new window; reuse must still find the codex pane.
    local ref2; ref2="$(tmux new-window -t "$PANE_SESSION" -P -F '#{pane_id}')"
    CC_CODEX_REF_PANE="$ref2" run "$SCRIPT" pane --cwd /tmp
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "$first" ]
}

@test "pane --size out of range / non-numeric exits 2" {
    run "$SCRIPT" pane --size 999 --cwd /tmp
    [ "$status" -eq 2 ]
    run "$SCRIPT" pane --size abc --cwd /tmp
    [ "$status" -eq 2 ]
}

@test "kill --mine removes this Claude's codex pane (pane-aware)" {
    run "$SCRIPT" pane --cwd /tmp
    [ "$status" -eq 0 ]
    local pane="${lines[0]}"
    tmux list-panes -a -F '#{pane_id}' | grep -Fxq "$pane"
    run "$SCRIPT" kill --mine
    [ "$status" -eq 0 ]
    [[ "$output" == *"pane"* ]]
    ! tmux list-panes -a -F '#{pane_id}' | grep -Fxq "$pane"
}
