# cc-dev-tools

Claude Code marketplace containing development tools and AI integrations for advanced workflows.

## Overview

This marketplace provides Claude Code plugins for enhanced development capabilities:

- **Codex**: High-reasoning AI assistant for complex coding tasks, architecture, and reviews
- *(More plugins coming soon)*

## Plugins

### Codex

High-reasoning AI assistant through Codex CLI integration.

- **Path**: `plugins/codex/`
- **Version**: 1.3.0
- **Documentation**: [plugins/codex/skills/codex/SKILL.md](plugins/codex/skills/codex/SKILL.md)

## Migration from cc-skill-codex

**Repository Renamed**: This repository was renamed from `cc-skill-codex` to `cc-dev-tools` on 2025-11-18.

**For existing clones**, update your remote URL:
```bash
git remote set-url origin git@github.com:Lucklyric/cc-dev-tools.git
```

GitHub automatically redirects the old URL, so existing clones will continue to work.

---

## About the Codex Plugin

A Claude Code **plugin** that provides a skill for seamless Codex CLI integration with high-reasoning capabilities.

## What is this?

**cc-dev-tools** is a Claude Code **marketplace** that contains development tool plugins. Currently includes:

- **codex plugin**: Provides the `codex` skill for seamless Codex CLI integration

**Identifiers**:
- **Marketplace name**: `cc-dev-tools`
- **Plugin name**: `codex`
- **Full plugin identifier**: `codex@cc-dev-tools`
- **Skill name**: `codex`
- **Installation**: Via Claude Code marketplace (installs the plugin, which includes the skill)

## Repository Structure

```
cc-dev-tools/                          # Marketplace root
├── .claude-plugin/
│   └── marketplace.json               # Marketplace metadata
├── README.md                          # This file - installation and usage guide
├── LICENSE                            # Apache 2.0 license
└── plugins/                           # Plugins directory
    └── codex/                         # The "codex" plugin
        ├── .claude-plugin/
        │   └── plugin.json            # Plugin manifest
        └── skills/                    # Skills provided by this plugin
            └── codex/                 # The "codex" skill
                ├── SKILL.md           # Skill definition (loaded by Claude Code)
                └── references/        # Reference documentation
                    ├── advanced-patterns.md
                    ├── codex-config.md
                    ├── codex-help.md
                    ├── command-patterns.md
                    └── session-workflows.md
```

**How it works**:
1. You add the **marketplace** (`cc-dev-tools`) from GitHub
2. You install the **plugin** (`codex`) from the marketplace
3. The plugin provides the **skill** (`codex`)
4. Claude Code loads `plugins/codex/skills/codex/SKILL.md` when the skill is invoked
5. All other files are documentation for users

**Three-tier hierarchy**: Marketplace → Plugin → Skill

---

## Installation in Claude Code

### Prerequisites

1. **Codex CLI** installed and authenticated:
   ```bash
   codex --version  # v0.58+
   codex login
   ```

2. **Claude Code** v1.0+

### Install Plugin from GitHub

**Step 1**: Add this repository as a dev marketplace:

```bash
/marketplace add https://github.com/Lucklyric/cc-dev-tools
```

**Step 2**: Install the plugin from the marketplace:

```bash
/plugin install codex@cc-dev-tools
```

This installs the **codex plugin**, which includes the **codex skill**.

**Step 3**: Restart Claude Code to activate the plugin and skill.

### Verify Installation

Test that the skill is working:
```
> Use Codex to design a binary search tree in Rust
```

The skill will automatically invoke Codex CLI with high-reasoning mode.

---

## Step-by-Step Tutorial

### Step 1: Install Prerequisites

```bash
# Check if Codex CLI is installed
codex --version

# If not installed, install it from OpenAI
# (Follow OpenAI's installation instructions)

# Authenticate with your OpenAI account
codex login
```

### Step 2: Add the Marketplace

In your Claude Code session, add the GitHub repository as a marketplace:

```bash
/marketplace add https://github.com/Lucklyric/cc-dev-tools
```

This registers the marketplace so Claude Code knows where to find the plugin.

### Step 3: Install the Plugin

Install the plugin from the marketplace you just added:

```bash
/plugin install codex@cc-dev-tools
```

This installs the **codex plugin** and makes the **codex skill** available.

**Note**: The full identifier is `codex@cc-dev-tools` where:
- `codex` = plugin name
- `cc-dev-tools` = marketplace name

Then restart Claude Code.

### Step 4: Test Basic Usage

**Simple request** (uses default model for general reasoning):
```
> Help me design a priority queue in Python
```

Claude will:
1. Detect this is a coding task
2. Invoke the skill automatically
3. Execute: `codex exec -m gpt-5.1 -s read-only -c model_reasoning_effort=high "Help me design..."`
4. Return Codex's high-reasoning response

### Step 5: Try Code Editing

**Code editing request** (uses code-optimized model):
```
> Edit my queue.py file to add thread-safety
```

Claude will:
1. Detect this is a code editing task
2. Use code-optimized model
3. Execute: `codex exec -m gpt-5.1-codex -s workspace-write -c model_reasoning_effort=high "Edit my queue.py..."`

### Step 6: Continue a Session

**Follow-up request**:
```
> Continue with that - add unit tests
```

Claude will:
1. Detect continuation context
2. Execute: `codex exec resume --last`
3. Continue from previous session

### Step 7: Explicit Codex Request

**Direct invocation**:
```
> Use Codex to review this code for security issues
```

Mentioning "Codex" explicitly triggers the skill.

---

## Quick Tips

- **Trigger keywords**: "codex", "use codex", "complex coding", "high reasoning"
- **Model selection**: Intelligent model selection based on task type (general vs code editing)
- **Session continuity**: Use "continue", "resume", "add to that" for session continuation
- **All commands use**: `codex exec` (non-interactive mode) in Claude Code environment

---

**License**: Apache 2.0
**Version**: 1.3.0
