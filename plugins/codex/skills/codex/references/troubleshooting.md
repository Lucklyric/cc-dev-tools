# Codex Skill — Errors and Troubleshooting

> **Scope.** This catalog focuses on `codex exec` (one-shot / legacy) failure modes. For tmux-mode operational issues (`detect-idle` false-positives, ready-regex calibration, scrollback limits, hung TUI), see `tmux-mode.md` § Troubleshooting.

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

Verify: codex --version  (require v0.144.0+ for the GPT-5.6 series)
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
- Use 'gpt-5.6-sol' (default) — or 'gpt-5.6-terra'/'gpt-5.6-luna' for cost/speed
- '-fast' tiers (e.g. 'gpt-5.6-sol-fast') are API-key auth only

Example: codex exec -m gpt-5.6-sol -s workspace-write \
  -c model_reasoning_effort=xhigh \
  -c sandbox_workspace_write.network_access=true \
  "implement feature"
Example (fast): codex exec -m gpt-5.6-sol-fast -s read-only "quick analysis"
```

### Model Not Supported on ChatGPT Account

The `-fast` service-tier variants (e.g. `gpt-5.6-sol-fast`) return:

```
The 'gpt-5.6-sol-fast' model is not supported when using Codex with a ChatGPT account.
```

The base 5.6 slugs (`gpt-5.6-sol`, `gpt-5.6-terra`, `gpt-5.6-luna`) and `gpt-5.5` DO work under ChatGPT-account auth. Only the `-fast` speed tier needs API-key auth.

To use a `-fast` variant: log out and log in with an OpenAI API key on a tier with access:

```
codex logout
codex login --api-key <key>
```

Otherwise, drop the `-fast` suffix (use `gpt-5.6-sol`) or lower the reasoning effort for speed.

### Model Requires a Newer Version of Codex

The 5.6 series requires codex CLI **≥ 0.144.0**. On an older CLI:

```
The 'gpt-5.6-sol' model requires a newer version of Codex. Please upgrade to the latest app or CLI and try again.
```

To fix: upgrade codex (`npm install -g @openai/codex@latest` or `brew upgrade --cask codex`), or set `CC_CODEX_MODEL=gpt-5.5` to keep using the prior model on the current CLI.

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
- Exception: `codex review` is itself non-interactive and safe without a TTY — this rule applies to plain interactive `codex`, not to `codex review`.

### Errors during execution

- Codex CLI errors are passed through directly.
- Check Codex CLI logs for detailed diagnostics.
- Verify working directory permissions when using `workspace-write`.
- Confirm `sandbox_workspace_write.network_access=true` is set if the failure mentions blocked HTTP / DNS.
- Check official Codex docs for latest updates and known issues.
