# Codex Tmux Mode — Reference

Tmux mode is the default for codex calls. This document covers the helper script's subcommands, multi-turn workflows, recovery across restarts, and troubleshooting.

## Single tmux session, one window per codex

All codex instances live in a single tmux session named `cc-codex`, lazy-created on first call. Each codex instance gets exactly one tmux window inside that session. Users can attach with:

```bash
tmux attach -t cc-codex
```

Inside, `Ctrl-b w` lists all codex windows and lets you switch between them.

## Window naming

Window names follow `codex-<topic>-<claude6>-<rand2>`:

- `<topic>` is a 2–15 char lowercase slug (`[a-z0-9-]`) derived from the user's request. Examples: `auth`, `refactor`, `tests`, `migration`.
- `<claude6>` is the first 6 chars of `$CLAUDE_CODE_SESSION_ID` (e.g., `0d61e6`). When unset, the script falls back to `sha256("$PPID:$PWD") | head -c 6`.
- `<rand2>` is two random `[a-z0-9]` characters to prevent collisions when the same topic recurs.

Example: `codex-auth-0d61e6-x7`.

## Subcommand catalog

Invoke via `$CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh <sub> [...]`.

| Subcommand | Purpose |
|---|---|
| `new <topic> [--cwd DIR] [--full-auto\|--read-only]` | Spawn a new codex window. Prints window name + attach hint. |
| `send <window> <prompt> [--timeout SECS]` | Send a prompt, wait for codex idle, return delta on stdout. |
| `capture <window> [--lines N]` | Print pane buffer without sending anything. |
| `ls [--mine]` | List windows; `--mine` filters to current Claude session. |
| `attach <window>` | Print the `tmux attach` command for the user to run. |
| `rename <old> <new-topic>` | Replace topic only; preserves claude6+rand2 suffix. |
| `kill <window>` / `kill --orphaned` | Remove a window or all dead codex windows. |
| `exec [flags...] <prompt>` | One-shot escape hatch using `codex exec` (no tmux). |

## Multi-turn workflow

```bash
# Turn 1: spawn a session and ask the first question.
WIN=$($CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh new auth --cwd "$PWD" | head -n1)
$CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh send "$WIN" "Analyze @src/auth.ts for race conditions"

# Turn 2 (continuation): reuse the same window.
$CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh send "$WIN" "now also check the SQL queries"

# Turn 3 (parallel topic): spawn a second window.
WIN2=$($CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh new tests | head -n1)
$CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh send "$WIN2" "review the test suite"
```

## Cross-restart recovery

Windows persist across Claude Code restarts. After a restart, `ls --mine` returns nothing (new `<claude6>` token), but plain `ls` shows everything. The skill matches candidates by topic + cwd and asks the user to confirm before resuming.

## State machine

`ls` reports each window's state as one of:

- `idle` — codex alive, ready regex matches the bottom of the pane.
- `busy` — codex alive, ready regex does not match (codex is still working).
- `dead` — codex process has exited; the window persists so the exit message is readable on attach.
- `unknown` — couldn't determine state in 1s (very rare; usually means tmux is overloaded).

`kill --orphaned` removes all `dead` windows.

## Approval policy

`new` launches codex with `approval_policy=on-request` so that any approval dialogs surface inside the tmux window. The user approves them via attach. Flags:

- `--read-only` (default) — `-s read-only`, approvals don't matter since codex can't write.
- `--full-auto` — `-s workspace-write` with `on-request`. User must attach to approve writes.

## Troubleshooting

### Ready timeout / `READY_REGEX_MISMATCH`

The script polls `tmux capture-pane` looking for a configurable ready marker (default `▌`). If codex's TUI changes upstream, the regex may no longer match and `send` will time out (exit 124) with the marker `READY_REGEX_MISMATCH` on stderr.

Fix by overriding the regex:

```bash
export CC_CODEX_READY_REGEX='your-new-pattern'
```

To find the right pattern: `codex-tmux.sh capture <window>` and look at the bottom of the buffer when codex is waiting for input.

### `tmux` not installed

Install with `brew install tmux` (macOS) or your package manager's equivalent. The script exits 127 with a hint if missing.

### Codex unauthenticated

`new` will time out and the captured tail will show codex's auth prompt. Run `codex login` then retry.

### Concurrent sends

Two `send` calls against the same window are serialized via a per-window lockfile at `~/.cache/cc-codex/locks/<window>.lock`. The second call waits up to the send timeout (default 600s) before failing with `EAGAIN`.

## Migration from previous versions

Prior to v3.0.0, codex calls always used `codex exec` headless. As of v3.0.0:

- Default mode is tmux (this document).
- One-shots still use `codex exec` via the script's `exec` subcommand.
- The `codex exec resume --last` / `resume <uuid>` patterns continue to work for `exec`-mode calls; they have no effect on tmux mode (tmux's window IS the session).

If you preferred the old behavior, use `codex-tmux.sh exec` directly, or set `CC_CODEX_FORCE_EXEC=1` (future flag — not in v1).
