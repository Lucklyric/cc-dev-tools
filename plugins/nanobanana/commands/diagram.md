---
description: Generate technical diagrams, flowcharts, and architectural mockups
argument-hint: <prompt> [--type=flowchart] [--style=professional] [--complexity=detailed]
allowed-tools: [mcp__nanobanana__generate_diagram, Read, Glob]
---

# Nano Banana: Generate Diagram

Parse the user's input and call the `generate_diagram` MCP tool.

## Arguments

User input: $ARGUMENTS

## Instructions

1. Extract the main prompt (text before any options, required)
2. Parse any options:
   - `--type=flowchart|architecture|network|database|wireframe|mindmap|sequence` → maps to `type` (default: flowchart)
   - `--style=professional|clean|hand-drawn|technical` → maps to `style` (default: professional)
   - `--layout=horizontal|vertical|hierarchical|circular` → maps to `layout` (default: hierarchical)
   - `--complexity=simple|detailed|comprehensive` → maps to `complexity` (default: detailed)
   - `--colors=mono|accent|categorical` → maps to `colors` (default: accent)
   - `--annotations=minimal|detailed` → maps to `annotations` (default: detailed)
3. If any options are invalid, tell the user and list valid values
4. Call `generate_diagram` with the parsed parameters
5. After generation, present the diagram to the user using the Read tool

## Examples

```
/diagram user authentication flow
/diagram microservices architecture for e-commerce --type=architecture --complexity=comprehensive
/diagram database schema for blog platform --type=database --style=clean
```
