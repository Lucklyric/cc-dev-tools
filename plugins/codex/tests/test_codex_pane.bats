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

@test "pane: respawns the codex pane when its process crashed (dead)" {
    run "$SCRIPT" pane --cwd /tmp
    [ "$status" -eq 0 ]
    local first="${lines[0]}"
    # Crash the codex process (SIGKILL = non-zero exit) so remain-on-exit=failed
    # keeps the pane around as DEAD.
    local pid; pid="$(tmux display-message -p -t "$first" '#{pane_pid}')"
    kill -KILL "$pid" 2>/dev/null || true
    sleep 0.7
    [ "$(tmux display-message -p -t "$first" '#{pane_dead}')" = "1" ]
    run "$SCRIPT" pane --cwd /tmp
    [ "$status" -eq 0 ]
    local second="${lines[0]}"
    [ "$first" != "$second" ]
    [ "$(tmux display-message -p -t "$second" '#{pane_dead}')" = "0" ]
}

@test "pane: a clean exit auto-closes the pane (remain-on-exit=failed, no dead clutter)" {
    run "$SCRIPT" pane --cwd /tmp
    [ "$status" -eq 0 ]
    local first="${lines[0]}"
    # /exit makes the mock exit 0 (clean) → the pane must AUTO-CLOSE, not linger dead.
    tmux send-keys -t "$first" "/exit" Enter
    sleep 0.8
    ! tmux list-panes -a -F '#{pane_id}' | grep -Fxq "$first"
    # Re-resolving after the pane closed spawns a fresh live pane.
    run "$SCRIPT" pane --cwd /tmp
    [ "$status" -eq 0 ]
    [ "${lines[0]}" != "$first" ]
}

