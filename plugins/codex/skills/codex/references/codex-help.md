# Codex CLI Help Reference

**Version**: 0.71.0

## IMPORTANT: Interactive vs Exec Mode Differences

Some flags are ONLY available in interactive `codex` mode, NOT in `codex exec`:

| Flag | Interactive `codex` | `codex exec` |
|------|---------------------|--------------|
| `--search` | ✅ Available | ❌ NOT available |
| `-a/--ask-for-approval` | ✅ Available | ❌ NOT available |
| `--add-dir` | ✅ Available | ✅ Available |
| `--full-auto` | ✅ Available | ✅ Available |

## Main Command: `codex --help`

```
Codex CLI

If no subcommand is specified, options will be forwarded to the interactive CLI.

Usage: codex [OPTIONS] [PROMPT]
       codex [OPTIONS] <COMMAND> [ARGS]

Commands:
  exec        Run Codex non-interactively [aliases: e]
  review      Run a code review non-interactively
  login       Manage login
  logout      Remove stored authentication credentials
  mcp         [experimental] Run Codex as an MCP server and manage MCP servers
  mcp-server  [experimental] Run the Codex MCP server (stdio transport)
  app-server  [experimental] Run the app server or related tooling
  completion  Generate shell completion scripts
  sandbox     Run commands within a Codex-provided sandbox [aliases: debug]
  apply       Apply the latest diff produced by Codex agent as a `git apply` to your local working
              tree [aliases: a]
  resume      Resume a previous interactive session (picker by default; use --last to continue the
              most recent)
  cloud       [EXPERIMENTAL] Browse tasks from Codex Cloud and apply changes locally
  features    Inspect feature flags
  help        Print this message or the help of the given subcommand(s)

Arguments:
  [PROMPT]
          Optional user prompt to start the session

Options:
  -c, --config <key=value>
          Override a configuration value that would otherwise be loaded from `~/.codex/config.toml`.
          Use a dotted path (`foo.bar.baz`) to override nested values. The `value` portion is parsed
          as TOML. If it fails to parse as TOML, the raw string is used as a literal.

          Examples: - `-c model="o3"` - `-c 'sandbox_permissions=["disk-full-read-access"]'` - `-c
          shell_environment_policy.inherit=all`

      --enable <FEATURE>
          Enable a feature (repeatable). Equivalent to `-c features.<name>=true`

      --disable <FEATURE>
          Disable a feature (repeatable). Equivalent to `-c features.<name>=false`

  -i, --image <FILE>...
          Optional image(s) to attach to the initial prompt

  -m, --model <MODEL>
          Model the agent should use

      --oss
          Convenience flag to select the local open source model provider. Equivalent to -c
          model_provider=oss; verifies a local LM Studio or Ollama server is running

      --local-provider <OSS_PROVIDER>
          Specify which local provider to use (lmstudio or ollama). If not specified with --oss,
          will use config default or show selection

  -p, --profile <CONFIG_PROFILE>
          Configuration profile from config.toml to specify default options

  -s, --sandbox <SANDBOX_MODE>
          Select the sandbox policy to use when executing model-generated shell commands

          [possible values: read-only, workspace-write, danger-full-access]

  -a, --ask-for-approval <APPROVAL_POLICY>
          Configure when the model requires human approval before executing a command

          Possible values:
          - untrusted:  Only run "trusted" commands (e.g. ls, cat, sed) without asking for user
            approval. Will escalate to the user if the model proposes a command that is not in the
            "trusted" set
          - on-failure: Run all commands without asking for user approval. Only asks for approval if
            a command fails to execute, in which case it will escalate to the user to ask for
            un-sandboxed execution
          - on-request: The model decides when to ask the user for approval
          - never:      Never ask for user approval Execution failures are immediately returned to
            the model

      --full-auto
          Convenience alias for low-friction sandboxed automatic execution (-a on-request, --sandbox
          workspace-write)

      --dangerously-bypass-approvals-and-sandbox
          Skip all confirmation prompts and execute commands without sandboxing. EXTREMELY
          DANGEROUS. Intended solely for running in environments that are externally sandboxed

  -C, --cd <DIR>
          Tell the agent to use the specified directory as its working root

      --search
          Enable web search (off by default). When enabled, the native Responses `web_search` tool
          is available to the model (no per‑call approval)

          NOTE: This flag is ONLY available in interactive mode, NOT in `codex exec`

      --add-dir <DIR>
          Additional directories that should be writable alongside the primary workspace

  -h, --help
          Print help (see a summary with '-h')

  -V, --version
          Print version
```

## Exec Command: `codex exec --help`

**NOTE**: `--search` and `-a/--ask-for-approval` are NOT available in exec mode.

