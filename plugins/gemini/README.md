# Gemini CLI Integration Plugin

Google Gemini AI integration for Claude Code, providing access to Gemini's advanced models through a local CLI.

## Overview

This plugin enables Claude Code users to invoke Google's Gemini AI models for complex reasoning tasks, research, and development assistance. It provides intelligent model selection, session continuation, and safe defaults for seamless integration.

## Features

- **Unified Model Selection**: Defaults to Gemini 3.1 Pro for ALL tasks (coding and reasoning)
- **Version-Based Mapping**: User requests like "use 3" automatically map to the latest 3.x model
- **Session Continuation**: Resume previous conversations with `-r latest` or `-r <index>`
- **Safe Defaults**: Auto-edit approval mode and disabled sandbox for trusted environments
- **Extensions Support**: Built-in web search and MCP server integration
- **Headless Execution**: Optimized for Claude Code's non-interactive bash environment

## Prerequisites

1. **Gemini CLI** (v0.29.5 or later)
   ```bash
   npm install -g @google/gemini-cli@latest
   ```

2. **Authentication**
   ```bash
   gemini login
   ```
   Authenticate via OAuth (personal Google account) or API key

3. **Gemini 3.1 Pro Access** (Optional)
   - Google AI Ultra subscription
   - Paid Gemini API key
   - Vertex API key with Gemini 3 access
   - Waitlist approval + Preview Features enabled

## Important: Preview Features & Headless Mode

**If you're using OAuth free tier**, there's a known issue with preview features in headless mode:

### The Issue

When `previewFeatures: true` in `~/.gemini/settings.json`, Gemini CLI automatically routes **all** requests to Gemini 3.1 Pro, even when you explicitly request `-m gemini-2.5-pro`. Since free tier OAuth accounts don't have Gemini 3.1 Pro access, this causes **404 "Requested entity was not found"** errors.

### The Solution

**Option 1: Disable Preview Features (Recommended for Headless)**

Edit `~/.gemini/settings.json`:
```json
{
  "general": {
    "previewFeatures": false
  }
}
```

**Option 2: Use Gemini 2.5 Flash (Always Works)**

The plugin automatically falls back to `gemini-2.5-flash` when other models are unavailable. Flash always works with free tier OAuth.

### Unified Fallback Strategy

This plugin implements a three-step fallback chain for ALL tasks:

1. **Try Gemini 3.1 Pro** (`gemini-3.1-pro-preview`) - Primary for all tasks
2. **Fallback to Gemini 2.5 Pro** (`gemini-2.5-pro`) - If 3 Pro unavailable
3. **Fallback to Gemini 2.5 Flash** (`gemini-2.5-flash`) - Always works

If you see 404 errors, the plugin will automatically retry with the next fallback. To prevent this issue, disable preview features as shown above.

## Installation

This plugin is part of the cc-dev-tools marketplace. To install:

1. Add the marketplace:
   ```bash
   /marketplace add https://github.com/Lucklyric/cc-dev-tools
   ```

2. Install the plugin:
   ```bash
   /plugin install gemini@cc-dev-tools
   ```

3. Restart Claude Code

## Usage

### Basic Invocation

The skill is automatically invoked when you mention "Gemini" or request Gemini assistance:

```
User: "Gemini, design a microservices architecture for e-commerce"
```

### Model Selection

**Default (Gemini 3.1 Pro for ALL tasks)**:
```bash
gemini -m gemini-3.1-pro-preview "Design a distributed cache"
```

**Code Editing (Also uses Gemini 3.1 Pro)**:
```bash
gemini -m gemini-3.1-pro-preview "Refactor this function"
```

**Version-Based Requests**:
- "use 3" → `gemini-3.1-pro-preview`
- "use 2.5" → `gemini-2.5-pro`
- "use flash" → `gemini-2.5-flash`

### Session Management

```bash
# List sessions
gemini --list-sessions

# Resume most recent
gemini -r latest

# Resume specific session
gemini -r 3

# Continue with new prompt
gemini -r latest "Continue our discussion about caching"
```

### Advanced Options

**With Web Search**:
```bash
gemini -m gemini-3.1-pro-preview -e web_search "Research React 19 features"
```

**With Sandbox**:
```bash
gemini -m gemini-2.5-pro -s "Analyze suspicious code"
```

**JSON Output**:
```bash
gemini -m gemini-2.5-pro --output-format json "List design patterns"
```

## Configuration

### Default Settings

| Parameter | Default | Override |
|-----------|---------|----------|
| Model | `gemini-3.1-pro-preview` | `-m <model>` |
| Approval Mode | `auto_edit` | `--approval-mode <mode>` |
| Sandbox | `false` | `-s` |
| Output Format | `text` | `--output-format <format>` |
| Extensions | All enabled | `-e <extensions>` |

### Approval Modes

- **default**: Prompt for all tool actions
- **auto_edit**: Auto-approve edit operations only (recommended)
- **plan**: Read-only mode - no file modifications allowed
- **yolo** (`-y`): Auto-approve all actions (use with caution)

## Rate Limits

**Free Tier (OAuth)**:
- 60 requests per minute
- 1,000 requests per day
- 1M token context window (Gemini 2.5 Pro)

**Gemini 3.1 Pro**:
- May have stricter quotas
- Automatic fallback to 2.5 models when exhausted

## Model Comparison

| Model | Use Case | Context | Speed | Access |
|-------|----------|---------|-------|--------|
| Gemini 3.1 Pro | ALL tasks (default) | 1M tokens | Medium | Preview |
| Gemini 2.5 Pro | Fallback for all tasks | 1M tokens | Fast | Free |
| Gemini 2.5 Flash | Last resort fallback | Unknown | Fastest | Free |

**Note**: Gemini 3.1 Pro is used for ALL tasks by default. Fallback to older models only when primary is unavailable.

## Troubleshooting

### CLI Not Installed
```bash
npm install -g @google/gemini-cli@latest
```

### Authentication Required
```bash
gemini login
```

### Rate Limit Exceeded
Wait for reset or upgrade to paid tier

### Gemini 3.1 Pro Unavailable
- Enable Preview Features in settings
- Or use fallback: `gemini-2.5-pro`

### Session Not Found
```bash
gemini --list-sessions  # Check available sessions
```

## Documentation

- **SKILL.md**: Complete skill definition and usage guide
- **references/gemini-help.md**: Full CLI reference
- **references/command-patterns.md**: Common command templates
- **references/session-workflows.md**: Multi-turn conversation patterns
- **references/model-selection.md**: Model selection decision tree

## Version Compatibility

- **Minimum**: Gemini CLI v0.29.5
- **Recommended**: Latest stable version
- **Breaking Changes**: `-p` flag deprecated (use positional prompts)

## When to Use Gemini vs Codex vs Claude

**Use Gemini when:**
- You need Google's latest AI models
- Research with web search is important
- You prefer Google's AI capabilities
- Codex is unavailable or rate-limited

**Use Codex when:**
- You need GPT-5.2's high-reasoning capabilities
- Complex coding tasks require GPT-5.3-Codex

**Use Claude (native) when:**
- Simple queries within Claude Code's capabilities
- No external AI needed

## Contributing

This plugin follows the cc-dev-tools marketplace structure:
- Plugin root: `plugins/gemini/`
- Metadata: `.claude-plugin/plugin.json`
- Skill definition: `skills/gemini/SKILL.md`
- References: `skills/gemini/references/`

## License

Apache-2.0

## Version

1.4.0

## Author

0xasun

## Repository

https://github.com/Lucklyric/cc-dev-tools
