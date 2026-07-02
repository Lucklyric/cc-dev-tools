---
name: codex
description: This skill should be used when the user asks to "use codex", "ask codex", "run codex", "call codex", "codex cli", or explicitly asks to delegate work to a frontier reasoning model (e.g., "have GPT-5 review this", "get the OpenAI reasoning model to design X", "ask the high-reasoning model"). Also triggers on "continue codex" / "resume the codex session" for iterative development. Do NOT trigger when the user is merely discussing GPT-5 / OpenAI reasoning as a topic, or asking Claude itself to do complex implementation / architecture / review work without naming codex or a frontier reasoning model.
---

# Codex: High-Reasoning AI Assistant for Claude Code

Use OpenAI's Codex CLI (`gpt-5.5`, `xhigh` reasoning) for complex coding, architecture, and review work that benefits from a frontier reasoning model.

**Default mode is tmux.** Codex runs in a long-lived attachable tmux pane/window so you can watch, intervene, and iterate. The helper script handles lifecycle (pane / bind / spawn / list / kill) and Claude drives the interaction layer directly with `tmux send-keys` and `tmux capture-pane`. A `codex exec` escape hatch remains for genuine one-shots.

**One codex pane in your current window by default.** When Claude is running inside tmux, codex runs as a PANE split into your CURRENT tmux window — right next to Claude — so you can watch progress live with NO separate attach. In the normal case there is one codex pane per Claude session, reused for every task (call `pane` first; it is idempotent). (A duplicate pane can occur if the Claude session id rolls — recover with `kill %id`, or `kill --mine` then re-resolve.) When Claude is NOT inside tmux, it falls back to a dedicated reused window `codex-<claude6>` in the `cc-codex` session (call `bind`). Only spawn an extra pane when the user explicitly asks for a parallel task (`pane --topic <slug>` — still in the current window; see "Detecting & orchestrating multiple codex panes"), and an extra window (`new`) only when the user explicitly asks for a separate window. The generic agentic-tmux concepts behind this (identity & naming patterns, send/capture/idle-detect, sync/locking, lifecycle) live in the **`tmux` skill** (tmux plugin); this skill links to it and keeps only codex-specifics. The codex plugin declares the tmux plugin as a dependency, so it auto-installs alongside codex and the tmux-skill references always resolve.

> **Agent-session isolation (hard rule).** Codex is bound to THIS agent's `claude6`. Every operation the skill performs — resolve/reuse, relocate (`join-pane`), spawn, and cleanup via `kill --mine` / `kill %id` — touches ONLY this session's own codex pane/window, identified by the `@cc_codex_claude6` marker. **Never** move, kill, reuse, or otherwise disturb a tmux pane or window belonging to another agent (a different `claude6`) or one you did not create. In particular, do **not** run `kill --orphaned` as part of normal work — it is a *global, cross-agent* housekeeping command that reaps every agent's dead codex, and is appropriate only when the user explicitly asks to clean up everything.

## When to use tmux mode vs `exec`

| Use **tmux** (default) when | Use **`exec`** escape hatch when |
|---|---|
| The user asks any analysis, design, or implementation that may need follow-up. | The user explicitly says "quick", "one-line", "just", "no session", "don't spawn", "fire and forget". |
| The user uses continuation verbs ("continue", "resume", "now also…"). | The user requests `codex review` or `codex apply` (always one-shot). |
| The user references files with `@` and expects iterative refinement. | A hook or automation calls codex with no follow-up planned. |
| The first codex call in a conversation, when intent is unclear. | A short standalone summary the user clearly does not intend to iterate on. |

When in doubt, default to tmux mode.

## Default workflow: codex pane in the current window

**By default, resolve THE codex target for this Claude session, then drive ALL interaction against it.** When Claude is inside tmux the target is a PANE split into the current window (visible right next to Claude); when Claude is not inside tmux it is a dedicated `cc-codex` window. This resolve-target snippet is the canonical opening of every codex interaction:

