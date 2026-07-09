# Advanced Configuration Examples

> **LEGACY — `exec`-mode only.** Since v3.1.0 the default codex workflow is tmux mode (see `tmux-mode.md`). The advanced flag combinations below apply to `codex exec` one-shots. In tmux mode (`pane`/`bind`/`new`), model and reasoning effort come from the `CC_CODEX_MODEL`/`CC_CODEX_EFFORT` env vars, and sandbox from `--full-auto`/`--read-only`.

---

## ⚠️ CRITICAL: Always Use `codex exec`

**ALL commands in this document use `codex exec` - this is mandatory in Claude Code.**

❌ **NEVER**: `codex -m ...` or `codex --flag ...` (will fail with "stdout is not a terminal")
✅ **ALWAYS**: `codex exec -m ...` or `codex exec --flag ...` (correct non-interactive mode)

Claude Code's bash environment is non-terminal. Plain `codex` commands will NOT work.

---

## Custom Model Selection

### Example 1: General Reasoning Task

**User Request**: "Review this code for architecture issues"

**Skill Executes**:
```bash
codex exec -m gpt-5.6-sol -s read-only \
  -c model_reasoning_effort=xhigh \
  "Review this code for architecture issues"
```

**Why**: Architectural review is a reasoning task - use gpt-5.6-sol with read-only sandbox.

---

### Example 2: Code Editing Task

**User Request**: "Implement the authentication module"

**Skill Executes**:
```bash
codex exec -m gpt-5.6-sol -s workspace-write \
  -c model_reasoning_effort=xhigh \
  -c sandbox_workspace_write.network_access=true \
  "Implement the authentication module"
```

**Why**: Implementation requires file writing and code generation - use gpt-5.6-sol with xhigh reasoning.

---

## Workspace Write Permission

### Example 3: Allow File Modifications

**User Request**: "Have Codex refactor this codebase (allow file writing)"

**Skill Executes**:
```bash
codex exec -m gpt-5.6-sol -s workspace-write \
  -c model_reasoning_effort=xhigh \
  -c sandbox_workspace_write.network_access=true \
  "Refactor this codebase for better maintainability"
```

**Permission**: `workspace-write` allows Codex to modify files directly.

⚠️ **Warning**: Only use `workspace-write` when you trust the operation and want file modifications.

---

### Example 4: Read-Only Code Review

**User Request**: "Review this code for security vulnerabilities (read-only)"

**Skill Executes**:
```bash
codex exec -m gpt-5.6-sol -s read-only \
  -c model_reasoning_effort=xhigh \
  "Review this code for security vulnerabilities"
```

**Permission**: `read-only` prevents file modifications - safer for review tasks.

---

## Web Search Integration

### Example 5: Research Latest Patterns

**User Request**: "Research latest Python async patterns and implement them (enable web search)"

**Skill Executes**:
```bash
codex exec -m gpt-5.6-sol -s workspace-write \
  -c model_reasoning_effort=xhigh \
  -c sandbox_workspace_write.network_access=true \
  "Research latest Python async patterns and implement them"
```

**Feature**: web search is built-in on supported models — no flag needed in `codex exec` (the old `--enable web_search_request` flag is deprecated).

---

### Example 6: Security Best Practices Research

**User Request**: "Use web search to find latest JWT security best practices, then review this auth code"

**Skill Executes**:
```bash
codex exec -m gpt-5.6-sol -s read-only \
  -c model_reasoning_effort=xhigh \
  "Find latest JWT security best practices and review this auth code"
```

---

## Reasoning Effort Control

### Example 7: Maximum Reasoning for Complex Algorithm

**User Request**: "Design an optimal algorithm for distributed consensus (maximum reasoning)"

**Skill Executes**:
```bash
codex exec -m gpt-5.6-sol -s read-only \
  -c model_reasoning_effort=xhigh \
  "Design an optimal algorithm for distributed consensus"
```

