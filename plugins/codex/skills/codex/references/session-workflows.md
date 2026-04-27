# Session Continuation Examples

---

## ⚠️ CRITICAL: Always Use `codex exec`

**ALL commands in this document use `codex exec` - this is mandatory in Claude Code.**

❌ **NEVER**: `codex resume ...` (will fail with "stdout is not a terminal")
✅ **ALWAYS**: `codex exec resume ...` (correct non-interactive mode)

Claude Code's bash environment is non-terminal. Plain `codex` commands will NOT work.

---

## Example 1: Basic Session Continuation

### Initial Request
**User**: "Help me design a queue data structure in Python"

**Skill Executes**:
```bash
codex exec -m gpt-5.5 -s read-only \
  -c model_reasoning_effort=xhigh \
  "Help me design a queue data structure in Python"
```

**Codex Response**: Provides queue design with multiple approaches.

**Session Auto-Saved**: Codex CLI saves this session automatically.

---

### Follow-Up Request
**User**: "Continue with that queue - now add thread-safety"

**Skill Detects**: Continuation keywords ("continue with that")

**Skill Executes**:
```bash
codex exec resume --last
```

**Codex Response**: Resumes previous session, maintains context about the queue design, and adds thread-safety implementation building on the previous discussion.

**Context Maintained**: All previous conversation history is available to Codex.

---

## Example 2: Multi-Turn Iterative Development

### Turn 1: Initial Design
**User**: "Design a REST API for a blog system"

```bash
codex exec -m gpt-5.5 -s read-only \
  -c model_reasoning_effort=xhigh \
  "Design a REST API for a blog system"
```

**Output**: API endpoint design, resource modeling, etc.

---

### Turn 2: Add Authentication
**User**: "Add authentication to that API design"

**Skill Executes**:
```bash
codex exec resume --last
```

**Output**: Codex continues from previous API design and adds JWT/OAuth authentication strategy.

---

### Turn 3: Add Error Handling
**User**: "Now add comprehensive error handling"

**Skill Executes**:
```bash
codex exec resume --last
```

**Output**: Codex builds on previous API + auth design and adds error handling patterns.

---

### Turn 4: Implementation
**User**: "Implement the user authentication endpoint"

**Skill Executes**:
```bash
codex exec resume --last
```

**Output**: Codex uses all previous context to implement the auth endpoint with full understanding of the API design.

**Result**: After 4 turns, you have a complete API with design, auth, error handling, and initial implementation - all with maintained context.

---

## Example 3: Explicit Resume Command

### When to Use Interactive Picker

If you have multiple Codex sessions and want to choose which one to continue:

**User**: "Show me my Codex sessions and let me pick which to resume"

**Manual Command** (run outside skill):
```bash
codex exec resume --last
```

This opens an interactive picker showing:
```
Recent Codex Sessions:
1. Queue data structure design (30 minutes ago)
2. REST API for blog system (2 hours ago)
3. Binary search tree implementation (yesterday)

Select session to resume:
```

---

## Example 4: Resuming After Claude Code Restart

### Scenario
1. You worked on a queue design with Codex
2. Closed Claude Code
3. Reopened Claude Code days later

### Resume Request
**User**: "Continue where we left off with the queue implementation"

**Skill Executes**:
```bash
codex exec resume --last
```

**Result**: Codex resumes the most recent session (the queue work) with full context maintained across Claude Code restarts.

**Why It Works**: Codex CLI persists session history independently of Claude Code.

---

## Continuation Keywords

The skill detects continuation requests when you use phrases like:

- "Continue with that"
- "Resume the previous session"
- "Keep going"
- "Add to that"
- "Now add X" (implies building on previous)
- "Continue where we left off"
- "Follow up on that"

---

## Decision Tree: New Session vs. Resume

```
User makes request
│
├─ Contains continuation keywords?
│  │
│  ├─ YES → Use `codex exec resume --last`
│  │
│  └─ NO → Check context
│     │
│     ├─ References previous Codex work?
│     │  │
│     │  ├─ YES → Use `codex exec resume --last`
│     │  │
│     │  └─ NO → New session: `codex exec -m ... "prompt"`
│
└─ User explicitly says "new" or "fresh"?
   │
   └─ YES → Force new session even if continuation keywords present
```

---

## Session History Management

### Automatic Save
- Every Codex session is automatically saved by Codex CLI
- No manual session ID tracking needed
- Sessions persist across:
  - Claude Code restarts
  - Terminal sessions
  - System reboots

### Accessing History
```bash
# Resume most recent (recommended for skill)
codex exec resume --last

# Interactive picker (manual use)
codex exec resume --last

# List sessions (manual use)
codex list
```

---

## Best Practices

### 1. Use Clear Continuation Language

**Good**:
- "Continue with that queue implementation - add unit tests"
- "Resume the API design session and add rate limiting"

**Less Clear**:
- "Add tests" (ambiguous - new or continue?)
- "Rate limiting" (no continuation context)

### 2. Build Incrementally

Start with high-level design, then iterate:
1. Design (new session)
2. Add feature A (resume)
3. Add feature B (resume)
4. Implement (resume with full context)

### 3. Leverage Context Accumulation

Each resumed session has ALL previous context:
- Design decisions
- Trade-offs discussed
- Code patterns chosen
- Error handling approaches

This allows Codex to provide increasingly sophisticated, context-aware assistance.

---

## Troubleshooting

### "No previous sessions found"

**Cause**: Codex CLI history is empty (no prior sessions)

