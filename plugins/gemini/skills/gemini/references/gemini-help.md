# Gemini CLI Help Reference

**Version**: v0.29.5
**Source**: Output from `gemini --help`
**Last Updated**: 2026-02-16

## Command Overview

```
Usage: gemini [options] [command]

Gemini CLI - Launch an interactive CLI, use -p/--prompt for non-interactive mode
```

## Commands

- `gemini [query..]` - Launch Gemini CLI (default)
- `gemini mcp` - Manage MCP servers
- `gemini extensions <command>` - Manage Gemini CLI extensions
- `gemini skills <command>` - Manage agent skills [aliases: skill]
- `gemini hooks <command>` - Manage Gemini CLI hooks [aliases: hook]

## Positionals

- `query` - Initial prompt. Runs in interactive mode by default; use `-p`/`--prompt` for non-interactive

## Options

### Core Flags

- `-d, --debug` - Run in debug mode [boolean] [default: false]
- `-m, --model` - Model to use [string]
- `-p, --prompt` - Run in non-interactive (headless) mode with the given prompt. Appended to input on stdin (if any). [string]
- `-i, --prompt-interactive` - Execute prompt and continue in interactive mode [string]
- `-s, --sandbox` - Run in sandbox [boolean]

### Approval & Security

- `-y, --yolo` - Automatically accept all actions (YOLO mode) [boolean] [default: false]
- `--approval-mode` - Set approval mode [string]
  **Choices**: `default` (prompt for approval), `auto_edit` (auto-approve edit tools), `plan` (read-only mode), `yolo` (auto-approve all tools)
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

### Workspace & Context (v0.20.0+)

- `--include-directories` - Additional directories to include in workspace [array]
  Comma-separated or multiple `--include-directories` flags
- `--screen-reader` - Enable screen reader mode for accessibility [boolean]

### Output

- `-o, --output-format` - Format of CLI output [string]
  **Choices**: `text`, `json`, `stream-json`
- `--raw-output` - Disable sanitization of model output (e.g. allow ANSI escape sequences). WARNING: Security risk with untrusted output. [boolean]
- `--accept-raw-output-risk` - Suppress security warning when using `--raw-output` [boolean]

### Meta

- `-v, --version` - Show version number [boolean]
- `-h, --help` - Show help [boolean]
- `--experimental-acp` - Start agent in ACP mode [boolean]

## Full CLI Output (v0.29.5)

```
Usage: gemini [options] [command]

Gemini CLI - Defaults to interactive mode. Use -p/--prompt for non-interactive (headless) mode.

Commands:
  gemini [query..]             Launch Gemini CLI  [default]
  gemini mcp                   Manage MCP servers
  gemini extensions <command>  Manage Gemini CLI extensions.  [aliases: extension]
  gemini skills <command>      Manage agent skills.  [aliases: skill]
  gemini hooks <command>       Manage Gemini CLI hooks.  [aliases: hook]

Positionals:
  query  Initial prompt. Runs in interactive mode by default; use -p/--prompt for non-interactive.

Options:
  -d, --debug                     Run in debug mode (open debug console with F12)  [boolean] [default: false]
  -m, --model                     Model  [string]
  -p, --prompt                    Run in non-interactive (headless) mode with the given prompt. Appended to input on stdin (if any).  [string]
  -i, --prompt-interactive        Execute the provided prompt and continue in interactive mode  [string]
  -s, --sandbox                   Run in sandbox?  [boolean]
  -y, --yolo                      Automatically accept all actions (aka YOLO mode, see https://www.youtube.com/watch?v=xvFZjo5PgG0 for more details)?  [boolean] [default: false]
      --approval-mode             Set the approval mode: default (prompt for approval), auto_edit (auto-approve edit tools), yolo (auto-approve all tools), plan (read-only mode)  [string] [choices: "default", "auto_edit", "yolo", "plan"]
      --experimental-acp          Starts the agent in ACP mode  [boolean]
      --allowed-mcp-server-names  Allowed MCP server names  [array]
      --allowed-tools             Tools that are allowed to run without confirmation  [array]
  -e, --extensions                A list of extensions to use. If not provided, all extensions are used.  [array]
  -l, --list-extensions           List all available extensions and exit.  [boolean]
  -r, --resume                    Resume a previous session. Use "latest" for most recent or index number (e.g. --resume 5)  [string]
      --list-sessions             List available sessions for the current project and exit.  [boolean]
      --delete-session            Delete a session by index number (use --list-sessions to see available sessions).  [string]
      --include-directories       Additional directories to include in the workspace (comma-separated or multiple --include-directories)  [array]
      --screen-reader             Enable screen reader mode for accessibility.  [boolean]
  -o, --output-format             The format of the CLI output.  [string] [choices: "text", "json", "stream-json"]
      --raw-output                Disable sanitization of model output (e.g. allow ANSI escape sequences). WARNING: This can be a security risk if the model output is untrusted.  [boolean]
      --accept-raw-output-risk    Suppress the security warning when using --raw-output.  [boolean]
  -v, --version                   Show version number  [boolean]
  -h, --help                      Show help  [boolean]
```