**Default**: Already uses `xhigh` reasoning effort.

---

### Example 8: Quick Code Review (Lower Reasoning)

**User Request**: "Quick syntax check on this code (low reasoning)"

**Skill Executes**:
```bash
codex exec -m gpt-5.6-sol -s read-only \
  -c model_reasoning_effort=low \
  "Quick syntax check on this code"
```

**Use Case**: Fast turnaround for simple tasks. Override xhigh when speed matters more than depth.

---

## Verbosity Control

### Example 9: Detailed Explanation

**User Request**: "Explain this algorithm in detail (high verbosity)"

**Skill Executes**:
```bash
codex exec -m gpt-5.6-sol -s read-only \
  -c model_reasoning_effort=xhigh \
  -c model_verbosity=high \
  "Explain this algorithm in detail"
```

**Output**: Comprehensive, detailed explanation.

---

### Example 10: Concise Summary

**User Request**: "Briefly review this code (low verbosity)"

**Skill Executes**:
```bash
codex exec -m gpt-5.6-sol -s read-only \
  -c model_reasoning_effort=xhigh \
  -c model_verbosity=low \
  "Review this code"
```

**Output**: Concise, focused feedback.

---

## Working Directory Control

### Example 11: Specific Project Directory

**User Request**: "Work in the backend directory and review the API code"

**Skill Executes**:
```bash
codex exec -m gpt-5.6-sol -s read-only \
  -c model_reasoning_effort=xhigh \
  -C ./backend \
  "Review the API code"
```

**Feature**: `-C` flag sets working directory for Codex.

---

## Approval Policy

### Example 12: Request Approval for Shell Commands

**User Request**: "Implement the build script (ask before running commands)"

**Skill Executes**:
```bash
codex exec -m gpt-5.6-sol -s workspace-write \
  -c model_reasoning_effort=xhigh \
  -c sandbox_workspace_write.network_access=true \
  -c approval_policy=on-request \
  "Implement the build script"
```

**Safety**: `approval_policy=on-request` requires approval before executing shell commands.

**Note**: `-a`/`--ask-for-approval` is interactive-only. Use `-c approval_policy=on-request` in `codex exec`.

---

## Combined Advanced Configuration

### Example 13: Full-Featured Request

**User Request**: "Use web search to find latest security practices, review my auth module in detail with high reasoning, allow file fixes if needed (ask for approval)"

**Skill Executes**:
```bash
codex exec -m gpt-5.6-sol -s workspace-write \
  -c model_reasoning_effort=xhigh \
  -c sandbox_workspace_write.network_access=true \
  -c model_verbosity=high \
  -c approval_policy=on-request \
  "Find latest security practices, review my auth module in detail, and fix issues"
```

**Features**:
- Web search built-in (no flag needed; `--enable web_search_request` is deprecated)
- Maximum reasoning (`model_reasoning_effort=xhigh`)
- Detailed output (`model_verbosity=high`)
- File writing allowed (`workspace-write`)
- Requires approval for commands (`-c approval_policy=on-request`)

---

## Model Selection: the GPT-5.6 series

**GPT-5.6-Sol** (default):
- Architecture, design, analysis, code editing, implementation, refactoring
- Long-horizon tasks with native context compaction
- Default `-c model_reasoning_effort=xhigh`; escalate to `max`/`ultra` for the hardest problems

**GPT-5.6-Terra** (balanced, cost-aware):
- Everyday coding and moderate reviews at lower cost than sol

**GPT-5.6-Luna** (fast & affordable):
- Quick syntax checks, simple reviews, high-volume work
- When user explicitly requests speed/fast mode (tops out at `max`, no `ultra`)

---

## Sandbox Mode Decision Matrix

