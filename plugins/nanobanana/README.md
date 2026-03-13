# Nano Banana Image Generation Plugin

Standalone image generation plugin for Claude Code using the Nano Banana MCP server. Generates and edits images via Gemini image models without requiring the Gemini CLI.

## Overview

This plugin runs the [nanobanana MCP server](https://github.com/gemini-cli-extensions/nanobanana) directly, providing 7 image generation and manipulation tools accessible as native MCP tools in Claude Code. Unlike the gemini plugin's nanobanana skill (which shells out to `gemini` CLI), this plugin has zero CLI dependencies — only Node.js >= 18 and a Gemini API key.

## Features

- **Direct MCP Integration**: 7 native tools available without CLI overhead
- **Text-to-Image**: Generate single or batch images with style/variation controls
- **Image Editing**: Modify existing images with natural language prompts
- **Photo Restoration**: Enhance and repair damaged photos
- **Icon Generation**: App icons, favicons, UI elements in multiple sizes
- **Pattern Generation**: Seamless textures, wallpapers, and backgrounds
- **Story Sequences**: Multi-step visual narratives (2-8 frames)
- **Technical Diagrams**: Flowcharts, architecture, network, database, wireframes, mindmaps

## Prerequisites

1. **Node.js** (v18.0.0 or later)
   ```bash
   node --version  # Should show v18+
   ```

2. **Gemini API Key**
   ```bash
   export GEMINI_API_KEY=your_key
   ```
   Get a key from [Google AI Studio](https://aistudio.google.com/apikey).

## Installation

This plugin is part of the cc-dev-tools marketplace. To install:

1. Add the marketplace:
   ```bash
   /marketplace add https://github.com/Lucklyric/cc-dev-tools
   ```

2. Install the plugin:
   ```bash
   /plugin install nanobanana@cc-dev-tools
   ```

3. Install MCP server dependencies (if not already present):
   ```bash
   cd ~/.claude/plugins/cache/cc-dev-tools/nanobanana/*/mcp-server
   npm install --production --ignore-scripts
   ```

4. Restart Claude Code

## Usage

The skill is automatically triggered when you ask for image generation:

```
User: "Generate 3 variations of a sunset over mountains"
User: "Create an app icon for a coffee shop"
User: "Draw a flowchart for user authentication"
User: "Edit this photo to change the background"
```

## Available MCP Tools

| Tool | Description |
|------|-------------|
| `generate_image` | Text-to-image with styles and variations |
| `edit_image` | Modify existing images via prompt |
| `restore_image` | Enhance and repair photos |
| `generate_icon` | Multi-size icon generation |
| `generate_pattern` | Seamless patterns and textures |
| `generate_story` | Sequential visual narratives |
| `generate_diagram` | Technical diagrams and flowcharts |

## Configuration

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `GEMINI_API_KEY` | Yes* | Gemini API key (primary) |
| `NANOBANANA_API_KEY` | Yes* | Alternative API key (takes precedence) |
| `NANOBANANA_MODEL` | No | Override image model (default: `gemini-3.1-flash-image-preview`) |

*At least one API key must be set.

### Model Selection

| Model | Quality | Speed |
|-------|---------|-------|
| `gemini-3.1-flash-image-preview` | Good (default) | Fast |
| `gemini-3-pro-image-preview` | Higher quality | Slower |
| `gemini-2.5-flash-image` | Legacy v1 | Fast |

## Output

All generated images are saved to `./nanobanana-output/` in the current working directory.

## Upstream Reference

This plugin bundles the MCP server from [gemini-cli-extensions/nanobanana](https://github.com/gemini-cli-extensions/nanobanana). Check the upstream repository for updates, new features, and bug fixes.

## Documentation

- **skills/nanobanana/SKILL.md**: Skill definition and quick usage guide
- **skills/nanobanana/references/commands.md**: Full tool parameter reference
- **skills/nanobanana/references/troubleshooting.md**: Auth and error reference

## Slash Commands

| Command | Description |
|---------|-------------|
| `/generate` | Generate images from text prompts |
| `/edit` | Edit an existing image |
| `/restore` | Restore or enhance a photo |
| `/icon` | Generate app icons in multiple sizes |
| `/pattern` | Generate seamless patterns and textures |
| `/story` | Generate sequential visual narratives |
| `/diagram` | Generate technical diagrams and flowcharts |
| `/nanobanana` | Natural language routing (auto-selects best tool) |

## Version

1.2.0

## Author

0xasun

## License

Apache-2.0