```bash
# Resolve THE codex target. Default: a pane in the current window.
if [[ -n "${TMUX:-}" ]] && _out=$($CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh pane --cwd "$PWD"); then
    TARGET=$(printf '%s\n' "$_out" | head -n1)   # pane id, e.g. %53
else
    # pane returned nonzero (exit 3 = not in tmux; exit 4 = codex died on launch)
    # → fall back to a dedicated cc-codex window.
    TARGET="cc-codex:$($CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh bind --cwd "$PWD" | head -n1)"
fi
# Now drive "$TARGET" with the interaction recipes (send → detect-idle → extract-delta).
```

Capture `pane`'s output to a variable first and check its real exit code (do **not** pipe straight into `head` — that masks the exit code, and without `pipefail` the `&&` would succeed with an empty `TARGET`). Exit 3 means "not inside tmux"; exit 4 means codex died on launch (after one auto-retry) — in either case the `bind` fallback (or a re-run, which auto-retries) is the recovery.

`$TARGET` is target-agnostic — it is a pane id (e.g. `%53`) inside tmux, or `cc-codex:<window>` in the fallback — and **all the interaction recipes below drive `"$TARGET"`**. Both `pane` and `bind` are idempotent: they reuse the live codex if alive and respawn it if dead, so follow-ups, continuations, and new sub-tasks all land in the same pane/window. You do **not** need `find` or a topic slug for the normal case. Pass `--full-auto` on the first `pane`/`bind` call for write mode (default is `--read-only`); the sandbox is fixed when the pane/window is first created.

**Spawn an EXTRA codex ONLY when the user explicitly asks for a genuinely separate or parallel codex.** Route the phrasing: "in parallel", "a second codex", "also start another", "keep this one running and…", "don't interrupt the current task", "spin up another" → an extra PANE in the CURRENT window via `pane --topic <slug>` (see "Detecting & orchestrating multiple codex panes"). "separate window" / "new window" → an extra WINDOW via `new <topic>`. A new tmux *session* is created only ever on an explicit user request. For everything else, the single reused pane/window is the answer.

> **"Side panel" / "side by side" / "beside me" / "next to me" / "in a pane" is the DEFAULT — NOT an extra window.** Those phrases describe the in-current-window pane that `pane` already produces (codex sits right next to Claude in the same window). Resolve `$TARGET` normally (→ `pane`); do **not** interpret them as a request for a separate `cc-codex` window via `new`. Only the explicit separate-window phrasing above warrants `new`; genuinely-parallel phrasing warrants `pane --topic <slug>` in the current window.

**Placement — codex stays with the agent.** The codex pane always lives in Claude's **current session and window**: `pane` splits into the current window, and if a prior codex pane exists in *another* window it is **relocated here** (`join-pane`), never duplicated. A new window or a new tmux session is used **only when the user explicitly asks** for one.

**Announce before spawning.** When you first open (or relocate) codex, briefly tell the user where — e.g. *"I'll open codex as a pane in your current window (`research:4`)."* — so a split or move is never a surprise.

## Detecting & orchestrating multiple codex panes

The multi-pane model: the default codex is the topic-`main` pane; parallel tasks get EXTRA topic-named panes in the SAME current window. Each codex pane carries `@cc_codex_claude6` (identity) and `@cc_codex_topic` (`main` for the primary pane, a topic slug for extras; legacy panes without the option count as `main`). Pane titles: `codex-<claude6>` when the topic is `main`, else `codex-<topic>-<claude6>`.

### Detect: `panes`

`panes` is the read-only detection command — run it to see every codex pane you own and where it is (e.g. at the start of a conversation, or before deciding to spawn):

```bash
$CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh panes          # this agent's codex panes
$CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh panes --all    # every agent's (diagnostics only)
```

Output: one TSV line per pane —

| Column | Meaning |
|---|---|
| `pane_id` | e.g. `%53` — usable directly as a `$TARGET` |
| `topic` | `main` for the primary pane, else the topic slug |
| `state` | `alive` / `dead` |
| `session:window_index` | where the pane lives |
| `cwd` | the pane's recorded working directory (`-` if unknown) |

