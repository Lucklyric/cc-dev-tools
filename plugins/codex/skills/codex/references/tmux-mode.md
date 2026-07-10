# Codex Tmux Mode — Reference (v3.7.0+)

> **Generic agentic-tmux concepts and the full recipe rationale now live in the `tmux` skill (tmux plugin).** This file documents only codex-specific calibration, the pane-mode default, and the dedicated-window fallback. For the *why* behind any recipe — the two-phase idle-detection rationale, copy-mode navigation, scrollback semantics, naming theory, and sync/locking — read the `tmux` skill's references (linked inline below). The codex plugin is the reference implementation that skill points back to. The codex plugin declares the tmux plugin as a dependency, so it auto-installs alongside codex and these cross-references always resolve.

The codex skill drives interaction with codex directly via `tmux send-keys` and `tmux capture-pane`. A thin helper script handles only lifecycle (pane, panes, bind, spawn, list, kill, etc.). By default — when Claude runs **inside tmux** — each Claude session gets **one reused codex pane** split into the current window (right next to Claude, visible live with no separate attach). When Claude is **not inside tmux**, it falls back to **one reused codex window** (`codex-<claude6>`) in the `cc-codex` session. Extra topic-named panes (still in the current window, via `pane --topic`) are spawned only when the user explicitly asks for a parallel task; an extra window (`new`) only for an explicitly requested separate window.

## Pane mode (default — Claude inside tmux)

When Claude is running inside tmux, the default is a codex **pane** split into the CURRENT Claude window (the window holding Claude's own pane). You watch progress live with no separate attach. In the normal case there is one codex pane per Claude session — the topic-`main` pane; `pane` marks it (via `claude6` + topic) so it is reused, not duplicated. (A duplicate can occur if the Claude session id rolls mid-conversation, since the `claude6` token changes; recover with `kill %id`, or `kill --mine` then re-resolve — both claude6-scoped; never `kill --orphaned` for this, it is global/cross-agent.)

Resolve THE codex target with this snippet (the canonical opening of every codex interaction). `$TARGET` is a pane id (e.g. `%53`) inside tmux, or `cc-codex:<window>` in the fallback:

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

Capture `pane`'s output and check its real exit code before `head` — piping straight into `head` masks the exit code, and without `pipefail` the `&&` would succeed with an empty `TARGET` on a nonzero `pane`. Exit 3 = not inside tmux; exit 4 = codex died on launch (after one auto-retry, with codex's last output on stderr). Both fall through to the `bind` fallback; a plain re-run also recovers exit 4 (`pane` auto-retries once).

