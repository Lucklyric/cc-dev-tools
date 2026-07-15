# Codex CLI Features Reference

**Codex CLI Version**: 0.144.0+ (required for the GPT-5.6 series)

This document provides a comprehensive reference for Codex CLI features and flags.

## CLI Flags Quick Reference

| Flag | Values | Description |
|------|--------|-------------|
| `-m, --model` | `gpt-5.6-sol` (default), `gpt-5.6-terra`, `gpt-5.6-luna`, `gpt-5.5`; `-fast` tiers (API-key auth) | Model selection |
| `-s, --sandbox` | `read-only`, `workspace-write`, `danger-full-access` | Sandbox mode |
| `-c, --config` | `key=value` | Config overrides (e.g., `model_reasoning_effort=xhigh`) |
| `-C, --cd` | directory path | Working directory |
| `-p, --profile` | profile name | Use config profile |
| `--enable` | feature name | Enable a feature (e.g., `web_search_request`) |
| `--disable` | feature name | Disable a feature |
| `-i, --image` | file path(s) | Attach image(s) to initial prompt |
| `--add-dir` | directory path | Additional writable directory (repeatable) |
| `--full-auto` | REMOVED (≤0.144.x) | Use `-s workspace-write -c approval_policy=on-request` instead (the helper script's own `--full-auto` flag still exists and maps to exactly that) |
| `--oss` | flag | Use local open source model provider |
| `--local-provider` | `lmstudio`, `ollama` | Specify local provider (with --oss) |
| `--no-alt-screen` | flag | Disable alternate screen mode (useful in Zellij) |
| `--ephemeral` | flag | Run without persisting session files to disk |
| `--skip-git-repo-check` | flag | Allow running outside Git repository |
| `--output-schema` | file path | JSON Schema file for response shape |
| `--color` | `always`, `never`, `auto` | Color settings for output |
| `--json` | flag | Print events as JSONL |
| `-o, --output-last-message` | file path | Save last message to file |
| `--dangerously-bypass-approvals-and-sandbox` | flag | Skip confirmations (DANGEROUS) |

## Feature Flags (`--enable` / `--disable`)

Enable or disable specific Codex features:

```bash
codex exec --enable web_search_request "Research latest patterns"
codex exec --disable some_feature "Run without feature"
```

## Image Attachment (`-i, --image`)

Attach images to prompts for visual analysis:

```bash
codex exec -i screenshot.png "Analyze this UI design"
codex exec -i diagram1.png -i diagram2.png "Compare these architectures"
```

## Additional Directories (`--add-dir`) (v0.71.0+)

Add writable directories beyond the primary workspace:

```bash
codex exec --add-dir /shared/libs --add-dir /config "task"
```

## Full Auto Mode (flag removed from the CLI)

The codex CLI's `--full-auto` flag has been REMOVED (absent from `codex --help` and `codex exec --help` as of 0.144.4). Use the explicit form:

```bash
codex exec -s workspace-write -c approval_policy=on-request "task"
```

Note: the PLUGIN's helper script (`codex-tmux.sh pane/bind/new --full-auto`) keeps its own `--full-auto` flag as a convenience name — it expands to the explicit form above and never passes `--full-auto` to codex.

## Non-Git Environments (`--skip-git-repo-check`)

Run Codex outside Git repositories:

```bash
codex exec --skip-git-repo-check "Help with this script"
```

## Structured Output (`--output-schema`)

Define JSON schema for model responses:

```bash
codex exec --output-schema schema.json "Generate structured data"
```

## Output Coloring (`--color`)

Control colored output (always, never, auto):

```bash
codex exec --color never "Run in CI/CD pipeline"
```

## Web Search

**Note (v0.125.0+)**: The `web_search_request` feature flag is **deprecated**. Web search is now built-in when the model supports it. No `--enable` flag is needed.

```bash
# v0.125.0+ - web search is automatic, no flag needed
codex exec -m gpt-5.6-sol "research latest patterns"

# Interactive mode still supports --search flag
codex --search "research topic"
```

## Feature Flags List (`codex features list`) (v0.71.0+)

Inspect and manage Codex feature flags:

```bash
# List all feature flags with their states
codex features list
```

### Stable Features

| Feature | Default | Description |
|---------|---------|-------------|
| `enable_request_compression` | true | Request compression |
| `fast_mode` | true | Fast mode |
| `personality` | true | Personality customization |
| `shell_snapshot` | true | Shell state snapshots |
| `shell_tool` | true | Shell command execution |
| `skill_mcp_dependency_install` | true | Auto-install MCP skill dependencies |
| `unified_exec` | true | Unified execution mode |
| `undo` | false | Undo functionality |

### Experimental Features

| Feature | Stage | Default | Description |
|---------|-------|---------|-------------|
| `guardian_approval` | experimental | false | Guardian approval system |
| `js_repl` | experimental | false | JavaScript REPL |
| `multi_agent` | experimental | false | Multi-agent support |
| `prevent_idle_sleep` | experimental | false | Prevent system idle sleep |

### Deprecated Features

| Feature | Description |
|---------|-------------|
| `web_search_request` | Web search (now built-in, no flag needed) |
| `web_search_cached` | Cached web search (now built-in) |

Enable/disable features with `--enable` and `--disable`:

```bash
codex exec --enable multi_agent "complex task"
codex exec --disable fast_mode "run in standard mode"
```

## JSONL Output (`--json`) (v0.71.0+)

Stream events as JSONL for programmatic processing:

```bash
codex exec --json "task" > events.jsonl
```

## Save Last Message (`-o/--output-last-message`) (v0.71.0+)

Write the final agent message to a file:

```bash
codex exec -o result.txt "generate summary"
```

---

## Interactive vs Exec Mode Flags

Some Codex CLI flags are ONLY available in interactive `codex` mode, NOT in `codex exec`.

| Flag | Interactive `codex` | `codex exec` | Alternative for exec |
|------|---------------------|--------------|---------------------|
| `--search` | ✅ Available | ❌ NOT available | Web search is built-in (no flag needed) |
| `-a/--ask-for-approval` | ✅ Available | ❌ NOT available | `-c approval_policy=...` |
| `--add-dir` | ✅ Available | ✅ Available | N/A |
| `--full-auto` | ❌ REMOVED | ❌ REMOVED | `-s workspace-write -c approval_policy=on-request` |

For approval control in exec mode:

```bash
# CORRECT - works in codex exec
codex exec -c approval_policy=on-request "task"
codex exec -s workspace-write -c approval_policy=on-request "task"

# WRONG - -a only works in interactive mode
codex -a on-request "task"
```

---

## Code Review Subcommand

The `codex review` subcommand runs a code review **non-interactively** — it is safe in Claude Code's non-TTY bash (the "always use `codex exec`" rule applies to plain `codex`, not to `codex review`). Canonical form is the top-level `codex review ...` (an equivalent `codex exec review ...` form exists; prefer the top-level one):

```bash
# Review uncommitted changes (staged, unstaged, untracked)
codex review --uncommitted

# Review changes against a base branch
codex review --base main

# Review a specific commit
codex review --commit abc123

# Review with custom instructions
codex review --uncommitted "Focus on security vulnerabilities"
```

Model: review uses the codex config's `review_model` (NOT the plugin's `CC_CODEX_MODEL`/`CC_CODEX_EFFORT`); pin per call with `-c review_model="gpt-5.6-sol"`.

| Flag | Description |
|------|-------------|
| `--uncommitted` | Review staged, unstaged, and untracked changes |
| `--base <BRANCH>` | Review changes against the given base branch |
| `--commit <SHA>` | Review the changes introduced by a commit |
| `--title <TITLE>` | Optional commit title for review summary |

---

## Apply Command (v0.98.0+)

The `codex apply` command applies the latest diff produced by the Codex agent as a `git apply` to the local working tree:

```bash
# Apply the latest diff from Codex
codex apply
```

Useful when Codex generates changes in read-only mode and the user wants to apply them locally.

## Interactive flags reachable via tmux mode

Interactive-only flags (`--search`, `-a/--ask-for-approval`) are unreachable from `codex exec` (non-interactive) and plain `codex` fails in Claude Code's bash (`stdout is not a terminal`). The default tmux flow (`pane`, or the `bind`/`new` fallbacks) launches interactive `codex` inside a tmux pane, which provides a PTY — interactive features are reached there via codex's own slash commands (e.g. `/search`), sent with the interaction recipes in `tmux-mode.md`. The `-a` flag is superseded by `approval_policy=on-request`, which the helper sets automatically on every spawn.
