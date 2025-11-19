# Gemini CLI Help Reference

**Version**: v0.16.0+
**Source**: Output from `gemini --help`
**Last Updated**: 2025-11-18

## Command Overview

```
Usage: gemini [options] [command]

Gemini CLI - Launch an interactive CLI, use -p/--prompt for non-interactive mode
```

## Commands

- `gemini [query..]` - Launch Gemini CLI (default)
- `gemini mcp` - Manage MCP servers
- `gemini extensions <command>` - Manage Gemini CLI extensions

## Positionals

- `query` - Positional prompt. Defaults to one-shot; use `-i`/`--prompt-interactive` for interactive mode

## Options

### Core Flags

- `-d, --debug` - Run in debug mode [boolean] [default: false]
- `-m, --model` - Model to use [string]
- `-p, --prompt` - Prompt text appended to stdin input [string]
  **⚠️ DEPRECATED**: Use positional prompt instead. This flag will be removed in a future version.
- `-i, --prompt-interactive` - Execute prompt and continue in interactive mode [string]
- `-s, --sandbox` - Run in sandbox [boolean]

### Approval & Security

- `-y, --yolo` - Automatically accept all actions (YOLO mode) [boolean] [default: false]
- `--approval-mode` - Set approval mode [string]
  **Choices**: `default` (prompt for approval), `auto_edit` (auto-approve edit tools), `yolo` (auto-approve all tools)
- `--allowed-tools` - Tools allowed to run without confirmation [array]

### Session Management

- `-r, --resume` - Resume previous session [string]
  Use `"latest"` for most recent or index number (e.g., `--resume 5`)
- `--list-sessions` - List available sessions for current project and exit [boolean]
- `--delete-session` - Delete session by index number [string]

### Extensions & MCP

- `-e, --extensions` - List of extensions to use [array]
  If not provided, all extensions are used
- `-l, --list-extensions` - List all available extensions and exit [boolean]
- `--allowed-mcp-server-names` - Allowed MCP server names [array]

### Workspace & Context

- `--include-directories` - Additional directories to include in workspace [array]
  Comma-separated or multiple `--include-directories` flags
- `--screen-reader` - Enable screen reader mode for accessibility [boolean]

### Output

- `-o, --output-format` - Format of CLI output [string]
  **Choices**: `text`, `json`, `stream-json`

### Meta

- `-v, --version` - Show version number [boolean]
- `-h, --help` - Show help [boolean]
- `--experimental-acp` - Start agent in ACP mode [boolean]

## Usage Patterns

### Headless/Non-Interactive Mode

```bash
# Preferred: Positional prompt
gemini -m gemini-3-pro-preview "Explain quicksort algorithm"

# Deprecated but still works: -p flag
gemini -m gemini-3-pro-preview -p "Explain quicksort algorithm"

# With output formatting
gemini -m gemini-3-pro-preview --output-format json "Analyze this code"

# With approval mode
gemini -m gemini-3-pro-preview --approval-mode auto_edit "Refactor this function"
```

### Session Management

```bash
# List sessions
gemini --list-sessions

# Resume latest session
gemini -r latest

# Resume specific session by index
gemini -r 5

# Delete session
gemini --delete-session 3
```

### Interactive Mode

```bash
# Start interactive session
gemini

# Execute prompt then continue interactively
gemini -i "Start by explaining React hooks"
```

## Important Notes

1. **Positional Prompts**: Preferred over `-p` flag as of v0.16.0
2. **Deprecation Warning**: `-p/--prompt` flag marked for removal in future versions
3. **Session Resume**: Fully supported via `-r/--resume` flag
4. **Approval Modes**: Three levels (default, auto_edit, yolo)
5. **Output Formats**: Text (default), JSON, or streaming JSON for programmatic use
6. **MCP Integration**: Built-in support for Model Context Protocol servers
7. **Extensions**: Plugin system for custom commands and functionality

## Session Index Format

Sessions are identified by:
- `"latest"` keyword for most recent session
- Integer index (e.g., `0`, `1`, `2`, etc.)
- Retrieved via `--list-sessions` command

## Compatibility Notes

- **Minimum Version**: v0.16.0
- **Breaking Changes in v0.16.0**:
  - `-p` flag deprecated in favor of positional prompts
  - Checkpointing moved to settings.json configuration
- **Future Deprecations**: `-p/--prompt` flag will be removed

## See Also

- `command-patterns.md` - Common command templates
- `session-workflows.md` - Multi-turn conversation patterns
- `model-selection.md` - Model selection guidance
