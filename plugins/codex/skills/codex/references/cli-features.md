# Codex CLI Features Reference

**Codex CLI Version**: 0.114.0+

This document provides a comprehensive reference for Codex CLI features and flags.

## CLI Flags Quick Reference

| Flag | Values | Description |
|------|--------|-------------|
| `-m, --model` | `gpt-5.4`, `gpt-5.4-fast` | Model selection |
| `-s, --sandbox` | `read-only`, `workspace-write`, `danger-full-access` | Sandbox mode |
| `-c, --config` | `key=value` | Config overrides (e.g., `model_reasoning_effort=xhigh`) |
| `-C, --cd` | directory path | Working directory |
| `-p, --profile` | profile name | Use config profile |
| `--enable` | feature name | Enable a feature (e.g., `web_search_request`) |
| `--disable` | feature name | Disable a feature |
| `-i, --image` | file path(s) | Attach image(s) to initial prompt |
| `--add-dir` | directory path | Additional writable directory (repeatable) |
| `--full-auto` | flag | Convenience for workspace-write sandbox with on-request approval |
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

## Full Auto Mode (`--full-auto`)

Convenience flag for low-friction execution:

```bash
codex exec --full-auto "task"
# Equivalent to: -s workspace-write with on-request approval
```

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

**Note (v0.114.0+)**: The `web_search_request` feature flag is **deprecated**. Web search is now built-in when the model supports it. No `--enable` flag is needed.

```bash
# v0.114.0+ - web search is automatic, no flag needed
codex exec -m gpt-5.4 "research latest patterns"

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
