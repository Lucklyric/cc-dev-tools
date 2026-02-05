# Gemini Model Selection Guide

**Purpose**: Guide for selecting the right Gemini model for your task
**Version**: v0.26.0+
**Last Updated**: 2026-02-05

## Quick Reference

| Task Type | Recommended Model | Reason |
|-----------|------------------|---------|
| ALL tasks (default) | `gemini-3-pro-preview` | Highest capability, best for all problems |
| Fallback (if 3 Pro unavailable) | `gemini-2.5-pro` | Stable, reliable, 1M context |
| Last resort fallback | `gemini-2.5-flash` | Always available on free tier |

**Note**: Use `gemini-3-pro-preview` for ALL tasks by default. Fallback to older models only when primary is unavailable.

## Version-Based Model Mapping

### Concept

When users mention a version number (e.g., "use Gemini 3"), map to the latest model in that family for future-proofing.

### Current Mappings (as of Feb 2026)

| User Request | Maps To | Actual Model ID | Status | Notes |
|--------------|---------|-----------------|--------|-------|
| "Gemini 3" or "use 3" | Latest 3.x Pro | `gemini-3-pro-preview` | Preview | Requires preview access |
| "Gemini 2.5" or "use 2.5" | 2.5 Pro | `gemini-2.5-pro` | Stable | 1M tokens context |
| "use flash" | 2.5 Flash | `gemini-2.5-flash` | Stable | Fast, always available |
| No version specified | Latest Pro (ALL tasks) | `gemini-3-pro-preview` | Preview | **DEFAULT** |

### Future-Proofing Strategy

```
User says "3" → Plugin maps to latest_3x_pro
                 Currently: gemini-3-pro-preview
                 Future:    gemini-3-pro (when stable)
                           gemini-3.1-pro (when released)

User says "2.5" → Plugin maps to gemini-2.5-pro
                  (No longer task-differentiated)

No version specified → gemini-3-pro-preview for ALL tasks
```

**Maintenance**: Update mapping table when new models release

## Model Family Overview

### Gemini 3 Family (Latest - Preview)

**gemini-3-pro-preview**
- **Status**: Preview (requires access)
- **Context**: 1M tokens
- **Strengths**: Cutting-edge reasoning, complex problem-solving
- **Use Cases**: System architecture, complex algorithms, research
- **Access**: Google AI Ultra subscribers, paid API keys, or waitlist
- **Availability**: May be quota-limited on free tier

```bash
gemini -m gemini-3-pro-preview "Design a distributed caching system"
```

### Gemini 2.5 Family (Stable)

**gemini-2.5-pro**
- **Status**: Stable, production-ready
- **Context**: 1M tokens
- **Strengths**: General reasoning, balanced performance
- **Use Cases**: Code review, technical writing, general assistance
- **Access**: Free tier (60 req/min, 1000 req/day)

```bash
gemini -m gemini-2.5-pro "Review this API design for best practices"
```

**gemini-2.5-flash**
- **Status**: Stable, production-ready
- **Context**: Unknown (likely lower than Pro)
- **Strengths**: Speed, code generation/editing
- **Use Cases**: Quick refactoring, syntax fixes, fast iterations
- **Access**: Free tier (60 req/min, 1000 req/day)

```bash
gemini -m gemini-2.5-flash "Refactor this function for better performance"
```

**gemini-2.5-flash-lite** (if available)
- **Status**: Stable (check CLI for availability)
- **Strengths**: Highest throughput, lowest cost
- **Use Cases**: High-volume simple tasks
- **Note**: May have reduced capabilities

## Task-Based Selection

### Single Model for All Tasks

**Use `gemini-3-pro-preview` for ALL task types:**

```
ALL Tasks (Any Complexity)
    ↓
    gemini-3-pro-preview (primary)
    ↓ (if unavailable)
    gemini-2.5-pro (fallback 1)
    ↓ (if unavailable)
    gemini-2.5-flash (fallback 2)
```

### By Task Type (All Use Same Model)

**Research & Design**
- Model: `gemini-3-pro-preview`
- Example: "Design a microservices architecture"

**Code Review & Analysis**
- Model: `gemini-3-pro-preview`
- Example: "Review this pull request for bugs"

**Code Generation & Editing**
- Model: `gemini-3-pro-preview`
- Example: "Refactor this code for readability"

**General Questions**
- Model: `gemini-3-pro-preview`
- Example: "Explain the CAP theorem"

**Rationale**: Gemini 3 Pro provides highest capability for all task types. No task differentiation needed.

## Selection Decision Tree

```
START: User makes request
  │
  ├─> User specifies model? ─────────────────┐
  │   (e.g., -m gemini-2.5-pro)               │
  │   YES ──> Use specified model ──> END     │
  │   NO ───> Continue                        │
  │                                           │
  ├─> User mentions version? ────────────────┤
  │   (e.g., "use 3" or "use 2.5")           │
  │   YES ──> Map to latest in family ──> END│
  │   NO ───> Continue                        │
  │                                           │
  ├─> Use gemini-3-pro-preview (ALL tasks)   │
  │                                           │
  └─> Apply fallback if primary unavailable  │
      (quota exhausted, access denied)        │
      gemini-3-pro-preview → gemini-2.5-pro  │
                          → gemini-2.5-flash │
      └──────────────────────────────────────┘
```

