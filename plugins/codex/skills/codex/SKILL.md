---
name: codex
description: This skill should be used when the user asks to "use codex", "ask codex", "run codex", "call codex", "codex cli", or explicitly asks to delegate work to a frontier reasoning model (e.g., "have GPT-5 review this", "get the OpenAI reasoning model to design X", "ask the high-reasoning model"). Also triggers on "continue codex" / "resume the codex session" for iterative development. Do NOT trigger when the user is merely discussing GPT-5 / OpenAI reasoning as a topic, or asking Claude itself to do complex implementation / architecture / review work without naming codex or a frontier reasoning model.
---

# Codex: High-Reasoning AI Assistant for Claude Code

Use OpenAI's Codex CLI (`gpt-5.5`, `xhigh` reasoning) for complex coding, architecture, and review work that benefits from a frontier reasoning model.

**Default mode is tmux.** Codex runs in a long-lived attachable tmux session so you can watch, intervene, and iterate. The helper script handles lifecycle (spawn / list / kill) and Claude drives the interaction layer directly with `tmux send-keys` and `tmux capture-pane`. A `codex exec` escape hatch remains for genuine one-shots.

## When to use tmux mode vs `exec`

| Use **tmux** (default) when | Use **`exec`** escape hatch when |
|---|---|
| The user asks any analysis, design, or implementation that may need follow-up. | The user explicitly says "quick", "one-line", "just", "no session", "don't spawn", "fire and forget". |
| The user uses continuation verbs ("continue", "resume", "now also…"). | The user requests `codex review` or `codex apply` (always one-shot). |
| The user references files with `@` and expects iterative refinement. | A hook or automation calls codex with no follow-up planned. |
| The first codex call in a conversation, when intent is unclear. | A short standalone summary the user clearly does not intend to iterate on. |

When in doubt, default to tmux mode.

## Topic naming protocol

Every `new` call needs a 2–15 char lowercase slug. Derive it from the user's request:

1. Identify the primary content noun or verb (e.g., `auth`, `refactor`, `tests`, `migration`).
2. Lowercase it; strip non-`[a-z0-9-]` characters.
3. Truncate to 15 chars.
4. If shorter than 2 chars or no content word is identifiable, default to `task`.

Examples:
- "analyze auth.ts" → `auth`
- "refactor the queue" → `refactor`
- "review the test suite" → `tests`
- "do that thing" → `task`

Window names become `codex-<topic>-<claude6>-<rand2>` (e.g., `codex-auth-0d61e6-x7`). Full naming rules: `references/tmux-mode.md`.

## Lifecycle one-liners (helper script)

The helper script at `$CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh` handles lifecycle only. It does NOT manage interaction.

```bash
# Spawn a new codex window. Returns immediately — does not wait for codex to be ready.
WIN=$($CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh new <topic> --cwd "$PWD" | head -n1)

# List sessions for the current conversation.
$CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh ls --mine

# Print attach command for the user.
$CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh attach "$WIN"

# Rename topic; preserves claude6+rand2 suffix.
$CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh rename "$WIN" "newtopic"

# Kill a specific window, all of this Claude session's windows, or all
# dead-codex windows.
$CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh kill "$WIN"
$CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh kill --mine
$CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh kill --orphaned

# One-shot escape hatch (no tmux).
$CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh exec "<prompt>"
```

The script keeps `send` and `capture` as recognized keywords ONLY to print a migration error pointing at the recipes below. **Drive interaction yourself via raw tmux commands.**

## Interaction one-liners

Each line is the short form. Full recipes with calibration notes live in `references/tmux-mode.md`.

