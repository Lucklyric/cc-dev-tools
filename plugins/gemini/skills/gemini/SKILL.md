---
name: gemini
version: 1.1.0
description: Invoke Google Gemini CLI for complex reasoning tasks, research, and AI assistance. This skill should be invoked when users explicitly mention "Gemini", request Google's AI models, need advanced reasoning capabilities, or want to continue previous Gemini conversations. Automatically triggers on Gemini-related requests and supports session continuation for iterative development.
---

# Gemini: Google AI Assistant for Claude Code

---

## DEFAULT MODEL: Gemini 3 Pro

**The default model for ALL Gemini invocations is `gemini-3-pro-preview`.**

- Always use `gemini-3-pro-preview` unless user explicitly requests another model
- This is the highest reasoning model available
- Fallback to `gemini-2.5-flash` ONLY on 404/access errors

```bash
# Default invocation - ALWAYS use gemini-3-pro-preview
gemini -m gemini-3-pro-preview "your prompt here"
```

---

## CRITICAL: Positional Prompts Required

**REQUIRED**: Use positional prompts for Gemini CLI invocations.

**DEPRECATED**: `-p/--prompt` flag is officially deprecated and will be removed in a future version.

**Examples:**
- `gemini -m gemini-3-pro-preview "prompt"` (CORRECT - positional)
- `gemini -m gemini-3-pro-preview -p "prompt"` (DEPRECATED - avoid using)
- `gemini -r latest` (CORRECT - session resume)

**Warning from CLI help**: "[deprecated: Use the positional prompt instead. This flag will be removed in a future version.]"

**Why?** As of Gemini CLI v0.20.0, the `-p` flag is explicitly marked deprecated. Use positional prompts for forward compatibility.

---

## IMPORTANT: Preview Features & OAuth Free Tier

**For OAuth free tier users in headless mode:**

When `previewFeatures: true` in `~/.gemini/settings.json`, the CLI routes ALL requests to Gemini 3 Pro (even `-m gemini-2.5-pro`). Since free tier doesn't have Gemini 3 access, this causes 404 errors.

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

When a user makes a request that falls into one of the above categories, determine the task type:

**General Reasoning Tasks** (architecture, design, reviews, research):
- Use model: `gemini-3-pro-preview` (latest, highest reasoning)
- Fallback: `gemini-2.5-pro` (stable, general reasoning)
- Example requests: "Design a distributed cache", "Research GraphQL best practices", "Explain CQRS pattern"

**Code Editing Tasks** (file modifications, refactoring):
- Use model: `gemini-2.5-flash` (optimized for speed and code)
- Fallback: `gemini-2.5-pro` (if Flash unavailable)
- Example requests: "Refactor this function", "Fix syntax errors", "Optimize this code"

### Bash CLI Command Structure

**IMPORTANT**: Gemini CLI works differently from Codex - no `exec` subcommand needed. Use positional prompts directly.

#### For General Reasoning Tasks (Default)

```bash
gemini -m gemini-3-pro-preview \
  --approval-mode auto_edit \
  --output-format text \
  "Design a microservices architecture for e-commerce"
```

#### For Code Editing Tasks