## Usage Patterns

### Headless/Non-Interactive Mode

```bash
# Preferred: Positional prompt
gemini -m gemini-3.1-pro-preview "Explain quicksort algorithm"

# Deprecated but still works: -p flag
gemini -m gemini-3.1-pro-preview -p "Explain quicksort algorithm"

# With output formatting
gemini -m gemini-3.1-pro-preview --output-format json "Analyze this code"

# With approval mode
gemini -m gemini-3.1-pro-preview --approval-mode auto_edit "Refactor this function"
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

### Workspace Expansion (v0.20.0+)

```bash
# Include additional directories
gemini -m gemini-3.1-pro-preview --include-directories /shared/libs "task"

# Multiple directories (comma-separated)
gemini -m gemini-3.1-pro-preview --include-directories /path1,/path2 "task"

# Multiple directories (repeated flag)
gemini -m gemini-3.1-pro-preview --include-directories /path1 --include-directories /path2 "task"
```

### Accessibility (v0.20.0+)

```bash
# Enable screen reader mode
gemini -m gemini-3.1-pro-preview --screen-reader "task"
```

## Important Notes

1. **Positional Prompts**: Default runs in interactive mode; use `-p`/`--prompt` for non-interactive (headless) mode
2. **Headless Mode**: Use `-p`/`--prompt` flag for non-interactive execution in Claude Code
3. **Session Resume**: Fully supported via `-r/--resume` flag
4. **Approval Modes**: Four levels (default, auto_edit, plan, yolo)
5. **Output Formats**: Text (default), JSON, or streaming JSON for programmatic use
6. **MCP Integration**: Built-in support for Model Context Protocol servers
7. **Extensions**: Plugin system for custom commands and functionality
8. **Accessibility**: New `--screen-reader` flag for screen reader support

## Session Index Format

Sessions are identified by:
- `"latest"` keyword for most recent session
- Integer index (e.g., `0`, `1`, `2`, etc.)
- Retrieved via `--list-sessions` command

## Compatibility Notes

- **Minimum Version**: v0.29.5
- **Changes in v0.29.x**:
  - Gemini 3 is now the default model family
  - `-p`/`--prompt` is now the headless (non-interactive) mode flag (no longer deprecated)
  - Positional prompts default to interactive mode
  - Plan mode via `/plan` command
  - Extension discovery and registry client
  - `gemini-3.1-pro-preview` model available (released Feb 19, 2026)
- **Changes in v0.28.x**:
  - New `--raw-output` and `--accept-raw-output-risk` flags
  - Skills expanded with install/uninstall/enable/disable subcommands
  - Hooks `migrate` subcommand for migrating from Claude Code hooks
- **Changes in v0.26.0**:
  - New `skills` command for managing agent skills
  - New `hooks` command for managing CLI hooks
  - New `plan` approval mode
- **Changes in v0.20.0**:
  - New `--include-directories` flag for workspace expansion
  - New `--screen-reader` flag for accessibility
  - New `--experimental-acp` flag for Agent Control Protocol mode

## See Also

- `command-patterns.md` - Common command templates
- `session-workflows.md` - Multi-turn conversation patterns
- `model-selection.md` - Model selection guidance
