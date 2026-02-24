---
name: gemini
version: 1.6.0
description: This skill should be used when the user wants to invoke Google Gemini CLI for complex reasoning tasks, research, and AI assistance. Trigger phrases include "use gemini", "ask gemini", "run gemini", "call gemini", "gemini cli", "Google AI", "Gemini reasoning", or when users request Google's AI models, need advanced reasoning capabilities, research with web search, or want to continue previous Gemini conversations. Automatically triggers on Gemini-related requests and supports session continuation for iterative development.
---

# Gemini: Google AI Assistant for Claude Code

---

## DEFAULT MODEL: Gemini 3.1 Pro

**The default model for ALL Gemini invocations is `gemini-3.1-pro-preview`.**

- Always use `gemini-3.1-pro-preview` unless user explicitly requests another model
- This is the highest reasoning model available (released Feb 19, 2026)
- CLI default (without `-m`) is `gemini-3-flash-preview` (fast but less capable)
- Fallback chain: `gemini-3.1-pro-preview` → `gemini-3-pro-preview` → `gemini-2.5-flash`

```bash
# Default invocation - ALWAYS use gemini-3.1-pro-preview
gemini -m gemini-3.1-pro-preview "your prompt here"
```

---

## CRITICAL: Headless Mode with `-p` Flag

**REQUIRED**: Use `-p`/`--prompt` flag for non-interactive (headless) execution in Claude Code.

As of Gemini CLI v0.29.0+, positional prompts default to **interactive mode**. The `-p` flag is the correct way to run in **non-interactive (headless) mode**.

**Examples:**
- `gemini -m gemini-3.1-pro-preview -p "prompt"` (CORRECT - headless mode)
- `gemini -m gemini-3.1-pro-preview "prompt"` (also works when piped, but `-p` is more explicit)
- `gemini -r latest` (session resume)

**Why?** As of v0.29.0, the CLI description states: "Defaults to interactive mode. Use -p/--prompt for non-interactive (headless) mode." The `-p` flag is no longer deprecated.

---

## IMPORTANT: Preview Features & OAuth Free Tier

**For OAuth free tier users in headless mode:**

When `previewFeatures: true` in `~/.gemini/settings.json`, the CLI routes ALL requests to Gemini 3.1 Pro (even `-m gemini-2.5-pro`). Since free tier doesn't have Gemini 3 access, this causes 404 errors.

**Solution**: Disable preview features for reliable headless operation:
```json
// ~/.gemini/settings.json
{
  "general": {
    "previewFeatures": false
  }
}
```

**Plugin Behavior**: This skill automatically falls back to `gemini-2.5-flash` when encountering 404 errors. Flash always works with OAuth free tier.

---

## Trigger Examples

This skill activates when users say phrases like:
- "Use gemini to research this topic"
- "Ask gemini about this design pattern"
- "Run gemini on this analysis"
- "Call gemini for help with this problem"
- "I need Google AI for this task"
- "Get Gemini's reasoning on this"
- "Continue with gemini" or "Resume the gemini session"
- "Gemini, help me with..." or simply "Gemini"
- "Use Gemini 3" or "Use Gemini 2.5"

## When to Use This Skill

This skill should be invoked when:
- User explicitly mentions "Gemini" or requests Gemini assistance
- User needs Google's AI models for reasoning, research, or analysis
- User requests complex problem-solving or architectural design
- User needs research capabilities with web search integration
- User wants to continue a previous Gemini conversation
- User needs an alternative to Codex or Claude for specific tasks

## How It Works

### Detecting New Gemini Requests

When a user makes a request, **default to read-only mode (default approval)** unless they explicitly request file editing:

**Use `gemini-3.1-pro-preview` for ALL tasks with `default` approval mode:**
- Architecture, design, reviews, research
- Explanations, analysis, problem-solving
- Code analysis and understanding
- ANY task where user does NOT explicitly request file editing

