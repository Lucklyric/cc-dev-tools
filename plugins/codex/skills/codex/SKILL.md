---
name: codex
version: 1.4.0
description: Invoke Codex CLI for complex coding tasks requiring high reasoning capabilities. This skill should be invoked when users explicitly mention "Codex", request complex implementation challenges, advanced reasoning, or need high-reasoning model assistance. Automatically triggers on codex-related requests and supports session continuation for iterative development.
---

# Codex: High-Reasoning AI Assistant for Claude Code

---

## DEFAULT MODEL: GPT-5.1-Codex-Max with xhigh Reasoning

**The default model for ALL Codex invocations is `gpt-5.1-codex-max` with `xhigh` reasoning effort.**

- Always use `gpt-5.1-codex-max` with `-c model_reasoning_effort=xhigh` unless user explicitly requests otherwise
- This provides maximum reasoning capability (27-42% faster, 30% fewer thinking tokens)
- Use `workspace-write` sandbox for code editing, `read-only` for analysis only

```bash
# Default invocation - ALWAYS use gpt-5.1-codex-max with xhigh
codex exec -m gpt-5.1-codex-max -s workspace-write \
  -c model_reasoning_effort=xhigh \
  "your prompt here"
```

---

## CRITICAL: Always Use `codex exec`

**MUST USE**: `codex exec` for ALL Codex CLI invocations in Claude Code.

**NEVER USE**: `codex` (interactive mode) - will fail with "stdout is not a terminal"
**ALWAYS USE**: `codex exec` (non-interactive mode)

**Examples:**
- `codex exec -m gpt-5.1 "prompt"` (CORRECT)
- `codex -m gpt-5.1 "prompt"` (WRONG - will fail)
- `codex exec resume --last` (CORRECT)
- `codex resume --last` (WRONG - will fail)

**Why?** Claude Code's bash environment is non-terminal/non-interactive. Only `codex exec` works in this environment.

---

## When to Use This Skill

This skill should be invoked when:
- User explicitly mentions "Codex" or requests Codex assistance
- User needs help with complex coding tasks, algorithms, or architecture
- User requests "high reasoning" or "advanced implementation" help
- User needs complex problem-solving or architectural design
- User wants to continue a previous Codex conversation

## How It Works

### Detecting New Codex Requests

When a user makes a request that falls into one of the above categories, determine the task type:

**General Tasks** (architecture, design, reviews, explanations):
- Use model: `gpt-5.1` (high-reasoning general model)
- Example requests: "Design a queue data structure", "Review this architecture", "Explain this algorithm"

**Code Editing Tasks** (file modifications, implementation):
- Use model: `gpt-5.1-codex-max` (maximum capability for code editing - 27-42% faster)
- Example requests: "Edit this file to add feature X", "Implement the function", "Refactor this code"

### Bash CLI Command Structure

**IMPORTANT**: Always use `codex exec` for non-interactive execution. Claude Code's bash environment is non-terminal, so the interactive `codex` command will fail with "stdout is not a terminal" error.

#### For Code Editing Tasks (Default)

```bash
codex exec -m gpt-5.1-codex-max -s workspace-write \
  -c model_reasoning_effort=xhigh \
  --enable web_search_request \
  "<user's prompt>"
```

#### For Read-Only Analysis Tasks

```bash
codex exec -m gpt-5.1-codex-max -s read-only \
  -c model_reasoning_effort=xhigh \
  --enable web_search_request \
  "<user's prompt>"
```

