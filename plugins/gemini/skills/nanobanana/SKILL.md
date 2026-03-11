---
name: nanobanana
version: 2.0.0
description: REQUIRED for all image generation requests. Generate and edit images using Nano Banana (Gemini CLI). Handles illustrations, icons, diagrams, patterns, thumbnails, featured images, visual assets, graphics, artwork, photos. Use this skill whenever the user asks to create, generate, make, draw, design, edit, or restore any image or visual content.
allowed-tools: Bash(gemini:*)
---

# Nano Banana Image Generation

Generate professional images via the Gemini CLI's nanobanana extension.

## When to Use This Skill

ALWAYS use this skill when the user:
- Asks for any image, graphic, illustration, or visual
- Wants a thumbnail, featured image, or banner
- Requests icons, diagrams, or patterns
- Asks to edit, modify, or restore a photo
- Uses words like: generate, create, make, draw, design, visualize

Do NOT attempt to generate images through any other method.

---

## Health Check (Run Before First Use)

```bash
# 1. Check Gemini CLI installed
command -v gemini && echo "OK: gemini found" || echo "FAIL: gemini not found"

# 2. Check nanobanana extension installed
ls ~/.gemini/extensions/ 2>/dev/null | grep -qi nanobanana && echo "OK: nanobanana installed" || echo "FAIL: nanobanana not installed"

# 3. Check authentication (API key OR Vertex AI)
AUTH="${NANOBANANA_AUTH_METHOD:-api_key}"
if [ "$AUTH" = "vertex_ai" ]; then
  [ -n "$GCP_PROJECT_ID" ] && [ -n "$GCP_REGION" ] && echo "OK: Vertex AI auth ($GCP_PROJECT_ID / $GCP_REGION)" || echo "FAIL: Vertex AI requires GCP_PROJECT_ID and GCP_REGION"
elif [ "$AUTH" = "auto" ]; then
  [ -n "$NANOBANANA_API_KEY" ] || [ -n "$GEMINI_API_KEY" ] || [ -n "$GCP_PROJECT_ID" ] && echo "OK: auth auto" || echo "FAIL: Set NANOBANANA_API_KEY, GEMINI_API_KEY, or GCP_PROJECT_ID+GCP_REGION"
else
  ([ -n "$NANOBANANA_API_KEY" ] || [ -n "$GEMINI_API_KEY" ]) && echo "OK: API key set" || echo "FAIL: NANOBANANA_API_KEY or GEMINI_API_KEY not set"
fi
echo "AUTH_METHOD=$AUTH"
```

