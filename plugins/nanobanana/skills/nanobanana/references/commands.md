# Nanobanana MCP Tools Reference

Full parameter reference for all 7 nanobanana MCP tools. Upstream: https://github.com/gemini-cli-extensions/nanobanana

---

## `generate_image` — Text-to-Image

Generate single or multiple images from text prompts with style and variation options.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `prompt` | string | Yes | — | Text prompt describing the image |
| `outputCount` | number | No | 1 (skill default: **3**) | Number of variations (1-8) |
| `styles` | string[] | No | — | Artistic styles to apply |
| `variations` | string[] | No | — | Variation types to generate |
| `format` | string | No | `separate` | `grid` or `separate` files |
| `seed` | number | No | — | Seed for reproducible results |
| `preview` | boolean | No | false | Auto-open in default viewer |

**Available styles**: photorealistic, watercolor, oil-painting, sketch, pixel-art, anime, vintage, modern, abstract, minimalist

**Available variations**: lighting, angle, color-palette, composition, mood, season, time-of-day

---

## `edit_image` — Image Modification

Edit an existing image based on a text prompt.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `prompt` | string | Yes | — | Edit instructions |
| `file` | string | Yes | — | Input image filename or path |
| `preview` | boolean | No | false | Auto-open in default viewer |

**File search paths**: Current directory, `images/`, `input/`, `nanobanana-output/`, `~/Downloads`, `~/Desktop`.

---

## `restore_image` — Photo Enhancement

Restore or enhance an existing image.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `prompt` | string | Yes | — | Restoration instructions |
| `file` | string | Yes | — | Input image filename or path |
| `preview` | boolean | No | false | Auto-open in default viewer |

---

## `generate_icon` — Icon Generation

Generate app icons, favicons, and UI elements in multiple sizes and formats.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `prompt` | string | Yes | — | Icon description |
| `sizes` | number[] | No | — | Pixel sizes: 16, 32, 64, 128, 256, 512, 1024 |
| `type` | string | No | `app-icon` | `app-icon`, `favicon`, `ui-element` |
| `style` | string | No | `modern` | `flat`, `skeuomorphic`, `minimal`, `modern` |
| `format` | string | No | `png` | `png`, `jpeg` |
| `background` | string | No | `transparent` | `transparent`, `white`, `black`, or color name |
| `corners` | string | No | `rounded` | `rounded`, `sharp` |
| `preview` | boolean | No | false | Auto-open in default viewer |

---

## `generate_pattern` — Seamless Patterns

Generate seamless patterns and textures for backgrounds and design elements.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `prompt` | string | Yes | — | Pattern description |
| `size` | string | No | `256x256` | Tile size (e.g., `128x128`, `512x512`) |
| `type` | string | No | `seamless` | `seamless`, `texture`, `wallpaper` |
| `style` | string | No | `abstract` | `geometric`, `organic`, `abstract`, `floral`, `tech` |
| `density` | string | No | `medium` | `sparse`, `medium`, `dense` |
| `colors` | string | No | `colorful` | `mono`, `duotone`, `colorful` |
| `repeat` | string | No | `tile` | `tile`, `mirror` |
| `preview` | boolean | No | false | Auto-open in default viewer |

---

## `generate_story` — Sequential Narratives

Generate a sequence of related images that tell a visual story or show a process.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `prompt` | string | Yes | — | Story or process description |
| `steps` | number | No | 4 | Number of sequential images (2-8) |
| `type` | string | No | `story` | `story`, `process`, `tutorial`, `timeline` |
| `style` | string | No | `consistent` | `consistent`, `evolving` |
| `layout` | string | No | `separate` | `separate`, `grid`, `comic` |
| `transition` | string | No | `smooth` | `smooth`, `dramatic`, `fade` |
| `format` | string | No | `individual` | `storyboard`, `individual` |
| `preview` | boolean | No | false | Auto-open in default viewer |

---

## `generate_diagram` — Technical Diagrams

Generate technical diagrams, flowcharts, and architectural mockups.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `prompt` | string | Yes | — | Diagram content description |
| `type` | string | No | `flowchart` | `flowchart`, `architecture`, `network`, `database`, `wireframe`, `mindmap`, `sequence` |
| `style` | string | No | `professional` | `professional`, `clean`, `hand-drawn`, `technical` |
| `layout` | string | No | `hierarchical` | `horizontal`, `vertical`, `hierarchical`, `circular` |
| `complexity` | string | No | `detailed` | `simple`, `detailed`, `comprehensive` |
| `colors` | string | No | `accent` | `mono`, `accent`, `categorical` |
| `annotations` | string | No | `detailed` | `minimal`, `detailed` |
| `preview` | boolean | No | false | Auto-open in default viewer |

---

## Model Selection

Default: `gemini-3.1-flash-image-preview` (fast, good quality)

| Model | Quality | Speed |
|-------|---------|-------|
| `gemini-3.1-flash-image-preview` | Good (default) | Fast |
| `gemini-3-pro-image-preview` | Higher quality | Slower |
| `gemini-2.5-flash-image` | Legacy v1 | Fast |

Override via environment variable:
```bash
export NANOBANANA_MODEL=gemini-3-pro-image-preview
```
