---
description: Generate seamless patterns and textures for backgrounds and design elements
argument-hint: <prompt> [--type=seamless] [--style=abstract] [--density=medium] [--colors=colorful]
allowed-tools: [mcp__nanobanana__generate_pattern, Read, Glob]
---

# Nano Banana: Generate Pattern

Parse the user's input and call the `generate_pattern` MCP tool.

## Arguments

User input: $ARGUMENTS

## Instructions

1. Extract the main prompt (text before any options, required)
2. Parse any options:
   - `--size="WxH"` → maps to `size` (e.g., 128x128, 256x256, 512x512; default: 256x256)
   - `--type=seamless|texture|wallpaper` → maps to `type` (default: seamless)
   - `--style=geometric|organic|abstract|floral|tech` → maps to `style` (default: abstract)
   - `--density=sparse|medium|dense` → maps to `density` (default: medium)
   - `--colors=mono|duotone|colorful` → maps to `colors` (default: colorful)
   - `--repeat=tile|mirror` → maps to `repeat` (default: tile)
3. If any options are invalid, tell the user and list valid values
4. Call `generate_pattern` with the parsed parameters
5. After generation, present the pattern to the user using the Read tool

## Examples

```
/pattern Japanese wave motif
/pattern geometric hexagons --style=tech --colors=mono --density=dense
/pattern floral vintage wallpaper --type=wallpaper --style=floral --size="512x512"
```
