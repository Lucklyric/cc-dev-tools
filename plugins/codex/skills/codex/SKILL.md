---
name: codex
version: 2.10.0
description: This skill should be used when the user asks to "use codex", "ask codex", "run codex", "call codex", "codex cli", "GPT-5 reasoning", "OpenAI reasoning", or requests complex implementation, architecture design, deep code review, or high-reasoning model assistance. Also triggers on "continue codex"/"resume the codex session" for iterative development.
---

# Codex: High-Reasoning AI Assistant for Claude Code

Use OpenAI's Codex CLI (`gpt-5.5`, `xhigh` reasoning) for complex coding, architecture, and review work that benefits from a frontier reasoning model. Always invoke via `codex exec` (Claude Code's bash environment is non-interactive).

## Defaults (apply unless the user overrides)

| Parameter | Default | CLI flag |
|-----------|---------|----------|
| Model | `gpt-5.5` | `-m gpt-5.5` |
| Sandbox | `read-only` | `-s read-only` |
| Reasoning effort | `xhigh` | `-c model_reasoning_effort=xhigh` |
| Network access (with `workspace-write`) | enabled | `-c sandbox_workspace_write.network_access=true` |
| Web search | built-in on supported models (no flag) | — |

Switch to `workspace-write` **only** when the user explicitly says "edit", "modify", "save", "write changes", "fix", "refactor", etc. When switching, always include the `network_access=true` config so package managers (`npm`/`pip`/`cargo`), `git fetch`, and HTTP calls work.

Use `gpt-5.5-fast` only when the user explicitly asks for speed ("fast", "quick"). On ChatGPT-account auth, only `gpt-5.5` is callable; `gpt-5.5-fast`, `gpt-5.5-codex`, and `gpt-5.5-pro` require API-key auth.

**Fallback chain**: model `gpt-5.5` → `gpt-5.5-fast` → `gpt-5.4`; effort `xhigh` → `high` → `medium`.

## Canonical commands

```bash
# Read-only reasoning / review (default)
codex exec -m gpt-5.5 -s read-only \
  -c model_reasoning_effort=xhigh \
  "<prompt>"

# Edit / implement (explicit edit request from the user)
codex exec -m gpt-5.5 -s workspace-write \
  -c model_reasoning_effort=xhigh \
  -c sandbox_workspace_write.network_access=true \
  "<prompt>"

# Fast variant (only when user requests speed)
codex exec -m gpt-5.5-fast -s read-only "<prompt>"
```

For more directories: add `--add-dir /path` (repeatable) or `-c 'sandbox_workspace_write.writable_roots=["/p1","/p2"]'`.

## CRITICAL: Always use `codex exec`

| Correct | Wrong |
|---------|-------|
| `codex exec -m gpt-5.5 "prompt"` | `codex -m gpt-5.5 "prompt"` |
| `codex exec resume --last` | `codex resume --last` |

Plain `codex` is interactive-only and fails with "stdout is not a terminal" in Claude Code's bash. The same applies to `codex fork` and `codex --search` — interactive only. See `references/cli-features.md` for the full interactive-vs-exec flag table.

## Choosing sandbox

- **`read-only`** (default): analysis, review, design, explanation — anything without an explicit edit request.
- **`workspace-write`**: only when the user explicitly asks to edit/modify/save/fix files. Always pair with `-c sandbox_workspace_write.network_access=true`.
- **`danger-full-access`**: never default to this; require explicit user request.

## Configuration overrides

Pass any of these as `-c key=value`:

- `model_reasoning_effort`: `none|minimal|low|medium|high|xhigh` — skill default `xhigh`.
- `model_verbosity`: `low|medium|high` — default `medium`.
- `sandbox_workspace_write.network_access`: `true|false` — skill default `true` whenever sandbox is `workspace-write`.
- `sandbox_workspace_write.writable_roots`: JSON array of extra writable dirs.
- `approval_policy`: `untrusted|on-failure|on-request|never` — required because `-a/--ask-for-approval` is interactive-only. Use `--full-auto` as a shortcut for `workspace-write` + `on-request`.