@test "pane: CC_CODEX_REMAIN_ON_EXIT=on keeps a clean-exit pane dead (override)" {
    CC_CODEX_REMAIN_ON_EXIT=on run "$SCRIPT" pane --cwd /tmp
    [ "$status" -eq 0 ]
    local first="${lines[0]}"
    tmux send-keys -t "$first" "/exit" Enter
    sleep 0.8
    # With the override, a clean exit is kept as a dead pane (old behavior).
    [ "$(tmux display-message -p -t "$first" '#{pane_dead}')" = "1" ]
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

@test "pane: passes default codex flags (model, read-only sandbox, policy, effort)" {
    local cwd; cwd="$(mktemp -d)"
    CC_CODEX_BIN="$BATS_TEST_DIRNAME/fixtures/mock-codex-logargs.sh" \
        run "$SCRIPT" pane --cwd "$cwd"
    [ "$status" -eq 0 ]
    sleep 0.3
    local argv; argv="$(cat "$cwd/mock-codex-argv.log")"
    [[ "$argv" == *"-m gpt-5.6-sol"* ]]
    [[ "$argv" == *"-s read-only"* ]]
    [[ "$argv" == *"approval_policy=on-request"* ]]
    [[ "$argv" == *"model_reasoning_effort=xhigh"* ]]
    [[ "$argv" != *"network_access=true"* ]]
    rm -rf "$cwd"
}

@test "pane: CC_CODEX_MODEL and CC_CODEX_EFFORT override the defaults" {
    local cwd; cwd="$(mktemp -d)"
    CC_CODEX_MODEL="gpt-5.6-terra" CC_CODEX_EFFORT="ultra" \
    CC_CODEX_BIN="$BATS_TEST_DIRNAME/fixtures/mock-codex-logargs.sh" \
        run "$SCRIPT" pane --cwd "$cwd"
    [ "$status" -eq 0 ]
    sleep 0.3
    local argv; argv="$(cat "$cwd/mock-codex-argv.log")"
    [[ "$argv" == *"-m gpt-5.6-terra"* ]]
    [[ "$argv" == *"model_reasoning_effort=ultra"* ]]
    [[ "$argv" != *"gpt-5.6-sol"* ]]
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

@test "pane: relocates this Claude's pane into the current window (not duplicated)" {
    run "$SCRIPT" pane --cwd /tmp
    [ "$status" -eq 0 ]
    local first="${lines[0]}"
    sleep 0.3
    # Move "Claude" to a brand-new window; the codex pane should FOLLOW here.
    local ref2 ref2_win
    ref2="$(tmux new-window -t "$PANE_SESSION" -P -F '#{pane_id}')"
    ref2_win="$(tmux display-message -p -t "$ref2" '#{window_index}')"
    CC_CODEX_REF_PANE="$ref2" run "$SCRIPT" pane --cwd /tmp
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "$first" ]                       # same pane, relocated not duplicated
    local now_win; now_win="$(tmux display-message -p -t "$first" '#{window_index}')"
    [ "$now_win" = "$ref2_win" ]                       # now lives in the current window
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

@test "pane / kill --mine do NOT auto-create the cc-codex session (no empty-session wart)" {
    local FRESH="cc-codex-wart-$$"
    export CC_CODEX_SESSION_NAME="$FRESH"
    tmux kill-session -t "$FRESH" 2>/dev/null || true
    # pane mode must never create the dedicated session
    run "$SCRIPT" pane --cwd /tmp
    [ "$status" -eq 0 ]
    ! tmux has-session -t "$FRESH" 2>/dev/null
    # kill --mine must clean the pane WITHOUT resurrecting an empty session
    run "$SCRIPT" kill --mine
    [ "$status" -eq 0 ]
    ! tmux has-session -t "$FRESH" 2>/dev/null
}

# ---------- Multi-pane surface (panes / pane --topic) ----------

# First bare pane-id line in $output. bats' `run` merges stderr into $output,
# and a second split in an already-halved window legitimately emits the
# width-floor warning ("<80 cols; using a vertical split") on stderr BEFORE
# the pane id — so ${lines[0]} is not reliable for topic panes.
output_pane_id() {
    printf '%s\n' "$output" | grep -m1 -E '^%[0-9]+$'
}

@test "panes: lists the primary pane with topic main" {
    run "$SCRIPT" pane --cwd /tmp
    [ "$status" -eq 0 ]
    local pane="${lines[0]}"
    run "$SCRIPT" panes
    [ "$status" -eq 0 ]
    [[ "$output" == *"$pane"$'\t'"main"$'\t'"alive"* ]]
}

@test "panes: exits 1 when this agent has no codex panes" {
    # Unique claude6 so stale panes from other agents/runs can never match.
    CLAUDE_CODE_SESSION_ID="e0e0e0e0-0000-4000-8000-000000000000" \
        run "$SCRIPT" panes
    [ "$status" -eq 1 ]
}

@test "panes: does not list another claude6's pane by default; --all does" {
    run "$SCRIPT" pane --cwd /tmp
    [ "$status" -eq 0 ]
    local mine="${lines[0]}"
    local foreign
    foreign="$(tmux split-window -t "$REF_PANE" -d -P -F '#{pane_id}' "sleep 60")"
    tmux set-option -p -t "$foreign" '@cc_codex_claude6' "ffffff"
    # Default: filtered to this agent's claude6 (match "<id>\t" to avoid the
    # %5-is-a-prefix-of-%53 substring trap).
    run "$SCRIPT" panes
    [ "$status" -eq 0 ]
    [[ "$output" == *"$mine"$'\t'* ]]
    [[ "$output" != *"$foreign"$'\t'* ]]
    # --all: every agent's codex panes, foreign included.
    run "$SCRIPT" panes --all
    [ "$status" -eq 0 ]
    [[ "$output" == *"$mine"$'\t'* ]]
    [[ "$output" == *"$foreign"$'\t'* ]]
}

@test "pane --topic: spawns an extra pane coexisting with the primary" {
    run "$SCRIPT" pane --cwd /tmp
    [ "$status" -eq 0 ]
    local primary="${lines[0]}"
    run "$SCRIPT" pane --topic auth --cwd /tmp
    [ "$status" -eq 0 ]
    local extra; extra="$(output_pane_id)"
    [ -n "$extra" ]
    [ "$primary" != "$extra" ]
    [ "$(tmux display-message -p -t "$primary" '#{pane_dead}')" = "0" ]
    [ "$(tmux display-message -p -t "$extra" '#{pane_dead}')" = "0" ]
    [ "$(tmux show-option -p -qv -t "$primary" '@cc_codex_topic')" = "main" ]
    [ "$(tmux show-option -p -qv -t "$extra" '@cc_codex_topic')" = "auth" ]
    [ "$(tmux display-message -p -t "$extra" '#{pane_title}')" = "codex-auth-0d61e6" ]
}

@test "pane --topic: reuses the same topic pane on repeat (idempotent)" {
    run "$SCRIPT" pane --topic auth --cwd /tmp
    [ "$status" -eq 0 ]
    local first="${lines[0]}"
    sleep 0.3
    local count1; count1="$(pane_count)"
    run "$SCRIPT" pane --topic auth --cwd /tmp
    [ "$status" -eq 0 ]
    local second="${lines[0]}"
    local count2; count2="$(pane_count)"
    [ "$first" = "$second" ]
    [ "$count1" -eq "$count2" ]
}

@test "pane --topic: invalid slug exits 2" {
    run "$SCRIPT" pane --topic x --cwd /tmp          # too short
    [ "$status" -eq 2 ]
    run "$SCRIPT" pane --topic Auth --cwd /tmp       # uppercase
    [ "$status" -eq 2 ]
    run "$SCRIPT" pane --topic way-too-long-topic-slug --cwd /tmp  # >15 chars
    [ "$status" -eq 2 ]
}

@test "legacy pane without @cc_codex_topic is treated as main" {
    # Simulate a pane created before the topic option existed: claude6 marker
    # only, no @cc_codex_topic. `pane` must reuse it, not spawn a duplicate.
    local legacy
    legacy="$(tmux split-window -t "$REF_PANE" -d -P -F '#{pane_id}' "sleep 60")"
    tmux set-option -p -t "$legacy" '@cc_codex_claude6' "0d61e6"
    local count1; count1="$(pane_count)"
    run "$SCRIPT" pane --cwd /tmp
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "$legacy" ]
    [ "$(pane_count)" -eq "$count1" ]
}

@test "kill --mine removes primary AND topic panes" {
    run "$SCRIPT" pane --cwd /tmp
    [ "$status" -eq 0 ]
    local primary="${lines[0]}"
    run "$SCRIPT" pane --topic auth --cwd /tmp
    [ "$status" -eq 0 ]
    local extra; extra="$(output_pane_id)"
    [ -n "$extra" ]
    tmux list-panes -a -F '#{pane_id}' | grep -Fxq "$primary"
    tmux list-panes -a -F '#{pane_id}' | grep -Fxq "$extra"
    run "$SCRIPT" kill --mine
    [ "$status" -eq 0 ]
    ! tmux list-panes -a -F '#{pane_id}' | grep -Fxq "$primary"
    ! tmux list-panes -a -F '#{pane_id}' | grep -Fxq "$extra"
}

@test "panes: TSV has 5 fields (pane_id, topic, state, window, cwd)" {
    run "$SCRIPT" pane --cwd /tmp
    [ "$status" -eq 0 ]
    run "$SCRIPT" pane --topic auth --cwd /tmp
    [ "$status" -eq 0 ]
    run "$SCRIPT" panes
    [ "$status" -eq 0 ]
    local nf
    nf="$(printf '%s\n' "$output" | awk -F'\t' '{print NF}' | sort -u)"
    [ "$nf" = "5" ]
}

@test "panes: does NOT auto-create the cc-codex session (read-only detection)" {
    local FRESH="cc-codex-panes-wart-$$"
    export CC_CODEX_SESSION_NAME="$FRESH"
    tmux kill-session -t "$FRESH" 2>/dev/null || true
    run "$SCRIPT" pane --cwd /tmp
    [ "$status" -eq 0 ]
    run "$SCRIPT" panes
    [ "$status" -eq 0 ]
    ! tmux has-session -t "$FRESH" 2>/dev/null
    run "$SCRIPT" panes --all
    [ "$status" -eq 0 ]
    ! tmux has-session -t "$FRESH" 2>/dev/null
}
