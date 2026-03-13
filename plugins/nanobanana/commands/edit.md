---
description: Edit an existing image based on a text prompt
argument-hint: <filename> <edit instructions>
allowed-tools: [mcp__nanobanana__edit_image, Read, Glob]
---

# Nano Banana: Edit Image

Parse the user's input and call the `edit_image` MCP tool.

## Arguments

User input: $ARGUMENTS

## Instructions

1. Extract the filename (first argument, required)
2. Extract the edit prompt (remaining text after filename, required)
3. If either is missing, show usage: `/edit <filename> <edit instructions>`
4. Call `edit_image` with:
   - `file`: the filename/path
   - `prompt`: the edit instructions
5. After editing, present the result image to the user using the Read tool

## Examples

```
/edit photo.jpg change the background to a beach scene
/edit ./nanobanana-output/sunset.png make the colors more vibrant
/edit logo.png add a shadow effect
```