Full key reference: `references/codex-config.md`.

## Session continuation: new vs. resume

Decide before every invocation. **Default to a new session.**

**Resume previous** (`codex exec resume --last` or `codex exec resume <uuid> "prompt"`) when any of:
- User uses continuation verbs ("continue", "resume", "keep going") or back-references ("that", "where we left off")
- Incremental modifier right after Codex output ("now also…", "and add…")
- Same artifact/topic as the last Codex turn

**Start fresh** when any of:
- Reset words ("new", "fresh", "from scratch")
- Topic shift to an unrelated file/task
- This is the first Codex call in the conversation

When ambiguous, prefer **new** and tell the user: "Starting a fresh Codex session — say 'continue' if you wanted to resume the previous one."

### Picking `--last` vs explicit UUID

Every `codex exec` prints `session id: <uuid>` near the top — that line stays in Claude Code's transcript. Use it.

- Use `--last` when only one Codex session has run in this conversation, or the user clearly means the most recent one.
- Use the explicit UUID when multiple Codex sessions are in play and the user names a specific prior task ("the auth one"). Pull the UUID from the matching `session id:` line earlier in the transcript.
- If the referenced session predates this conversation (no UUID in transcript), either run `--last` and verify, or ask the user for the UUID. **Never invent or guess UUIDs.**

Full decision rules, signal lists, and a continuation-vs-new lookup table: `references/session-workflows.md`.

## Quick examples

```bash
# Analyze a file (read-only)
codex exec -m gpt-5.5 -s read-only \
  -c model_reasoning_effort=xhigh \
  "Analyze @src/auth.ts for security issues"

# Implement with edits + network (run installers, fetch deps)
codex exec -m gpt-5.5 -s workspace-write \
  -c model_reasoning_effort=xhigh \
  -c sandbox_workspace_write.network_access=true \
  "Edit @src/queue.py to add thread-safety and run the tests"

# Resume the most recent session
codex exec resume --last "now also add error handling"

# Review uncommitted changes
codex exec review --uncommitted "Focus on security"
```

More patterns by use case: `references/examples.md` and `references/command-patterns.md`.

## File context passing

Pass file paths to Codex; do not embed file contents in the prompt.

- `-C /path` — set working directory.
- `--add-dir /path` — additional readable/writable directory (repeatable).
- `@path/to/file` — explicit file reference inside the prompt.

Details, multi-directory examples, and resolution rules: `references/file-context.md`.

## Errors and troubleshooting

For "command not found", "not authenticated", "model not supported on ChatGPT account", "stdout is not a terminal", network failures in `workspace-write`, and skill-not-triggering issues, see `references/troubleshooting.md`.

Quick reminders:
- `codex --help`, `codex --version`, `codex login`, `codex logout` work without `exec`.
- ChatGPT-account auth supports only `gpt-5.5`. For `gpt-5.5-fast`/`-codex`/`-pro`, use API-key auth.

## Reference index

- `references/session-workflows.md` — continuation decision rules, session-ID tracking, fork workaround, multi-turn examples.
- `references/cli-features.md` — full CLI flag table, interactive-vs-exec differences, `codex review` and `codex apply`, feature flags.
- `references/codex-config.md` — every `-c` key with type and default.
- `references/codex-help.md` — raw `--help` output for `codex`, `codex exec`, `codex review`, `codex exec resume`, etc.
- `references/file-context.md` — passing files, directories, and the `@` syntax.
- `references/examples.md` — full examples by use case (analysis, edit, web search, code review).
- `references/command-patterns.md` — common `codex exec` invocation patterns.
- `references/advanced-patterns.md` — combined flag patterns, profiles, approval policy, multi-phase workflows.
- `references/troubleshooting.md` — error catalog and fixes.