| Check | If FAIL | Fix |
|-------|---------|-----|
| Gemini CLI not found | Install it | `npm install -g @google/gemini-cli` |
| Nanobanana not installed | Install extension | `gemini extensions install https://github.com/gemini-cli-extensions/nanobanana` |
| API key not set | Set env var | Get key from [Google AI Studio](https://aistudio.google.com/apikey), then `export GEMINI_API_KEY=your_key` |
| Vertex AI missing vars | Set GCP env vars | `export NANOBANANA_AUTH_METHOD=vertex_ai GCP_PROJECT_ID=your-project GCP_REGION=us-central1` |

**If any check fails**, stop and guide the user. Do not run nanobanana commands until all checks pass.

---

## Authentication Methods

| Method | Env Vars Required | Best For |
|--------|-------------------|----------|
| `api_key` (default) | `NANOBANANA_API_KEY` or `GEMINI_API_KEY` | Local dev, simple setups |
| `vertex_ai` | `GCP_PROJECT_ID`, `GCP_REGION` + ADC | Production on GCP |
| `auto` | Tries API key first, falls back to Vertex AI | Flexible environments |

**Vertex AI setup** (add to `.zshrc`):
```bash
export NANOBANANA_AUTH_METHOD=vertex_ai
export GCP_PROJECT_ID=your-project-id
export GCP_REGION=us-central1
```

**IAM requirement**: Grant `roles/aiplatform.user` to the service account or user.

---

## Command Pattern

**Always use `--yolo` flag** to auto-approve all tool actions (prevents hanging in non-interactive mode):

```bash
gemini --yolo "/command 'description' --flags"
```

**Skill default: `--count=3`** — always generate 3 images unless user specifies otherwise.

---

## Command Selection

| User Request | Command |
|--------------|---------|
| "generate an image of..." | `/generate` |
| "create an app icon" | `/icon` |
| "draw a flowchart of..." | `/diagram` |
| "fix this old photo" | `/restore` |
| "edit this image" | `/edit` |
| "create a repeating texture" | `/pattern` |
| "make a comic strip" | `/story` |
| General/unclear request | `/nanobanana` |

---

## Commands Reference

### `/generate` - Text-to-Image

```bash
# Default (3 images)
gemini --yolo "/generate 'a sunset over mountains' --count=3"

# With styles
gemini --yolo "/generate 'mountain landscape' --count=3 --styles='watercolor,oil-painting,sketch'"

# With preview
gemini --yolo "/generate 'portrait of a cat' --count=3 --preview"

# Reproducible
gemini --yolo "/generate 'abstract art' --seed=42 --count=3"
```

**Flags:**

| Flag | Values | Description |
|------|--------|-------------|
| `--count` | 1-8 (skill default: **3**) | Number of images |
| `--styles` | comma-separated | Artistic styles |
| `--variations` | comma-separated | Variation types |
| `--format` | `grid`, `separate` | Output layout |
| `--seed` | integer | Reproducible variations |
| `--preview` | flag | Auto-open results |

**Styles:** photorealistic, watercolor, oil-painting, sketch, pixel-art, anime, vintage, modern, abstract, minimalist

**Variations:** lighting, angle, color-palette, composition, mood, season, time-of-day

### `/edit` - Image Modification

```bash
gemini --yolo "/edit path/to/image.jpg 'change background to beach scene' --preview"
```

### `/restore` - Photo Enhancement

```bash
gemini --yolo "/restore old_photo.jpg 'remove scratches and enhance colors' --preview"
```

### `/icon` - Icon Generation

```bash
gemini --yolo "/icon 'coffee cup logo' --sizes='64,128,256,512' --type='app-icon' --corners='rounded' --preview"
```

| Flag | Values |
|------|--------|
| `--sizes` | e.g., "64,128,256,512" |
| `--type` | `app-icon`, `favicon`, `ui-element` |
| `--style` | `flat`, `skeuomorphic`, `minimal`, `modern` |
| `--background` | `transparent`, `white`, `black`, color |
| `--corners` | `rounded`, `sharp` |

### `/pattern` - Seamless Patterns

```bash
gemini --yolo "/pattern 'geometric triangles' --type='seamless' --style='geometric' --preview"
```

| Flag | Values |
|------|--------|
| `--type` | `seamless`, `texture`, `wallpaper` |
| `--style` | `geometric`, `organic`, `abstract`, `floral`, `tech` |
| `--density` | `sparse`, `medium`, `dense` |
| `--colors` | `mono`, `duotone`, `colorful` |

### `/story` - Sequential Visual Narratives

```bash
gemini --yolo "/story 'seed growing into tree' --steps=4 --type='process' --preview"
```

| Flag | Values |
|------|--------|
| `--steps` | 2-8 |
| `--type` | `story`, `process`, `tutorial`, `timeline` |
| `--style` | `consistent`, `evolving` |
| `--layout` | `separate`, `grid`, `comic` |

### `/diagram` - Technical Diagrams

```bash
gemini --yolo "/diagram 'microservices architecture' --type='architecture' --complexity='detailed'"
```

| Flag | Values |
|------|--------|
| `--type` | `flowchart`, `architecture`, `network`, `database`, `wireframe`, `mindmap`, `sequence` |
| `--style` | `professional`, `clean`, `hand-drawn`, `technical` |
| `--complexity` | `simple`, `detailed`, `comprehensive` |

### `/nanobanana` - Natural Language Interface

```bash
gemini --yolo "/nanobanana create a logo for my tech startup"
```

Use when the request doesn't map cleanly to a specific command.

---

## Common Sizes

| Use Case | Dimensions | Notes |
|----------|------------|-------|
| YouTube thumbnail | 1280x720 | `--aspect=16:9` |
| Blog featured image | 1200x630 | Social preview friendly |
| Square social | 1080x1080 | Instagram, LinkedIn |
| Twitter/X header | 1500x500 | Wide banner |
| Vertical story | 1080x1920 | `--aspect=9:16` |

---

## Model Selection

Default: `gemini-3.1-flash-image-preview` (fast, good quality)

| Model | Quality | Speed |
|-------|---------|-------|
| `gemini-3.1-flash-image-preview` | Good (default) | Fast |
| `gemini-3-pro-image-preview` | Higher quality | Slower |
| `gemini-2.5-flash-image` | Legacy v1 | Fast |

Override inline:
```bash
NANOBANANA_MODEL=gemini-3-pro-image-preview gemini --yolo "/generate 'prompt' --count=3"
```

---

## Output Location

All generated images are saved to `./nanobanana-output/` in the current directory.

## Presenting Results

After generation completes:
1. List contents of `./nanobanana-output/` to find generated files
2. Present the most recent image(s) to the user using the Read tool
3. Offer to regenerate with variations if needed

---

## Refinements and Iterations

When the user asks for changes:
- **"Try again" / "Give me options"**: Regenerate with `--count=3`
- **"Make it more [adjective]"**: Adjust prompt and regenerate
- **"Edit this one"**: Use `gemini --yolo "/edit nanobanana-output/filename.png 'adjustment'"`
- **"Different style"**: Add `--styles="requested_style"` to the command

## Prompt Tips

1. **Be specific**: Include style, mood, colors, composition details
2. **Add "no text"**: If you don't want text rendered in the image
3. **Reference styles**: "editorial photography", "flat illustration", "3D render", "watercolor"
4. **Specify aspect ratio**: "wide banner", "square thumbnail", "vertical story"

---

## Error Handling

| Error | Cause | Fix |
|-------|-------|-----|
| Extension not found | Not installed | `gemini extensions install https://github.com/gemini-cli-extensions/nanobanana` |
| API key missing | No auth configured | Set `GEMINI_API_KEY` or switch to `vertex_ai` auth |
| Vertex AI auth failed | Missing GCP vars or no ADC | Run `gcloud auth application-default login` and set env vars |
| IAM permission denied | Missing `roles/aiplatform.user` | Grant IAM role to service account |
| Model unavailable | Invalid model ID | Check `NANOBANANA_MODEL` value |
| Generation failed | Prompt safety filter | Rephrase the prompt |
| Quota exceeded | Rate limit hit | Wait for reset or switch to flash model |
