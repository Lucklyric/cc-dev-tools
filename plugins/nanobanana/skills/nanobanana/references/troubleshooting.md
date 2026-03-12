# Nanobanana Troubleshooting

Upstream reference: https://github.com/gemini-cli-extensions/nanobanana

## Prerequisites

| Requirement | Check | Fix |
|-------------|-------|-----|
| Node.js >= 18 | `node --version` | Install from https://nodejs.org |
| API key | `echo $GEMINI_API_KEY` | Get from https://aistudio.google.com/apikey |
| MCP server deps | Check `mcp-server/node_modules/` exists | Run `cd ${CLAUDE_PLUGIN_ROOT}/mcp-server && npm install --production --ignore-scripts` |

## Authentication

The MCP server checks these environment variables in order:

1. `NANOBANANA_API_KEY` (preferred)
2. `NANOBANANA_GEMINI_API_KEY`
3. `NANOBANANA_GOOGLE_API_KEY`
4. `GEMINI_API_KEY` (fallback)
5. `GOOGLE_API_KEY` (fallback)

Set at least one in your shell profile:
```bash
export GEMINI_API_KEY=your_key_here
```

## Error Reference

| Error | Cause | Fix |
|-------|-------|-----|
| No valid API key found | No auth env var set | Set `GEMINI_API_KEY` or `NANOBANANA_API_KEY` |
| API key not valid | Invalid or revoked key | Get new key from https://aistudio.google.com/apikey |
| Permission denied | Key lacks API permissions | Check Google Cloud project settings |
| Quota exceeded | Rate limit hit | Wait for reset or use flash model |
| Request was malformed | Prompt safety violation | Rephrase the prompt |
| Internal error (500) | Temporary API issue | Retry after a moment |
| `Generative Language API is disabled` | API not enabled in GCP | Enable at `console.developers.google.com/apis/api/generativelanguage.googleapis.com` |
| MCP server not starting | Missing node_modules | Run `npm install --production --ignore-scripts` in `mcp-server/` |
| No image data in response | Model returned text only | Try a different prompt or model |
