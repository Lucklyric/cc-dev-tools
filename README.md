# cc-dev-tools

Claude Code marketplace containing development tools and AI integrations for advanced workflows.

## Overview

This marketplace provides Claude Code plugins for enhanced development capabilities through external AI CLI integrations.

## Available Plugins

### Codex Plugin

High-reasoning AI assistant through Codex CLI (GPT-5.1) integration.

- **Path**: [`plugins/codex/`](plugins/codex/)
- **Version**: 1.5.0
- **Models**: GPT-5.1, GPT-5.1-Codex-Max, GPT-5.1-Codex
- **Documentation**: [Codex Plugin README](plugins/codex/README.md)
- **Skill Reference**: [SKILL.md](plugins/codex/skills/codex/SKILL.md)

**Features**:
- **Custom Agent**: `codex-agent` for explicit task delegation via Task tool
- Maximum capability code editing with GPT-5.1-Codex-Max (27-42% faster)
- High-reasoning capabilities for complex coding tasks
- Intelligent model selection (general vs code editing)
- Session continuation support
- Safe sandbox defaults

### Gemini Plugin

Google Gemini AI integration through Gemini CLI.

- **Path**: [`plugins/gemini/`](plugins/gemini/)
- **Version**: 1.1.0
- **Models**: Gemini 3 Pro, 2.5 Pro, 2.5 Flash
- **Documentation**: [Gemini Plugin README](plugins/gemini/README.md)
- **Skill Reference**: [SKILL.md](plugins/gemini/skills/gemini/SKILL.md)

**Features**:
- **Custom Agent**: `gemini-agent` for explicit task delegation via Task tool
- Access to Google's latest Gemini models
- Version-based model mapping
- Session continuation via `-r` flag
- Automatic fallback for OAuth free tier
- Web search integration

## Quick Start

### Prerequisites

**For Codex Plugin:**
```bash
codex --version  # v0.59.0+ (required for gpt-5.1-codex-max)
codex login
```

**For Gemini Plugin:**
```bash
npm install -g @google/gemini-cli@latest
gemini login
```

### Installation

**Step 1**: Add this marketplace
```bash
/marketplace add https://github.com/Lucklyric/cc-dev-tools
```

**Step 2**: Install plugins
```bash
# Install Codex plugin
/plugin install codex@cc-dev-tools

# Install Gemini plugin
/plugin install gemini@cc-dev-tools
```

**Step 3**: Restart Claude Code

### Usage

**Codex Example:**
```
> Use Codex to design a binary search tree in Rust
```

**Gemini Example:**
```
> Gemini, explain the observer pattern with examples
```

## Repository Structure

```
cc-dev-tools/                          # Marketplace root
├── .claude-plugin/
│   └── marketplace.json               # Marketplace metadata
├── README.md                          # This file
├── LICENSE                            # Apache 2.0
└── plugins/                           # Plugins directory
    ├── codex/                         # Codex CLI integration
    │   ├── .claude-plugin/
    │   │   └── plugin.json            # Plugin manifest
    │   ├── agents/                    # Custom agents
    │   │   └── codex-agent.md         # Routing agent for codex skill
    │   ├── README.md                  # Plugin documentation
    │   └── skills/codex/
    │       ├── SKILL.md               # Skill definition
    │       └── references/            # Reference docs
    │
    └── gemini/                        # Gemini CLI integration
        ├── .claude-plugin/
        │   └── plugin.json            # Plugin manifest
        ├── agents/                    # Custom agents
        │   └── gemini-agent.md        # Routing agent for gemini skill
        ├── README.md                  # Plugin documentation
        └── skills/gemini/
            ├── SKILL.md               # Skill definition
            └── references/            # Reference docs
```

## Migration from cc-skill-codex

**Repository Renamed**: This repository was renamed from `cc-skill-codex` to `cc-dev-tools` on 2025-11-18.

**For existing clones**, update your remote URL:
```bash
git remote set-url origin git@github.com:Lucklyric/cc-dev-tools.git
```

GitHub automatically redirects the old URL, so existing clones will continue to work.

## How It Works

**Three-tier hierarchy**: Marketplace → Plugin → Skill

1. You add the **marketplace** (`cc-dev-tools`) from GitHub
2. You install a **plugin** (e.g., `codex` or `gemini`) from the marketplace
3. The plugin provides a **skill** that Claude Code loads automatically
4. When triggered, the skill executes commands via the respective CLI

## Contributing

Contributions welcome! This marketplace follows Claude Code's official plugin structure.

## License

Apache 2.0

## Version

**Marketplace**: 1.2.0
**Plugins**:
- Codex: 1.5.0
- Gemini: 1.1.0

## Links

- **Repository**: https://github.com/Lucklyric/cc-dev-tools
- **Issues**: https://github.com/Lucklyric/cc-dev-tools/issues
- **Author**: 0xasun
