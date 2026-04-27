# Codex CLI Integration Plugin

OpenAI Codex (GPT-5.5) integration for Claude Code, providing high-reasoning capabilities for complex coding tasks.

## Overview

This plugin enables Claude Code users to invoke OpenAI's Codex CLI with GPT-5.5 models for advanced reasoning, complex implementations, and architectural design. It provides intelligent model selection, session continuation, and safe defaults for seamless integration.

## Features

- **High-Reasoning Capabilities**: GPT-5.5 with xhigh reasoning effort for maximum capability
- **Fast Mode**: `gpt-5.5-fast` available on demand for speed-sensitive tasks
- **Session Continuation**: Resume previous conversations with `codex exec resume --last`
- **Safe Sandbox Defaults**: Read-only for general tasks, workspace-write for code editing
- **Web Search Integration**: Built-in web search for research and documentation lookup
- **Non-Interactive Execution**: Optimized for Claude Code's non-terminal bash environment

## Prerequisites

1. **Codex CLI** (v0.125.0 or later) — install via either of the two officially recommended methods from [`openai/codex`](https://github.com/openai/codex):

   ```bash
   # npm (cross-platform)
   npm install -g @openai/codex

   # OR Homebrew (macOS)
   brew install --cask codex

   # Verify
   codex --version  # Should show v0.125.0+
   ```

   To upgrade later, re-run the matching command:
   ```bash
   npm install -g @openai/codex@latest      # npm install
   brew upgrade --cask codex                # Homebrew install
   ```

   Alternative: download a prebuilt binary from the [latest GitHub release](https://github.com/openai/codex/releases/latest), extract, rename to `codex`, and place on `$PATH`.

2. **Authentication**
   ```bash
   codex login
   ```
   ChatGPT-account auth supports `gpt-5.5` only. For `gpt-5.5-fast`/`gpt-5.5-codex`/`gpt-5.5-pro`, log in with an OpenAI API key (`codex logout && codex login --api-key <key>`).

3. **API Access**
   - OpenAI API key (or ChatGPT plan with GPT-5.5 access)
   - Codex CLI API access enabled

## Installation

This plugin is part of the cc-dev-tools marketplace. To install:

1. Add the marketplace:
   ```bash
   /marketplace add https://github.com/Lucklyric/cc-dev-tools
   ```

2. Install the plugin:
   ```bash
   /plugin install codex@cc-dev-tools
   ```

3. Restart Claude Code

## Usage

### Basic Invocation

The skill is automatically invoked when you mention "Codex" or request complex coding assistance:

```
User: "Use Codex to design a binary search tree in Rust"
```

### Model Selection

**Code Editing Tasks (GPT-5.5, network enabled)**:
```bash
codex exec -m gpt-5.5 -s workspace-write \
  -c model_reasoning_effort=xhigh \
  -c sandbox_workspace_write.network_access=true \
  "Implement thread-safe queue in Python"
```

**General Reasoning Tasks (GPT-5.5)**:
```bash
codex exec -m gpt-5.5 -s read-only \
  -c model_reasoning_effort=xhigh \
  "Design a distributed cache system"
```

### Session Management

```bash
# Start a new session (automatic on first request)
codex exec -m gpt-5.5 "Implement authentication system"

# Resume most recent session
codex exec resume --last

# Continue with new prompt in same session
codex exec resume --last "Now implement the login flow"
```

### Advanced Options

**With Web Search** (built-in on supported models, no flag needed in `codex exec`):
```bash
codex exec -m gpt-5.5 \
  -c model_reasoning_effort=xhigh \
  "Research React 19 Server Components"
```

**Workspace-Write with Network Access** (run installers, fetch deps, hit APIs):
```bash
codex exec -m gpt-5.5 -s workspace-write \
  -c model_reasoning_effort=xhigh \
  -c sandbox_workspace_write.network_access=true \
  "Install dependencies and run the test suite"
```

**Custom Reasoning Effort**:
```bash
codex exec -m gpt-5.5 -c model_reasoning_effort=medium \
  "Explain quicksort algorithm"
```

**Different Sandbox Modes**:
```bash
# Read-only (for reasoning tasks)
codex exec -m gpt-5.5 -s read-only "Review code"

# Workspace-write (for code editing)
codex exec -m gpt-5.5 -s workspace-write "Refactor module"

# Full access (advanced users only)
codex exec -m gpt-5.5 -s danger-full-access "Complex task"
```

## Configuration

### Default Settings

| Parameter | Default Value | CLI Flag | Notes |
|-----------|---------------|----------|-------|
| Model | `gpt-5.5` | `-m gpt-5.5` | Frontier reasoning model for all tasks |
| Model (fast) | `gpt-5.5-fast` | `-m gpt-5.5-fast` | Speed-optimized variant (on demand) |
| Sandbox (default) | `read-only` | `-s read-only` | Safe default for reasoning / review |
| Sandbox (coding) | `workspace-write` | `-s workspace-write` | Required for file edits |
| Network access | `enabled` (with `workspace-write`) | `-c sandbox_workspace_write.network_access=true` | Required for `npm`/`pip`/`cargo`/HTTP calls |
| Reasoning Effort | `xhigh` | `-c model_reasoning_effort=xhigh` | Maximum reasoning capability |
| Web Search | built-in | (no flag in `codex exec`) | Native `web_search` tool on supported models |

### Reasoning Effort Levels

- **xhigh**: Maximum reasoning (default for all tasks)
- **high**: High reasoning
- **medium**: Balanced reasoning and speed
- **low**: Fast responses, less reasoning

## Model Comparison

| Model | Use Case | Sandbox | Reasoning |
|-------|----------|---------|-----------|
| GPT-5.5 | All tasks (default) | read-only / workspace-write | xhigh |
| GPT-5.5-Fast | Quick tasks (on demand) | read-only / workspace-write | high |

### Fallback Chain
- **Primary**: `gpt-5.5` → `gpt-5.5-fast`
- **Reasoning effort**: `xhigh` → `high` → `medium`

## Troubleshooting

### CLI Not Installed
```bash
# Check if Codex CLI is installed
codex --version

# If not found, follow OpenAI's installation guide
```

### Authentication Required
```bash
# Authenticate with OpenAI
codex login
```

### "stdout is not a terminal" Error

**Problem**: Using `codex` instead of `codex exec` in non-interactive environment

**Solution**: Always use `codex exec` in Claude Code:
```bash
# WRONG
codex -m gpt-5.5 "prompt"

# CORRECT
codex exec -m gpt-5.5 "prompt"
```

### Session Not Found
```bash
# Check if there are previous sessions
codex exec resume --list

# Start a new session
codex exec -m gpt-5.5 "New task"
```

### API Rate Limits

If you encounter rate limits, check your OpenAI API usage dashboard. The plugin uses high-reasoning models which may have different rate limits.

## Documentation

- **SKILL.md**: Complete skill definition and usage guide
- **references/codex-help.md**: Full CLI reference
- **references/command-patterns.md**: Common command templates
- **references/session-workflows.md**: Multi-turn conversation patterns
- **references/advanced-patterns.md**: Advanced usage patterns
- **references/codex-config.md**: Configuration options

## Version Compatibility

- **Minimum**: Codex CLI v0.125.0
- **Recommended**: Latest stable version
- **Models**: GPT-5.5 (default), GPT-5.5-Fast (on demand)

## When to Use Codex vs Gemini vs Claude

**Use Codex when:**
- You need GPT-5.5's frontier reasoning capabilities with xhigh effort
- Complex coding tasks requiring high-reasoning model
- Architecture and system design with maximum reasoning
- Code reviews requiring deep analysis

**Use Gemini when:**
- You need Google's latest AI models
- Research with web search is important
- Free tier OAuth access (Codex requires API key)
- Creative or general reasoning tasks

**Use Claude (native) when:**
- Simple queries within Claude Code's capabilities
- No external AI needed
- Quick responses preferred

## Rate Limits & Costs

**Note**: Codex CLI uses OpenAI's API, which may have associated costs:
- GPT-5.5 and GPT-5.5-Fast usage is billed per token
- xhigh reasoning effort may consume more tokens
- Check OpenAI's pricing for current rates

## Contributing

This plugin follows the cc-dev-tools marketplace structure:
- Plugin root: `plugins/codex/`
- Metadata: `.claude-plugin/plugin.json`
- Skill definition: `skills/codex/SKILL.md`
- References: `skills/codex/references/`

## License

Apache-2.0

## Author

0xasun

## Repository

https://github.com/Lucklyric/cc-dev-tools

## Version

2.11.0
