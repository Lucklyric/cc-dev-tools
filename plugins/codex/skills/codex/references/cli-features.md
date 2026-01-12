# Codex CLI Features Reference

This document provides a comprehensive reference for Codex CLI features and flags.

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

## Web Search in Exec Mode

**Note**: `--search` flag is interactive-only. Use `--enable` for exec mode:

```bash
# CORRECT for codex exec
codex exec --enable web_search_request "research topic"

# WRONG - --search only works in interactive mode
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
| `web_search_request` | false | Enable web search capability |
| `parallel` | true | Parallel execution |
| `shell_tool` | true | Shell command execution |
| `undo` | true | Undo functionality |
| `view_image_tool` | true | Image viewing capability |
| `warnings` | true | Display warnings |

### Experimental/Beta Features

| Feature | Stage | Default | Description |
|---------|-------|---------|-------------|
| `exec_policy` | experimental | true | Execution policy control |
| `remote_compaction` | experimental | true | Remote compaction |
| `unified_exec` | experimental | false | Unified execution mode |
| `rmcp_client` | experimental | false | RMCP client support |
| `apply_patch_freeform` | beta | false | Freeform patch application |
| `skills` | experimental | false | Skills support |
| `shell_snapshot` | experimental | false | Shell state snapshots |
| `remote_models` | experimental | false | Remote model support |

Enable/disable features with `--enable` and `--disable`:

```bash
codex exec --enable web_search_request "research task"
codex exec --disable parallel "run sequentially"
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
