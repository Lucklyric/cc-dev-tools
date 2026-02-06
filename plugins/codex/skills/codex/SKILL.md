---
name: codex
version: 2.4.0
description: This skill should be used when the user wants to invoke Codex CLI for complex coding tasks requiring high reasoning capabilities. Trigger phrases include "use codex", "ask codex", "run codex", "call codex", "codex cli", "GPT-5 reasoning", "OpenAI reasoning", or when users request complex implementation challenges, advanced reasoning, architecture design, or high-reasoning model assistance. Automatically triggers on codex-related requests and supports session continuation for iterative development.
---

# Codex: High-Reasoning AI Assistant for Claude Code

---

## DEFAULT MODEL: Task-Based Model Selection with Read-Only Default

**Codex uses task-based model selection. Sandbox is `read-only` by default - only use `workspace-write` when user explicitly requests file editing.**

| Task Type | Model | Sandbox (default) | Sandbox (explicit edit) |
|-----------|-------|-------------------|------------------------|
| Code-related tasks | `gpt-5.3-codex` | read-only | workspace-write |
| General tasks | `gpt-5.2` | read-only | workspace-write |

- **Code-related tasks**: Use `gpt-5.3-codex` - optimized for agentic coding (56.8% SWE-Bench Pro)
- **General tasks**: Use `gpt-5.2` - high-reasoning general model
- **Sandbox default**: Always `read-only` unless user explicitly requests editing
- **Explicit editing**: Only when user says "edit", "modify", "write changes", etc., use `workspace-write`
- Always use `-c model_reasoning_effort=xhigh` for maximum capability

```bash
# Code task (read-only default)
codex exec -m gpt-5.3-codex -s read-only \
  -c model_reasoning_effort=xhigh \
  "analyze this function implementation"

# General task (read-only default)
codex exec -m gpt-5.2 -s read-only \
  -c model_reasoning_effort=xhigh \
  "explain this architecture"

# Code task with explicit edit request
codex exec -m gpt-5.3-codex -s workspace-write \
  -c model_reasoning_effort=xhigh \
  "edit this file to add the feature"

# General task with explicit edit request
codex exec -m gpt-5.2 -s workspace-write \
  -c model_reasoning_effort=xhigh \
  "modify the documentation file"
```

### Model Fallback Chain

If the primary model is unavailable, fallback gracefully:
1. **Code tasks**: `gpt-5.3-codex` → `gpt-5.2`
2. **General tasks**: `gpt-5.2` → `gpt-5.3-codex`
3. **Reasoning effort**: `xhigh` → `high` → `medium`

---

## CRITICAL: Always Use `codex exec`

**MUST USE**: `codex exec` for ALL Codex CLI invocations in Claude Code.

**NEVER USE**: `codex` (interactive mode) - will fail with "stdout is not a terminal"
**ALWAYS USE**: `codex exec` (non-interactive mode)

**Examples:**
- `codex exec -m gpt-5.2 "prompt"` (CORRECT)
- `codex -m gpt-5.2 "prompt"` (WRONG - will fail)
- `codex exec resume --last` (CORRECT)
- `codex resume --last` (WRONG - will fail)

**Why?** Claude Code's bash environment is non-terminal/non-interactive. Only `codex exec` works in this environment.

---

## IMPORTANT: Interactive vs Exec Mode Flags

**Some Codex CLI flags are ONLY available in interactive mode, NOT in `codex exec`.**

| Flag | Interactive `codex` | `codex exec` | Alternative for exec |
|------|---------------------|--------------|---------------------|
| `--search` | ✅ Available | ❌ NOT available | `--enable web_search_request` |
| `-a/--ask-for-approval` | ✅ Available | ❌ NOT available | `--full-auto` or `-c approval_policy=...` |
| `--add-dir` | ✅ Available | ✅ Available | N/A |
| `--full-auto` | ✅ Available | ✅ Available | N/A |

**For web search in exec mode**:
```bash
# CORRECT - works in codex exec
codex exec --enable web_search_request "research topic"

# WRONG - --search only works in interactive mode
codex --search "research topic"
```

**For approval control in exec mode**:
```bash
# CORRECT - works in codex exec
codex exec --full-auto "task"
codex exec -c approval_policy=on-request "task"

# WRONG - -a only works in interactive mode
codex -a on-request "task"
```

---

## Trigger Examples

This skill activates when users say phrases like:
- "Use codex to analyze this architecture"
- "Ask codex about this design decision"
- "Run codex on this problem"
- "Call codex for help with this implementation"
- "I need GPT-5 reasoning for this task"
- "Get OpenAI's high-reasoning model on this"
- "Continue with codex" or "Resume the codex session"
- "Codex, help me with..." or simply "Codex"

## When to Use This Skill

