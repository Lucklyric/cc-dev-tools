---
description: Generate a sequence of related images that tell a visual story or show a process
argument-hint: <prompt> [--steps=N] [--type=story] [--style=consistent] [--layout=separate]
allowed-tools: [mcp__nanobanana__generate_story, Read, Glob]
---

# Nano Banana: Generate Story

Parse the user's input and call the `generate_story` MCP tool.

## Arguments

User input: $ARGUMENTS

## Instructions

1. Extract the main prompt (text before any options, required)
2. Parse any options:
   - `--steps=N` → maps to `steps` (2-8, default: 4)
   - `--type=story|process|tutorial|timeline` → maps to `type` (default: story)
   - `--style=consistent|evolving` → maps to `style` (default: consistent)
   - `--layout=separate|grid|comic` → maps to `layout` (default: separate)
   - `--transition=smooth|dramatic|fade` → maps to `transition` (default: smooth)
   - `--format=storyboard|individual` → maps to `format` (default: individual)
3. If any options are invalid, tell the user and list valid values
4. Call `generate_story` with the parsed parameters
5. After generation, present all story frames to the user using the Read tool

## Examples

```
/story a day in the life of a robot barista
/story how to make sushi --type=tutorial --steps=6
/story seasons changing in a garden --style=evolving --transition=fade
```
