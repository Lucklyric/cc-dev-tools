---
description: Generate app icons, favicons, and UI elements in multiple sizes
argument-hint: <prompt> [--sizes="64,128,256"] [--type=app-icon] [--style=modern] [--corners=rounded]
allowed-tools: [mcp__nanobanana__generate_icon, Read, Glob]
---

# Nano Banana: Generate Icon

Parse the user's input and call the `generate_icon` MCP tool.

## Arguments

User input: $ARGUMENTS

## Instructions

1. Extract the main prompt (text before any options, required)
2. Parse any options:
   - `--sizes="16,32,64"` → maps to `sizes` array. Valid sizes: 16, 32, 64, 128, 256, 512, 1024
   - `--type=app-icon|favicon|ui-element` → maps to `type` (default: app-icon)
   - `--style=flat|skeuomorphic|minimal|modern` → maps to `style` (default: modern)
   - `--format=png|jpeg` → maps to `format` (default: png)
   - `--background=transparent|white|black` → maps to `background` (default: transparent)
   - `--corners=rounded|sharp` → maps to `corners` (default: rounded)
3. If any options are invalid, tell the user and list valid values
4. Call `generate_icon` with the parsed parameters
5. After generation, present the icon(s) to the user using the Read tool

## Examples

```
/icon coffee cup logo
/icon rocket ship app icon --sizes="64,128,256,512" --style=flat
/icon settings gear --type=ui-element --corners=sharp --background=white
```