This skill should be invoked when:
- User explicitly mentions "Codex" or requests Codex assistance
- User needs help with complex coding tasks, algorithms, or architecture
- User requests "high reasoning" or "advanced implementation" help
- User needs complex problem-solving or architectural design
- User wants to continue a previous Codex conversation

## How It Works

### Detecting New Codex Requests

When a user makes a request, first determine the task type (code vs general), then determine sandbox based on explicit edit request:

**Step 1: Determine Task Type (Model Selection)**
- **Code-related tasks**: Use `gpt-5.3-codex` - for implementation, refactoring, code analysis, debugging, etc.
- **General tasks**: Use `gpt-5.2` - for architecture design, explanations, reviews, documentation, etc.

**Step 2: Determine Sandbox (Edit Permission)**
- **Default**: `read-only` - safe for all tasks unless user explicitly requests editing
- **Explicit edit request**: `workspace-write` - ONLY when user explicitly says to edit/modify/write files

**Code-related task examples**:
- Read-only: "Analyze this function", "Review this implementation", "Debug this code"
- With editing: "Edit this file to fix the bug", "Modify the function", "Refactor and save"

**General task examples**:
- Read-only: "Design a queue data structure", "Explain this algorithm", "Review the architecture"
- With editing: "Update the documentation file", "Modify the README"

**⚠️ Important**: The key distinction for sandbox is whether the user explicitly asks for file modifications. Use `workspace-write` ONLY when user says "edit", "modify", "write changes", "save", etc.

### Bash CLI Command Structure

