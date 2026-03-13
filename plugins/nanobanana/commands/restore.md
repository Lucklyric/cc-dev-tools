---
description: Restore or enhance an existing image
argument-hint: <filename> <restoration instructions>
allowed-tools: [mcp__nanobanana__restore_image, Read, Glob]
---

# Nano Banana: Restore Image

Parse the user's input and call the `restore_image` MCP tool.

## Arguments

User input: $ARGUMENTS

## Instructions

1. Extract the filename (first argument, required)
2. Extract the restoration prompt (remaining text after filename, required)
3. If either is missing, show usage: `/restore <filename> <restoration instructions>`
4. Resolve the filename to an **absolute path** before passing to the MCP tool
5. Call `restore_image` with:
   - `file`: the absolute file path
   - `prompt`: the restoration instructions
5. After restoration, present the result image to the user using the Read tool

## Examples

```
/restore old_photo.jpg enhance and remove scratches
/restore damaged.png fix the torn edges and improve clarity
/restore faded.jpg restore original colors and sharpness
```
