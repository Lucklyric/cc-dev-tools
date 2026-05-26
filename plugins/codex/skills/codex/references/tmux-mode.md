# Codex Tmux Mode — Reference (v3.1.0+)

The codex skill drives interaction with codex directly via `tmux send-keys` and `tmux capture-pane`. A thin helper script handles only lifecycle (spawn, list, kill, etc.). The recipes below are the source of truth for how to interact; the script is just a shortcut for management.

## Lifecycle (script-managed)

All codex instances live in a single tmux session named `cc-codex`. Attach at any time with:

```bash
tmux attach -t cc-codex
```

Inside, `Ctrl-b w` lists windows, `Ctrl-b n` / `p` cycle through them.

The helper script at `$CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh` exposes these lifecycle subcommands:

| Subcommand | Purpose |
|---|---|
| `new <topic> [--cwd DIR] [--full-auto\|--read-only]` | Spawn a new codex window. Returns immediately — does NOT wait for codex's TUI to be ready. |
| `ls [--mine]` | List windows. State is `alive` / `dead` / `unknown` based on tmux + process inspection (no pane parsing). |
| `find <topic> [--cwd DIR] [--include-dead] [--any-session]` | Look up matching windows in the current Claude session's claude6 namespace. Use BEFORE `new` to decide reuse vs spawn. Exits 0 on match (one line per result), 1 on no match. |
| `attach <window>` | Print the tmux attach command (the script does not exec it; Claude Code's bash is non-interactive). |
| `rename <old> <new-topic>` | Replace topic only; preserves the `<claude6>-<rand2>` suffix. |
| `kill <window>` / `kill --mine` / `kill --orphaned` | Remove a window, all of the current Claude session's windows, or all dead-codex windows. |
| `exec [flags...] <prompt>` | One-shot escape hatch using `codex exec` (no tmux). |

Window naming stays `codex-<topic>-<claude6>-<rand2>` (see `SKILL.md` for the topic-slug rules).

## Interaction recipes (skill-driven)

Each recipe below is copy-pasteable bash. Substitute `<window>` with the actual window name returned by `new` (e.g., `codex-auth-0d61e6-x7`).

### Recipe: `short-inline-prompt`

Use when the prompt is ≤ ~500 chars, single line, no code blocks.

```bash
# 1) Send the prompt literally, then Enter.
tmux send-keys -t cc-codex:<window> -l -- "<prompt>"
sleep 0.3   # let the TUI register the typing before the Enter
tmux send-keys -t cc-codex:<window> Enter
```

The 0.3s pause matters: without it, codex's TUI sometimes treats the Enter as part of the typing burst and does not submit on the first try. Increase to 0.5–1s on slow machines.

### Recipe: `tmp-file-prompt`

Use when the prompt is > 500 chars, multi-line, contains code blocks, or contains characters that are tedious to send-key.

The robust pattern is to use Claude's `Write` tool (not a shell heredoc) for the prompt body, so no quoting or delimiter-collision concerns matter. The shell only sends a short inline reference.

```bash
# 1) Compute a tmp path (do NOT write via heredoc — use the Write tool).
PROMPT_FILE=$(mktemp -t cc-codex-prompt.XXXXXX.md)

# 2) From Claude: invoke the Write tool with file_path=$PROMPT_FILE and the
#    full prompt body as `content`. This handles arbitrary content (code
#    blocks, nested heredocs, quotes, multi-line, etc.) without escaping.

# 3) Send a short inline message that points codex at the file.
tmux send-keys -t cc-codex:<window> -l -- "Read @${PROMPT_FILE} and follow its instructions."
sleep 0.3
tmux send-keys -t cc-codex:<window> Enter

# 4) After capturing the response (recipe extract-delta), best-effort clean up:
rm -f "$PROMPT_FILE"
```

Codex's `@file` syntax loads the file in-context, so `send-keys` does not have to stream the prompt body. The file should be readable by the codex process; `mktemp` defaults are fine. Cleanup is best-effort: codex re-reads the file only on explicit reference, so once the response is captured, removal is safe.

Why not a heredoc? `cat > file <<'PROMPT_EOF' ... PROMPT_EOF` silently truncates if the prompt body itself contains the literal `PROMPT_EOF` line (e.g. when asking codex to review shell scripts that demonstrate nested heredocs). The Write-tool path has no such collision.

### Recipe: `detect-idle`

This is the **recheck strategy**. There is no auto-notification when codex finishes a turn — Claude must actively poll the pane. The recipe is two phases run in order: activity-wait, then stability.

**Why two phases:** codex's status line (`gpt-5.5 xhigh · /path`) is present *both* before a prompt is sent and after the response completes. A naive stability-only loop will exit immediately on the pre-send pane and treat the prompt as already complete (false positive). The activity-wait phase fixes this by requiring the pane to first **differ** from a baseline taken before the send.

**Calibration.** Run `tmux capture-pane -t cc-codex:<window> -p | tail -5` while codex is idle to see what your CLI version puts near the bottom. For codex 0.133, the status line looks like `gpt-5.5 xhigh · /path/to/cwd`, so the default `IDLE_REGEX` below matches `gpt-5.5` plus any effort level. Update the regex if your codex version uses a different status line.

```bash
IDLE_REGEX='gpt-5\.5.*(xhigh|high|medium|low)'

# --- Phase 0: take baseline BEFORE sending the prompt ------------------------
BASELINE=$(tmux capture-pane -t cc-codex:<window> -p -S -200)

# ...send prompt with short-inline-prompt or tmp-file-prompt recipe...

# --- Phase 1: activity-wait — pane must first differ from baseline ----------
ACTIVITY_DEADLINE=$(( $(date +%s) + 30 ))   # codex usually starts within 5s
while (( $(date +%s) < ACTIVITY_DEADLINE )); do
    [[ "$(tmux capture-pane -t cc-codex:<window> -p -S -200)" != "$BASELINE" ]] && break
    sleep 0.5
done

# --- Phase 2: stability — pane unchanged for 2 polls AND idle regex matches -
PREV=""
STABLE=0
DEADLINE=$(( $(date +%s) + 600 ))   # 10-minute upper bound for the response
while (( $(date +%s) < DEADLINE )); do
    BUF=$(tmux capture-pane -t cc-codex:<window> -p -S -200)
    if [[ "$BUF" == "$PREV" ]] && echo "$BUF" | grep -qE "$IDLE_REGEX"; then
        STABLE=$(( STABLE + 1 ))
        (( STABLE >= 2 )) && break
    else
        STABLE=0
    fi
    PREV="$BUF"
    sleep 0.5
done
```

Common pitfalls: skipping Phase 0/1 produces the false positive described above; setting `ACTIVITY_DEADLINE` too low aborts before codex's TUI redraws (slow machines need 10–30s); setting `DEADLINE` too low truncates long reasoning chains (xhigh effort can take several minutes for hard problems).

### Recipe: `extract-delta`

After `detect-idle` confirms codex is ready again, read the new output (everything since the prompt was sent).

```bash
# Compute the line-count delta:
#   AFTER = current pane capture
#   BASELINE = capture taken just before sending the prompt
#
# Print only the lines past the baseline length.
BEFORE_LINES=$(printf '%s\n' "$BASELINE" | wc -l)
AFTER=$(tmux capture-pane -t cc-codex:<window> -p -S -200)
AFTER_LINES=$(printf '%s\n' "$AFTER" | wc -l)
if (( AFTER_LINES > BEFORE_LINES )); then
    printf '%s\n' "$AFTER" | tail -n "$(( AFTER_LINES - BEFORE_LINES ))"
fi
```

Alternative — marker-based: when sending the prompt, prepend a uniquely-recognizable marker (e.g., a UUID) so you can re-locate the prompt in the pane after-the-fact, and read everything below it.

### Recipe: `incremental-capture`

When the response is longer than the default 200-line capture window.

```bash
# Capture progressively more scrollback until the full response is included.
# -S -N means "start N lines back from the current view".
for N in 200 500 1000 2000; do
    BUF=$(tmux capture-pane -t cc-codex:<window> -p -S -"$N")
    # Heuristic: stop when BUF contains the prompt marker / known top boundary.
    if echo "$BUF" | grep -qF "<known-top-boundary>"; then
        break
    fi
done
```

tmux's `history-limit` setting (default ~2000 lines) is the absolute upper bound for scrollback. If a single codex response exceeds that, use `copy-mode-navigation` (next recipe) or instruct codex to write its output to a file instead.

### Recipe: `copy-mode-navigation`

When the response exceeds the scrollback limit. Codex's pane usually doesn't auto-enter copy mode, so we drive it programmatically.

```bash
# Enter copy mode in the codex pane.
tmux copy-mode -t cc-codex:<window>

# Navigate to history top (oldest lines available in this window's scrollback).
tmux send-keys -X -t cc-codex:<window> history-top

# Capture from this position.
tmux capture-pane -t cc-codex:<window> -p -S -2000 -E -

# Exit copy mode when done.
tmux send-keys -t cc-codex:<window> q
```

This is rarely needed in practice — most codex responses fit within a 2000-line scrollback. Reach for it only when `incremental-capture` returned a truncated buffer.

### Recipe: `cancel-in-flight`

Use when the user changes their mind mid-response ("stop, ask it X instead" / "never mind, cancel that"). Codex's TUI binds `Esc` to cancel the current generation; we drive that key, then wait for idle, then send the new prompt.

```bash
# Cancel the in-flight generation.
tmux send-keys -t cc-codex:<window> Escape

# Wait for codex to settle back to idle before sending anything new.
# Use a fresh baseline because Esc itself may not produce visible activity.
BASELINE=$(tmux capture-pane -t cc-codex:<window> -p -S -200)
PREV=""; STABLE=0; DEADLINE=$(( $(date +%s) + 30 ))
while (( $(date +%s) < DEADLINE )); do
    BUF=$(tmux capture-pane -t cc-codex:<window> -p -S -200)
    if [[ "$BUF" == "$PREV" ]] && echo "$BUF" | grep -qE 'gpt-5\.5.*(xhigh|high|medium|low)'; then
        STABLE=$(( STABLE + 1 )); (( STABLE >= 2 )) && break
    else STABLE=0; fi
    PREV="$BUF"; sleep 0.5
done

# Now send the replacement prompt via short-inline-prompt or tmp-file-prompt.
```

If `Escape` does not cancel (rare — codex stuck in a tool call), fall back to `tmux send-keys -t cc-codex:<window> C-c`. As a last resort, `codex-tmux.sh kill <window>` and respawn with `new`.

### Recipe: `reuse-existing-window`

Use BEFORE every `new` to avoid spawning duplicate windows. Also use when:
- The Claude conversation was resumed and `$CLAUDE_CODE_SESSION_ID` rolled — `find` without `--any-session` returns nothing, but the user is referring to a prior codex window.
- The user asks to "continue the earlier discussion" or "go back to the auth window".

```bash
# 1) Lookup matching window in current session (alive only, same cwd).
#    Tab-separated output: window<TAB>state<TAB>cwd
MATCHES=$(codex-tmux.sh find auth --cwd "$PWD" || true)

# 2) If something matched, pick the first window.
if [[ -n "$MATCHES" ]]; then
    WIN=$(printf '%s\n' "$MATCHES" | head -n1 | cut -f1)
    # WIN is the window name; drive it via short-inline-prompt + detect-idle.
else
    # No match — safe to spawn fresh.
    WIN=$(codex-tmux.sh new auth --cwd "$PWD" | head -n1)
fi
```

For dead-window recovery (codex process exited but scrollback preserved):

```bash
# Find any matching window including dead ones.
DEAD=$(codex-tmux.sh find auth --cwd "$PWD" --include-dead | awk -F'\t' '$2=="dead" {print $1; exit}')
if [[ -n "$DEAD" ]]; then
    # Salvage prior conversation context from scrollback before killing.
    PRIOR=$(tmux capture-pane -t cc-codex:$DEAD -p -S -2000)
    codex-tmux.sh kill "$DEAD"
    WIN=$(codex-tmux.sh new auth --cwd "$PWD" | head -n1)
    # Pass $PRIOR to codex inline as context in the first prompt.
fi
```

For cross-Claude-session references (user resumed a conversation and wants their old auth window):

```bash
# Widen search to all claude sessions, then confirm with the user.
codex-tmux.sh find auth --any-session
# → codex-auth-bbbbbb-x7    alive    /Users/asun/codes/myproj
# Confirm: "I see codex-auth-bbbbbb-x7 (alive) — reuse this one?"
```

Why the `claude6` token isn't enough on its own: it's the first 6 chars of the *current* `$CLAUDE_CODE_SESSION_ID`. If the conversation was resumed in a new Claude session, every prior window will have a different claude6 token and the default `find` will miss them — that's what `--any-session` is for.

Codex sometimes shows interactive prompts that need acknowledgement before the main response can continue.

| What you see in the pane | What to do |
|---|---|
| `Hooks need review` (first-ever codex run) | `tmux send-keys -t cc-codex:<window> "2" Enter` to "Trust all and continue". |
| Approval prompt (`Apply this edit? [y/n]` or similar in workspace-write mode) | If safe: `tmux send-keys -t cc-codex:<window> "y" Enter`. If unsafe or unclear: tell the user to attach and approve manually. |
| `Sign in to Codex` / `Not authenticated` | `codex login` from the user's terminal. Codex doesn't recover by itself. |
| MCP startup warning (`MCP client for X failed`) | Usually benign — codex continues. No action needed unless the user is relying on that MCP. |

After any interruption, re-run `detect-idle` to wait for the status line to reappear.

## Choosing recipes — heuristics

| Situation | Recipe |
|---|---|
| Prompt < ~500 chars, single line | `short-inline-prompt` |
| Multi-line prompt, code blocks, > ~1KB | `tmp-file-prompt` |
| Need to know "is codex done" (the recheck strategy) | `detect-idle` |
| Reading the latest response | `extract-delta` |
| Response > ~200 lines | `incremental-capture` |
| Response > tmux `history-limit` (~2000 lines) | `copy-mode-navigation` (rare) |
| User says "stop / cancel / never mind" mid-response | `cancel-in-flight` |
| Codex shows a non-response prompt | `handle-interruption` |
| Conversation resumed, session-id rolled, want to reuse prior window | `reuse-existing-window` |

## Tmux scrollback semantics

`tmux capture-pane -S -N` starts the capture N lines back from the current view (negative N = scrollback). The default `history-limit` (per pane) is around 2000 lines; once exceeded, older content is dropped. Configure on a per-session basis with `tmux set-option -t cc-codex history-limit 10000` if you need more.

## Troubleshooting

### Codex appears hung

The most common cause is a one-time interruption (hooks-review, approval prompt). `tmux capture-pane -p` and look for an interactive prompt; if present, see `handle-interruption`.

If no prompt is visible: codex may be doing a long reasoning step. Wait longer, or `attach` and watch live.

### `detect-idle` returns immediately (false positive)

This happens when the status line is already present in `BASELINE` and the pre-send pane content == post-send pane content because codex hasn't started responding yet. Add the "wait for activity" pre-step shown in the `detect-idle` recipe.

### Ready regex doesn't match

Codex CLI may have updated. Run `tmux capture-pane -p | tail -10` while codex is idle and pick a stable substring (typically the model + effort line near the bottom). Update `IDLE_REGEX` in your recipe accordingly.

## Migration from v3.0.0

| v3.0.0 (script-managed) | v3.1.0 (skill-driven) |
|---|---|
| `codex-tmux.sh send <window> <prompt>` | `short-inline-prompt` recipe, or `tmp-file-prompt` for long prompts |
| `codex-tmux.sh capture <window>` | `tmux capture-pane -t cc-codex:<window> -p` (optionally `-S -N` for scrollback) |
| `CC_CODEX_READY_REGEX` | Inline `IDLE_REGEX` in each `detect-idle` call. Tune per codex CLI version. |
| `CC_CODEX_ACTIVITY_TIMEOUT` | Inline deadline in your `detect-idle` activity loop. Tune per call. |
| `CC_CODEX_TIMEOUT` | Inline deadline in `detect-idle`. |

The `cmd_send` lockfile pattern is no longer provided. If you need serialization across parallel sends (rare in normal use), wrap your call with `flock`:

```bash
LOCKFILE="$HOME/.cache/cc-codex/locks/<window>.lock"
mkdir -p "$(dirname "$LOCKFILE")"
flock "$LOCKFILE" bash -c '
    tmux send-keys -t cc-codex:<window> -l -- "<prompt>"
    sleep 0.3
    tmux send-keys -t cc-codex:<window> Enter
    # ... detect-idle and extract-delta inside the lock ...
'
```
