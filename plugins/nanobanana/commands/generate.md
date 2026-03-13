---
description: Generate images from a text prompt with optional style and variation controls
argument-hint: <prompt> [--count=N] [--styles="style1,style2"] [--variations="var1,var2"]
allowed-tools: [mcp__nanobanana__generate_image, Read, Glob]
---

# Nano Banana: Generate Image

Parse the user's input and call the `generate_image` MCP tool.

## Arguments

User input: $ARGUMENTS

## Instructions

1. Extract the main prompt (text before any options)
2. Parse any options from the input:
   - `--count=N` (1-8, default: 3) → maps to `outputCount`
   - `--styles="style1,style2"` → maps to `styles` array. Valid: photorealistic, watercolor, oil-painting, sketch, pixel-art, anime, vintage, modern, abstract, minimalist
   - `--variations="var1,var2"` → maps to `variations` array. Valid: lighting, angle, color-palette, composition, mood, season, time-of-day
   - `--format=grid|separate` → maps to `format` (default: separate)
   - `--seed=123` → maps to `seed` (integer)
3. If any options are invalid, tell the user what's wrong and list the valid options
4. Call `generate_image` with the parsed parameters. Default `outputCount` to 3 if not specified.
5. After generation, list the contents of `./nanobanana-output/` and present the most recent image(s) to the user using the Read tool

## Examples

```
/generate a sunset over mountains, photorealistic
/generate a cute robot mascot --count=5 --styles="pixel-art,modern"
/generate abstract wallpaper --variations="color-palette,mood" --count=2
```
