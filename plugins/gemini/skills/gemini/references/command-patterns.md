# Gemini CLI Command Patterns

**Purpose**: Common command templates for Gemini CLI integration
**Version**: v0.29.5+
**Last Updated**: 2026-02-05

## Basic Invocation Patterns

### One-Shot Queries (Headless Mode)

```bash
# Preferred syntax (positional prompt)
gemini -m gemini-3.1-pro-preview "Explain the observer pattern in software design"

# Alternative (deprecated -p flag, still works)
gemini -m gemini-3.1-pro-preview -p "Explain the observer pattern in software design"

# With stdin input
echo "function add(a, b) { return a + b; }" | gemini -m gemini-3.1-pro-preview "Explain this code"
```

### Model Selection

```bash
# Use Gemini 3.1 Pro (default for complex reasoning)
gemini -m gemini-3.1-pro-preview "Design a microservices architecture"

# Use Gemini 2.5 Pro (stable, general reasoning)
gemini -m gemini-2.5-pro "Review this API design"

# Use Gemini 2.5 Flash (faster, code-focused)
gemini -m gemini-2.5-flash "Refactor this function for performance"
```

### Version-Based Model Selection

When user requests a specific version, map to the latest model in that family:

```bash
# User says "use Gemini 3" or "use 3" → Latest 3.x Pro
gemini -m gemini-3.1-pro-preview "Design a distributed caching system"

# User says "use Gemini 2.5" for general tasks → 2.5 Pro
gemini -m gemini-2.5-pro "Explain the CAP theorem with examples"

# User says "use Gemini 2.5" for code editing → 2.5 Flash
gemini -m gemini-2.5-flash "Refactor this module for readability"

# No version specified → Default to latest Pro
gemini -m gemini-3.1-pro-preview "Research microservices best practices"
```

**Fallback Strategy** (when primary model unavailable):

```bash
# Try Gemini 3.1 Pro first
gemini -m gemini-3.1-pro-preview "Complex reasoning task" 2>&1

# If quota exhausted, fallback to 2.5 Pro (general) or 2.5 Flash (code)
if [ $? -ne 0 ]; then
    # For general reasoning
    gemini -m gemini-2.5-pro "Complex reasoning task"

    # OR for code editing
    # gemini -m gemini-2.5-flash "Complex reasoning task"
fi
```

## Output Formatting

### Text Output (Default)

```bash
gemini -m gemini-3.1-pro-preview "What is dependency injection?"
```

### JSON Output (Programmatic)

```bash
gemini -m gemini-3.1-pro-preview --output-format json "List top 5 design patterns"
```

### Streaming JSON (Real-time)

```bash
gemini -m gemini-3.1-pro-preview --output-format stream-json "Explain async/await in JavaScript"
```

## Approval Modes & Security

### Default Mode (Prompt for all actions)

```bash
# Explicit
gemini -m gemini-3.1-pro-preview --approval-mode default "Refactor this code"

# Implicit (no flag = default)
gemini -m gemini-3.1-pro-preview "Refactor this code"
```

### Auto-Edit Mode (Auto-approve edit tools only)

```bash
gemini -m gemini-3.1-pro-preview --approval-mode auto_edit "Fix bugs in this file"
```

### Plan Mode (Require plan approval before execution)

```bash
gemini -m gemini-3.1-pro-preview --approval-mode plan "Refactor the authentication module"
```

### YOLO Mode (Auto-approve all tools)

```bash
# Long form
gemini -m gemini-3.1-pro-preview --approval-mode yolo "Deploy to production"

# Short form
gemini -m gemini-3.1-pro-preview -y "Deploy to production"
```

## Sandbox Mode

### Enable Sandbox

```bash
gemini -m gemini-3.1-pro-preview -s "Run untrusted code analysis"
```

### Disable Sandbox (Default)

```bash
gemini -m gemini-3.1-pro-preview "Analyze trusted codebase"
```

## Session Management

### List Sessions

```bash
gemini --list-sessions
```

### Resume Sessions

```bash
# Resume most recent session
gemini -r latest

# Resume specific session by index
gemini -r 3

# Resume and add new prompt
gemini -r latest "Continue from where we left off"
```

### Delete Sessions

```bash
gemini --delete-session 5
```

## Extensions & MCP

### List Available Extensions

```bash
gemini -l
# or
gemini --list-extensions
```