**Approval Mode Selection:**
- **`default`** (default): For all tasks - prompts for approval on edits (safe)
- **`auto_edit`**: ONLY when user explicitly requests file editing
- **`plan`**: Read-only mode - no file modifications allowed
- **`yolo`**: When user explicitly wants full auto-approval (use with caution)

**⚠️ Explicit Edit Request**: If the user explicitly asks to "edit files", "modify code", "write changes", or "make edits" - ONLY then use `--approval-mode auto_edit` to enable file modifications.

**Fallback Chain** (if primary unavailable):
1. `gemini-3.1-pro-preview` (primary - highest capability)
2. `gemini-2.5-pro` (stable general reasoning)
3. `gemini-2.5-flash` (fast, always available)

**Example requests**: "Design a distributed cache", "Explain CQRS pattern", "Analyze this code"

### Bash CLI Command Structure

**IMPORTANT**: Gemini CLI works differently from Codex - no `exec` subcommand needed. Use positional prompts directly.

#### Default Command (Read-Only) - Use for ALL Tasks

```bash
gemini -m gemini-3.1-pro-preview \
  "Design a microservices architecture for e-commerce"
```

#### Explicit Edit Request Only - When User Asks to Edit Files

```bash
gemini -m gemini-3.1-pro-preview \
  --approval-mode auto_edit \
  "Edit this file to refactor the function"
```

#### For Session Continuation

```bash
# Resume most recent session
gemini -r latest

# Resume specific session by index
gemini -r 3

# Resume and add new prompt
gemini -r latest "Continue our discussion about caching strategies"
```

