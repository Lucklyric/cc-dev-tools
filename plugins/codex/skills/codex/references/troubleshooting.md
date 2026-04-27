# Codex Skill — Errors and Troubleshooting

Reference for diagnosing problems when invoking Codex CLI from Claude Code.

## Error Response Strategy

Return clear, actionable messages without complex diagnostics:

```
Error: [Clear description of what went wrong]

To fix: [Concrete remediation action]

[Optional: Specific command example]
```

## Common Errors

### Command Not Found

```
Error: Codex CLI not found

To fix: Install via either of the two officially recommended methods —
  npm install -g @openai/codex
  brew install --cask codex   (macOS)

To upgrade an existing install:
  npm install -g @openai/codex@latest
  brew upgrade --cask codex

Verify: codex --version  (require v0.125.0+)
Source of truth: https://github.com/openai/codex
```

### Authentication Required

```
Error: Not authenticated with Codex

To fix: Run 'codex login' to authenticate

After authentication, retry the request.
```

### Invalid Configuration

```
Error: Invalid model specified

To fix:
- Use 'gpt-5.5' for all tasks
- Use 'gpt-5.5-fast' for speed-sensitive tasks (API-key auth only)

Example: codex exec -m gpt-5.5 -s workspace-write \
  -c model_reasoning_effort=xhigh \
  -c sandbox_workspace_write.network_access=true \
  "implement feature"
Example (fast): codex exec -m gpt-5.5-fast -s read-only "quick analysis"
```

### Model Not Supported on ChatGPT Account

Variants such as `gpt-5.5-pro`, `gpt-5.5-codex`, and `gpt-5.5-fast` return:

```
The 'gpt-5.5-pro' model is not supported when using Codex with a ChatGPT account.
```

To fix: log out and log in with an OpenAI API key on a tier with access to the model:

```
codex logout
codex login --api-key <key>
```

Otherwise, fall back to `gpt-5.5`.

## Troubleshooting

### First Steps

1. Check Codex CLI built-in help: `codex --help`, `codex exec --help`, `codex exec resume --help`
2. Consult the official docs: https://github.com/openai/codex/tree/main/docs
3. Verify skill resources in the `references/` directory.

Commands like `codex --help`, `codex --version`, `codex login`, and `codex logout` work without the `exec` subcommand. The `exec` requirement only applies to task execution.

### Skill not being invoked?

- Check that the request matches trigger keywords (Codex, complex coding, high reasoning, etc.)
- Explicitly mention "Codex" in the request.
- Try: "Use Codex to help me with..."

### Session not resuming?

- Verify a previous Codex session exists (check command output for session IDs).
- Try: `codex exec resume --last` to resume the most recent session.
- If no history exists, start a new session first.

### "stdout is not a terminal" error

- Always use `codex exec` instead of plain `codex` in Claude Code.
- Claude Code's bash environment is non-interactive/non-terminal.

### Errors during execution

- Codex CLI errors are passed through directly.
- Check Codex CLI logs for detailed diagnostics.
- Verify working directory permissions when using `workspace-write`.
- Confirm `sandbox_workspace_write.network_access=true` is set if the failure mentions blocked HTTP / DNS.
- Check official Codex docs for latest updates and known issues.