Exit 0 if at least one pane printed, exit 1 if none. Every field is guaranteed non-empty (unknown values print `-`), so tab-splitting the output is safe. `panes` never creates anything — not even the `cc-codex` session — so it is always safe to run.

### Spawn: `pane --topic <slug>` (parallel task requested)

When the user requests a parallel task, spawn/reuse the EXTRA pane for that topic IN THE CURRENT WINDOW. Capture-and-check like the resolve snippet — do **not** pipe into `head` unchecked (exit 4 = codex died at launch would yield an empty id):

```bash
if _eout=$($CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh pane --topic tests --cwd "$PWD"); then
    EXTRA=$(printf '%s\n' "$_eout" | head -n1)
fi   # nonzero exit: surface stderr; never drive an empty target
```

All the default `pane` semantics apply per-topic: reuse-if-alive, relocate into the current window if it drifted to another one (`join-pane`, never duplicated), respawn-if-dead, width floor, liveness check with one auto-retry (exit 4), sandbox-mismatch warning. Plain `pane` is exactly `pane --topic main` (the primary pane; behavior unchanged). **Announce before spawning**, e.g. *"I'll open a second codex pane (topic: tests) in your current window."*

### Address: one `$TARGET` per pane, one driver per pane

Each pane is an independent `$TARGET`. Keep a PER-PANE baseline and a PER-PANE idle loop — never share `BASELINE`/`PREV` state across panes. One driver (this Claude) per pane; you may drive several panes concurrently:

```bash
# (both resolved with the capture-and-check pattern above; shown short here)
MAIN=$($CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh pane --cwd "$PWD" | head -n1)
TESTS=$($CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh pane --topic tests --cwd "$PWD" | head -n1)

BASE_MAIN=$(tmux capture-pane -t "$MAIN" -p -S -200)
BASE_TESTS=$(tmux capture-pane -t "$TESTS" -p -S -200)
# Send task A to $MAIN and task B to $TESTS (short-inline-prompt / tmp-file-prompt),
# then run detect-idle against each pane with its own baseline, and extract each
# delta per pane (line-count tail against BASE_MAIN / BASE_TESTS respectively).
```

### Separate window: `new <topic>` (explicit request only)

`new <topic>` is ONLY for an explicitly requested SEPARATE WINDOW ("separate window", "new window") — it is NOT the parallel default; parallel work goes into `pane --topic` panes in the current window. (One exception: outside tmux, where `pane` is unavailable — exit 3 — a parallel task falls back to `new <topic>`; see `references/tmux-mode.md`.) Cleanup is unchanged: `kill --mine` removes ALL of this agent's codex panes regardless of topic (plus its windows); `kill %id` removes one specific pane.

## Topic naming protocol (extra pane / extra window only)

> **Only needed when the user explicitly asked for a parallel task (`pane --topic`) or a separate window (`new`).** For the default single codex pane/window you do not derive a topic — `pane` reuses the topic-`main` pane in the current window, and `bind` names the fallback window `codex-<claude6>` automatically.

Every `pane --topic` / `new` call needs a 2–15 char slug (`[a-z0-9-]`; note `main` passes the regex but is reserved for the primary pane — `pane --topic main` is just the default `pane`). Derive the slug from the user's request:

1. Identify the primary content noun or verb (e.g., `auth`, `refactor`, `tests`, `migration`).
2. Lowercase it; strip non-`[a-z0-9-]` characters.
3. Truncate to 15 chars.
4. If shorter than 2 chars or no content word is identifiable, default to `task`.

Examples:
- "refactor the queue in parallel" → `pane --topic refactor`
- "review the test suite, don't touch the current one" → `pane --topic tests`
- "spin up another codex" → `pane --topic task`
- "analyze auth.ts in a separate window" → `new auth`