```
Run Codex non-interactively

Usage: codex exec [OPTIONS] [PROMPT] [COMMAND]

Commands:
  resume  Resume a previous session by id or pick the most recent with --last
  review  Run a code review against the current repository
  help    Print this message or the help of the given subcommand(s)

Arguments:
  [PROMPT]
          Initial instructions for the agent. If not provided as an argument (or if `-` is used),
          instructions are read from stdin

Options:
  -c, --config <key=value>
          Override a configuration value that would otherwise be loaded from `~/.codex/config.toml`.
          Use a dotted path (`foo.bar.baz`) to override nested values. The `value` portion is parsed
          as TOML. If it fails to parse as TOML, the raw string is used as a literal.

          Examples: - `-c model="o3"` - `-c 'sandbox_permissions=["disk-full-read-access"]'` - `-c
          shell_environment_policy.inherit=all`

      --enable <FEATURE>
          Enable a feature (repeatable). Equivalent to `-c features.<name>=true`

      --disable <FEATURE>
          Disable a feature (repeatable). Equivalent to `-c features.<name>=false`

  -i, --image <FILE>...
          Optional image(s) to attach to the initial prompt

  -m, --model <MODEL>
          Model the agent should use

      --oss
          Use open-source provider

      --local-provider <OSS_PROVIDER>
          Specify which local provider to use (lmstudio or ollama). If not specified with --oss,
          will use config default or show selection

  -s, --sandbox <SANDBOX_MODE>
          Select the sandbox policy to use when executing model-generated shell commands

          [possible values: read-only, workspace-write, danger-full-access]

  -p, --profile <CONFIG_PROFILE>
          Configuration profile from config.toml to specify default options

      --full-auto
          Convenience alias for low-friction sandboxed automatic execution (-a on-request, --sandbox
          workspace-write)

      --dangerously-bypass-approvals-and-sandbox
          Skip all confirmation prompts and execute commands without sandboxing. EXTREMELY
          DANGEROUS. Intended solely for running in environments that are externally sandboxed

  -C, --cd <DIR>
          Tell the agent to use the specified directory as its working root

      --skip-git-repo-check
          Allow running Codex outside a Git repository

      --add-dir <DIR>
          Additional directories that should be writable alongside the primary workspace

      --output-schema <FILE>
          Path to a JSON Schema file describing the model's final response shape

      --color <COLOR>
          Specifies color settings for use in the output

          [default: auto]
          [possible values: always, never, auto]

      --json
          Print events to stdout as JSONL

  -o, --output-last-message <FILE>
          Specifies file where the last message from the agent should be written

  -h, --help
          Print help (see a summary with '-h')

  -V, --version
          Print version
```

## Review Command: `codex review --help`

```
Run a code review non-interactively

Usage: codex review [OPTIONS] [PROMPT]

Arguments:
  [PROMPT]
          Custom review instructions. If `-` is used, read from stdin

Options:
  -c, --config <key=value>
          Override a configuration value

      --uncommitted
          Review staged, unstaged, and untracked changes

      --base <BRANCH>
          Review changes against the given base branch

      --enable <FEATURE>
          Enable a feature (repeatable)

      --commit <SHA>
          Review the changes introduced by a commit

      --disable <FEATURE>
          Disable a feature (repeatable)

      --title <TITLE>
          Optional commit title to display in the review summary

  -h, --help
          Print help
```

## Exec Resume Command: `codex exec resume --help`

```
Resume a previous session by id or pick the most recent with --last

Usage: codex exec resume [OPTIONS] [SESSION_ID] [PROMPT]

Arguments:
  [SESSION_ID]
          Conversation/session id (UUID). When provided, resumes this session. If omitted, use
          --last to pick the most recent recorded session

  [PROMPT]
          Prompt to send after resuming the session. If `-` is used, read from stdin

Options:
  -c, --config <key=value>
          Override a configuration value that would otherwise be loaded from `~/.codex/config.toml`.
          Use a dotted path (`foo.bar.baz`) to override nested values. The `value` portion is parsed
          as TOML. If it fails to parse as TOML, the raw string is used as a literal.

          Examples: - `-c model="o3"` - `-c 'sandbox_permissions=["disk-full-read-access"]'` - `-c
          shell_environment_policy.inherit=all`

      --last
          Resume the most recent recorded session (newest) without specifying an id

      --enable <FEATURE>
          Enable a feature (repeatable). Equivalent to `-c features.<name>=true`

      --disable <FEATURE>
          Disable a feature (repeatable). Equivalent to `-c features.<name>=false`

  -h, --help
          Print help (see a summary with '-h')
```

## Features Command: `codex features list`

```
Inspect feature flags

Usage: codex features list

Lists all known features with their stage (stable/beta/experimental) and effective state (enabled/disabled).

Current features (v0.71.0):
- undo (stable, default: true)
- parallel (stable, default: true)
- view_image_tool (stable, default: true)
- shell_tool (stable, default: true)
- warnings (stable, default: true)
- web_search_request (stable, default: false)
- exec_policy (experimental, default: true)
- remote_compaction (experimental, default: true)
- unified_exec (experimental, default: false)
- rmcp_client (experimental, default: false)
- apply_patch_freeform (beta, default: false)
- skills (experimental, default: false)
```

## Cloud Command: `codex cloud --help` (EXPERIMENTAL)

```
[EXPERIMENTAL] Browse tasks from Codex Cloud and apply changes locally

Usage: codex cloud [OPTIONS] [COMMAND]

Commands:
  exec    Submit a new Codex Cloud task without launching the TUI
  status  Show the status of a Codex Cloud task
  apply   Apply the diff for a Codex Cloud task locally
  diff    Show the unified diff for a Codex Cloud task
  help    Print this message or the help of the given subcommand(s)
```

## Model Support (v0.71.0)

**Available Models**:
- `gpt-5.2` - Latest model with all reasoning levels (NEW)
- `gpt-5.1` - General high-reasoning model
- `gpt-5.1-codex-max` - Maximum capability code editing (27-42% faster)
- `gpt-5.1-codex` - Standard code editing (backward compatibility)

**Reasoning Effort Levels** (all supported by gpt-5.2):
- `low` - Minimal reasoning
- `medium` - Balanced reasoning
- `high` - High reasoning (default)
- `xhigh` - Extra-high reasoning for maximum capability
