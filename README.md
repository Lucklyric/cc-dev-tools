# cc-dev-tools

Claude Code marketplace containing development tools and AI integrations for advanced workflows.

## Overview

This marketplace provides Claude Code plugins for enhanced development capabilities through external AI CLI integrations and automation tools.

## Available Plugins

| Plugin | Description | Type |
|--------|-------------|------|
| [Codex](#codex-plugin) | OpenAI GPT-5.1 integration for high-reasoning coding tasks | Skill |
| [Gemini](#gemini-plugin) | Google Gemini AI integration for research and reasoning | Skill |
| [Telegram Notifier](#telegram-notifier-plugin) | Telegram notifications for Claude Code events | Hooks |

---

### Codex Plugin

High-reasoning AI assistant through OpenAI Codex CLI (GPT-5.1) integration.

**Core Features:**
- **High-Reasoning Capabilities**: GPT-5.1 with configurable reasoning effort for complex tasks
- **Intelligent Model Selection**: Automatic selection between general (GPT-5.1) and code editing (GPT-5.1-Codex-Max) models
- **Session Continuation**: Resume previous conversations with `codex exec resume --last`
- **Safe Sandbox Defaults**: Read-only for general tasks, workspace-write for code editing

**Quick Start:**
```bash
codex --version  # Requires v0.59.0+
codex login
```

**Usage:**
```
> Use Codex to design a binary search tree in Rust
```

| Info | Value |
|------|-------|
| Path | [`plugins/codex/`](plugins/codex/) |
| Version | 2.0.1 |
| Models | GPT-5.1, GPT-5.1-Codex-Max, GPT-5.1-Codex |

**Full Documentation**: [Codex Plugin README](plugins/codex/README.md)

---

### Gemini Plugin

Google Gemini AI integration through Gemini CLI for research, reasoning, and web search.

**Core Features:**
- **Automatic Model Selection**: Defaults to Gemini 3 Pro with intelligent fallback to 2.5 models
- **Version-Based Mapping**: User requests like "use 3" automatically map to the latest 3.x model
- **Session Continuation**: Resume previous conversations with `-r latest`
- **Web Search Integration**: Built-in web search for research and documentation lookup

**Quick Start:**
```bash
npm install -g @google/gemini-cli@latest
gemini login
```

**Usage:**
```
> Gemini, explain the observer pattern with examples
```

| Info | Value |
|------|-------|
| Path | [`plugins/gemini/`](plugins/gemini/) |
| Version | 1.4.1 |
| Models | Gemini 3 Pro, 2.5 Pro, 2.5 Flash |

**Full Documentation**: [Gemini Plugin README](plugins/gemini/README.md)

---

### Telegram Notifier Plugin

Receive Telegram notifications when Claude Code completes responses, subagent tasks finish, or system notifications occur.

**Core Features:**
- **Stop Hook**: Notifies when Claude Code completes a response
- **SubagentStop Hook**: Notifies when subagent tasks complete
- **Notification Hook**: Forwards Claude Code system notifications
- **Custom Messages**: Customize notification messages via environment variables
- **Dry-Run Mode**: Test configuration without sending real notifications

**Quick Start:**
```bash
# Set environment variables
export CC_TELEGRAM_BOT_TOKEN="your-bot-token"
export CC_TELEGRAM_CHAT_ID="your-chat-id"
```

**Environment Variables:**

| Variable | Required | Description |
|----------|----------|-------------|
| `CC_TELEGRAM_BOT_TOKEN` | Yes | Bot API token from BotFather |
| `CC_TELEGRAM_CHAT_ID` | Yes | Target chat ID for notifications |
| `CC_TELEGRAM_STOP_MSG` | No | Custom message for Stop events |
| `CC_TELEGRAM_SUBAGENT_MSG` | No | Custom message for SubagentStop events |
| `CC_TELEGRAM_NOTIFY_MSG` | No | Custom message for Notification events |
| `CC_TELEGRAM_DRY_RUN` | No | Set to `true` to log without sending |

| Info | Value |
|------|-------|
| Path | [`plugins/telegram-notifier/`](plugins/telegram-notifier/) |
| Version | 0.1.0 |
| Type | Hooks only (no skills or agents) |

**Full Documentation**: [Telegram Notifier README](plugins/telegram-notifier/README.md)

---

## Installation

### Step 1: Add this marketplace
```bash
/marketplace add https://github.com/Lucklyric/cc-dev-tools
```

### Step 2: Install plugins
```bash
# Install Codex plugin
/plugin install codex@cc-dev-tools

# Install Gemini plugin
/plugin install gemini@cc-dev-tools

# Install Telegram Notifier plugin
/plugin install telegram-notifier@cc-dev-tools
```

### Step 3: Restart Claude Code

## Repository Structure

```
cc-dev-tools/                          # Marketplace root
├── .claude-plugin/
│   └── marketplace.json               # Marketplace metadata
├── README.md                          # This file
├── LICENSE                            # Apache 2.0
└── plugins/
    ├── codex/                         # Codex CLI integration
    │   ├── .claude-plugin/
    │   │   └── plugin.json
    │   ├── README.md
    │   └── skills/codex/
    │       ├── SKILL.md
    │       └── references/
    │
    ├── gemini/                        # Gemini CLI integration
    │   ├── .claude-plugin/
    │   │   └── plugin.json
    │   ├── README.md
    │   └── skills/gemini/
    │       ├── SKILL.md
    │       └── references/
    │
    └── telegram-notifier/             # Telegram notifications
        ├── .claude-plugin/
        │   └── plugin.json
        ├── hooks/
        │   └── hooks.json             # Stop, SubagentStop, Notification hooks
        └── README.md
```

## How It Works

**Three-tier hierarchy**: Marketplace → Plugin → Components (Skills/Hooks)

1. You add the **marketplace** (`cc-dev-tools`) from GitHub
2. You install a **plugin** (e.g., `codex`, `gemini`, or `telegram-notifier`)
3. The plugin provides **components**:
   - **Skills**: Invoked by Claude when triggered (codex, gemini)
   - **Hooks**: Event-driven automation (telegram-notifier)

## Migration from cc-skill-codex

**Repository Renamed**: This repository was renamed from `cc-skill-codex` to `cc-dev-tools` on 2025-11-18.

**For existing clones**, update your remote URL:
```bash
git remote set-url origin git@github.com:Lucklyric/cc-dev-tools.git
```

GitHub automatically redirects the old URL, so existing clones will continue to work.

## Contributing

Contributions welcome! This marketplace follows Claude Code's official plugin structure.

## License

Apache 2.0

## Version

**Marketplace**: 2.0.0

| Plugin | Version |
|--------|---------|
| Codex | 2.0.1 |
| Gemini | 1.4.1 |
| Telegram Notifier | 0.1.0 |

## Links

- **Repository**: https://github.com/Lucklyric/cc-dev-tools
- **Issues**: https://github.com/Lucklyric/cc-dev-tools/issues
- **Author**: 0xasun