| Task | Recommended Sandbox | Rationale |
|------|---------------------|-----------|
| Code review | `read-only` | No modifications needed |
| Architecture design | `read-only` | Planning phase only |
| Security audit | `read-only` | Analysis without changes |
| Implement feature | `workspace-write` | Requires file modifications |
| Refactor code | `workspace-write` | Must edit existing files |
| Generate new files | `workspace-write` | Creates new files |
| Bug fix | `workspace-write` | Edits source files |

---

## Configuration Profiles

### Create a Config Profile

You can create reusable configuration profiles in `~/.codex/config.toml`:

```toml
[profiles.review]
model = "gpt-5.6-sol"
sandbox = "read-only"
model_reasoning_effort = "xhigh"
model_verbosity = "medium"

[profiles.implement]
model = "gpt-5.6-sol"
sandbox = "workspace-write"
model_reasoning_effort = "xhigh"
approval_policy = "on-request"
```

### Use Profile in Skill

**User Request**: "Use the review profile to analyze this code"

**Skill Executes**:
```bash
codex exec -p review "Analyze this code"
```

**Result**: Uses all settings from `[profiles.review]`.

---

## Best Practices

### 1. Pick the GPT-5.6 model + effort by task

- **Default**: `gpt-5.6-sol` with xhigh reasoning (escalate to `max`/`ultra` for the hardest problems)
- **Cost-aware / everyday**: `gpt-5.6-terra` (high/xhigh)
- **Speed**: `gpt-5.6-luna` and/or a lower effort; the `-fast` service tier (`gpt-5.6-sol-fast`) needs API-key auth

### 2. Use Safe Defaults, Override Intentionally

- Default to `read-only` unless file writing is explicitly needed
- Default to `xhigh` reasoning for all tasks (maximum capability)
- Reduce reasoning effort only for simple, quick tasks

### 3. Combine Web Search with xhigh Reasoning

For best results researching current practices:
```bash
codex exec -m gpt-5.6-sol -s read-only \
  -c model_reasoning_effort=xhigh \
  "Research latest distributed systems patterns"
```

### 4. Request Approval for Risky Operations

Use `-c approval_policy=on-request` (in `codex exec`) when:
- Working with production code
- Running shell commands
- Making broad changes

**Note**: `-a`/`--ask-for-approval` is interactive-only. In `codex exec`, use `-c approval_policy=on-request`.

---

## Common Patterns

### Pattern 1: Research → Design → Implement

**Phase 1 - Research** (GPT-5.6-Sol + web search):
```bash
codex exec -m gpt-5.6-sol -s read-only \
  -c model_reasoning_effort=xhigh \
  "Research latest authentication patterns"
```

**Phase 2 - Design** (GPT-5.6-Sol + xhigh reasoning):
```bash
codex exec resume --last
# "Design the authentication system based on research"
```

**Phase 3 - Implement** (GPT-5.6-Sol + workspace-write):
```bash
codex exec -m gpt-5.6-sol -s workspace-write \
  -c model_reasoning_effort=xhigh \
  -c sandbox_workspace_write.network_access=true \
  "Implement the authentication system we designed"
```

---

### Pattern 2: Review → Fix → Verify

**Review** (GPT-5.6-Sol + read-only):
```bash
codex exec -m gpt-5.6-sol -s read-only \
  -c model_reasoning_effort=xhigh \
  "Review this code for security issues"
```

**Fix** (GPT-5.6-Sol + workspace-write):
```bash
codex exec resume --last
# "Fix the security issues identified"
```

**Verify** (GPT-5.6-Sol + read-only):
```bash
codex exec resume --last
# "Verify the fixes are correct"
```

---

## Next Steps

- **Basic usage**: See [command-patterns.md](./command-patterns.md)
- **Session continuation**: See [session-workflows.md](./session-workflows.md)
- **Full documentation**: See [../SKILL.md](../SKILL.md)
- **CLI reference**: See [codex-help.md](./codex-help.md)
- **Config reference**: See [codex-config.md](./codex-config.md)
