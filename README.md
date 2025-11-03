# cc-skill-codex

A Claude Code **plugin** that provides a skill for seamless OpenAI Codex CLI integration with GPT-5 high-reasoning capabilities.

## What is this?

**cc-skill-codex** is a Claude Code **plugin** that contains the **codex skill**. When you install this plugin, you get access to the skill that enables Codex CLI integration.

- **Marketplace name**: `cc-skill-codex-marketplace`
- **Plugin name**: `cc-skill-codex`
- **Full plugin identifier**: `cc-skill-codex@cc-skill-codex-marketplace`
- **Skill name**: `codex`
- **Installation**: Via Claude Code marketplace (installs the plugin, which includes the skill)

## Repository Structure

```
cc-skill-codex/                  # Plugin root
├── .claude-plugin/              # Plugin metadata
│   ├── plugin.json             # Plugin configuration
│   └── marketplace.json        # Marketplace configuration
├── README.md                    # This file - installation and usage guide
├── LICENSE                      # Apache 2.0 license
└── skills/                      # Skills provided by this plugin
    └── codex/                  # The "codex" skill
        ├── SKILL.md            # Main skill definition (loaded by Claude Code)
        ├── examples/           # Usage examples (for users)
        │   ├── basic-usage.md
        │   ├── session-continuation.md
        │   └── advanced-config.md
        └── resources/          # Reference documentation (for users)
            ├── codex-help.md        # Codex CLI v0.53.0 help reference
            ├── codex-config.md      # Configuration options
            └── claude-skill-doc.md  # Skill development guide
```

**How it works**:
1. You add the **marketplace** (`cc-skill-codex-marketplace`) from GitHub
2. You install the **plugin** (`cc-skill-codex`) from the marketplace
3. The plugin provides the **skill** (`codex`)
4. Claude Code loads `skills/codex/SKILL.md` when the skill is invoked
5. All other files are documentation for users

---

## Installation in Claude Code

### Prerequisites

1. **Codex CLI** installed and authenticated:
   ```bash
   codex --version  # v0.53.0+
   codex login
   ```

2. **Claude Code** v1.0+

### Install Plugin from GitHub

**Step 1**: Add this repository as a dev marketplace:

```bash
/marketplace add https://github.com/Lucklyric/cc-skill-codex
```

**Step 2**: Install the plugin from the marketplace:

```bash
/plugin install cc-skill-codex@cc-skill-codex-marketplace
```

This installs the **cc-skill-codex plugin**, which includes the **codex skill**.

**Step 3**: Restart Claude Code to activate the plugin and skill.

### Verify Installation

Test that the skill is working:
```
> Use Codex to design a binary search tree in Rust
```

The skill will automatically invoke Codex CLI with GPT-5 high-reasoning mode.

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
/marketplace add https://github.com/Lucklyric/cc-skill-codex
```

This registers the marketplace so Claude Code knows where to find the plugin.

### Step 3: Install the Plugin

Install the plugin from the marketplace you just added:

```bash
/plugin install cc-skill-codex@cc-skill-codex-marketplace
```

This installs the **cc-skill-codex plugin** and makes the **codex skill** available.

**Note**: The full identifier is `cc-skill-codex@cc-skill-codex-marketplace` where:
- `cc-skill-codex` = plugin name
- `cc-skill-codex-marketplace` = marketplace name

Then restart Claude Code.

### Step 4: Test Basic Usage

**Simple request** (uses GPT-5 for general reasoning):
```
> Help me design a priority queue in Python
```

Claude will:
1. Detect this is a coding task
2. Invoke the skill automatically
3. Execute: `codex exec -m gpt-5 -s read-only -c model_reasoning_effort=high "Help me design..."`
4. Return Codex's high-reasoning response

### Step 5: Try Code Editing

**Code editing request** (uses GPT-5-Codex):
```
> Edit my queue.py file to add thread-safety
```

Claude will:
1. Detect this is a code editing task
2. Use GPT-5-Codex model
3. Execute: `codex exec -m gpt-5-codex -s workspace-write -c model_reasoning_effort=high "Edit my queue.py..."`

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
- **Model selection**: GPT-5 (default) for design, GPT-5-Codex for code editing
- **Session continuity**: Use "continue", "resume", "add to that" for session continuation
- **All commands use**: `codex exec` (non-interactive mode) in Claude Code environment

---

**License**: Apache 2.0
**Version**: 1.2.0