See the [DEFAULT MODEL](#default-model-task-based-model-selection-with-read-only-default) section above for complete command templates. Key points:

- Always use `codex exec` (non-interactive mode required)
- Add `--enable web_search_request` for research tasks
- See `references/command-patterns.md` for additional patterns

### Model Selection Logic

**Step 1: Choose Model Based on Task Type**

**Use `gpt-5.3-codex` for code-related tasks:**
- Implementation, refactoring, code analysis
- Debugging, fixing bugs, optimization
- Any task involving code understanding or modification

**Use `gpt-5.2` for general tasks:**
- Architecture and system design
- Explanations, documentation, reviews
- Planning, strategy, general reasoning

**Step 2: Choose Sandbox Based on Edit Intent**

**Use `read-only` (DEFAULT):**
- Analysis, review, explanation tasks
- ANY task where user does NOT explicitly request file editing

**Use `workspace-write` (ONLY when explicitly requested):**
- User explicitly says "edit this file", "modify the code", "write changes"
- User explicitly asks to "make edits" or "save the changes"
- User explicitly requests "refactor and save" or "implement and write"

**Fallback**: If primary model unavailable, fallback to the other 5.2 variant. See fallback chain in DEFAULT MODEL section.

### Default Configuration

All Codex invocations use these defaults unless user specifies otherwise:

| Parameter | Default Value | CLI Flag | Notes |
|-----------|---------------|----------|-------|
| Model (code tasks) | `gpt-5.3-codex` | `-m gpt-5.3-codex` | For code-related tasks |
| Model (general tasks) | `gpt-5.2` | `-m gpt-5.2` | For general tasks |
| Sandbox (default) | `read-only` | `-s read-only` | Safe default for ALL tasks |
| Sandbox (explicit edit) | `workspace-write` | `-s workspace-write` | Only when user explicitly requests editing |
| Reasoning Effort | `xhigh` | `-c model_reasoning_effort=xhigh` | Maximum reasoning capability |
| Verbosity | `medium` | `-c model_verbosity=medium` | Balanced output detail |
| Web Search | `enabled` | `--enable web_search_request` | Access to up-to-date information |

### CLI Flags Reference

**Codex CLI Version**: 0.98.0+

**See**: `references/cli-features.md` for the complete CLI flags table and feature documentation.

**Key flags for this skill**:
- `-m, --model` - Model selection (`gpt-5.3-codex`, `gpt-5.2`)
- `-s, --sandbox` - Sandbox mode (`read-only`, `workspace-write`)
- `-c, --config` - Config overrides (e.g., `model_reasoning_effort=xhigh`)
- `--enable` / `--disable` - Feature toggles (e.g., `web_search_request`)

### Configuration Parameters

Pass these as `-c key=value`:

- `model_reasoning_effort`: `minimal`, `low`, `medium`, `high`, `xhigh`
  - **CLI default**: `high` - The Codex CLI defaults to high reasoning
  - **Skill default**: `xhigh` - This skill explicitly uses xhigh for maximum capability
  - **`xhigh`**: Extra-high reasoning for maximum capability (supported by gpt-5.2 models)
  - Use `xhigh` for complex architectural refactoring, long-horizon tasks, or when quality is more important than speed
- `model_verbosity`: `low`, `medium`, `high` (default: `medium`)
- `model_reasoning_summary`: `auto`, `concise`, `detailed`, `none` (default: `auto`)
- `sandbox_workspace_write.writable_roots`: JSON array of additional writable directories (e.g., `["/path1","/path2"]`)
- `approval_policy`: `untrusted`, `on-failure`, `on-request`, `never` (approval behavior)

**Additional Writable Directories**:

Use `--add-dir` flag (preferred) or config:
```bash
# Using --add-dir for multiple directories
codex exec --add-dir /path1 --add-dir /path2 "task"

# Alternative - config approach
codex exec -c 'sandbox_workspace_write.writable_roots=["/path1","/path2"]' "task"
```

### Model Selection Guide

**Available Models**:
- `gpt-5.3-codex` - Code tasks (implementation, refactoring, debugging)
- `gpt-5.2` - General tasks (architecture, reviews, explanations)

**Default**: `gpt-5.3-codex` for code tasks, `gpt-5.2` for general tasks with `xhigh` reasoning effort.

## Session Continuation

### Detecting Continuation Requests

When user indicates they want to continue a previous Codex conversation:
- Keywords: "continue", "resume", "keep going", "add to that"
- Follow-up context referencing previous Codex work
- Explicit request like "continue where we left off"

### Resuming Sessions

For continuation requests, use the `codex resume` command:

#### Resume Most Recent Session (Recommended)

```bash
codex exec resume --last
```

This automatically continues the most recent Codex session with all previous context maintained.

#### Resume Specific Session

```bash
codex exec resume <session-id>
```

Resume a specific session by providing its UUID. Get session IDs from previous Codex output or by running `codex exec resume --last` to see the most recent session.

**Note**: The interactive session picker (`codex resume` without arguments) is NOT available in non-interactive/Claude Code environments. Always use `--last` or provide explicit session ID.

### Forking Sessions (Interactive Only)

The `codex fork` command creates a new session from a previous one, allowing exploration of different directions without affecting the original session.

```bash
# Fork the most recent session (interactive terminal only)
codex fork --last

# Fork a specific session by ID (interactive terminal only)
codex fork <session-id>
```

**⚠️ Important**: `codex fork` is an **interactive-only** command. It is NOT available under `codex exec` and will fail with "stdin is not a terminal" in Claude Code's non-interactive environment.

**Workaround for Claude Code**: To achieve similar functionality, use `codex exec resume --last` with a prompt that indicates you want to explore an alternative approach. The session history will be preserved.

**Note**: Unlike `resume` which continues the same session, `fork` creates a new independent session with the same history as a starting point.

### Decision Logic: New vs. Continue

**Use `codex exec -m ... "<prompt>"`** when:
- User makes a new, independent request
- No reference to previous Codex work
- User explicitly wants a "fresh" or "new" session

**Use `codex exec resume --last`** when:
- User indicates continuation ("continue", "resume", "add to that")
- Follow-up question building on previous Codex conversation
- Iterative development on same task
- User wants to explore alternatives (provide new direction in prompt)

### Session History Management

- Codex CLI automatically saves session history
- No manual session ID tracking needed
- Sessions persist across Claude Code restarts
- Use `codex exec resume --last` to access most recent session
- Use `codex exec resume <session-id>` for specific sessions

## Error Handling

### Simple Error Response Strategy

When errors occur, return clear, actionable messages without complex diagnostics:

**Error Message Format:**
```
Error: [Clear description of what went wrong]

To fix: [Concrete remediation action]

[Optional: Specific command example]
```

### Common Errors

#### Command Not Found

```
Error: Codex CLI not found

To fix: Install Codex CLI and ensure it's available in your PATH

Check installation: codex --version
```

#### Authentication Required

```
Error: Not authenticated with Codex

To fix: Run 'codex login' to authenticate

After authentication, try your request again.
```

#### Invalid Configuration

```
Error: Invalid model specified

To fix:
- For coding tasks: Use 'gpt-5.3-codex' with workspace-write sandbox
- For reasoning tasks: Use 'gpt-5.2' with read-only sandbox

Example (coding): codex exec -m gpt-5.3-codex -s workspace-write -c model_reasoning_effort=xhigh "implement feature"
Example (reasoning): codex exec -m gpt-5.2 -s read-only -c model_reasoning_effort=xhigh "explain architecture"
```

### Troubleshooting

**First Steps for Any Issues:**
1. Check Codex CLI built-in help: `codex --help`, `codex exec --help`, `codex exec resume --help`
2. Consult official documentation: [https://github.com/openai/codex/tree/main/docs](https://github.com/openai/codex/tree/main/docs)
3. Verify skill resources in `references/` directory

**Note**: Commands like `codex --help`, `codex --version`, `codex login`, and `codex logout` work without the `exec` subcommand. The `exec` requirement only applies to task execution.

**Skill not being invoked?**
- Check that request matches trigger keywords (Codex, complex coding, high reasoning, etc.)
- Explicitly mention "Codex" in your request
- Try: "Use Codex to help me with..."

**Session not resuming?**
- Verify you have a previous Codex session (check command output for session IDs)
- Try: `codex exec resume --last` to resume most recent session
- If no history exists, start a new session first

**"stdout is not a terminal" error?**
- Always use `codex exec` instead of plain `codex` in Claude Code
- Claude Code's bash environment is non-interactive/non-terminal

**Errors during execution?**
- Codex CLI errors are passed through directly
- Check Codex CLI logs for detailed diagnostics
- Verify working directory permissions if using workspace-write
- Check official Codex docs for latest updates and known issues

## Examples

### Code Analysis (Read-Only)
```bash
codex exec -m gpt-5.3-codex -s read-only \
  -c model_reasoning_effort=xhigh \
  "Analyze this function implementation"
```

### Code Editing (Explicit Request)
```bash
codex exec -m gpt-5.3-codex -s workspace-write \
  -c model_reasoning_effort=xhigh \
  "Edit this file to implement the feature"
```

### Session Continuation
```bash
codex exec resume --last
```

**See**: `references/examples.md` for more examples including web search, file context, and code review patterns.

---

## Code Review Subcommand (v0.71.0+)

The `codex review` subcommand provides non-interactive code review capabilities:

```bash
# Review uncommitted changes (staged, unstaged, untracked)
codex review --uncommitted

# Review changes against a base branch
codex review --base main

# Review a specific commit
codex review --commit abc123

# Review with custom instructions
codex review --uncommitted "Focus on security vulnerabilities"

# Non-interactive via exec
codex exec review --uncommitted
```

**Review Options**:
| Flag | Description |
|------|-------------|
| `--uncommitted` | Review staged, unstaged, and untracked changes |
| `--base <BRANCH>` | Review changes against the given base branch |
| `--commit <SHA>` | Review the changes introduced by a commit |
| `--title <TITLE>` | Optional commit title for review summary |

---

## Apply Command (v0.98.0+)

The `codex apply` command applies the latest diff produced by the Codex agent as a `git apply` to your local working tree:

```bash
# Apply the latest diff from Codex
codex apply
```

This is useful when Codex generates code changes in read-only mode and you want to apply those changes to your local files.

---

## CLI Features Reference

For detailed CLI feature documentation, see `references/cli-features.md`.

**Quick Reference** - Common features:
- `--enable web_search_request` - Enable web search
- `-i, --image` - Attach images to prompts
- `--add-dir` - Add writable directories
- `--full-auto` - Low-friction workspace-write mode
- `--json` - JSONL output for programmatic processing

---

## File Context Passing

**IMPORTANT**: Pass file paths to Codex CLI instead of embedding file content in prompts. This enables Codex to read files autonomously.

**Quick reference**:
- Use `-C /path` to set working directory
- Use `--add-dir /path` for additional directories
- Use `@path/to/file` syntax for explicit file references

```bash
# Example: analyze file with explicit @ syntax
codex exec -m gpt-5.3-codex -s read-only \
  "Analyze @src/auth.ts and compare with @src/session.ts"

# Example: multi-directory analysis
codex exec -m gpt-5.3-codex -s read-only \
  --add-dir /shared/libs \
  "Review how auth module uses shared utilities"
```

**See**: `references/file-context.md` for complete file context documentation.

---

## Best Practices

### 1. Use Descriptive Requests

**Good**: "Help me implement a thread-safe queue with priority support in Python"
**Vague**: "Code help"

Clear, specific requests get better results from high-reasoning models.

### 2. Indicate Continuation Clearly

**Good**: "Continue with that queue implementation - add unit tests"
**Unclear**: "Add tests" (might start new session)

Explicit continuation keywords help the skill choose the right command.

### 3. Specify Permissions When Needed

**Good**: "Refactor this code (allow file writing)"
**Risky**: Assuming permissions without specifying

Make your intent clear when you need workspace-write permissions.

### 4. Leverage High Reasoning

The skill defaults to high reasoning effort - perfect for:
- Complex algorithms
- Architecture design
- Performance optimization
- Security reviews

## Reference Documentation

For detailed information, consult these reference files:

### Core References
- **`references/file-context.md`** - File and directory context passing guide
- **`references/examples.md`** - Complete command examples by use case
- **`references/cli-features.md`** - Feature flags and CLI options

### Workflow References
- **`references/command-patterns.md`** - Common codex exec usage patterns
- **`references/session-workflows.md`** - Session continuation and resume workflows
- **`references/advanced-patterns.md`** - Complex configuration and flag combinations

### CLI References
- **`references/codex-help.md`** - Codex CLI command reference
- **`references/codex-config.md`** - Full configuration options
