# Codex Examples

Complete examples showing common Codex invocation patterns.

## Code Tasks (Read-Only Default)

### Example 1: Code Analysis

**User Request**: "Analyze this function implementation and suggest improvements"

**Command**:
```bash
codex exec -m gpt-5.2-codex -s read-only \
  -c model_reasoning_effort=xhigh \
  "Analyze this function implementation and suggest improvements"
```

**Result**: Code-related task uses gpt-5.2-codex with read-only sandbox (default). No file modifications.

### Example 2: Architecture Review

**User Request**: "Help me design a binary search tree architecture in Rust"

**Command**:
```bash
codex exec -m gpt-5.2 -s read-only \
  -c model_reasoning_effort=xhigh \
  "Help me design a binary search tree architecture in Rust"
```

**Result**: General task uses gpt-5.2 with read-only sandbox (default). Session automatically saved for continuation.

### Example 3: Web Search Research

**User Request**: "Use Codex with web search to research async patterns"

**Command**:
```bash
codex exec -m gpt-5.2-codex -s read-only \
  -c model_reasoning_effort=xhigh \
  --enable web_search_request \
  "Research async patterns"
```

**Result**: Code-related research uses gpt-5.2-codex with read-only sandbox (default) and web search enabled.

## Code Tasks (Explicit Edit Request)

### Example 4: File Editing

**User Request**: "Edit this file to implement the BST insert method"

**Command**:
```bash
codex exec -m gpt-5.2-codex -s workspace-write \
  -c model_reasoning_effort=xhigh \
  "Edit this file to implement the BST insert method"
```

**Result**: User explicitly said "Edit this file" - code task uses gpt-5.2-codex with workspace-write permissions.

### Example 5: Refactoring

**User Request**: "Refactor and save the authentication system code"

**Command**:
```bash
codex exec -m gpt-5.2-codex -s workspace-write \
  -c model_reasoning_effort=xhigh \
  "Refactor and save the authentication system code"
```

**Result**: User explicitly said "Refactor and save" - code task uses gpt-5.2-codex with workspace-write for file modifications.

## Session Continuation

### Example 6: Resume Previous Session

**User Request**: "Continue with the BST - add a deletion method"

**Command**:
```bash
codex exec resume --last
```

**Result**: Codex resumes the previous BST session and continues with deletion method implementation, maintaining full context.

### Example 7: Resume with New Prompt

**User Request**: "Continue where we left off and add error handling"

**Command**:
```bash
codex exec resume --last
# Codex maintains previous context and continues with error handling
```

## File Context Examples

### Example 8: Analyze Specific File

**User Request**: "Analyze @src/auth.ts for security issues"

**Command**:
```bash
codex exec -m gpt-5.2-codex -s read-only \
  "Analyze @src/auth.ts for security issues"
```

### Example 9: Multi-Directory Analysis

**User Request**: "Compare how frontend and backend handle authentication"

**Command**:
```bash
codex exec -m gpt-5.2-codex -s read-only \
  --add-dir /frontend/src \
  --add-dir /backend/src \
  "Compare how frontend and backend handle authentication"
```

## Code Review

### Example 10: Review Uncommitted Changes

**Command**:
```bash
codex exec review --uncommitted
```

### Example 11: Review Against Branch

**Command**:
```bash
codex review --base main "Focus on security vulnerabilities"
```
