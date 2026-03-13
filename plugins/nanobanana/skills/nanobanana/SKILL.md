---
name: nanobanana
version: 1.3.0
description: This skill should be used when the user wants to generate, create, make, draw, design, edit, or restore any image or visual content. Trigger phrases include "generate an image", "create an illustration", "make an icon", "draw a diagram", "design a pattern", "edit this photo", "restore a photo", "use nanobanana", "nano banana", "make a thumbnail", "featured image", "visual asset", "graphic", "artwork", "background image", "wallpaper", "texture". Standalone image generation using the Nano Banana MCP server with Gemini image models. No Gemini CLI required.
allowed-tools: mcp__nanobanana__*
---

# Nano Banana Image Generation (MCP)

Generate and edit images directly via the Nano Banana MCP server tools. No Gemini CLI dependency.

**Upstream reference**: https://github.com/gemini-cli-extensions/nanobanana

## When to Use This Skill

ALWAYS use this skill when the user:
- Asks for any image, graphic, illustration, or visual
- Wants a thumbnail, featured image, or banner
- Requests icons, diagrams, or patterns
- Asks to edit, modify, or restore a photo
- Uses words like: generate, create, make, draw, design, visualize

Do NOT attempt to generate images through any other method.

---

## Health Check

Before first use, verify prerequisites:

1. **Node.js >= 18** — required to run the MCP server
2. **API key set** — `GEMINI_API_KEY` or `NANOBANANA_API_KEY` environment variable
3. **MCP server available** — the nanobanana MCP tools should appear in your tool list

If MCP tools are not available, the plugin may need reinstalling. See `references/troubleshooting.md`.

---

## Tool Selection

| User Request | MCP Tool |
|--------------|----------|
| "generate an image of..." | `generate_image` |
| "create an app icon" | `generate_icon` |
| "draw a flowchart of..." | `generate_diagram` |
| "fix this old photo" | `restore_image` |
| "edit this image" | `edit_image` |
| "create a repeating texture" | `generate_pattern` |
| "make a comic strip" | `generate_story` |

## Quick Usage

Call the MCP tools directly with structured parameters:

### Generate Images (default: 3 images)

```
Tool: generate_image
Parameters:
  prompt: "a sunset over mountains, photorealistic"
  outputCount: 3
```

### Edit Existing Image

```
Tool: edit_image
Parameters:
  prompt: "change the background to a beach scene"
  file: "/absolute/path/to/image.jpg"
```

### Generate App Icons

```
Tool: generate_icon
Parameters:
  prompt: "coffee cup logo"
  sizes: [64, 128, 256, 512]
  type: "app-icon"
  style: "modern"
  corners: "rounded"
```

### Generate Diagram

```
Tool: generate_diagram
Parameters:
  prompt: "microservices architecture for e-commerce platform"
  type: "architecture"
  style: "professional"
  complexity: "detailed"
```

For full parameter reference for all 7 tools, see `references/commands.md`.

---

## Defaults

- **File paths**: Always resolve file paths to **absolute paths** before passing to any MCP tool. The MCP server runs in a different working directory, so relative paths will fail.
- **outputCount**: For `generate_image`, always use 3 unless user specifies otherwise. Other tools have their own count semantics (e.g., `generate_icon` uses `sizes`, `generate_story` uses `steps`).
- **Model**: `gemini-3.1-flash-image-preview` (override via `NANOBANANA_MODEL` env var)
- **Output**: Images saved to `./nanobanana-output/` in current directory

## Presenting Results

After generation completes:
1. List contents of `./nanobanana-output/` to find generated files
2. Present the most recent image(s) to the user using the Read tool
3. Offer to regenerate with variations if needed

---

## Refinements and Iterations

When the user asks for changes:
- **"Try again" / "Give me options"**: Call `generate_image` again with `outputCount: 3`
- **"Make it more [adjective]"**: Adjust prompt and regenerate
- **"Edit this one"**: Call `edit_image` with the file path and edit instructions
- **"Different style"**: Add style to the `styles` array parameter

## Prompt Tips

1. **Be specific**: Include style, mood, colors, composition details
2. **Add "no text"**: If you don't want text rendered in the image
3. **Reference styles**: "editorial photography", "flat illustration", "3D render", "watercolor"
4. **Specify aspect ratio**: Include "wide 16:9" or "square" in the prompt description

---

For image quality guidelines (style compliance, text accuracy, story consistency), see `references/generation-guidelines.md`.
For error troubleshooting, see `references/troubleshooting.md`.