**Why positional prompts?**
- Simpler, more direct syntax
- Future-proof (recommended by Gemini CLI)
- Works in non-TTY environments (like Claude Code's bash)
- No separate `exec` command needed

### Model Selection Logic

**Use `gemini-3.1-pro-preview` (default for ALL tasks):**
- Code editing, refactoring, implementation
- Designing architecture or system design
- Conducting research or analysis
- Explaining complex concepts
- Planning implementation strategies
- General problem-solving and advanced reasoning

**Fallback to `gemini-2.5-pro` when:**
- Gemini 3.1 Pro unavailable or quota exhausted
- User explicitly requests "Gemini 2.5" or "use 2.5"
- Stable, production-ready tasks

**Fallback to `gemini-2.5-flash` when:**
- Both Gemini 3.1 Pro and 2.5 Pro unavailable
- Fast iterations needed (explicit user request)
- Simple, quick responses (explicit user request)

### Version-Based Model Mapping

When users mention a version number, map to the latest model in that family:

| User Request | Maps To | Actual Model ID |
|--------------|---------|-----------------|
| "use 3" / "Gemini 3" | Latest 3.x Pro | `gemini-3.1-pro-preview` |
| "use 2.5" | 2.5 Pro | `gemini-2.5-pro` |
| "use flash" | 2.5 Flash | `gemini-2.5-flash` |
| No version specified | Latest Pro (ALL tasks) | `gemini-3.1-pro-preview` |

**See**: `references/model-selection.md` for detailed model selection guidance and decision tree.

### Default Configuration

All Gemini invocations use these defaults unless user specifies otherwise:

| Parameter | Default Value | CLI Flag | Notes |
|-----------|---------------|----------|-------|
| Model | `gemini-3.1-pro-preview` | `-m gemini-3.1-pro-preview` | For ALL tasks (highest capability) |
| Model (fallback 1) | `gemini-2.5-pro` | `-m gemini-2.5-pro` | If Gemini 3.1 Pro unavailable |
| Model (fallback 2) | `gemini-2.5-flash` | `-m gemini-2.5-flash` | Always works on free tier |
| Approval Mode (default) | `default` | No flag | Safe default - prompts for edits |
| Approval Mode (editing) | `auto_edit` | `--approval-mode auto_edit` | Only when user explicitly requests editing |
| Sandbox | `false` (disabled) | No flag | Sandbox disabled by default |
| Output Format | `text` | No flag | Human-readable text output |
| Web Search | Enabled when appropriate | `-e web_search` (if needed) | Context-dependent |

**Rationale for Defaults:**
- **Gemini 3.1 Pro for ALL tasks**: Highest capability model, optimized for both reasoning and code
- **Fallback chain**: gemini-3.1-pro-preview → gemini-2.5-pro → gemini-2.5-flash
- **default mode**: Safe default that prompts for approval on edits
- **auto_edit mode**: Only use when user explicitly requests file editing
- **No sandbox**: Claude Code environment assumed trusted
- **Text output**: Default for human consumption (use `--output-format json` for parsing)

**Note**: If you have `previewFeatures: true` in settings, disable it for reliable headless operation (see warning above).

### Error Handling

The skill handles these common errors gracefully:

#### CLI Not Installed

**Error**: `command not found: gemini`

**Message**: "Gemini CLI not installed. Install from: https://github.com/google-gemini/gemini-cli"

**Action**: User must install Gemini CLI before using this skill

#### Authentication Required

**Error**: Output contains "auth" or "authentication"

**Message**: "Authentication required. Run: `gemini login` to authenticate with your Google account"

**Action**: User must authenticate via OAuth or API key

#### Rate Limit Exceeded

**Error**: Output contains "quota" or "rate limit" or status 429

**Message**: "Rate limit exceeded (60 req/min, 1000 req/day free tier). Retry in X seconds or upgrade account."

**Action**: Wait for rate limit reset or upgrade to paid tier

#### Model Unavailable

**Error**: Output contains "model not found" or "404" or status 403

**Message**: "Model unavailable. Trying fallback model..."

**Action**: Automatically retry with fallback:
- `gemini-3.1-pro-preview` unavailable → try `gemini-2.5-pro`
- `gemini-2.5-pro` unavailable → try `gemini-2.5-flash`

#### Session Not Found

**Error**: Using `-r` flag but session doesn't exist

**Message**: "Session not found. Use `gemini --list-sessions` to see available sessions."

**Action**: User should list sessions or start new session

#### Gemini 3.1 Pro Access Denied

**Error**: Status 403 or "preview access required"

**Message**: "Gemini 3.1 Pro requires preview access. Enable Preview Features in settings or use `gemini-2.5-pro` instead."

**Action**: Either enable preview features, get API key, or use 2.5 models

**See**: `references/gemini-help.md` for complete CLI reference and troubleshooting.

---

## Examples

### Basic Invocation (General Reasoning)

```bash
# Design system architecture
gemini -m gemini-3.1-pro-preview "Design a scalable payment processing system"

# Research with web search
gemini -m gemini-3.1-pro-preview -e web_search "Research latest React 19 features"

# Explain complex concept
gemini -m gemini-3.1-pro-preview "Explain the CAP theorem with real-world examples"
```

### Code Editing Tasks

```bash
# Refactoring (uses gemini-3.1-pro-preview for all tasks)
gemini -m gemini-3.1-pro-preview "Refactor this function for better readability"

# Fix syntax errors
gemini -m gemini-3.1-pro-preview "Fix the syntax errors in this JavaScript code"

# Optimize performance
gemini -m gemini-3.1-pro-preview "Optimize this database query for better performance"
```

### Session Management

```bash
# Start a session (automatic)
gemini -m gemini-3.1-pro-preview "Design an authentication system"

# List available sessions
gemini --list-sessions

# Resume most recent
gemini -r latest

# Resume specific session
gemini -r 3

# Continue with new prompt
gemini -r latest "Now help me implement the login flow"
```

### With Output Formatting

```bash
# JSON output for parsing
gemini -m gemini-3.1-pro-preview --output-format json "List top 5 design patterns"

# Streaming JSON for real-time
gemini -m gemini-3.1-pro-preview --output-format stream-json "Explain async patterns"
```

### Approval Modes

```bash
# Default mode (prompt for all)
gemini -m gemini-3.1-pro-preview --approval-mode default "Review this code"

# Auto-edit (auto-approve edits only)
gemini -m gemini-3.1-pro-preview --approval-mode auto_edit "Refactor this module"

# Plan mode (read-only, no file modifications)
gemini -m gemini-3.1-pro-preview --approval-mode plan "Analyze this codebase"

# YOLO mode (auto-approve ALL - use with caution)
gemini -m gemini-3.1-pro-preview --approval-mode yolo "Deploy to production"
```

### Sandbox Mode

```bash
# Enable sandbox for untrusted code
gemini -m gemini-3.1-pro-preview -s "Analyze this suspicious code snippet"

# Disabled by default (trusted environment)
gemini -m gemini-3.1-pro-preview "Review this internal codebase"
```

### Extensions & MCP Integration

Gemini CLI supports extensions and Model Context Protocol (MCP) servers for enhanced functionality.

```bash
# List available extensions
gemini --list-extensions

# Use specific extensions (web search, code analysis, etc.)
gemini -m gemini-3.1-pro-preview -e web_search "Research React 19 features"

# Use all extensions (default)
gemini -m gemini-3.1-pro-preview "Design system architecture"
```

**Note**: This plugin does not implement custom extensions or MCP servers. Users can configure extensions and MCP servers through the Gemini CLI's standard configuration in `~/.gemini/settings.json`. Extensions are enabled by default when appropriate for the task.

### Skills Management (`gemini skills`) (v0.29.5+)

Gemini CLI supports agent skills - reusable capabilities that extend the agent's abilities. Manage skills through the CLI:

```bash
# List available skills
gemini skills list

# Install a skill
gemini skills install <source>

# Enable/disable a skill
gemini skills enable <name>
gemini skills disable <name>
```

**Note**: Skills in Gemini CLI are agent-level capabilities (like file operations, code execution), distinct from Claude Code plugin skills. Configure skills in `~/.gemini/settings.json`.

### Hooks Management (`gemini hooks`) (v0.29.5+)

Gemini CLI supports hooks - event-driven automation that runs at specific points during agent execution. Manage hooks through the CLI:

```bash
# Migrate hooks from Claude Code to Gemini CLI
gemini hooks migrate

# Get help on hooks management
gemini hooks --help
```

**Note**: Gemini CLI hooks are similar to Claude Code hooks. Use `gemini hooks migrate` to migrate existing Claude Code hooks. Configure hooks in `~/.gemini/settings.json`.

### Additional Directories (`--include-directories`) (v0.20.0+)

Include additional directories in workspace context:

```bash
# Single directory
gemini -m gemini-3.1-pro-preview --include-directories /shared/libs "task"

# Multiple directories (comma-separated)
gemini -m gemini-3.1-pro-preview --include-directories /path1,/path2 "task"

# Multiple directories (repeated flag)
gemini -m gemini-3.1-pro-preview --include-directories /path1 --include-directories /path2 "task"
```

**Note**: Disabled in restrictive sandbox profiles.

---

## File Context Passing

**IMPORTANT**: Pass file paths to Gemini CLI instead of embedding file content in prompts. This enables Gemini to read files autonomously.

**Quick reference**:
- Use `--include-directories /path` for additional directories
- Use `@path/to/file` syntax for explicit file references

```bash
# Example: analyze file with explicit @ syntax
gemini -m gemini-3.1-pro-preview \
  "Analyze @src/auth.ts and compare with @src/session.ts"

# Example: multi-directory analysis
gemini -m gemini-3.1-pro-preview \
  --include-directories /shared/libs \
  "Review how auth module uses shared utilities"
```

**See**: `references/file-context.md` for complete file context documentation.

---

### Accessibility (`--screen-reader`) (v0.20.0+)

Enable screen reader mode for accessibility:

```bash
gemini -m gemini-3.1-pro-preview --screen-reader "task"
```

### Interactive with Prompt (`-i/--prompt-interactive`) (v0.20.0+)

Execute a prompt and continue in interactive mode:

```bash
gemini -m gemini-3.1-pro-preview -i "initial prompt here"
```

**⚠️ Not applicable for Claude Code**: This flag requires an interactive terminal and will not work in Claude Code's non-interactive bash environment. Use standard positional prompts instead.

### Experimental ACP Mode (`--experimental-acp`)

Start agent in Agent Control Protocol mode for programmatic interaction:

```bash
gemini --experimental-acp "task"
```

**Note**: Experimental feature. Works with `GEMINI_API_KEY` environment variable.

---

## Reference Documentation

For detailed information, consult these reference files:

### Core References
- **`references/file-context.md`** - File and directory context passing guide
- **`references/model-selection.md`** - Model selection decision tree and version mapping

### Workflow References
- **`references/command-patterns.md`** - Common command templates organized by use case
- **`references/session-workflows.md`** - Multi-turn conversation patterns and best practices

### CLI References
- **`references/gemini-help.md`** - Complete Gemini CLI help output and flag reference

---

## Tips & Best Practices

1. **Always Specify Model**: Use `-m` flag explicitly for predictable behavior
2. **Use Positional Prompts**: Prefer `gemini "prompt"` over deprecated `-p` flag
3. **Enable Web Search When Needed**: Add `-e web_search` for research tasks
4. **Resume Sessions for Complex Tasks**: Use `-r latest` for multi-turn conversations
5. **Start with Gemini 3.1 Pro**: Default to `gemini-3.1-pro-preview`, fallback to 2.5 models
6. **Use Appropriate Approval Mode**: `default` for all tasks, `auto_edit` only when user explicitly requests file editing
7. **Monitor Rate Limits**: 60 req/min, 1000 req/day on free tier
8. **Check CLI Availability**: Validate `command -v gemini` before invocation

---

## Differences from Codex

| Feature | Codex CLI | Gemini CLI |
|---------|-----------|------------|
| Invocation | `codex exec "prompt"` | `gemini "prompt"` |
| Subcommand | Required (`exec`) | Not needed |
| Positional Prompts | Not supported | Preferred |
| Session Resume | `codex exec resume --last` | `gemini -r latest` |
| Models | GPT-5.2, GPT-5.3-Codex | Gemini 3.1 Pro, 2.5 Pro/Flash |
| Provider | OpenAI (via Codex) | Google |

---

## When to Use Gemini vs Codex vs Claude

**Use Gemini when:**
- You need Google's latest models
- Research with web search is important
- You prefer Google's AI capabilities
- Codex is unavailable or rate-limited
- Task benefits from Gemini's strengths

**Use Codex when:**
- You need GPT-5.2's high-reasoning capabilities
- Complex coding tasks require GPT-5.3-Codex (optimized for agentic coding)
- Code editing with specific Codex optimizations
- You're already using Codex workflow

**Use Claude (native) when:**
- Simple queries within Claude Code's capabilities
- No external AI needed
- Quick responses preferred
- Task doesn't require specialized models

---

## Version Compatibility

**Minimum Gemini CLI**: v0.29.5

| Feature | Minimum Version | Notes |
|---------|-----------------|-------|
| Core functionality | v0.20.0+ | Positional prompts, session resume |
| `--include-directories` | v0.20.0+ | Workspace expansion |
| `--screen-reader` | v0.20.0+ | Accessibility mode |
| `--approval-mode plan` | v0.29.5+ | Read-only mode |
| `gemini skills` | v0.29.5+ | Skills management |
| `gemini hooks` | v0.29.5+ | Hooks management |

For questions or issues, consult `references/gemini-help.md` or run `gemini --help`.