## Fallback Strategy

### Unified Fallback Chain

**Reason**: Quota exhausted, access denied, or service issue

**Fallback Logic** (same for ALL task types):
```
gemini-3-pro-preview unavailable
  │
  └─> gemini-2.5-pro
      │
      └─> gemini-2.5-flash (always available)
```

**Implementation Pattern**:
```bash
# Try Gemini 3 Pro first (all tasks)
gemini -m gemini-3-pro-preview "Your task" 2>&1

# If fails with quota/access error, retry with fallback
if [ $? -ne 0 ]; then
    gemini -m gemini-2.5-pro "Your task"
fi
```

## Free Tier Considerations

### Rate Limits (OAuth Free Tier)

- **60 requests per minute**
- **1,000 requests per day**
- **Context**: 1M tokens with Gemini 2.5 Pro

### Quota Management

**Gemini 3 Pro (Preview)**:
- May have stricter quotas
- May auto-switch to lower tier when exhausted
- Monitor for 429 (rate limit) or 403 (quota exceeded) errors

**Gemini 2.5 Models**:
- More generous free tier quotas
- Better availability
- Recommended for high-volume usage

### Cost Optimization

```
High volume, simple tasks → gemini-2.5-flash (fastest, cheapest)
Moderate volume, general → gemini-2.5-pro (balanced)
Low volume, complex → gemini-3-pro-preview (best quality)
```

## Model Capabilities Comparison

| Capability | Gemini 3 Pro | Gemini 2.5 Pro | Gemini 2.5 Flash |
|-----------|--------------|----------------|------------------|
| Reasoning | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| Code Generation | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Speed | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Context Window | 1M tokens | 1M tokens | Unknown |
| Stability | Preview | Stable | Stable |
| Free Tier Access | Limited | Yes | Yes |

## Access Requirements

### Gemini 3 Pro Access

**Preview Features Required**:
1. Update Gemini CLI to v0.16.x+
2. Enable Preview Features in CLI settings
3. Have one of:
   - Google AI Ultra subscription
   - Paid Gemini API key
   - Vertex API key with Gemini 3 access
   - Waitlist approval (free tier users)

**Verification**:
```bash
gemini -m gemini-3-pro-preview "test" 2>&1

# Success: Model responds
# Failure: 404 "model not found" or 403 "access denied"
```

### Gemini 2.5 Access

**Always Available** (free tier):
- `gemini-2.5-pro`
- `gemini-2.5-flash`

No special access required.

## Best Practices

1. **Default to Gemini 3 Pro for ALL tasks**: Use `gemini-3-pro-preview` regardless of task type
2. **Implement Graceful Fallback**: Use chain: gemini-3-pro-preview → gemini-2.5-pro → gemini-2.5-flash
3. **No Task Differentiation Needed**: Gemini 3 Pro handles coding and reasoning equally well
4. **Monitor Quotas**: Track rate limits and use fallback chain when needed
5. **Update Mapping Table**: Review quarterly for new model releases
6. **Test Access**: Verify Gemini 3 Pro access before defaulting to it
7. **Use Explicit Model Selection**: Specify `-m gemini-3-pro-preview` rather than relying on CLI defaults

## Updating This Guide

When new models are released:

1. Update "Current Mappings" table
2. Add new model to "Model Family Overview"
3. Update "Model Capabilities Comparison"
4. Revise fallback logic if needed
5. Update examples with new model IDs
6. Test all command patterns
7. Update "Last Updated" date

## Example Selection Scenarios

### Scenario 1: System Architecture Design

**Task**: "Design a scalable payment processing system"
**Selection**: `gemini-3-pro-preview` (default for all tasks)
**Fallback**: `gemini-2.5-pro` → `gemini-2.5-flash`

```bash
gemini -m gemini-3-pro-preview "Design a scalable payment processing system"
```

### Scenario 2: Code Fix

**Task**: "Fix the syntax error in this JavaScript"
**Selection**: `gemini-3-pro-preview` (default for all tasks)
**Fallback**: `gemini-2.5-pro` → `gemini-2.5-flash`

```bash
gemini -m gemini-3-pro-preview "Fix the syntax error in this code"
```

### Scenario 3: Pull Request Review

**Task**: "Review this pull request for best practices"
**Selection**: `gemini-3-pro-preview` (default for all tasks)
**Fallback**: `gemini-2.5-pro` → `gemini-2.5-flash`

```bash
gemini -m gemini-3-pro-preview "Review this pull request"
```

## See Also

- `gemini-help.md` - Full CLI reference
- `command-patterns.md` - Common command templates
- `session-workflows.md` - Session continuation patterns