```bash
# Wait for codex to be input-ready (status line appears). Use after `new`.
IDLE_REGEX='gpt-5\.5.*(xhigh|high|medium|low)'
while ! tmux capture-pane -t cc-codex:$WIN -p -S -200 | grep -qE "$IDLE_REGEX"; do sleep 0.5; done

# Take a baseline BEFORE sending; you'll use it both as the activity-wait
# anchor and for delta extraction.
BASELINE=$(tmux capture-pane -t cc-codex:$WIN -p -S -200)

# Send a short prompt (≤500 chars, single line).
tmux send-keys -t cc-codex:$WIN -l -- "<prompt>"
sleep 0.3
tmux send-keys -t cc-codex:$WIN Enter

# Send a long / multi-line / code-block prompt: use the Write tool to drop
# the prompt body to a tmp file, then point codex at it. Avoids shell
# quoting and heredoc-delimiter collisions.
#   1. Write tool → $PROMPT_FILE  (e.g. mktemp -t cc-codex-prompt.XXXX.md path)
#   2. tmux send-keys -t cc-codex:$WIN -l -- "Read @$PROMPT_FILE and follow its instructions."
#   3. sleep 0.3 && tmux send-keys -t cc-codex:$WIN Enter

# Two-phase recheck: (a) wait for pane to differ from BASELINE (activity
# started), (b) then wait for pane to stop changing AND show status line.
# This is the recheck strategy — Claude must actively poll; there's no
# auto-notification when codex finishes.
ACTIVITY_DEADLINE=$(( $(date +%s) + 30 ))
while (( $(date +%s) < ACTIVITY_DEADLINE )); do
    [[ "$(tmux capture-pane -t cc-codex:$WIN -p -S -200)" != "$BASELINE" ]] && break
    sleep 0.5
done
PREV=""; STABLE=0; DEADLINE=$(( $(date +%s) + 600 ))
while (( $(date +%s) < DEADLINE )); do
    BUF=$(tmux capture-pane -t cc-codex:$WIN -p -S -200)
    if [[ "$BUF" == "$PREV" ]] && echo "$BUF" | grep -qE "$IDLE_REGEX"; then
        STABLE=$(( STABLE + 1 )); (( STABLE >= 2 )) && break
    else STABLE=0; fi
    PREV="$BUF"; sleep 0.5
done

# Read the delta (everything codex emitted since BASELINE).
AFTER=$(tmux capture-pane -t cc-codex:$WIN -p -S -200)
diff <(printf '%s\n' "$BASELINE") <(printf '%s\n' "$AFTER") | grep '^>' | sed 's/^> //'

# Capture more scrollback when the response is long (>200 lines).
tmux capture-pane -t cc-codex:$WIN -p -S -1000

# Cancel an in-flight generation (e.g., user said "stop, ask it X instead").
tmux send-keys -t cc-codex:$WIN Escape       # codex TUI binds Esc to cancel
# Then re-run detect-idle and send the new prompt.

# Handle a hooks-review prompt (first-ever codex run, one-time).
tmux send-keys -t cc-codex:$WIN "2" Enter
```

See `references/tmux-mode.md` for the full recipes including the activity-wait loop, stability check, delta computation, copy-mode navigation, and per-version regex calibration.

## Choosing the right recipe

| Situation | Recipe |
|---|---|
| Prompt < ~500 chars, single line | `short-inline-prompt` |
| Multi-line prompt, code blocks, > ~1KB | `tmp-file-prompt` |
| Need to know "is codex done" | `detect-idle` |
| Reading the latest response | `extract-delta` |
| Response > ~200 lines | `incremental-capture` |
| Response > tmux `history-limit` (~2000 lines) | `copy-mode-navigation` (rare) |
| User says "stop / cancel / never mind" mid-response | `cancel-in-flight` |
| Codex shows a non-response prompt | `handle-interruption` |
| Resuming after the session id rolled or windows were killed | `reuse-existing-window` |

## Choosing the right window across turns

- **First codex call of the conversation** → `new <topic>`. Save the returned window name. Then run the idle-wait loop before the first send.
- **Continuation ("now also…", "continue")** → drive `send-keys` on the most recent matching window (`ls --mine`).
- **Parallel topic** → `new` a second window with a distinct topic.
- **Reference to a prior conversation's window or after `kill --orphaned`** → use the `reuse-existing-window` recipe in `tmux-mode.md`. `ls` (no `--mine`) lists everything; match by topic + cwd, confirm with the user before resuming. If the window is `dead`, scrollback is still readable (codex process exited but `remain-on-exit` keeps the window); if the window is gone, spawn fresh with `new` and pass prior context inline.

