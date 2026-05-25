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
| `attach <window>` | Print the tmux attach command (the script does not exec it; Claude Code's bash is non-interactive). |
| `rename <old> <new-topic>` | Replace topic only; preserves the `<claude6>-<rand2>` suffix. |
| `kill <window>` / `kill --orphaned` | Remove a window or all dead-codex windows. |
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

```bash
# 1) Write the prompt to a tmp file.
PROMPT_FILE=$(mktemp -t cc-codex-prompt.XXXXXX.md)
cat > "$PROMPT_FILE" <<'PROMPT_EOF'
<the full prompt, possibly multi-line, code blocks, etc.>
PROMPT_EOF

# 2) Send a short inline message that points codex at the file.
tmux send-keys -t cc-codex:<window> -l -- "Read @${PROMPT_FILE} and follow its instructions."
sleep 0.3
tmux send-keys -t cc-codex:<window> Enter

# 3) After capturing the response (recipe extract-delta), best-effort clean up:
rm -f "$PROMPT_FILE"
```

Codex's `@file` syntax loads the file in-context, so `send-keys` does not have to stream the prompt body. The file should be readable by the codex process; `mktemp` defaults are fine. Cleanup is best-effort: codex re-reads the file only on explicit reference, so once the response is captured, removal is safe.

### Recipe: `detect-idle`

After a `send`, poll the pane to know when codex is idle and ready for the next prompt.

```bash
# Poll capture-pane every 500ms. Codex is idle when:
#   (a) the pane content has stopped changing for 2 consecutive polls, AND
#   (b) the bottom of the pane shows codex's status line (e.g., contains the
#       model+effort string for the current codex CLI release).
#
# Calibration: run `tmux capture-pane -t cc-codex:<window> -p | tail -5` to
# see what your codex CLI version puts at the bottom when idle. For
# codex 0.133, the status line looks like:
#     gpt-5.5 xhigh · /path/to/cwd
#
# So a reasonable IDLE_REGEX is: 'gpt-5\.5.*xhigh' (or include all effort
# levels: 'gpt-5\.5.*(xhigh|high|medium|low)').

IDLE_REGEX='gpt-5\.5.*(xhigh|high|medium|low)'
PREV=""
STABLE=0
DEADLINE=$(( $(date +%s) + 600 ))   # 10-minute upper bound

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

Important: after sending a prompt, wait for the pane to first **differ** from its pre-send baseline before starting stability counting. Otherwise the still-present status line will let the loop exit before codex has even started responding. Sketch:

```bash
BASELINE=$(tmux capture-pane -t cc-codex:<window> -p -S -200)
# ...send prompt...
# Wait for activity (pane differs from baseline) before stability checks.
ACTIVITY_DEADLINE=$(( $(date +%s) + 30 ))
while (( $(date +%s) < ACTIVITY_DEADLINE )); do
    [[ "$(tmux capture-pane -t cc-codex:<window> -p -S -200)" != "$BASELINE" ]] && break
    sleep 0.5
done
# Now run the stability loop above.
```

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

### Recipe: `handle-interruption`

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
| Need to know "is codex done" | `detect-idle` |
| Reading the latest response | `extract-delta` |
| Response > ~200 lines | `incremental-capture` |
| Response > tmux `history-limit` (~2000 lines) | `copy-mode-navigation` (rare) |
| Codex shows a non-response prompt | `handle-interruption` |

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