- **Returns a pane id.** `pane` prints the pane id (e.g. `%53`) on stdout line 1. Use it directly as `tmux ... -t "$TARGET"`.
- **Reuse / relaunch / respawn semantics.** `pane` is idempotent: it locates and reuses the existing codex pane if alive, RELAUNCHES codex inside the kept shell pane if codex exited (keep-shell default — same pane id, no new split), respawns the pane if its root process died, and only splits a new pane when none exists. Follow-ups, continuations, and new sub-tasks all land in the same pane.
- **Multiple panes (topics).** `--topic <slug>` resolves the EXTRA pane for that topic with the same semantics applied per-topic: reuse-if-alive, relaunch-in-kept-shell if codex exited, relocate into the current window if it lives in another one (`join-pane`, never duplicated), respawn-if-dead, width floor, liveness check + one auto-retry (exit 4), sandbox-mismatch warning. Plain `pane` is exactly `--topic main` (the primary pane). Every codex pane carries `@cc_codex_claude6` + `@cc_codex_topic`; legacy panes without `@cc_codex_topic` are treated as topic `main`. Pane titles: `codex-<claude6>` (topic `main`) / `codex-<topic>-<claude6>` (extras). Use `panes` to detect them; each pane is its own `$TARGET` with its own baseline and idle loop (one driver per pane).
- **Split flags.** `--horizontal` / `--vertical` choose the split direction (default `--horizontal`); `--size PCT` sets the new pane's size (integer **10–90**, default `45`; out-of-range → exit 2). Sandbox flags `--full-auto` / `--read-only` (default read-only) are fixed while codex runs; a relaunch after codex exited (kept shell) applies the newly requested sandbox.
- **Pane width / shrink.** Splitting off Claude's own pane shrinks Claude's pane once (to ~45% by default). If a **horizontal** split would leave codex too narrow, `pane` auto-switches to a **vertical (full-width)** split so codex keeps ≥80 cols. Pass `--vertical` up front to keep full width regardless.
- **Not inside tmux.** `pane` exits **3** (with a hint to use `bind`) when there is no surrounding tmux; the resolve-target guard above handles this by falling back to `bind`.
- **Codex died on launch.** `pane` exits **4** if codex exits immediately at launch (after one auto-retry), printing codex's last output on stderr. (`bind` uses the same exit 4 for immediate death.) Re-run to auto-retry once, or fall back to `bind` — see Troubleshooting § "Codex exited immediately at launch".
- **When codex exits (keep-shell default).** The pane does NOT close: it drops into an interactive shell in the same pane — hint line printed, scrollback intact, manually usable (the user can run `codex resume --last` there to continue the conversation by hand). `panes` reports it as state `shell`, and the next `pane` call relaunches codex inside it. Typing `exit` in the kept shell closes the pane (a crashed shell is kept `dead` per `remain-on-exit failed`). Set `CC_CODEX_KEEP_SHELL=0` for the legacy behavior (codex is the pane's root process; a clean exit auto-closes the pane, a crash keeps it `dead`; tune with `CC_CODEX_REMAIN_ON_EXIT=on|off`). `CC_CODEX_EXIT_SHELL` picks the drop-in shell (default `$SHELL`).
- **Cleanup.** `kill "$TARGET"` accepts the pane id (e.g. `%53`) and kills the codex pane. `kill --mine` / `kill --orphaned` are pane-aware. See cleanup below.

The dedicated-window path (`bind`) is the fallback when Claude is not inside tmux — see "Dedicated-window fallback" below. Everything else (recipes, calibration) is identical because the recipes drive `"$TARGET"` regardless of whether it is a pane id or `cc-codex:<window>`.

## Lifecycle (script-managed)

All codex instances live in a single tmux session named `cc-codex` (override with `CC_CODEX_SESSION_NAME`). Attach at any time with:

```bash
tmux attach -t cc-codex
```

Inside, `Ctrl-b w` lists windows, `Ctrl-b n` / `p` cycle through them.

The helper script at `$CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh` exposes these lifecycle subcommands:

| Subcommand | Purpose |
|---|---|
| `pane [--topic <slug>] [--cwd DIR] [--full-auto\|--read-only] [--horizontal\|--vertical] [--size PCT]` | **Default entry point (Claude inside tmux).** Spawn/locate/reuse the codex pane for a topic, split into the CURRENT Claude window, marked by `claude6` + topic so it is reused, not duplicated. `--topic` defaults to `main` (the primary pane; behavior unchanged); a slug (2–15 chars `[a-z0-9-]`) resolves the EXTRA pane for that topic with the same per-topic semantics (reuse-if-alive, relocate-into-current-window, respawn-if-dead, width floor, sandbox-mismatch warning). Prints the pane id (e.g. `%53`) on line 1. Default split `--horizontal`, `--size 45` (size 10–90, else exit 2); a too-narrow horizontal split auto-switches to vertical (full-width) so codex keeps ≥80 cols. Exits **3** (hint to use `bind`) when NOT inside tmux; exits **4** if codex dies immediately at launch (after one auto-retry; codex's last output on stderr). |
| `panes [--all]` | **Read-only detection.** List codex panes server-wide, filtered to this agent's `claude6` by default (`--all` = every agent's). One TSV line per pane: `pane_id`, `topic`, `state` (`alive`/`dead`), `session:window_index`, `cwd` — every field guaranteed non-empty (`-` for unknown), so tab-splitting is safe. Exit 0 if ≥1 pane printed, else 1. Never creates anything (not even the `cc-codex` session). |
| `bind [--cwd DIR] [--full-auto\|--read-only]` | **Fallback entry point (Claude NOT inside tmux).** Get/create THE single bound window `codex-<claude6>` in the `cc-codex` session. Idempotent: reuse if alive, respawn codex if dead, create if absent. Records `@cc_codex_cwd/created/sandbox` metadata and sets `remain-on-exit failed`. Output: window name on line 1, attach hint on line 2. Exits **4** if codex dies immediately at launch (after one auto-retry; codex's last output on stderr). |
| `new <topic> [--cwd DIR] [--full-auto\|--read-only]` | Spawn an EXTRA codex window — ONLY for an explicitly requested SEPARATE WINDOW (parallel tasks stay in the current window via `pane --topic`). Returns immediately — does NOT wait for codex's TUI to be ready. |
| `ls [--mine]` | List windows. State is `alive` / `dead` / `unknown` based on tmux + process inspection (no pane parsing). `--mine` matches both the bound name `codex-<claude6>` and extras `codex-<topic>-<claude6>-<rand2>`. |
| `find <topic> [--cwd DIR] [--include-dead] [--any-session]` | Look up matching EXTRA windows in the current Claude session's claude6 namespace. Exits 0 on match (one line per result), 1 on no match. Rarely needed under the pane/bound default — use it for extra-topic reuse or `--any-session` cross-session lookup. |
| `attach <window>` | Print the tmux attach command for a **window** (the script does not exec it; Claude Code's bash is non-interactive). **Window-only** — passing a pane id fails (exit 6). A codex pane is already visible in your current window and needs no attach. |
| `rename <old> <new-topic>` | Replace topic only; preserves the `<claude6>-<rand2>` suffix. (Extra windows only — the bound window has no topic to rename.) |
| `kill <window>` / `kill <%pane-id>` / `kill --mine` / `kill --orphaned` | Remove a specific window, a specific codex pane (`kill %53`), all of the current Claude session's codex (`--mine`: ALL panes regardless of topic AND bound/extra windows), or all dead-codex panes/windows (`--orphaned`). `--mine` and `--orphaned` are **pane-aware** — they remove codex PANES as well as `cc-codex` windows. |
| `exec [flags...] <prompt>` | One-shot escape hatch using `codex exec` (no tmux). |

**Pane / window naming.** Panes (inside tmux): each codex pane is identified by its pane id (e.g. `%53`) and marked with `@cc_codex_claude6` plus `@cc_codex_topic` — `main` for the primary pane, a topic slug for extras (legacy panes without `@cc_codex_topic` are treated as topic `main`) — so `pane` reuses the right pane per topic instead of splitting a duplicate. Pane titles: `codex-<claude6>` when the topic is `main`, else `codex-<topic>-<claude6>`. Fallback bound window: `codex-<claude6>` (e.g. `codex-0d61e6`), topic-agnostic, reused for every task. Extra windows (explicit separate-window request only): `codex-<topic>-<claude6>-<rand2>` (e.g. `codex-auth-0d61e6-x7`). `claude6` = first 6 chars of `$CLAUDE_CODE_SESSION_ID` (fallback: sha256 of `"$PPID:$PWD"`, first 6 chars). Full naming theory (the generic `<tool>-<claude6>` / `<tool>-<topic>-<claude6>-<rand2>` pattern, identity derivation, why the suffix exists) is in the `tmux` skill's `references/model-and-identity.md`; the topic-slug rules are in `SKILL.md`.

## Dedicated-window fallback (not inside tmux)

This is the fallback when Claude is **not** running inside tmux (so `pane` cannot split into a current window). One window in the `cc-codex` session, reused, driven through the recipes below. The resolve-target snippet in "Pane mode" above already selects this path automatically; below is the standalone form.

```bash
# 1) Get THE bound window for this Claude session (idempotent).
#    Line 1 = window name; line 2 = attach hint. Default sandbox is read-only;
#    add --full-auto on first creation for an editable workspace.
WIN=$($CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh bind --cwd "$PWD" | head -n1)
TARGET="cc-codex:$WIN"

# 2) Wait for codex to be input-ready (only needed right after creation;
#    a reused alive window is already idle). Bound the wait so a dead/empty
#    target can't spin forever (mirrors the detect-idle deadline).
IDLE_REGEX='gpt-5\.[0-9].*·'   # model-agnostic: sol/terra/luna/5.5
RDY_DEADLINE=$(( $(date +%s) + 30 ))
until tmux capture-pane -t "$TARGET" -p -S -200 | tail -3 | grep -qE "$IDLE_REGEX"; do
    (( $(date +%s) > RDY_DEADLINE )) && { echo "codex not ready after 30s (dead pane?)"; break; }
    sleep 0.5
done

# 3) Baseline → send → detect-idle → extract-delta, all against "$TARGET".
BASELINE=$(tmux capture-pane -t "$TARGET" -p -S -200)
tmux send-keys -t "$TARGET" -l -- "<prompt>"
sleep 0.3
tmux send-keys -t "$TARGET" Enter
# ...detect-idle (see recipe below)...
# Preferred delta: line-count tail (robust on redraw-heavy TUIs).
BEFORE_LINES=$(printf '%s\n' "$BASELINE" | wc -l)
AFTER=$(tmux capture-pane -t "$TARGET" -p -S -200)
AFTER_LINES=$(printf '%s\n' "$AFTER" | wc -l)
(( AFTER_LINES > BEFORE_LINES )) && printf '%s\n' "$AFTER" | tail -n "$(( AFTER_LINES - BEFORE_LINES ))"
# Alternative (noisy on redraw-heavy TUIs): diff <(...) <(...) | grep '^>'
```

Every follow-up, continuation, and new sub-task in the same Claude session reuses the same `$TARGET` — just take a fresh `BASELINE`, send, detect-idle, extract-delta again. No `find`, no topic slug, no reuse-vs-spawn decision. (Inside tmux the only difference is that `$TARGET` is a pane id from `pane` instead of `cc-codex:$WIN` from `bind` — the recipes are identical.)

### Multiple panes / extra windows (explicit request only)

Parallel task in the CURRENT window ("in parallel", "a second codex", "also start another", "don't interrupt the current task") → an extra topic pane. (Inside tmux only — `pane` exits 3 outside tmux; in the not-inside-tmux fallback a parallel task gets an extra `new <topic>` window instead.)

```bash
# Derive a topic slug per SKILL.md, then spawn/reuse the EXTRA pane
# (announce before spawning). Capture-and-check like the resolve snippet —
# do NOT pipe into head unchecked (exit 4 = codex died would yield an empty id).
if _eout=$($CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh pane --topic tests --cwd "$PWD"); then
    EXTRA=$(printf '%s\n' "$_eout" | head -n1)
fi
# Drive it as its own $TARGET with the same recipes. Keep a PER-PANE baseline
# and idle loop (one driver per pane); the main pane keeps running untouched.
```

Per-topic reuse/relocate semantics: `pane --topic` is idempotent per topic — it reuses the topic's pane if alive, relaunches codex in the kept shell if codex exited, relocates it into the current window if it drifted to another one, and respawns codex if dead. Legacy panes without `@cc_codex_topic` count as topic `main`. `panes` lists every pane you own (TSV: pane id, topic, state, location, cwd) without creating anything.

Explicitly requested SEPARATE WINDOW ("separate window", "new window") → `new`:

```bash
EXTRA=$($CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh new auth --cwd "$PWD" | head -n1)
# Wait for ready, then drive it with the same recipes targeting cc-codex:$EXTRA
# (set TARGET="cc-codex:$EXTRA"). The default codex pane/window keeps running
# untouched in parallel.
```

The main pane, any topic panes, and any extra windows coexist; `panes` shows this agent's panes and `ls --mine` shows the windows. A new tmux *session* is created only ever on explicit user request. Generic one-driver discipline and spawn/cleanup theory: `tmux` skill `references/sync-and-lifecycle.md`.

## Interaction recipes (codex-specific)

The recipe *mechanics and rationale* live in the `tmux` skill's `references/interaction-recipes.md`. Below are the codex-calibrated commands — they all target `"$TARGET"`, which is the pane id from `pane` (default, inside tmux) or `cc-codex:<window>` from `bind` (fallback) or an extra window. The recipes are target-agnostic: identical whether `$TARGET` is a pane id like `%53` or a `session:window`.

### Recipe: `short-inline-prompt`

Use when the prompt is ≤ ~500 chars, single line, no code blocks.

```bash
tmux send-keys -t "$TARGET" -l -- "<prompt>"
sleep 0.3   # let the TUI register the typing before the Enter
tmux send-keys -t "$TARGET" Enter
```

The 0.3s pause matters: without it, codex's TUI sometimes treats the Enter as part of the typing burst and does not submit on the first try. Increase to 0.5–1s on slow machines. (Rationale: `tmux` skill `references/interaction-recipes.md` § send-inline.)

### Recipe: `tmp-file-prompt`

Use when the prompt is > 500 chars, multi-line, contains code blocks, or contains characters that are tedious to send-key. Use Claude's `Write` tool for the prompt body, then send a short inline reference — codex's `@file` syntax loads it in-context.

```bash
# 1) Compute a tmp path (do NOT write via heredoc — use the Write tool).
PROMPT_FILE=$(mktemp -t cc-codex-prompt.XXXXXX.md)

# 2) From Claude: invoke the Write tool with file_path=$PROMPT_FILE and the
#    full prompt body as `content` (handles code blocks, quotes, nested
#    heredocs, multi-line — no escaping).

# 3) Point codex at the file.
tmux send-keys -t "$TARGET" -l -- "Read @${PROMPT_FILE} and follow its instructions."
sleep 0.3
tmux send-keys -t "$TARGET" Enter

# 4) After capturing the response, best-effort clean up.
rm -f "$PROMPT_FILE"
```

Why the Write tool and not a heredoc: a `<<'EOF'` heredoc silently truncates if the prompt body contains the delimiter line (e.g. when asking codex to review shell that demonstrates nested heredocs). The Write-tool path has no such collision. (Full rationale: `tmux` skill § send-via-tmpfile.)

### Recipe: `detect-idle`

The **recheck strategy** — Claude must actively poll; there is no auto-notification when codex finishes. Two phases: activity-wait, then stability. (Why two phases — the status line is present both before send and after completion, so a stability-only loop false-positives on the pre-send pane — is explained in full in the `tmux` skill's `references/interaction-recipes.md` § detect-idle.)

**Codex calibration.** For codex 0.144+ the idle status line looks like `gpt-5.6-sol xhigh · /path/to/cwd`, so anchor the regex to the middot before the cwd path. Keep it model-agnostic (`gpt-5\.[0-9]`) so it matches whichever 5.6 slug (sol/terra/luna) or `gpt-5.5` override is running:

```bash
IDLE_REGEX='gpt-5\.[0-9].*·'   # model-agnostic: sol/terra/luna/5.5
```

Anchor to the ` · /path` status line, not just the model name, because the model name can appear in response text. Run `tmux capture-pane -t "$TARGET" -p | tail -5` while codex is idle to confirm what your CLI version prints, and update the regex if the status line changed.

```bash
# Phase 0: baseline BEFORE sending (also the delta anchor).
BASELINE=$(tmux capture-pane -t "$TARGET" -p -S -200)

# ...send prompt (short-inline-prompt or tmp-file-prompt)...

# Phase 1: activity-wait — pane must first differ from baseline.
ACTIVITY_DEADLINE=$(( $(date +%s) + 30 ))   # codex usually starts within 5s
while (( $(date +%s) < ACTIVITY_DEADLINE )); do
    [[ "$(tmux capture-pane -t "$TARGET" -p -S -200)" != "$BASELINE" ]] && break
    sleep 0.5
done

# Phase 2: stability — pane unchanged for 2 polls AND idle regex matches the
# BOTTOM of the pane only (last ~3 lines), so a response echoing the status line
# can't fire a false idle. The stability compare stays over the whole buffer.
PREV=""; STABLE=0; DEADLINE=$(( $(date +%s) + 600 ))   # 10-min upper bound
while (( $(date +%s) < DEADLINE )); do
    BUF=$(tmux capture-pane -t "$TARGET" -p -S -200)
    if [[ "$BUF" == "$PREV" ]] && printf '%s\n' "$BUF" | tail -3 | grep -qE "$IDLE_REGEX"; then
        STABLE=$(( STABLE + 1 )); (( STABLE >= 2 )) && break
    else STABLE=0; fi
    PREV="$BUF"; sleep 0.5
done
```

Codex-specific tuning: `xhigh` effort can take several minutes on hard problems, so keep `DEADLINE` generous (600s+); slow machines may need `ACTIVITY_DEADLINE` raised to 10–30s before codex's TUI first redraws.

### Recipe: `extract-delta`

After `detect-idle` confirms codex is idle again, read everything emitted since `BASELINE`.

```bash
BEFORE_LINES=$(printf '%s\n' "$BASELINE" | wc -l)
AFTER=$(tmux capture-pane -t "$TARGET" -p -S -200)
AFTER_LINES=$(printf '%s\n' "$AFTER" | wc -l)
if (( AFTER_LINES > BEFORE_LINES )); then
    printf '%s\n' "$AFTER" | tail -n "$(( AFTER_LINES - BEFORE_LINES ))"
fi
```

For longer responses (`incremental-capture`, >200 lines) and responses past the scrollback limit (`copy-mode-navigation`), use the generic recipes in the `tmux` skill's `references/interaction-recipes.md`; they apply unchanged to `"$TARGET"`. Scrollback semantics (`-S -N`, `history-limit`) are documented there too.

### Recipe: `cancel-in-flight`

User changes their mind mid-response. Codex's TUI binds `Esc` to cancel the current generation:

```bash
tmux send-keys -t "$TARGET" Escape

# Wait for codex to settle back to idle (fresh baseline — Esc may not show activity).
# Match the status line on the bottom of the pane only (last ~3 lines).
BASELINE=$(tmux capture-pane -t "$TARGET" -p -S -200)
PREV=""; STABLE=0; DEADLINE=$(( $(date +%s) + 30 ))
while (( $(date +%s) < DEADLINE )); do
    BUF=$(tmux capture-pane -t "$TARGET" -p -S -200)
    if [[ "$BUF" == "$PREV" ]] && printf '%s\n' "$BUF" | tail -3 | grep -qE 'gpt-5\.[0-9].*·'; then
        STABLE=$(( STABLE + 1 )); (( STABLE >= 2 )) && break
    else STABLE=0; fi
    PREV="$BUF"; sleep 0.5
done
# Then send the replacement prompt.
```

Codex-specific fallback if `Escape` doesn't cancel (rare — stuck in a tool call): `tmux send-keys -t "$TARGET" C-c`. Last resort: `codex-tmux.sh kill "$TARGET"` then resolve the target again to recreate the codex pane/window.

### Recipe: `handle-interruption` (codex-specific prompts)

Codex sometimes shows interactive prompts that need acknowledgement before the main response continues. These are codex-TUI-specific:

| What you see in the pane | What to do |
|---|---|
| `Hooks need review` (first-ever codex run) | `tmux send-keys -t "$TARGET" "2" Enter` to "Trust all and continue". |
| Approval prompt (`Apply this edit? [y/n]` or similar in workspace-write mode) | If safe: `tmux send-keys -t "$TARGET" "y" Enter`. If unsafe or unclear: have the user approve in the pane (it's visible in their window) — or, in the fallback, attach to the `cc-codex` window and approve there. |
| `Sign in to Codex` / `Not authenticated` | `codex login` from the user's terminal. Codex doesn't recover by itself. |
| MCP startup warning (`MCP client for X failed`) | Usually benign — codex continues. No action needed unless the user relies on that MCP. |

After any interruption, re-run `detect-idle` to wait for the status line to reappear.

### Recipe: `reuse-existing-window`

Under the pane/bound default, normal reuse is automatic — `pane` (inside tmux) or `bind` (fallback) returns the same target every time. This recipe covers the edge cases:

- **Codex exited (state `shell`).** `pane`/`bind` relaunches codex inside the kept pane/window; the user can also continue manually there (`codex resume --last`).
- **The pane/window's root process died (state `dead`).** `pane`/`bind` respawns it; no salvage unless the user wants continuity.
- **Conversation resumed and `$CLAUDE_CODE_SESSION_ID` rolled.** A new claude6 means `pane`/`bind` creates a *new* pane/bound window; the prior one is invisible to default lookups. Use `--any-session` to find a prior window.
- **User references a prior extra window** ("go back to the auth window").

```bash
# Dead pane/window recovery with context salvage (only if continuity matters).
# Re-run the resolve-target snippet (pane inside tmux, else bind).
TARGET=$($CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh pane --cwd "$PWD" | head -n1)
# If you saved scrollback before it died, replay it as inline context in the
# first prompt. (pane/bind already respawned codex in $TARGET.)

# Cross-Claude-session reference: widen the search, then confirm with the user.
$CLAUDE_PLUGIN_ROOT/scripts/codex-tmux.sh find auth --any-session
# → codex-auth-bbbbbb-x7    alive    /Users/asun/codes/myproj
# Confirm: "I see codex-auth-bbbbbb-x7 (alive) — reuse this one?"
```

Why `claude6` alone isn't enough across resumes, plus the generic dead-window scrollback-salvage pattern, are in the `tmux` skill's `references/sync-and-lifecycle.md`.

## Choosing recipes — heuristics

| Situation | Recipe |
|---|---|
| Any task in the default flow | resolve `$TARGET` (`pane` inside tmux, else `bind`) → `short-inline-prompt`/`tmp-file-prompt` → `detect-idle` → `extract-delta` |
| Prompt < ~500 chars, single line | `short-inline-prompt` |
| Multi-line prompt, code blocks, > ~1KB | `tmp-file-prompt` |
| Need to know "is codex done" (the recheck strategy) | `detect-idle` |
| Reading the latest response | `extract-delta` |
| Response > ~200 lines / > scrollback limit | generic `incremental-capture` / `copy-mode-navigation` (`tmux` skill) |
| User says "stop / cancel / never mind" mid-response | `cancel-in-flight` |
| Codex shows a hooks-review / approval / auth prompt | `handle-interruption` |
| Codex pane/window died, session-id rolled, or prior extra window wanted | `reuse-existing-window` |
| Rediscovering which codex panes you own | `panes` (read-only TSV: pane id, topic, state, location, cwd) |
| User explicitly wants a parallel task | `pane --topic <slug>` then drive the extra pane (current window; per-pane baseline + idle loop) |
| User explicitly wants a SEPARATE WINDOW | `new <topic>` then drive the extra window |

## Sync / locking

One driver (Claude) per pane/window is the normal case, so no locking is needed. With multiple topic panes, driving several panes concurrently is fine — each pane has exactly one driver and its own baseline/idle state; what needs serialization is two drivers on the SAME pane. If you ever run parallel sends against the same pane/window, wrap them with `flock` — see the generic serialization pattern in the `tmux` skill's `references/sync-and-lifecycle.md`.

## Troubleshooting (codex-specific)

### Codex appears hung

Most common cause is a one-time interruption (hooks-review, approval prompt). `tmux capture-pane -t "$TARGET" -p` and look for an interactive prompt; if present, see `handle-interruption`. If no prompt is visible, codex may be in a long reasoning step (xhigh) — wait longer. If `$TARGET` is a **pane** (default, inside tmux) it is already on-screen in your current window — just watch it (no attach; `attach` is window-only and exits 6 for a pane id). If `$TARGET` is a fallback `cc-codex:<window>`, `attach` it (or `tmux attach -t cc-codex`) to watch live.

### Codex exited immediately at launch

`pane` / `bind` exit **4** when codex dies on arrival (the process exits right after launch, even after the one auto-retry the script performs). Detect it two ways:

- **At launch:** the `pane` / `bind` call returns exit 4 and prints codex's last output on stderr. The resolve-target snippet already routes exit 4 to the `bind` fallback; surface codex's stderr to the user.
- **Steady state:** `ls --mine` or `find` reports the pane/window as `dead`.

Recovery: re-run the resolve-target snippet — `pane`/`bind` auto-retries once on the respawn — or fall back to `bind` (which the snippet does automatically when `pane` exits 4). This is usually a transient codex startup hiccup (e.g. `$CODEX_HOME` / MCP init), so a re-run typically succeeds. If it keeps dying, read codex's stderr output for the real cause (auth, bad config, MCP server failing to start).

### `detect-idle` returns immediately (false positive)

The status line is already in `BASELINE` and codex hasn't started responding. Ensure Phase 0/1 (the activity-wait pre-step) is present. Generic explanation: `tmux` skill § detect-idle.

### Ready regex doesn't match

Codex CLI may have updated its status line. Run `tmux capture-pane -t "$TARGET" -p | tail -10` while codex is idle, pick a stable substring (the model + effort line near the bottom), and update `IDLE_REGEX`. The default regex covers any `gpt-5.x` slug — but if you override `CC_CODEX_MODEL` to a non-`gpt-5` slug (e.g. an `--oss` local model), idle detection silently breaks until you recalibrate it the same way.

### Sandbox mismatch on `pane` / `bind`

If `--full-auto` is requested but the codex pane/window was created read-only (or vice-versa), the script warns on stderr and reuses the existing pane/window (recorded in `@cc_codex_sandbox` for windows). The check is per pane, so each topic pane has its own fixed sandbox. Surface the warning. To switch sandbox, `kill "$TARGET"` then re-resolve the target with the desired flag.

### Model/effort mismatch on `pane` / `bind`

Same shape as the sandbox mismatch: an explicit `CC_CODEX_MODEL`/`CC_CODEX_EFFORT` override cannot apply to an already-running codex, so on reuse the script warns on stderr (`… do NOT apply to a reused pane`) and keeps the existing pane/window (its combo is recorded in `@cc_codex_model` / `@cc_codex_effort`). Surface the warning. To actually switch, `kill "$TARGET"` and re-resolve with the env set — or prefer an `exec` one-shot / new `--topic` pane for a one-off different combo.

### Migration notes

The `send` / `capture` keywords print an error and exit 64 — drive interaction via the recipes above. Generic migration history (the older script-managed `send`/`capture` model, `CC_CODEX_*` env knobs, and the lockfile pattern) is documented once in the `tmux` skill; it is not repeated here.
