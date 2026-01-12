# File Context Passing

**IMPORTANT**: When users reference files or directories in their requests, pass file paths to Codex CLI instead of embedding file content in the prompt. This enables Codex to read and explore files autonomously using its native capabilities.

## Benefits

- **Reduced token usage**: File content not embedded in prompts
- **Large file support**: Codex handles files natively without truncation
- **Better performance**: Codex optimizes file reading internally
- **Unchanged workflow**: Works with natural file references

## Directory Context (`-C` flag)

Use `-C` to set the working directory for Codex operations:

```bash
# Set working directory to project root
codex exec -m gpt-5.2-codex -s read-only -C /path/to/project \
  "Analyze the authentication module"

# Codex will explore files within /path/to/project
```

## Additional Directories (`--add-dir` flag)

Use `--add-dir` to include directories outside the primary workspace:

```bash
# Include shared libraries directory
codex exec -m gpt-5.2-codex -s read-only \
  --add-dir /shared/libs \
  "Review how the auth module uses shared utilities"

# Include multiple directories
codex exec -m gpt-5.2-codex -s read-only \
  --add-dir /shared/libs \
  --add-dir /config \
  "Analyze configuration usage across the codebase"
```

## File Context Examples

```bash
# Analyze a specific file (Codex reads it autonomously)
codex exec -m gpt-5.2-codex -s read-only \
  "Analyze the implementation in src/auth/login.ts"

# Review multiple files
codex exec -m gpt-5.2-codex -s read-only \
  "Compare the implementations in src/v1/api.ts and src/v2/api.ts"

# Work with files across directories
codex exec -m gpt-5.2-codex -s read-only \
  --add-dir /shared/types \
  "Check how src/services/user.ts uses types from the shared directory"
```

## Directory Context Examples

```bash
# Analyze entire directory
codex exec -m gpt-5.2-codex -s read-only -C /project/src \
  "Review the architecture of this module"

# Multi-directory codebase analysis
codex exec -m gpt-5.2-codex -s read-only \
  --add-dir /frontend/src \
  --add-dir /backend/src \
  "Analyze how frontend and backend communicate"
```

## Path Detection

The skill automatically detects file/directory paths in user requests:

**Auto-detected patterns**:
- Paths with separators: `src/auth/login.ts`, `lib/utils.py`
- Relative paths: `./config.json`, `../shared/types.ts`
- Absolute paths: `/home/user/project/file.rs`
- Common extensions: `.ts`, `.js`, `.py`, `.rs`, `.go`, etc.

**Explicit syntax** (`@` prefix):
- Use `@path/to/file` for explicit file references
- Example: "Analyze @src/auth.ts and @src/session.ts"
- Multiple files: "Compare @v1/api.ts with @v2/api.ts"
- Directories: "Review @src/services/ architecture"

```bash
# Complete example using @ prefix syntax
codex exec -m gpt-5.2-codex -s read-only \
  "Analyze @src/auth.ts and compare with @src/session.ts"

# Directory reference with @ prefix
codex exec -m gpt-5.2-codex -s read-only \
  "Review the structure of @src/components/ directory"
```

## Path Resolution

- Relative paths are resolved against the current working directory
- Absolute paths are passed directly to Codex
- The skill converts all paths to absolute before invoking CLI

## When NOT to Embed File Content

**DO NOT** read files and embed content in prompts when:
- User mentions specific file paths in their request
- Request involves analyzing, reviewing, or understanding code
- Working with large files (>10KB)
- Multi-file operations are requested

**Instead**: Pass file paths to Codex and let it read files autonomously.

## Edge Cases

- **Missing files**: Codex reports the error with context
- **Files outside workspace**: Use `--add-dir` to include external directories
- **Binary files**: Codex determines if it can process the file
- **Large directories**: Codex handles exploration internally