### Cleaning up windows

| Goal | Command |
|---|---|
| Remove one window | `codex-tmux.sh kill <window>` |
| Remove this Claude session's windows (alive or dead) | `codex-tmux.sh kill --mine` |
| Remove only dead-codex windows (any session) | `codex-tmux.sh kill --orphaned` |

Killing destroys scrollback. If you might need the conversation later, prefer `kill --orphaned` and leave alive windows in place — they can be reused via the `reuse-existing-window` recipe.

## Sandbox and approval policy

| User intent | Flags |
|---|---|
| Default (read-only analysis) | `new <topic>` (uses `--read-only`, `approval_policy=on-request`) |
| Explicit edit request | `new <topic> --full-auto` (uses `workspace-write` + `on-request`; user approves writes via attach) |
| One-shot edit (no tmux) | `exec -s workspace-write -c sandbox_workspace_write.network_access=true "<prompt>"` |

The skill still defaults to read-only sandbox; switch to `--full-auto` only when the user explicitly says "edit", "modify", "save", "fix", "refactor", etc.

## Model and reasoning effort

Defaults: model `gpt-5.5`, reasoning effort `xhigh`. Both apply in tmux mode (via codex flags on `new`) and in `exec` mode (via the script's default flag injection).

Use `gpt-5.5-fast` only when the user explicitly asks for speed ("fast", "quick"). On ChatGPT-account auth, only `gpt-5.5` is callable; `gpt-5.5-fast`, `gpt-5.5-codex`, and `gpt-5.5-pro` require API-key auth.

**Fallback chain**: model `gpt-5.5` → `gpt-5.5-fast`; effort `xhigh` → `high` → `medium`.

## File context passing

Pass file paths to codex; do not embed file contents in the prompt.

- `@path/to/file` — explicit file reference inside the prompt (works in both modes).
- `--cwd /path` on `new` — set working directory for the codex window.
- `--add-dir /path` on `exec` — additional readable/writable directory (one-shot mode only).

Details and resolution rules: `references/file-context.md`.

## Surfacing failures to the user

The helper script fails loudly (non-zero exit + stderr) for lifecycle errors. When it fails, surface the output verbatim. Common markers in the script:

- `CODEX_DEAD` — codex process in the window exited. Offer to spawn fresh.
- Window-not-found errors from `ls`, `kill`, `attach`, `rename` — surface the message.
- v3.1.0 migration errors from `send`/`capture` — exit 64. Switch to the skill recipes.

Interaction errors (codex hung, regex doesn't match, unexpected TUI prompt) are now Claude's responsibility to detect from `capture-pane` output and either recover (see the `handle-interruption` recipe) or escalate to the user.

## Reference index

**Canonical (v3.1.0 default tmux workflow):**
- `references/tmux-mode.md` — **canonical** — full recipe catalog, scrollback semantics, troubleshooting, v3.0.0 migration table.
- `references/cli-features.md` — CLI flag table, interactive-vs-exec differences, `codex review` and `codex apply`.
- `references/codex-config.md` — every `-c` key with type and default.
- `references/codex-help.md` — raw `--help` output.
- `references/file-context.md` — passing files, directories, and the `@` syntax.

**Legacy (`exec`-mode escape hatch only):**
- `references/session-workflows.md` — `codex exec resume` continuation rules and session-ID tracking.
- `references/examples.md` — `codex exec` examples by use case.
- `references/command-patterns.md` — `codex exec` invocation templates.
- `references/advanced-patterns.md` — `codex exec` flag combinations, profiles, multi-phase workflows.
- `references/troubleshooting.md` — `codex exec` error catalog and fixes (tmux-mode troubleshooting lives in `tmux-mode.md`).