### Use Specific Extensions

```bash
gemini -e web_search,code_analysis "Research React best practices"
```

### Use All Extensions (Default)

```bash
gemini "Research React best practices"
```

## Workspace Context

### Include Additional Directories

```bash
gemini --include-directories ./lib,./tests "Analyze the full project"

# Or multiple flags
gemini --include-directories ./lib --include-directories ./tests "Analyze project"
```

## Combined Patterns

### Production-Safe Code Review

```bash
gemini -m gemini-3.1-pro-preview \
  --approval-mode default \
  --output-format json \
  "Review this pull request for security issues"
```

### Fast Code Refactoring

```bash
gemini -m gemini-3.1-pro-preview \
  --approval-mode auto_edit \
  "Refactor these functions for better performance"
```

### Research with Web Search

```bash
gemini -m gemini-3.1-pro-preview \
  -e web_search \
  --output-format text \
  "What are the latest trends in GraphQL?"
```

### Sandbox Testing

```bash
gemini -m gemini-3.1-pro-preview \
  -s \
  --approval-mode default \
  "Test this suspicious code snippet"
```

## Claude Code Integration Patterns

### Skill Invocation (via Claude)

```bash
# Basic invocation from skill
gemini -m gemini-3.1-pro-preview "Explain microservices"

# With explicit approval mode
gemini -m gemini-3.1-pro-preview --approval-mode auto_edit "Fix type errors"

# With JSON output for parsing
gemini -m gemini-3.1-pro-preview --output-format json "List API endpoints"
```

### Error Handling Pattern

```bash
# Check CLI availability
if ! command -v gemini &> /dev/null; then
    echo "Error: Gemini CLI not installed"
    exit 1
fi

# Execute with error capture
gemini -m gemini-3.1-pro-preview "task" 2>&1 || echo "Gemini CLI failed"
```

## Model Selection by Task Type

**Default**: Use `gemini-3.1-pro-preview` for ALL tasks (highest capability).

```bash
# All tasks default to gemini-3.1-pro-preview
gemini -m gemini-3.1-pro-preview "Design system architecture"
gemini -m gemini-3.1-pro-preview "Review this pull request"
gemini -m gemini-3.1-pro-preview "Fix syntax errors in this file"
```

**Fallback models** (only if gemini-3.1-pro-preview is unavailable):
- `gemini-2.5-pro` - Strong alternative for complex tasks
- `gemini-2.5-flash` - Fast responses, lower capability

## Skills & Hooks Management (v0.29.5+)

### Skills Management

```bash
# List available skills
gemini skills list

# Install a skill
gemini skills install <source>

# Enable/disable a skill
gemini skills enable <name>
gemini skills disable <name>

# Uninstall a skill
gemini skills uninstall <name>
```

### Hooks Management

```bash
# Migrate hooks from Claude Code
gemini hooks migrate

# Get help on hooks
gemini hooks --help
```

### Extensions Management

```bash
# List installed extensions
gemini extensions list

# Install an extension
gemini extensions install <source>

# Update extensions
gemini extensions update --all
```

## Anti-Patterns (Avoid These)

```bash
# ❌ Using -p flag (deprecated)
gemini -p "prompt"  # Will be removed in future

# ❌ Using -i for headless mode
gemini -i "prompt"  # This starts interactive mode, not one-shot

# ❌ Hardcoding model without fallback
# Always have fallback logic when gemini-3.1-pro-preview unavailable

# ❌ Using YOLO mode without user confirmation
# Always require explicit user approval for YOLO mode
```

## Best Practices

1. **Prefer Positional Prompts**: Use `gemini "prompt"` instead of `gemini -p "prompt"`
2. **Specify Model Explicitly**: Always use `-m` flag for predictable behavior
3. **Use Appropriate Approval Mode**: Default for untrusted tasks, auto_edit for code editing
4. **Enable Sandbox for Unknown Code**: Use `-s` when analyzing untrusted input
5. **Format Output for Parsing**: Use `--output-format json` when processing results programmatically
6. **Resume Sessions When Needed**: Use `-r latest` for multi-turn conversations
7. **Validate CLI Availability**: Always check `command -v gemini` before invocation

## See Also

- `gemini-help.md` - Full CLI reference
- `session-workflows.md` - Session continuation patterns
- `model-selection.md` - Model selection guidance
