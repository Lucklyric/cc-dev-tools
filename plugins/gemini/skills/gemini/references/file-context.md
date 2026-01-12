# File Context Passing

**IMPORTANT**: When users reference files or directories in their requests, pass file paths to Gemini CLI instead of embedding file content in the prompt. This enables Gemini to read and explore files autonomously.

## Benefits

- **Reduced token usage**: File content not embedded in prompts
- **Large file support**: Gemini handles files natively without truncation
- **Better performance**: Gemini optimizes file reading internally
- **Unchanged workflow**: Works with natural file references

## Directory Context (`--include-directories` flag)

Use `--include-directories` to include additional directories:

```bash
# Include shared libraries directory
gemini -m gemini-3-pro-preview \
  --include-directories /shared/libs \
  "Review how the auth module uses shared utilities"

# Include multiple directories (comma-separated)
gemini -m gemini-3-pro-preview \
  --include-directories /shared/libs,/config \
  "Analyze configuration usage across the codebase"

# Include multiple directories (repeated flag)
gemini -m gemini-3-pro-preview \
  --include-directories /shared/libs \
  --include-directories /config \
  "Analyze configuration usage"
```

## File Context Examples

```bash
# Analyze a specific file (include path in prompt)
gemini -m gemini-3-pro-preview \
  "Analyze the implementation in src/auth/login.ts"

# Review multiple files (paths in prompt)
gemini -m gemini-3-pro-preview \
  "Compare the implementations in src/v1/api.ts and src/v2/api.ts"

# Work with files across directories
gemini -m gemini-3-pro-preview \
  --include-directories /shared/types \
  "Check how src/services/user.ts uses types from /shared/types"
```

## Directory Context Examples

```bash
# Analyze entire directory
gemini -m gemini-3-pro-preview \
  "Review the architecture of the src/ module"

# Multi-directory codebase analysis
gemini -m gemini-3-pro-preview \
  --include-directories /frontend/src,/backend/src \
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
gemini -m gemini-3-pro-preview \
  "Analyze @src/auth.ts and compare with @src/session.ts"

# Directory reference with @ prefix
gemini -m gemini-3-pro-preview \
  "Review the structure of @src/components/ directory"
```

## Path Resolution

- Relative paths are resolved against the current working directory
- Absolute paths are passed directly to Gemini
- The skill converts all paths to absolute before invoking CLI

## When NOT to Embed File Content

**DO NOT** read files and embed content in prompts when:
- User mentions specific file paths in their request
- Request involves analyzing, reviewing, or understanding code
- Working with large files (>10KB)
- Multi-file operations are requested

**Instead**: Pass file paths to Gemini and let it read files autonomously.

## Edge Cases

- **Missing files**: Gemini reports the error with context
- **Files outside workspace**: Use `--include-directories` to include external directories
- **Binary files**: Gemini determines if it can process the file
- **Large directories**: Gemini handles exploration internally
