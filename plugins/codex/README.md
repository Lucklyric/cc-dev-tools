# Codex CLI Integration Plugin

OpenAI Codex (GPT-5.2) integration for Claude Code, providing high-reasoning capabilities for complex coding tasks.

## Overview

This plugin enables Claude Code users to invoke OpenAI's Codex CLI with GPT-5.2 models for advanced reasoning, complex implementations, and architectural design. It provides intelligent model selection, session continuation, and safe defaults for seamless integration.

## Features

- **High-Reasoning Capabilities**: GPT-5.2 with xhigh reasoning effort for maximum capability
- **Intelligent Model Selection**: Automatic selection between `gpt-5.3-codex` (coding) and `gpt-5.2` (reasoning) models
- **Session Continuation**: Resume previous conversations with `codex exec resume --last`
- **Safe Sandbox Defaults**: Read-only for general tasks, workspace-write for code editing
- **Web Search Integration**: Built-in web search for research and documentation lookup
- **Non-Interactive Execution**: Optimized for Claude Code's non-terminal bash environment

## Prerequisites

1. **Codex CLI** (v0.104.0 or later)
   ```bash
   # Install Codex CLI (follow OpenAI's installation instructions)
   codex --version  # Should show v0.104.0+
   ```

2. **Authentication**
   ```bash
   codex login
   ```
   Authenticate with your OpenAI account (requires API access)

3. **API Access**
   - OpenAI API key with GPT-5.2 access
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

**Code Editing Tasks (GPT-5.3-Codex)**:
```bash
codex exec -m gpt-5.3-codex -s workspace-write \
  -c model_reasoning_effort=xhigh \
  "Implement thread-safe queue in Python"
```

**General Reasoning Tasks (GPT-5.2)**:
```bash
codex exec -m gpt-5.2 -s read-only \
  -c model_reasoning_effort=xhigh \
  "Design a distributed cache system"
```

### Session Management

```bash
# Start a new session (automatic on first request)
codex exec -m gpt-5.3-codex "Implement authentication system"

# Resume most recent session
codex exec resume --last

# Continue with new prompt in same session
codex exec resume --last "Now implement the login flow"
```

### Advanced Options

**With Web Search**:
```bash
codex exec -m gpt-5.3-codex --enable web_search_request \
  -c model_reasoning_effort=xhigh \
  "Research React 19 Server Components"
```

**Custom Reasoning Effort**:
```bash
codex exec -m gpt-5.2 -c model_reasoning_effort=medium \
  "Explain quicksort algorithm"
```

**Different Sandbox Modes**:
```bash
# Read-only (for reasoning tasks)
codex exec -m gpt-5.2 -s read-only "Review code"

# Workspace-write (for code editing)
codex exec -m gpt-5.3-codex -s workspace-write "Refactor module"

# Full access (advanced users only)
codex exec -m gpt-5.2 -s danger-full-access "Complex task"
```

## Configuration

### Default Settings

| Parameter | Default Value | CLI Flag | Notes |
|-----------|---------------|----------|-------|
| Model (coding) | `gpt-5.3-codex` | `-m gpt-5.3-codex` | Optimized for agentic coding (56.8% SWE-Bench Pro) |
| Model (reasoning) | `gpt-5.2` | `-m gpt-5.2` | High-reasoning general model |
| Sandbox (coding) | `workspace-write` | `-s workspace-write` | Can edit files |
| Sandbox (reasoning) | `read-only` | `-s read-only` | Safe for reviews |
| Reasoning Effort | `xhigh` | `-c model_reasoning_effort=xhigh` | Maximum reasoning capability |
| Web Search | Enabled when appropriate | `--enable web_search_request` | Context-dependent |

### Reasoning Effort Levels

- **xhigh**: Maximum reasoning (default for all tasks)
- **high**: High reasoning
- **medium**: Balanced reasoning and speed
- **low**: Fast responses, less reasoning

## Model Comparison

| Model | Use Case | Sandbox | Reasoning |
|-------|----------|---------|-----------|
| GPT-5.3-Codex | Code editing, implementation, refactoring | workspace-write | xhigh |
| GPT-5.2 | Architecture, design, reviews, analysis | read-only | xhigh |

### Fallback Chain
- **Coding**: `gpt-5.3-codex` → `gpt-5.2`
- **General**: `gpt-5.2` → `gpt-5.3-codex`
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
codex -m gpt-5.2 "prompt"

# CORRECT
codex exec -m gpt-5.2 "prompt"
```

### Session Not Found
```bash
# Check if there are previous sessions
codex exec resume --list

# Start a new session
codex exec -m gpt-5.2 "New task"
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

- **Minimum**: Codex CLI v0.104.0
- **Recommended**: Latest stable version
- **Models**: GPT-5.3-Codex (coding), GPT-5.2 (reasoning)

## When to Use Codex vs Gemini vs Claude

**Use Codex when:**
- You need GPT-5.2's high-reasoning capabilities with xhigh effort
- Complex coding tasks require gpt-5.3-codex (optimized for agentic coding)
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
- GPT-5.2 and GPT-5.3-Codex usage is billed per token
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

2.3.0
