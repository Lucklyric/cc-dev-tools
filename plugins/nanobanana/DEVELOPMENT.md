# Nanobanana Plugin Development Guide

This plugin bundles the MCP server from the upstream [gemini-cli-extensions/nanobanana](https://github.com/gemini-cli-extensions/nanobanana) repository. This guide covers how to maintain, update, and develop the plugin.

## Upstream Reference

| Item | Value |
|------|-------|
| Repository | https://github.com/gemini-cli-extensions/nanobanana |
| MCP Server | `mcp-server/` directory in upstream |
| Last Synced Upstream Version | 1.0.12 |
| License | Apache-2.0 (Google LLC) |

## Syncing with Upstream

When the upstream nanobanana extension releases updates (new features, bug fixes, model changes), follow these steps to sync:

### 1. Check Upstream Changes

```bash
# Clone or update the upstream repo
git clone https://github.com/gemini-cli-extensions/nanobanana /tmp/nanobanana-upstream
cd /tmp/nanobanana-upstream
git log --oneline -20
```

Review what changed:
- `mcp-server/src/` — MCP server source code changes
- `mcp-server/package.json` — dependency updates
- `commands/*.toml` — command prompt/schema changes (adapt to skill docs)
- `GEMINI.md` — generation guidelines (adapt to `references/generation-guidelines.md`)
- `README.md` — feature/usage changes (adapt to plugin README and skill docs)

### 2. Update MCP Server

```bash
# From the cc-dev-tools repo
PLUGIN_DIR=plugins/nanobanana/mcp-server
UPSTREAM=/tmp/nanobanana-upstream/mcp-server

# Copy source files
cp $UPSTREAM/src/*.ts $PLUGIN_DIR/src/
cp $UPSTREAM/package.json $PLUGIN_DIR/package.json
cp $UPSTREAM/package-lock.json $PLUGIN_DIR/package-lock.json
cp $UPSTREAM/tsconfig.json $PLUGIN_DIR/tsconfig.json

# Rebuild
cd $PLUGIN_DIR
npm install --ignore-scripts
npx tsc

# Or copy pre-built dist if available
cp $UPSTREAM/dist/*.js $PLUGIN_DIR/dist/
cp $UPSTREAM/dist/*.d.ts $PLUGIN_DIR/dist/
```

### 3. Update Skill Documentation

Check if upstream added/changed:
- New MCP tools → add to `skills/nanobanana/references/commands.md`
- New parameters → update parameter tables in `references/commands.md`
- New models → update model table in `references/commands.md`
- New auth methods → update `references/troubleshooting.md`
- Generation guidelines → update `references/generation-guidelines.md`

Cross-reference upstream files:
| Upstream File | Maps To |
|---------------|---------|
| `commands/*.toml` | `skills/nanobanana/references/commands.md` |
| `GEMINI.md` | `skills/nanobanana/references/generation-guidelines.md` |
| `README.md` | `README.md` + `skills/nanobanana/SKILL.md` |
| `mcp-server/src/index.ts` | Tool schemas in `references/commands.md` |
| `mcp-server/src/types.ts` | TypeScript interfaces (internal reference) |

### 4. Test

```bash
# Verify MCP server starts
cd plugins/nanobanana
GEMINI_API_KEY=test node mcp-server/dist/index.js
# Should output: "Nano Banana MCP server running on stdio"

# Test image generation (requires real API key)
# Install the plugin and trigger via Claude Code
```

### 5. Version and Commit

```bash
# Bump version in plugin.json
# Bump version in SKILL.md frontmatter
# Bump marketplace version in .claude-plugin/marketplace.json
# Update version table in root README.md
```

## Plugin Architecture

```
plugins/nanobanana/
├── .claude-plugin/
│   └── plugin.json           # Plugin manifest (name, version, skills)
├── .mcp.json                 # MCP server config (command, args, env)
├── mcp-server/               # Bundled MCP server from upstream
│   ├── dist/                 # Pre-built JS (committed, force-added)
│   ├── src/                  # TypeScript source (for reference/rebuild)
│   ├── package.json          # Node.js dependencies
│   └── .gitignore            # Ignores node_modules/, un-ignores dist/
├── commands/                 # Claude Code slash commands
│   ├── generate.md          # /generate — text-to-image
│   ├── edit.md              # /edit — modify existing image
│   ├── restore.md           # /restore — enhance/repair photo
│   ├── icon.md              # /icon — multi-size icon generation
│   ├── pattern.md           # /pattern — seamless textures
│   ├── story.md             # /story — sequential narratives
│   ├── diagram.md           # /diagram — technical diagrams
│   └── nanobanana.md        # /nanobanana — natural language routing
├── skills/nanobanana/
│   ├── SKILL.md              # Claude-facing skill definition
│   └── references/
│       ├── commands.md       # Full MCP tool parameter reference
│       ├── generation-guidelines.md  # Quality/prompting guidelines
│       └── troubleshooting.md        # Auth and error reference
├── README.md                 # User-facing plugin documentation
└── DEVELOPMENT.md            # This file
```

### Key Design Decisions

1. **MCP over CLI**: This plugin calls the MCP server directly instead of going through `gemini --yolo -p`. This removes the Gemini CLI dependency and avoids known bytestring encoding issues with CLI passthrough.

2. **Bundled dist/**: Pre-built JavaScript is committed (force-added past root `.gitignore`'s `dist/` rule) so users don't need TypeScript to install. The `mcp-server/.gitignore` has `!dist/` to un-ignore it locally.

3. **Source included**: TypeScript source is included for transparency and local rebuilds, but the plugin runs from `dist/` only.

4. **Env var inheritance**: `.mcp.json` uses empty `env: {}` so the Node process inherits all parent environment variables. The `${VAR}` syntax requires variables to exist, which would break for users missing some of the 5 API key fallbacks.

5. **`allowed-tools: mcp__nanobanana__*`**: The skill uses a wildcard pattern to match all 7 MCP tools from this server.

6. **Slash commands**: 8 commands in `commands/` mirror the upstream Gemini CLI extension's TOML command files, adapted as Claude Code markdown commands with `$ARGUMENTS` parsing.

## Adding New Features

If you want to extend the plugin beyond upstream:

1. **New MCP tool**: Add to `mcp-server/src/index.ts` (tool definition + handler), rebuild, update `references/commands.md`
2. **New slash command**: Add markdown file to `commands/`, set `allowed-tools` to the corresponding MCP tool
3. **New skill parameter**: Document in `references/commands.md`, add examples to `SKILL.md`
4. **New auth method**: Update `imageGenerator.ts:validateAuthentication`, update `.mcp.json` env block, update `references/troubleshooting.md`

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `@google/genai` | ^1.17.0 | Gemini API client |
| `@modelcontextprotocol/sdk` | ^1.0.0 | MCP server framework |
| Node.js | >= 18.0.0 | Runtime |