Extra-pane titles become `codex-<topic>-<claude6>` (the primary pane's title stays `codex-<claude6>`); extra-window names become `codex-<topic>-<claude6>-<rand2>` (e.g., `codex-auth-0d61e6-x7`). The fallback bound window stays `codex-<claude6>`. Full naming rules: `references/tmux-mode.md`.

## Lifecycle one-liners (helper script)

The helper script at `$CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh` handles lifecycle only. It does NOT manage interaction.

```bash
# DEFAULT entry point (inside tmux): get/create THE codex pane in the CURRENT
# window. Idempotent — reuse if alive, respawn if dead. Prints a pane id (e.g.
# %53) on line 1. Exits 3 (with a hint to use `bind`) when NOT inside tmux;
# exits 4 when codex dies immediately at launch (after one auto-retry — codex's
# last output goes to stderr). Auto-switches a too-narrow horizontal split to a
# vertical (full-width) split so codex keeps ≥80 cols.
# Optional: --horizontal|--vertical (default horizontal), --size PCT (10–90,
# default 45; out-of-range → exit 2); --topic <slug> (default "main" = the
# primary pane; a slug resolves the EXTRA pane for that topic, same per-topic
# semantics).
TARGET=$($CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh pane --cwd "$PWD" | head -n1)
# See the resolve-$TARGET snippet above for the full inside-tmux-vs-fallback guard
# (it checks pane's exit code, so exit 3/4 fall through to the bind fallback).

# DETECT (read-only): list this agent's codex panes server-wide. One TSV line
# per pane: pane_id<TAB>topic<TAB>state<TAB>session:window_index<TAB>cwd
# (state = alive|dead). Exit 0 if ≥1 pane printed, else 1. Never creates
# anything. --all = every agent's panes (diagnostics only).
$CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh panes

# PARALLEL task (user explicitly asked): spawn/reuse the EXTRA topic pane
# IN THE CURRENT WINDOW. Announce before spawning; capture-and-check the exit
# code (see "Detecting & orchestrating multiple codex panes").
if _eout=$($CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh pane --topic <slug> --cwd "$PWD"); then
    EXTRA=$(printf '%s\n' "$_eout" | head -n1)
fi

# FALLBACK entry point (NOT inside tmux): get/create THE single bound window
# (codex-<claude6>) in the cc-codex session. Idempotent. Line 1 = window name;
# line 2 = attach hint. Drive it as TARGET="cc-codex:$WIN".
WIN=$($CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh bind --cwd "$PWD" | head -n1)

# Spawn an EXTRA window — ONLY when the user explicitly asked for a SEPARATE
# WINDOW (parallel tasks in the current window use `pane --topic` above).
# Needs a topic slug. Returns immediately — does not wait for codex to be ready.
WIN=$($CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh new <topic> --cwd "$PWD" | head -n1)

# List this conversation's windows (bound + any extras).
$CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh ls --mine

# Look up an extra window by topic (rarely needed; pane/bind handle the default).
$CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh find <topic> --cwd "$PWD"
# Exit 0 + one line per match (tab-separated: window, state, cwd).
# Exit 1 + no output → no match.

# Print attach command for the user.
$CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh attach "$WIN"

# Rename an extra window's topic; preserves claude6+rand2 suffix.
$CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh rename "$WIN" "newtopic"

# Kill a specific codex pane/window (kill accepts a pane id like %53) or all of
# THIS Claude session's codex (ALL panes regardless of topic + windows). Both are
# claude6-scoped and pane-aware — they only ever touch this agent's own codex.
$CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh kill "$TARGET"   # pane id (%53) OR window
$CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh kill --mine
# kill --orphaned exists too but is GLOBAL/cross-agent (reaps every agent's dead
# codex) — do NOT use it in normal flow; only on explicit "clean up everything".

# One-shot escape hatch (no tmux).
$CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh exec "<prompt>"
```

The script keeps `send` and `capture` as recognized keywords ONLY to print a migration error pointing at the recipes below. **Drive interaction yourself via raw tmux commands.**

## Interaction one-liners

Each line is the short form. Full recipes with calibration notes live in `references/tmux-mode.md`.

```bash
# Wait for codex to be input-ready (status line appears). Use after `new`.
# Anchor IDLE_REGEX to the ` · /path` status line, not just the model name —
# the model name can appear in response text. $TARGET is the pane id or
# cc-codex:window from the resolve-target snippet above. Bound the wait so a
# dead/empty target can't spin forever (mirrors the detect-idle deadline).
IDLE_REGEX='gpt-5\.5.*·'
RDY_DEADLINE=$(( $(date +%s) + 30 ))
until tmux capture-pane -t "$TARGET" -p -S -200 | tail -3 | grep -qE "$IDLE_REGEX"; do
    (( $(date +%s) > RDY_DEADLINE )) && { echo "codex not ready after 30s (dead pane?)"; break; }
    sleep 0.5
done

# Take a baseline BEFORE sending; you'll use it both as the activity-wait
# anchor and for delta extraction.
BASELINE=$(tmux capture-pane -t "$TARGET" -p -S -200)

# Send a short prompt (≤500 chars, single line).
tmux send-keys -t "$TARGET" -l -- "<prompt>"
sleep 0.3
tmux send-keys -t "$TARGET" Enter

# Send a long / multi-line / code-block prompt: use the Write tool to drop
# the prompt body to a tmp file, then point codex at it. Avoids shell
# quoting and heredoc-delimiter collisions.
#   1. Write tool → $PROMPT_FILE  (e.g. mktemp -t cc-codex-prompt.XXXX.md path)
#   2. tmux send-keys -t "$TARGET" -l -- "Read @$PROMPT_FILE and follow its instructions."
#   3. sleep 0.3 && tmux send-keys -t "$TARGET" Enter

# Two-phase recheck: (a) wait for pane to differ from BASELINE (activity
# started), (b) then wait for pane to stop changing AND show status line.
# This is the recheck strategy — Claude must actively poll; there's no
# auto-notification when codex finishes.
ACTIVITY_DEADLINE=$(( $(date +%s) + 30 ))
while (( $(date +%s) < ACTIVITY_DEADLINE )); do
    [[ "$(tmux capture-pane -t "$TARGET" -p -S -200)" != "$BASELINE" ]] && break
    sleep 0.5
done
PREV=""; STABLE=0; DEADLINE=$(( $(date +%s) + 600 ))
while (( $(date +%s) < DEADLINE )); do
    BUF=$(tmux capture-pane -t "$TARGET" -p -S -200)
    # Match IDLE_REGEX on the bottom of the pane only (last ~3 lines) so a
    # response echoing the status line can't fire a false idle.
    if [[ "$BUF" == "$PREV" ]] && printf '%s\n' "$BUF" | tail -3 | grep -qE "$IDLE_REGEX"; then
        STABLE=$(( STABLE + 1 )); (( STABLE >= 2 )) && break
    else STABLE=0; fi
    PREV="$BUF"; sleep 0.5
done

# Read the delta (everything codex emitted since BASELINE). Preferred: line-count
# tail — robust on redraw-heavy TUIs.
BEFORE_LINES=$(printf '%s\n' "$BASELINE" | wc -l)
AFTER=$(tmux capture-pane -t "$TARGET" -p -S -200)
AFTER_LINES=$(printf '%s\n' "$AFTER" | wc -l)
(( AFTER_LINES > BEFORE_LINES )) && printf '%s\n' "$AFTER" | tail -n "$(( AFTER_LINES - BEFORE_LINES ))"
# Alternative (noisy on redraw-heavy TUIs — spinners/status redraws):
#   diff <(printf '%s\n' "$BASELINE") <(printf '%s\n' "$AFTER") | grep '^>' | sed 's/^> //'

# Capture more scrollback when the response is long (>200 lines).
tmux capture-pane -t "$TARGET" -p -S -1000

# Cancel an in-flight generation (e.g., user said "stop, ask it X instead").
tmux send-keys -t "$TARGET" Escape       # codex TUI binds Esc to cancel
# Then re-run detect-idle and send the new prompt.

# Handle a hooks-review prompt (first-ever codex run, one-time).
tmux send-keys -t "$TARGET" "2" Enter
```

See `references/tmux-mode.md` for the codex-specific calibration, the pane-mode default, and the dedicated-window fallback. The full generic recipe catalog (activity-wait loop, stability check, delta computation, copy-mode navigation) lives in the `tmux` skill's `references/interaction-recipes.md`.

## Choosing the right recipe

| Situation | Recipe |
|---|---|
| Prompt < ~500 chars, single line | `short-inline-prompt` |
| Multi-line prompt, code blocks, > ~1KB | `tmp-file-prompt` |
| Need to know "is codex done" | `detect-idle` |
| Reading the latest response | `extract-delta` |
| Response > ~200 lines | `incremental-capture` |
| Response > tmux `history-limit` (~2000 lines) | `copy-mode-navigation` (rare) |
| User says "stop / cancel / never mind" mid-response | `cancel-in-flight` |
| Codex shows a non-response prompt | `handle-interruption` |
| Resuming after the session id rolled or windows were killed | `reuse-existing-window` |

## Choosing the right window — mandatory pre-spawn workflow

**By default there is exactly one codex target: a pane in your current window (inside tmux) or the bound `codex-<claude6>` window (fallback).** Run the resolve-target snippet — `pane` when inside tmux, `bind` otherwise — and drive `$TARGET`. You do not need `find`, a topic slug, or a reuse-vs-spawn decision for normal work — both `pane` and `bind` are idempotent and always resolve to the same pane/window for this Claude session.

| Situation | Action |
|---|---|
| Any task (analysis, design, implementation, follow-up, new sub-task) | Run the resolve-target snippet (`pane` inside tmux, else `bind`), then drive `"$TARGET"`. |
| Need to see which codex panes you already own (start of conversation, after interruptions) | `codex-tmux.sh panes` — read-only TSV listing (pane id, topic, state, location, cwd). |
| User explicitly wants a parallel task ("in parallel", "a second codex", "also start another", "keep this one and also…", "don't interrupt the current task") | Derive a topic slug, resolve the extra pane with `pane --topic <slug>` (capture output, check exit code — as in the resolve snippet), drive that extra pane in the CURRENT window (per-pane baseline + idle loop). |
| User explicitly wants a SEPARATE WINDOW ("separate window", "new window") | Derive a topic slug, `WIN=$(codex-tmux.sh new <topic> --cwd "$PWD" \| head -n1)`, drive that extra window. A new tmux *session* only ever on explicit request. |
| The codex process in the pane/window died | Nothing special — `pane`/`bind` respawns it automatically. Salvage prior context only if the user wants continuity (see `reuse-existing-window`). |
| User asks to start over from scratch ("reset codex", "fresh codex") | `codex-tmux.sh kill "$TARGET"` (pane id or window) then resolve the target again. |
| `--full-auto` requested but the pane/window is read-only (or vice-versa) | The script warns on stderr and reuses the existing pane/window. Surface the warning; only `kill` + re-resolve if the user wants the other sandbox. |

Both `pane` and `bind` already filter by `claude6` (the pane is also marked so it is normally reused, not duplicated — though a duplicate can occur if the session id rolls, recovered via `kill %id` / `kill --mine`, both claude6-scoped), so cwd/topic matching that `find` used to do is unnecessary for the default flow. Reach for `pane --topic`/`find`/`new`/`--any-session` only in the explicit parallel/extra-window or cross-session cases below.

### Extra panes / extra windows

Only when the user explicitly asked. Parallel task → derive a topic slug (see "Topic naming protocol") and `pane --topic <slug>` (extra pane in the CURRENT window — idempotent per topic, so re-running it reuses/relocates/respawns the same pane); separate window → `new <topic>`. Before re-spawning the *same* extra window topic later, you may `find <topic> --cwd "$PWD"` to reuse it; for panes, `panes` shows what already exists. Generic reuse-vs-spawn theory lives in the `tmux` skill's `references/sync-and-lifecycle.md`.

### Cross-session references

If the user references a window from a prior Claude conversation ("go back to yesterday's auth window"), `pane`/`bind`/`find` won't return it (different `claude6` token). Use `find <topic> --any-session` to widen the search, then confirm with the user before resuming. Full recipe in `tmux-mode.md` § `reuse-existing-window`.

## End-of-conversation cleanup

Cleanup is simple under the pane default: normally there is just the one codex pane in your current window (or the one bound window in the fallback). At natural breakpoints — user says "we're done", "thanks that's it", "wrap up", or the codex task is clearly complete:

```bash
# What codex do I own? Panes (main + any topic extras) via panes; windows via ls.
$CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh panes
$CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh ls --mine
```

| Situation | Offer the user |
|---|---|
| Just the one codex pane / bound window, still useful | Leave it. It's reused next time you resolve the target, and resumable via `find --any-session`. |
| Main pane + extra topic panes / extra windows no longer needed | "Want me to `kill --mine` (clears this session's codex — ALL panes regardless of topic, plus windows), or just `kill "$TARGET"` for the one?" |
| Some of THIS session's panes/windows dead | "Want me to clear them — `kill %id` for a specific dead pane, or `kill --mine` for all of this session's codex?" (both claude6-scoped — they never touch another agent's codex) |
| User explicitly says "clean up" / "kill all" | Run `kill --mine` (removes only THIS session's codex panes and windows) and report what was removed. Use the global `kill --orphaned` only if the user explicitly asks to clear *every* agent's dead codex. |

**Never kill silently.** Always tell the user which pane/windows you're about to remove and wait for confirmation, unless they explicitly said "kill all of them". Killing destroys scrollback irreversibly. Leaving the codex pane/window alive is the friendly default — the next resolve-target call reuses it instead of spawning a fresh one.

### Cleanup commands reference

| Goal | Command |
|---|---|
| Remove a specific codex pane (pane id like `%53`) or one window | `codex-tmux.sh kill "$TARGET"` (or `kill <%pane-id>`) |
| Remove this Claude session's codex — ALL panes (every topic) AND bound/extra windows (alive or dead) | `codex-tmux.sh kill --mine` |
| GLOBAL / cross-agent — dead codex of EVERY agent (any session) | `codex-tmux.sh kill --orphaned` — escape hatch; use ONLY on explicit "clean up everything", never in normal flow |

Note: `kill --mine` is claude6-scoped (touches only THIS agent's codex) and pane-aware — it removes this session's codex PANES (all topics: `main` and extras alike) as well as its `cc-codex` windows, recognizing both the exact bound name `codex-<claude6>` and the extra-window pattern `codex-<topic>-<claude6>-<rand2>`. `kill <%pane-id>` (e.g. `kill %53`) removes one specific codex pane. `kill --orphaned` is the one non-scoped command — it reaps dead codex across ALL agents, so do not use it as part of normal cleanup.

## Sandbox and approval policy

| User intent | Flags |
|---|---|
| Default (read-only analysis), inside tmux | `pane --cwd "$PWD"` (uses `--read-only`, `approval_policy=on-request`) |
| Default (read-only analysis), fallback | `bind --cwd "$PWD"` (uses `--read-only`, `approval_policy=on-request`) |
| Explicit edit request, inside tmux | `pane --cwd "$PWD" --full-auto` (uses `workspace-write` + `on-request`) |
| Explicit edit request, fallback | `bind --cwd "$PWD" --full-auto` (uses `workspace-write` + `on-request`; user approves writes via attach) |
| Edit in an explicit extra topic pane | `pane --topic <slug> --cwd "$PWD" --full-auto` (sandbox fixed per pane on first creation) |
| Edit in an explicit extra window | `new <topic> --cwd "$PWD" --full-auto` |
| One-shot edit (no tmux) | `exec -s workspace-write -c sandbox_workspace_write.network_access=true "<prompt>"` |

The skill still defaults to read-only sandbox; switch to `--full-auto` only when the user explicitly says "edit", "modify", "save", "fix", "refactor", etc. The sandbox is fixed when the pane/window is first created. If you pass `--full-auto` but the pane/window already exists as read-only (or vice-versa), the script warns on stderr and reuses it; surface the warning and `kill` + re-resolve only if the user wants the other sandbox.

## Model and reasoning effort

Defaults: model `gpt-5.5`, reasoning effort `xhigh`. In tmux mode (`pane`/`bind`/`new`) the script pins only the reasoning effort (`-c model_reasoning_effort=xhigh`); the **model comes from your codex config's default** (typically `gpt-5.5`). `-m gpt-5.5` is injected only in `exec` mode. If your codex config defaults to a different model, the calibrated `IDLE_REGEX` (`gpt-5\.5.*·`) will not match — recalibrate it per `references/tmux-mode.md` § calibration.

Use `gpt-5.5-fast` only when the user explicitly asks for speed ("fast", "quick"). On ChatGPT-account auth, only `gpt-5.5` is callable; `gpt-5.5-fast`, `gpt-5.5-codex`, and `gpt-5.5-pro` require API-key auth.

**Fallback chain**: model `gpt-5.5` → `gpt-5.5-fast`; effort `xhigh` → `high` → `medium`.

## File context passing

Pass file paths to codex; do not embed file contents in the prompt.

- `@path/to/file` — explicit file reference inside the prompt (works in both modes).
- `--cwd /path` on `pane`/`bind`/`new` — set working directory for the codex pane/window.
- `--add-dir /path` on `exec` — additional readable/writable directory (one-shot mode only).

Details and resolution rules: `references/file-context.md`.

## Surfacing failures to the user

The helper script fails loudly (non-zero exit + stderr) for lifecycle errors. When it fails, surface the output verbatim. Common signals:

- **Codex exited immediately at launch** — `pane`/`bind` exit **4** (after one auto-retry) and print codex's last output on stderr. Surface that output; re-run (auto-retries once) or fall back to `bind`. A `dead` state in `ls --mine` / `find` is the steady-state version of the same signal (codex's process is gone). Offer to respawn (resolve the target again) or salvage context first (see `reuse-existing-window`).
- Window/pane-not-found errors from `ls`, `kill`, `attach`, `rename` — surface the message.
- v3.1.0 migration errors from `send`/`capture` — exit 64. Switch to the skill recipes.

Interaction errors (codex hung, regex doesn't match, unexpected TUI prompt) are now Claude's responsibility to detect from `capture-pane` output and either recover (see the `handle-interruption` recipe) or escalate to the user.

## Reference index

**Generic agentic-tmux background (other plugin):**
- The **`tmux` skill** (tmux plugin) is now the canonical home for generic agentic-tmux concepts and the full recipe catalog — identity & naming patterns, the session/window/pane model, send/capture/idle-detect (incl. why two-phase), sync/locking, scrollback semantics, and lifecycle/cleanup. This skill links to it for background; see the **tmux skill's own** `references/interaction-recipes.md`, `references/model-and-identity.md`, and `references/sync-and-lifecycle.md` (files in the tmux plugin, not in this plugin's references/). Read it when you need the *why* behind a recipe.

**Canonical (codex-specific tmux workflow):**
- `references/tmux-mode.md` — **canonical for codex** — codex-specific calibration (`gpt-5.5` `IDLE_REGEX`), the `pane` (default) / `panes` (detection) / `bind` (fallback) workflow, multi-pane topics, `"$TARGET"`-driven recipes, hooks-review handling, sandbox flags. Generic theory is delegated to the `tmux` skill.
- `references/cli-features.md` — CLI flag table, interactive-vs-exec differences, `codex review` and `codex apply`.
- `references/codex-config.md` — every `-c` key with type and default.
- `references/codex-help.md` — raw `--help` output.
- `references/file-context.md` — passing files, directories, and the `@` syntax.

**Legacy (`exec`-mode escape hatch only):**
- `references/session-workflows.md` — `codex exec resume` continuation rules and session-ID tracking.
- `references/examples.md` — `codex exec` examples by use case.
- `references/command-patterns.md` — `codex exec` invocation templates.
- `references/advanced-patterns.md` — `codex exec` flag combinations, profiles, multi-phase workflows.
- `references/troubleshooting.md` — `codex exec` error catalog and fixes (tmux-mode troubleshooting lives in `tmux-mode.md`).