**Fix**: Start a new session first:
```bash
codex exec -m gpt-5.5 "Design a queue"
```

Then subsequent "continue" requests will work.

---

### Session Not Resuming Correctly

**Symptoms**: Resume works but context seems lost

**Possible Causes**:
- Multiple sessions mixed together
- User explicitly requested "fresh start"

**Fix**: Use interactive picker to select correct session:
```bash
codex exec resume --last
```

---

### Multiple Sessions Confusion

**Scenario**: Working on two projects, want to resume specific one

**Solution**:
1. Be explicit: "Resume the queue design session" (skill will use --last)
2. Or manually: `codex exec resume --last` (or `codex exec resume <session-id>`) → pick correct session

---

## Next Steps

- **Advanced config**: See [advanced-patterns.md](./advanced-patterns.md)
- **Basic examples**: See [command-patterns.md](./command-patterns.md)
- **Full docs**: See [../SKILL.md](../SKILL.md)

---

## Detecting Continuation Requests (decision rules)

Decide between **new session** and **resume previous** before every Codex invocation. Default to **new session**; only resume when at least one signal below clearly fires.

### Strong continuation signals (resume)

Any one of these is sufficient to use `codex exec resume --last`:

1. **Explicit continuation verbs**: "continue", "resume", "keep going", "carry on", "pick up", "go on"
2. **Back-reference phrases**: "that", "it", "the previous", "what you just did", "where we left off", "from before", "earlier"
3. **Incremental modifiers** following prior Codex output: "now also…", "and add…", "next, do…", "then…", "also include…"
4. **Iteration on the same artifact**: same file/feature/function discussed in the last Codex turn, no new topic introduced
5. **Direct correction of last response**: "that was wrong, fix it", "regenerate", "try again with X"

### Strong new-session signals (do NOT resume)

Any one of these forces a fresh `codex exec -m gpt-5.5 …`:

1. **Explicit reset words**: "new", "fresh", "from scratch", "start over", "ignore previous"
2. **Topic shift**: completely unrelated task/file/domain from the last Codex turn
3. **No prior Codex session this conversation** (first Codex invocation in the chat — there is nothing to resume)
4. **User pasted a full standalone problem statement** without referencing prior work
5. **Long gap with new framing**: user says "now let's work on X" where X is unrelated

### Ambiguous cases — tie-breaking rules

- If the request would make sense **without the prior session context**, start new.
- If the request only makes sense **as a follow-up** (e.g., "add tests" with no file mentioned), resume.
- If unclear, prefer **new session** and surface a one-line note: "Starting a fresh Codex session — say 'continue' if you wanted to resume the previous one."

### Quick decision table

| User says… | Action |
|------------|--------|
| "Use codex to design X" (first time) | New |
| "Continue with that" / "keep going" | Resume `--last` |
| "Now add error handling" (right after Codex output) | Resume `--last` |
| "Fresh codex run on Y" | New |
| "Codex, look at @other-file.ts" (different file, different topic) | New |
| "Codex, redo what you just did but with logging" | Resume `--last` |
| "Add tests" (no file ref, just after Codex implementation) | Resume `--last` |
| "Add tests for @src/foo.ts" (new file, no prior Codex on it) | New |

---

## Tracking Session IDs in Claude Code Context

Every `codex exec` run prints a line like:

```
session id: 019dccf9-9c0f-73d3-8966-4ed74d8f5fd4
```

This UUID is preserved in Claude Code's conversation transcript. Use it instead of `--last` when the user references a *specific* prior task — `--last` only points at the most recent session, which may be the wrong one.

### Capture rule

After every Codex invocation, mentally tag the session ID with what it was about (e.g., "auth refactor → 019dcc…", "queue design → 019dcd…"). The transcript already contains the IDs; the binding (ID ↔ topic) is what Claude tracks.

### Pick `--last` vs explicit UUID

Prefer `codex exec resume --last` when **either**:
- Only one Codex session has run in this Claude Code conversation, or
- The user's wording clearly points at the most recent run ("what you just did", "that one", "where we left off") AND no other `codex exec` run happened in between.

Prefer `codex exec resume <uuid> "prompt"` when **any** of these hold:
- Multiple Codex sessions exist in this conversation and the user names a specific one ("the auth one", "the queue design")
- Time/turns have passed since that session and other Codex calls happened in between
- The user explicitly quotes or pastes a session id

### When the ID cannot be found

If the user references a session that started **before this Claude Code conversation** (no `session id:` line is present in the transcript), choose one:
1. Run `codex exec resume --last` and inspect the printed first turn to confirm it is the intended session.
2. Ask the user to paste the session UUID, or start a fresh `codex exec` and explain that the prior session could not be located.

Never invent or guess UUIDs.

---

## Forking Sessions (Interactive Only)

The `codex fork` command creates a new session from a previous one, allowing exploration of different directions without affecting the original session.

```bash
# Fork the most recent session (interactive terminal only)
codex fork --last

# Fork a specific session by ID (interactive terminal only)
codex fork <session-id>
```

**⚠️ Important**: `codex fork` is an **interactive-only** command. It is NOT available under `codex exec` and will fail with "stdin is not a terminal" in Claude Code's non-interactive environment.

**Workaround for Claude Code**: To achieve similar functionality, use `codex exec resume --last` with a prompt that indicates an alternative direction. The session history will be preserved.

Unlike `resume` which continues the same session, `fork` creates a new independent session with the same history as a starting point.
