# Basic Usage Examples

---

## ⚠️ CRITICAL: Always Use `codex exec`

**ALL commands in this document use `codex exec` - this is mandatory in Claude Code.**

❌ **NEVER**: `codex -m ...` (will fail with "stdout is not a terminal")
✅ **ALWAYS**: `codex exec -m ...` (correct non-interactive mode)

Claude Code's bash environment is non-terminal. Plain `codex` commands will NOT work.

---

## Example 1: General Reasoning Task - Queue Design

### User Request
"Help me design a queue data structure in Python"

### What Happens

1. **Claude detects** the reasoning task (queue design)
2. **Skill is invoked** autonomously
3. **Codex CLI is called** with gpt-5.2 (high-reasoning general model):

```bash
codex exec -m gpt-5.2 -s read-only \
  -c model_reasoning_effort=xhigh \
  "Help me design a queue data structure in Python"
```

4. **Codex responds** with xhigh-reasoning architectural guidance on queue design
5. **Session is auto-saved** for potential continuation

### Expected Output

Codex provides:
- Queue design principles and trade-offs
- Multiple implementation approaches (list-based, deque, linked-list)
- Performance characteristics (O(1) enqueue/dequeue)
- Thread-safety considerations
- Usage examples and best practices

---

## Example 2: Code Editing Task - Implement Queue

### User Request
"Edit my Python file to implement the queue with thread-safety"

### What Happens

1. **Skill detects** code editing request
2. **Uses gpt-5.2-codex** (optimized for agentic coding - 56.4% SWE-Bench Pro):

```bash
codex exec -m gpt-5.2-codex -s workspace-write \
  -c model_reasoning_effort=xhigh \
  "Edit my Python file to implement the queue with thread-safety"
```

3. **Codex performs code editing** with xhigh reasoning capability
4. **Files are modified** (workspace-write sandbox)

### Expected Output

Codex:
- Edits the target Python file
- Implements thread-safe queue using `threading.Lock`
- Adds proper synchronization primitives
- Includes docstrings and type hints
- Provides usage examples

---

## Example 3: Explicit Codex Request

### User Request
"Use Codex to design a REST API for a blog system"

### What Happens

1. **Explicit "Codex" mention** triggers skill
2. **Codex invoked** with general reasoning settings:

```bash
codex exec -m gpt-5.2 -s read-only \
  -c model_reasoning_effort=xhigh \
  "Design a REST API for a blog system"
```

3. **xhigh-reasoning analysis** provides comprehensive API design

### Expected Output

Codex delivers:
- RESTful endpoint design (GET/POST/PUT/DELETE)
- Resource modeling (posts, authors, comments)
- Authentication and authorization strategy
- Data validation approaches
- API versioning recommendations
- Error handling patterns

---

## Example 4: Complex Algorithm Design

### User Request
"Help me implement a binary search tree with balancing"

### What Happens

```bash
codex exec -m gpt-5.2 -s read-only \
  -c model_reasoning_effort=xhigh \
  "Help me implement a binary search tree with balancing"
```

### Expected Output

Codex provides:
- BST fundamentals and invariants
- AVL vs Red-Black tree trade-offs
- Rotation algorithms (left, right, left-right, right-left)
- Insertion and deletion with rebalancing
- Complexity analysis
- Implementation guidance

---

## Example 5: Complex Refactoring with xhigh

### User Request
"Refactor the authentication system with comprehensive security improvements"

### What Happens

```bash
codex exec -m gpt-5.2-codex -s workspace-write \
  -c model_reasoning_effort=xhigh \
  "Refactor the authentication system with comprehensive security improvements"
```

### Expected Output

Codex provides:
- Deep architectural analysis of current system
- Comprehensive security vulnerability assessment
- Multi-layered refactoring strategy
- Implementation of security best practices
- Detailed reasoning about trade-offs
- Long-horizon planning for complex changes (native context compaction)

**Note**: xhigh is the default reasoning effort for all Codex invocations. gpt-5.2-codex has native context compaction ideal for long-horizon refactoring tasks.

---

## Model Selection Summary

| Task Type | Model | Sandbox | Reasoning | Example |
|-----------|-------|---------|-----------|---------|
| General reasoning | `gpt-5.2` | `read-only` | xhigh | "Design a queue" |
| Architecture design | `gpt-5.2` | `read-only` | xhigh | "Design REST API" |
| Code review | `gpt-5.2` | `read-only` | xhigh | "Review this code" |
| Code editing | `gpt-5.2-codex` | `workspace-write` | xhigh | "Edit file to add X" |
| Complex refactoring | `gpt-5.2-codex` | `workspace-write` | xhigh | "Refactor auth system" |
| Implementation | `gpt-5.2-codex` | `workspace-write` | xhigh | "Implement function Y" |

**Note**: `gpt-5.2-codex` is optimized for agentic coding (56.4% SWE-Bench Pro) with native context compaction. Always use `xhigh` reasoning effort for maximum capability.

### Fallback Chain
- **Coding**: `gpt-5.2-codex` → `gpt-5.2` → `gpt-5.1-codex-max`
- **Reasoning effort**: `xhigh` → `high` → `medium`

---

## Tips for Best Results

1. **Be specific** in your requests - detailed prompts get better reasoning
2. **Indicate task type** clearly (design vs. implementation)
3. **Mention permissions** when you need file writes ("allow file writing")
4. **Use continuation** for iterative development (see session-continuation.md)

---

## Next Steps

- **Continue a session**: See [session-continuation.md](./session-continuation.md)
- **Advanced config**: See [advanced-config.md](./advanced-config.md)
- **Full documentation**: See [../SKILL.md](../SKILL.md)