```bash
gemini -m gemini-2.5-flash \
  --approval-mode auto_edit \
  --output-format text \
  "Refactor this function for better performance"
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

**Use `gemini-3-pro-preview` (default) when:**
- Designing architecture or system design
- Conducting research or analysis
- Explaining complex concepts
- Planning implementation strategies
- General problem-solving and advanced reasoning
- User explicitly requests "Gemini 3" or "use 3"

**Use `gemini-2.5-pro` when:**
- Gemini 3 Pro unavailable or quota exhausted
- Stable, production-ready tasks
- General reasoning with proven reliability
- User explicitly requests "Gemini 2.5" or "use 2.5"

**Use `gemini-2.5-flash` when:**
- Code editing or refactoring tasks
- Fast iterations needed
- Simple, quick responses
- Gemini 3 Pro quota concerns

### Version-Based Model Mapping

When users mention a version number, map to the latest model in that family:

| User Request | Maps To | Actual Model ID |
|--------------|---------|-----------------|
| "use 3" / "Gemini 3" | Latest 3.x Pro | `gemini-3-pro-preview` |
| "use 2.5" (general) | 2.5 Pro | `gemini-2.5-pro` |
| "use 2.5" (code editing) | 2.5 Flash | `gemini-2.5-flash` |
| No version specified | Latest Pro | `gemini-3-pro-preview` |

**See**: `references/model-selection.md` for detailed model selection guidance and decision tree.

### Default Configuration

All Gemini invocations use these defaults unless user specifies otherwise:

| Parameter | Default Value | CLI Flag | Notes |
|-----------|---------------|----------|-------|
| Model (general) | `gemini-3-pro-preview` | `-m gemini-3-pro-preview` | Tries first, falls back to Flash |
| Model (fallback) | `gemini-2.5-flash` | `-m gemini-2.5-flash` | Always works on free tier |
| Model (code editing) | `gemini-2.5-flash` | `-m gemini-2.5-flash` | Optimized for code |
| Approval Mode | `auto_edit` | `--approval-mode auto_edit` | Auto-approve edit tools only |
| Sandbox | `false` (disabled) | No flag | Sandbox disabled by default |
| Output Format | `text` | No flag | Human-readable text output |
| Web Search | Enabled when appropriate | `-e web_search` (if needed) | Context-dependent |

**Rationale for Defaults:**
- **Gemini 3 Pro → Flash Fallback**: Tries latest model first, automatically falls back to Flash (which always works on OAuth free tier)
- **auto_edit mode**: Balances safety (prompts for destructive actions) with efficiency (auto-approves edits)
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
- `gemini-3-pro-preview` unavailable → try `gemini-2.5-pro`
- `gemini-2.5-pro` unavailable → try `gemini-2.5-flash`

#### Session Not Found

**Error**: Using `-r` flag but session doesn't exist

**Message**: "Session not found. Use `gemini --list-sessions` to see available sessions."

**Action**: User should list sessions or start new session

#### Gemini 3 Pro Access Denied

**Error**: Status 403 or "preview access required"

**Message**: "Gemini 3 Pro requires preview access. Enable Preview Features in settings or use `gemini-2.5-pro` instead."

**Action**: Either enable preview features, get API key, or use 2.5 models

**See**: `references/gemini-help.md` for complete CLI reference and troubleshooting.

---

## Examples

### Basic Invocation (General Reasoning)

```bash
# Design system architecture
gemini -m gemini-3-pro-preview "Design a scalable payment processing system"

# Research with web search
gemini -m gemini-3-pro-preview -e web_search "Research latest React 19 features"

# Explain complex concept
gemini -m gemini-2.5-pro "Explain the CAP theorem with real-world examples"
```

### Code Editing Tasks

```bash
# Fast refactoring
gemini -m gemini-2.5-flash "Refactor this function for better readability"

# Fix syntax errors
gemini -m gemini-2.5-flash "Fix the syntax errors in this JavaScript code"

# Optimize performance
gemini -m gemini-2.5-flash "Optimize this database query for better performance"
```

### Session Management

```bash
# Start a session (automatic)
gemini -m gemini-3-pro-preview "Design an authentication system"

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
gemini -m gemini-2.5-pro --output-format json "List top 5 design patterns"

# Streaming JSON for real-time
gemini -m gemini-2.5-pro --output-format stream-json "Explain async patterns"
```

### Approval Modes

```bash
# Default mode (prompt for all)
gemini -m gemini-2.5-pro --approval-mode default "Review this code"

# Auto-edit (auto-approve edits only)
gemini -m gemini-2.5-pro --approval-mode auto_edit "Refactor this module"

# YOLO mode (auto-approve ALL - use with caution)
gemini -m gemini-2.5-pro --approval-mode yolo "Deploy to production"
```

### Sandbox Mode

```bash
# Enable sandbox for untrusted code
gemini -m gemini-2.5-pro -s "Analyze this suspicious code snippet"

