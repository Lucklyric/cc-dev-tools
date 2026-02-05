# Gemini CLI Session Workflows

**Purpose**: Guide for session management and multi-turn conversations
**Version**: v0.26.0+
**Last Updated**: 2026-02-05

**Note**: Session management features documented here are available in Gemini CLI v0.16.0+ but may not be directly accessible through Claude Code's headless integration. See limitations section below.

## Overview

Gemini CLI supports session persistence for multi-turn conversations, allowing you to resume previous interactions and build on context across multiple invocations.

## Session Basics

### What is a Session?

A session is a conversation thread with Gemini that:
- Maintains conversation history
- Preserves context across turns
- Can be resumed later
- Is stored locally in `~/.gemini/`

### Session Lifecycle

```
Create → Use → Pause → Resume → Complete → Archive/Delete
```

## Session Management Commands

### List Available Sessions

```bash
gemini --list-sessions
```

**Example Output**:
```
Available sessions:
 0: "test non-interactive mode" (5 minutes ago)
 1: "architecture design discussion" (1 hour ago)
 2: "code review session" (yesterday)
```

### Resume a Session

```bash
# Resume most recent session
gemini -r latest

# Resume specific session by index
gemini -r 0
gemini -r 1
gemini -r 2

# Resume and add new prompt
gemini -r latest "Continue our discussion about microservices"
```

### Delete a Session

```bash
# Delete session by index
gemini --delete-session 0

# Delete after listing
gemini --list-sessions
gemini --delete-session 2
```

## Session Workflows

### Workflow 1: Iterative Development

**Scenario**: Building a feature across multiple sessions

```bash
# Session 1: Initial design
gemini -m gemini-3-pro-preview "Design a user authentication system"
# ... conversation happens ...

# Later: Resume to implement
gemini -r latest "Now help me implement the login component"

# Even later: Review and refine
gemini -r latest "Review the implementation for security issues"
```

### Workflow 2: Research Continuation

**Scenario**: Deep research across multiple timeframes

```bash
# Day 1: Start research
gemini -m gemini-3-pro-preview -e web_search "Research GraphQL best practices"

# Day 2: Continue research
gemini -r latest "Now compare GraphQL with REST for our use case"

# Day 3: Make decision
gemini -r latest "Based on our research, recommend the best approach"
```

### Workflow 3: Code Review Marathon

**Scenario**: Reviewing multiple files in sequence

```bash
# Start with first file
gemini -m gemini-2.5-pro "Review this authentication module"

# Resume for next file (context preserved)
gemini -r latest "Now review the authorization module"

# Continue pattern
gemini -r latest "Review the session management module"
```

### Workflow 4: Collaborative Debugging

**Scenario**: Debugging complex issues over time

```bash
# Initial investigation
gemini -m gemini-2.5-pro "Help debug this memory leak"

# After implementing first fix
gemini -r latest "The leak still occurs. Here's the new log output..."

# Final resolution
gemini -r latest "Confirmed fixed! Summarize what we found"
```

## Best Practices

### When to Use Sessions

✅ **Good Use Cases**:
- Complex multi-step tasks
- Iterative design and implementation
- Long-running research projects
- Code review across multiple files
- Debugging sessions spanning multiple attempts

❌ **Poor Use Cases**:
- Quick one-off queries
- Unrelated tasks
- Simple factual questions
- When context doesn't matter

### Session Management Tips

1. **Name Sessions Meaningfully**: Use descriptive names for easy identification
2. **Clean Up Regularly**: Delete completed sessions to reduce clutter
3. **Use Latest Wisely**: `gemini -r latest` is convenient but verify you're resuming the right session
4. **Context Limits**: Very long sessions may hit context window limits
5. **Explicit Resume**: When in doubt, use numeric index rather than `latest`

### Session Organization

```bash
# Pattern: One session per feature/task
# Session 0: "auth-implementation"
# Session 1: "payment-integration"
# Session 2: "performance-optimization"

# Check which session you need
gemini --list-sessions

# Resume the right one
gemini -r 1  # payment-integration
```

## Session Storage

### Location

Sessions are stored in:
```
~/.gemini/
├── sessions/
│   ├── session-0.json
│   ├── session-1.json
│   └── session-2.json
└── settings.json
```

### Privacy & Security

- Sessions stored locally only
- No automatic cloud sync
- Contains conversation history
- May include sensitive code/data
- Should be included in `.gitignore`

## Interactive vs Non-Interactive Sessions

### Interactive Mode

```bash
# Start interactive session
gemini

# Session automatically created
# Type /chat save mytag to save with tag
# Type /chat resume mytag to resume later
```

### Non-Interactive Mode (Headless)

```bash
# Sessions work with -r flag
gemini -r latest "New prompt here"

# But creating NEW sessions requires prompt-interactive
gemini -i "Start session with this prompt"
```

## Limitations in Claude Code Integration

⚠️ **Important**: Claude Code's bash environment is non-interactive/headless, which means:

1. **No Interactive Session Commands**: Commands like `/chat save` and `/chat resume` don't work in headless mode
2. **Resume Flag May Work**: The `-r` flag SHOULD work for resuming, but hasn't been tested in headless context
3. **Session Creation**: New sessions created automatically on first invocation
4. **Session Persistence**: Sessions persist across Claude Code skill invocations if using same working directory

### Workaround for Claude Code

Since full session management may not be available in headless mode, consider:
- Using one-shot queries for each invocation
- Maintaining conversation context at the plugin level (if needed)
- Documenting session management as manual user workflow outside Claude Code

## Advanced Patterns

### Session Branching

```bash
# Main session
gemini -r 0 "Implement approach A"

# Try alternative without affecting main session
gemini "Try approach B instead"  # New session

# Return to main session
gemini -r 0 "Continue with approach A"
```

### Session Cleanup Script

```bash
#!/bin/bash
# cleanup-old-sessions.sh

# List sessions
gemini --list-sessions

# Delete sessions older than 7 days (manual inspection required)
# No automated deletion to prevent data loss
```

## Troubleshooting

### Session Not Found

```bash
$ gemini -r 5
Error: Session 5 not found

# Solution: List sessions first
$ gemini --list-sessions
# Use valid index
```

### Lost Session Context

```bash
# If session seems to have lost context:
# 1. Verify you're resuming correct session
gemini --list-sessions

# 2. Resume with summary prompt
gemini -r 2 "Summarize what we discussed so far"

# 3. If context truly lost, start fresh
gemini "Let's restart our discussion about..."
```

### Session Conflicts

```bash
# If multiple sessions seem to interfere:
# 1. Check current sessions
gemini --list-sessions

# 2. Delete unused sessions
gemini --delete-session 1
gemini --delete-session 3

# 3. Start fresh with clear naming
gemini "New session: payment gateway integration"
```

## See Also

- `gemini-help.md` - Full CLI reference
- `command-patterns.md` - Common command templates
- `model-selection.md` - Model selection guidance
