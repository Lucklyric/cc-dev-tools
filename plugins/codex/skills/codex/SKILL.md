---
name: codex
version: 3.0.0
description: This skill should be used when the user asks to "use codex", "ask codex", "run codex", "call codex", "codex cli", "GPT-5 reasoning", "OpenAI reasoning", or requests complex implementation, architecture design, deep code review, or high-reasoning model assistance. Also triggers on "continue codex"/"resume the codex session" for iterative development.
---

# Codex: High-Reasoning AI Assistant for Claude Code

Use OpenAI's Codex CLI (`gpt-5.5`, `xhigh` reasoning) for complex coding, architecture, and review work that benefits from a frontier reasoning model.

**Default mode is now tmux.** Codex runs in a long-lived attachable tmux session so you can watch, intervene, and iterate. A `codex exec` escape hatch remains for genuine one-shots.

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

Window names then become `codex-<topic>-<claude6>-<rand2>` (e.g., `codex-auth-0d61e6-x7`). The full reference is in `references/tmux-mode.md`.

## Canonical commands

```bash
# Spawn a new codex window (returns window name + attach hint).
WIN=$($CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh new <topic> --cwd "$PWD" | head -n1)

# Send a prompt; returns the delta when codex is idle.
$CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh send "$WIN" "<prompt>"

# Inspect pane without sending.
$CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh capture "$WIN"

# List sessions for the current conversation.
$CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh ls --mine

# One-shot escape hatch.
$CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh exec "<prompt>"
```

The helper script lives at `plugins/codex/scripts/codex-tmux.sh` (path resolved via `$CLAUDE_PLUGIN_ROOT`). Never call `tmux` directly from the skill — always go through the helper.

## Choosing the right window across turns

- **First codex call of the conversation** → `new <topic>`. Save the returned window name.
- **Continuation ("now also…", "continue")** → `send` to the most recent matching window (`ls --mine`).
- **Parallel topic** → `new` a second window with a distinct topic.
- **Reference to a prior conversation's window** → `ls` (no `--mine`), match by topic + cwd, confirm with the user before resuming.

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

The helper script fails loudly (non-zero exit + stderr marker). When it fails, surface the output verbatim. Common markers:

- `CODEX_DEAD` — codex process in the window exited. Offer to spawn fresh.
- `READY_REGEX_MISMATCH` — ready detection timed out. Tell the user about `CC_CODEX_READY_REGEX`.
- `EAGAIN` — lock contention on `send`. Usually means a parallel call; retry or report.
- `ENXIO` — window doesn't exist anymore. Suggest spawning new or running `ls`.

## Reference index

- `references/tmux-mode.md` — **NEW** — full tmux workflow, subcommand reference, troubleshooting, migration note.
- `references/session-workflows.md` — continuation decision rules for `exec` mode, session-ID tracking.
- `references/cli-features.md` — CLI flag table, interactive-vs-exec differences, `codex review` and `codex apply`.
- `references/codex-config.md` — every `-c` key with type and default.
- `references/codex-help.md` — raw `--help` output.
- `references/file-context.md` — passing files, directories, and the `@` syntax.
- `references/examples.md` — full examples by use case.
- `references/command-patterns.md` — common invocation patterns (both modes).
- `references/advanced-patterns.md` — combined flag patterns, profiles, multi-phase workflows.
- `references/troubleshooting.md` — error catalog and fixes.