# Disabled by default (trusted environment)
gemini -m gemini-2.5-pro "Review this internal codebase"
```

### Extensions & MCP Integration

Gemini CLI supports extensions and Model Context Protocol (MCP) servers for enhanced functionality.

```bash
# List available extensions
gemini --list-extensions

# Use specific extensions (web search, code analysis, etc.)
gemini -m gemini-3-pro-preview -e web_search "Research React 19 features"

# Use all extensions (default)
gemini -m gemini-3-pro-preview "Design system architecture"
```

**Note**: This plugin does not implement custom extensions or MCP servers. Users can configure extensions and MCP servers through the Gemini CLI's standard configuration in `~/.gemini/settings.json`. Extensions are enabled by default when appropriate for the task.

### Additional Directories (`--include-directories`) (v0.20.0+)

Include additional directories in workspace context:

```bash
# Single directory
gemini -m gemini-3-pro-preview --include-directories /shared/libs "task"

# Multiple directories (comma-separated)
gemini -m gemini-3-pro-preview --include-directories /path1,/path2 "task"

# Multiple directories (repeated flag)
gemini -m gemini-3-pro-preview --include-directories /path1 --include-directories /path2 "task"
```

**Note**: Disabled in restrictive sandbox profiles.

### Accessibility (`--screen-reader`) (v0.20.0+)

Enable screen reader mode for accessibility:

```bash
gemini -m gemini-3-pro-preview --screen-reader "task"
```

### Interactive with Prompt (`-i/--prompt-interactive`) (v0.20.0+)

Execute a prompt and continue in interactive mode:

```bash
gemini -m gemini-3-pro-preview -i "initial prompt here"
```

**Note**: Limited applicability for Claude Code skills which use non-interactive mode.

### Experimental ACP Mode (`--experimental-acp`)

Start agent in Agent Control Protocol mode for programmatic interaction:

```bash
gemini --experimental-acp "task"
```

**Note**: Experimental feature. Works with `GEMINI_API_KEY` environment variable.

---

## Reference Documentation

For detailed information, see the references directory:

- **`references/gemini-help.md`** - Complete Gemini CLI help output and flag reference
- **`references/command-patterns.md`** - Common command templates organized by use case
- **`references/session-workflows.md`** - Multi-turn conversation patterns and best practices
- **`references/model-selection.md`** - Model selection decision tree and version mapping

---

## Tips & Best Practices

1. **Always Specify Model**: Use `-m` flag explicitly for predictable behavior
2. **Use Positional Prompts**: Prefer `gemini "prompt"` over deprecated `-p` flag
3. **Enable Web Search When Needed**: Add `-e web_search` for research tasks
4. **Resume Sessions for Complex Tasks**: Use `-r latest` for multi-turn conversations
5. **Start with Gemini 3 Pro**: Default to `gemini-3-pro-preview`, fallback to 2.5 models
6. **Use Appropriate Approval Mode**: `auto_edit` for code, `default` for untrusted tasks
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
| Models | GPT-5.1, GPT-5.1-Codex | Gemini 3 Pro, 2.5 Pro/Flash |
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
- You need GPT-5.1's reasoning capabilities
- Task requires high-reasoning model
- Code editing with specific Codex optimizations
- You're already using Codex workflow

**Use Claude (native) when:**
- Simple queries within Claude Code's capabilities
- No external AI needed
- Quick responses preferred
- Task doesn't require specialized models

---

## Version Compatibility

- **Minimum Gemini CLI**: v0.20.0
- **Recommended**: v0.20.x stable (latest)
- **Preview/Nightly**: Weekly previews available (Tuesdays UTC 2359)

**Changes in v0.20.0:**
- `-p/--prompt` flag officially deprecated (use positional prompts)
- New `--include-directories` flag for workspace expansion
- New `-i/--prompt-interactive` flag for interactive continuation
- New `--screen-reader` accessibility flag
- New `--experimental-acp` Agent Control Protocol mode
- Session management via `-r` flag standard

---

For questions or issues, consult `references/gemini-help.md` or run `gemini --help`.