**Why `codex exec`?**
- Non-interactive mode required for automation and Claude Code integration
- Produces clean output suitable for parsing
- Works in non-TTY environments (like Claude Code's bash)

### Model Selection Logic

**Use `gpt-5.1` (default) when:**
- Designing architecture or data structures
- Reviewing code for quality, security, or performance
- Explaining concepts or algorithms
- Planning implementation strategies
- General problem-solving and reasoning

**Use `gpt-5.1-codex-max` when:**
- Editing or modifying existing code files
- Implementing specific functions or features
- Refactoring code
- Writing new code with file I/O
- Any task requiring `workspace-write` sandbox
- Complex code editing requiring maximum reasoning capability

**Note**: For backward compatibility, `gpt-5.1-codex` (standard model) is still available and works identically. Use `gpt-5.1-codex-max` as the default for better performance (27-42% faster, 30% fewer thinking tokens).

### Default Configuration

All Codex invocations use these defaults unless user specifies otherwise:

| Parameter | Default Value | CLI Flag | Notes |
|-----------|---------------|----------|-------|
| Model | `gpt-5.1-codex-max` | `-m gpt-5.1-codex-max` | Default for ALL tasks (27-42% faster) |
| Sandbox | `workspace-write` | `-s workspace-write` | Allows file modifications (default) |
| Sandbox (analysis) | `read-only` | `-s read-only` | For read-only analysis tasks |
| Reasoning Effort | `xhigh` | `-c model_reasoning_effort=xhigh` | Maximum reasoning capability |
| Verbosity | `medium` | `-c model_verbosity=medium` | Balanced output detail |
| Web Search | `enabled` | `--enable web_search_request` | Access to up-to-date information |

### CLI Flags Reference

**Codex CLI Version**: 0.59.0+ (requires 0.59.0+ for gpt-5.1-codex-max support)

| Flag | Values | Description |
|------|--------|-------------|
| `-m, --model` | `gpt-5.1`, `gpt-5.1-codex`, `gpt-5.1-codex-max` | Model selection |
| `-s, --sandbox` | `read-only`, `workspace-write`, `danger-full-access` | Sandbox mode |
| `-c, --config` | `key=value` | Config overrides (e.g., `model_reasoning_effort=high`) |
| `-C, --cd` | directory path | Working directory |
| `-p, --profile` | profile name | Use config profile |
| `--enable` | feature name | Enable a feature (e.g., `web_search_request`) |
| `--disable` | feature name | Disable a feature |
| `-i, --image` | file path(s) | Attach image(s) to initial prompt |
| `--full-auto` | flag | Convenience for workspace-write sandbox with on-failure approval |
| `--oss` | flag | Use local open source model provider |
| `--skip-git-repo-check` | flag | Allow running outside Git repository |
| `--output-schema` | file path | JSON Schema file for response shape |
| `--color` | `always`, `never`, `auto` | Color settings for output |
| `--json` | flag | Print events as JSONL |
| `-o, --output-last-message` | file path | Save last message to file |
| `--dangerously-bypass-approvals-and-sandbox` | flag | Skip confirmations (DANGEROUS) |

### Configuration Parameters

Pass these as `-c key=value`:

- `model_reasoning_effort`: `minimal`, `low`, `medium`, `high`, `xhigh` (default: `high`)
  - **`xhigh`**: Extra-high reasoning for maximum capability (gpt-5.1-codex-max only)
  - Use `xhigh` for complex architectural refactoring, long-horizon tasks, or when quality is more important than speed
- `model_verbosity`: `low`, `medium`, `high` (default: `medium`)
- `model_reasoning_summary`: `auto`, `concise`, `detailed`, `none` (default: `auto`)
- `sandbox_workspace_write.writable_roots`: JSON array of additional writable directories (e.g., `["/path1","/path2"]`)

**Note**: To specify additional writable directories beyond the workspace, use:
```bash
-c 'sandbox_workspace_write.writable_roots=["/path1","/path2"]'
```
This replaces the removed `--add-dir` flag from earlier versions.

### Model Selection Guide

**Default Models (Codex CLI v0.59.0+)**

This skill defaults to the GPT-5.1 model family:
- `gpt-5.1` - General reasoning, architecture, reviews (default)
- `gpt-5.1-codex-max` - Code editing and implementation (default for code tasks)
- `gpt-5.1-codex` - Standard code editing (available for backward compatibility)

**Performance Characteristics**:
- `gpt-5.1-codex-max` is 27-42% faster than `gpt-5.1-codex`
- Uses ~30% fewer thinking tokens at the same reasoning effort level
- Supports new `xhigh` reasoning effort for maximum capability
- Requires Codex CLI 0.59.0+ and ChatGPT Plus/Pro/Business/Edu/Enterprise subscription

**Backward Compatibility**

You can override to use older models when needed:

```bash
# Use older gpt-5 model explicitly
codex exec -m gpt-5 -s read-only "Design a data structure"

# Use older gpt-5-codex model explicitly
codex exec -m gpt-5-codex -s workspace-write "Implement feature X"
```

**When to Override**

- **Testing compatibility**: Verify behavior matches older model versions
- **Specific model requirements**: Project requires specific model version
- **Model comparison**: Compare outputs between model versions

**Model Override Examples**

Override via `-m` flag:
```bash
# Override to gpt-5 for general task
codex exec -m gpt-5 "Explain algorithm complexity"

# Override to gpt-5-codex for code task
codex exec -m gpt-5-codex -s workspace-write "Refactor authentication"

# Override to gpt-4 if available
codex exec -m gpt-4 "Review this code"
```

**Default Behavior**

Without explicit `-m` override:
- General tasks → `gpt-5.1`
- Code editing tasks → `gpt-5.1-codex-max` (recommended for best performance)
- Backward compatibility → `gpt-5.1-codex` still works if explicitly specified

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

### Decision Logic: New vs. Continue

**Use `codex exec -m ... "<prompt>"`** when:
- User makes a new, independent request
- No reference to previous Codex work
- User explicitly wants a "fresh" or "new" session

**Use `codex exec resume --last`** when:
- User indicates continuation ("continue", "resume", "add to that")
- Follow-up question building on previous Codex conversation
- Iterative development on same task

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

To fix: Use 'gpt-5.1' for general reasoning or 'gpt-5.1-codex-max' for code editing (gpt-5.1-codex also available for backward compatibility)

Example: codex exec -m gpt-5.1 "your prompt here"
Example: codex exec -m gpt-5.1-codex-max -s workspace-write "code editing task"
```

### Troubleshooting

**First Steps for Any Issues:**
1. Check Codex CLI built-in help: `codex --help`, `codex exec --help`, `codex exec resume --help`
2. Consult official documentation: [https://github.com/openai/codex/tree/main/docs](https://github.com/openai/codex/tree/main/docs)
3. Verify skill resources in `references/` directory

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

### Example 1: Architecture Design Task

**User Request**: "Help me design a binary search tree architecture in Rust"

**Skill Executes**:
```bash
codex exec -m gpt-5.1-codex-max -s read-only \
  -c model_reasoning_effort=xhigh \
  "Help me design a binary search tree architecture in Rust"
```

**Result**: Codex provides maximum reasoning architectural guidance using gpt-5.1-codex-max with xhigh reasoning. Session automatically saved for continuation.

---

### Example 2: Code Editing Task

**User Request**: "Edit this file to implement the BST insert method"

**Skill Executes**:
```bash
codex exec -m gpt-5.1-codex-max -s workspace-write \
  -c model_reasoning_effort=xhigh \
  "Edit this file to implement the BST insert method"
```

**Result**: Codex uses gpt-5.1-codex-max with xhigh reasoning and workspace-write permissions to modify files.

---

### Example 3: Session Continuation

**User Request**: "Continue with the BST - add a deletion method"

**Skill Executes**:
```bash
codex exec resume --last
```

**Result**: Codex resumes the previous BST session and continues with deletion method implementation, maintaining full context.

---

### Example 4: With Web Search

**User Request**: "Use Codex with web search to research and implement async patterns"

**Skill Executes**:
```bash
codex exec -m gpt-5.1-codex-max -s workspace-write \
  -c model_reasoning_effort=xhigh \
  --enable web_search_request \
  "Research and implement async patterns"
```

**Result**: Codex uses web search capability for latest information, then implements with xhigh reasoning and maximum code editing capability.

---

### Example 5: Complex Architectural Refactoring

**User Request**: "Perform complex architectural refactoring of authentication system"

**Skill Executes**:
```bash
codex exec -m gpt-5.1-codex-max -s workspace-write \
  -c model_reasoning_effort=xhigh \
  "Perform complex architectural refactoring of authentication system"
```

**Result**: Codex uses xhigh reasoning effort (default) for maximum capability on complex long-horizon tasks. Ideal for architectural refactoring where quality is critical.

---

## New in v0.53.0

### Feature Flags (`--enable` / `--disable`)
Enable or disable specific Codex features:
```bash
codex exec --enable web_search_request "Research latest patterns"
codex exec --disable some_feature "Run without feature"
```

### Image Attachment (`-i, --image`)
Attach images to prompts for visual analysis:
```bash
codex exec -i screenshot.png "Analyze this UI design"
codex exec -i diagram1.png -i diagram2.png "Compare these architectures"
```

### Non-Git Environments (`--skip-git-repo-check`)
Run Codex outside Git repositories:
```bash
codex exec --skip-git-repo-check "Help with this script"
```

### Structured Output (`--output-schema`)
Define JSON schema for model responses:
```bash
codex exec --output-schema schema.json "Generate structured data"
```

### Output Coloring (`--color`)
Control colored output (always, never, auto):
```bash
codex exec --color never "Run in CI/CD pipeline"
```

### Web Search Migration
**Deprecated**: `--search` flag (not available in `codex exec`)
**New**: Use `--enable web_search_request` instead
```bash
# Old (invalid for codex exec)
codex --search "research topic"

# New (correct)
codex exec --enable web_search_request "research topic"
```

---

## When to Use GPT-5.1 vs GPT-5.1-Codex-Max

### Use GPT-5.1 (General High-Reasoning) For:
- Architecture and system design
- Code reviews and quality analysis
- Security audits and vulnerability assessment
- Performance optimization strategies
- Algorithm design and analysis
- Explaining complex concepts
- Planning and strategy

### Use GPT-5.1-Codex-Max (Maximum Code Capability) For:
- Editing existing code files (27-42% faster than standard codex)
- Implementing specific features
- Refactoring and code transformations
- Writing new code with file I/O
- Code generation tasks
- Debugging and fixes requiring file changes
- Complex architectural refactoring (with `xhigh` reasoning effort)

### Use GPT-5.1-Codex (Standard Code Model) For:
- Backward compatibility scenarios
- When you need to replicate behavior from earlier versions
- Explicit requirement to use the standard (non-max) model

**Default**: When in doubt, use `gpt-5.1` for general tasks. Use `gpt-5.1-codex-max` when specifically editing code for best performance and quality.

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

## Platform & Capabilities (v0.53.0)

### Windows Sandbox Support
Windows sandbox is now available in alpha (experimental). Use with caution in production environments.

### Interactive Mode Features
The `/exit` slash-command alias is available in interactive `codex` mode (not applicable to `codex exec` non-interactive mode used by this skill).

### Model Verbosity Override
All code editing models (gpt-5.1-codex-max, gpt-5.1-codex) support verbosity override via `-c model_verbosity=<level>` for controlling output detail levels.

## Pattern References

For command construction examples and workflow patterns, Claude can reference:
- `references/command-patterns.md` - Common codex exec usage patterns
- `references/session-workflows.md` - Session continuation and resume workflows
- `references/advanced-patterns.md` - Complex configuration and flag combinations

These files provide detailed examples for constructing valid codex exec commands for various scenarios.

## Additional Resources

For more details, see:
- `references/codex-help.md` - Codex CLI command reference
- `references/codex-config.md` - Full configuration options
- `README.md` - Installation and quick start guide
