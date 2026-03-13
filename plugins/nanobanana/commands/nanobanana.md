---
description: Generate and manipulate images using natural language (auto-selects the best tool)
argument-hint: <natural language request>
allowed-tools: [mcp__nanobanana__generate_image, mcp__nanobanana__edit_image, mcp__nanobanana__restore_image, mcp__nanobanana__generate_icon, mcp__nanobanana__generate_pattern, mcp__nanobanana__generate_story, mcp__nanobanana__generate_diagram, Read, Glob]
---

# Nano Banana: Natural Language Image Generation

Analyze the user's request and route to the most appropriate MCP tool.

## Arguments

User input: $ARGUMENTS

## Instructions

Analyze the user's natural language request and determine the best tool:

| Intent | Tool |
|--------|------|
| Generate single/multiple images | `generate_image` |
| Edit an existing image | `edit_image` |
| Restore/enhance a photo | `restore_image` |
| Create app icons, favicons, UI elements | `generate_icon` |
| Create seamless patterns, textures | `generate_pattern` |
| Create visual stories, sequences | `generate_story` |
| Create technical diagrams, flowcharts | `generate_diagram` |

1. Parse the natural language request to identify intent and parameters
2. Select the most specialized tool for the request
3. If the request references a file, resolve it to an **absolute path** before passing to the MCP tool
4. Call the tool with appropriate parameters
5. For `generate_image`, default `outputCount` to 3 unless specified otherwise
5. After generation, present the result(s) to the user using the Read tool

## Examples

```
/nanobanana create 3 variations of a mountain landscape at sunset
/nanobanana edit photo.jpg to add a rainbow in the sky
/nanobanana design a mobile app icon for a fitness tracker
/nanobanana draw a flowchart for CI/CD pipeline
/nanobanana make a comic strip about a cat learning to code
```
