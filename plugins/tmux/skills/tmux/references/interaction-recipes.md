# Interaction Recipes — Reference

A copy-pasteable catalog for driving *any* interactive CLI through tmux: send a prompt, detect when the CLI is done, read what it produced, and recover from interruptions. The recipes are parameterized by two values you set once per driven window:

```bash
TARGET="<session>:<window>"          # e.g. cc-codex:codex-0d61e6  (see model-and-identity.md)
IDLE_REGEX='<idle-marker-regex>'     # matches the CLI's prompt/status line when input-ready
```

`IDLE_REGEX` is the **only** CLI-specific knob. Calibrate it per tool with `driving-agent-clis.md`; the rest of every recipe is identical regardless of which CLI you drive.

---

## Recipe: `send-inline`

Use when the prompt is ≤ ~500 chars, single line, no code blocks, no awkward characters.

```bash
# 1) Send the prompt body literally (-l = literal, no key-name interpretation).
tmux send-keys -t "$TARGET" -l -- "<prompt>"
# 2) Let the TUI register the typing burst BEFORE submitting.
sleep 0.3
# 3) Submit.
tmux send-keys -t "$TARGET" Enter
```

**The ~0.3s sleep is load-bearing.** Without it, many TUIs treat the `Enter` as part of the same input burst as the typed text and fail to submit on the first try — the prompt just sits in the input box. The pause lets the CLI's render loop catch up so the `Enter` lands as a distinct keystroke. Bump to `0.5`–`1.0` on slow machines or over high-latency SSH.

`-l` and the `--` guard ensure the body is sent verbatim — no tmux key-name parsing (so a literal `Enter` or `C-c` *inside* the prompt text is typed, not executed).

---

## Recipe: `send-via-tmpfile`

Use when the prompt is > ~500 chars, multi-line, contains code blocks, or contains characters tedious/risky to send-key.

The robust pattern: write the prompt body to a temp file with the **`Write` tool** (not a shell heredoc), then send a short inline message that points the CLI at the file.

```bash
# 1) Compute a tmp path. Do NOT write the body here — only the path.
PROMPT_FILE=$(mktemp -t cc-tmux-prompt.XXXXXX.md)

# 2) From the agent: invoke the Write tool with file_path=$PROMPT_FILE and the
#    full prompt body as `content`. This handles arbitrary content — code
#    blocks, nested heredocs, quotes, multi-line — with zero escaping.

# 3) Send a short inline reference (use the CLI's file-include syntax if it has
#    one, e.g. "@path"; otherwise just give the path and ask it to read).
tmux send-keys -t "$TARGET" -l -- "Read @${PROMPT_FILE} and follow its instructions."
sleep 0.3
tmux send-keys -t "$TARGET" Enter

# 4) After capturing the response, best-effort cleanup.
rm -f "$PROMPT_FILE"
```

**Why the Write tool and not a heredoc?** `cat > file <<'EOF' ... EOF` silently **truncates** if the prompt body itself contains the delimiter line (a real hazard when asking a CLI to review shell scripts that demonstrate nested heredocs). The Write-tool path has no delimiter-collision class of bug, no quoting concerns, and no shell escaping. The temp file only needs to be readable by the driven process; `mktemp` defaults suffice. Cleanup is best-effort — most CLIs read the file once at submit time, so removal after capture is safe.

---

## Recipe: `detect-idle`

This is the **recheck strategy**. There is no notification when the CLI finishes a turn — the agent must actively poll the pane. The recipe is **two phases run in order**: activity-wait, then stability.

**Why two phases.** Most TUIs show the *same* idle marker (a prompt or status line) both **before** a prompt is sent and **after** the response completes. A naive stability-only loop sees the marker already present on the pre-send pane, declares "done" immediately, and treats the not-yet-started prompt as finished — a **false positive**. Phase 1 fixes this by requiring the pane to first **differ from a baseline** captured before the send (proving the CLI actually started working). Only then does Phase 2 wait for output to **settle**.

```bash
# --- Phase 0: capture a baseline BEFORE sending the prompt -------------------
BASELINE=$(tmux capture-pane -t "$TARGET" -p -S -200)

# ...send the prompt with send-inline or send-via-tmpfile...

# --- Phase 1: activity-wait — pane must first DIFFER from baseline ----------
ACTIVITY_DEADLINE=$(( $(date +%s) + 30 ))   # CLIs usually start within a few seconds
while (( $(date +%s) < ACTIVITY_DEADLINE )); do
    [[ "$(tmux capture-pane -t "$TARGET" -p -S -200)" != "$BASELINE" ]] && break
    sleep 0.5
done

# --- Phase 2: stability — pane unchanged for 2 polls AND idle marker present -
# Match IDLE_REGEX against only the BOTTOM of the pane (the last ~3 lines), not
# the whole buffer, so a response that echoes the marker mid-stream can't fire a
# false idle. The stability compare stays over the WHOLE buffer.
PREV=""
STABLE=0
DEADLINE=$(( $(date +%s) + 600 ))   # upper bound for the whole response
while (( $(date +%s) < DEADLINE )); do
    BUF=$(tmux capture-pane -t "$TARGET" -p -S -200)
    if [[ "$BUF" == "$PREV" ]] && printf '%s\n' "$BUF" | tail -3 | grep -qE "$IDLE_REGEX"; then
        STABLE=$(( STABLE + 1 ))
        (( STABLE >= 2 )) && break
    else
        STABLE=0
    fi
    PREV="$BUF"
    sleep 0.5
done
```

The two stability conditions are **both** required: "unchanged for 2 consecutive polls" rules out a momentary pause mid-stream, and "`IDLE_REGEX` matches" rules out the pane settling on a prompt for *input* (an interruption — see `handle-interruption`) rather than the ready state.

**Calibration & pitfalls:**
- Run `tmux capture-pane -t "$TARGET" -p | tail -5` while the CLI is idle to find a stable substring for `IDLE_REGEX` (usually the prompt/status line near the bottom).
- Match `IDLE_REGEX` against only the last few lines of the pane (as above) and anchor it to something the CLI does **not** print mid-stream (a status-line suffix), so a response that echoes the marker can't trigger an early idle.
- Skipping Phase 0/1 reproduces the false-positive described above.
- `ACTIVITY_DEADLINE` too low aborts before a slow TUI redraws — give slow machines 10–30s.
- `DEADLINE` too low truncates long reasoning chains — hard problems on high-effort models can take minutes.

---

## Recipe: `extract-delta`

After `detect-idle` confirms the CLI is ready again, read only what was emitted since the prompt was sent.

**Line-count delta** (uses the `BASELINE` from `detect-idle`):

```bash
BEFORE_LINES=$(printf '%s\n' "$BASELINE" | wc -l)
AFTER=$(tmux capture-pane -t "$TARGET" -p -S -200)
AFTER_LINES=$(printf '%s\n' "$AFTER" | wc -l)
if (( AFTER_LINES > BEFORE_LINES )); then
    printf '%s\n' "$AFTER" | tail -n "$(( AFTER_LINES - BEFORE_LINES ))"
fi
```

**`diff` alternative.** A `diff` of baseline vs. after also works, but it is noisy on redraw-heavy TUIs (spinners/status redraws) and drops new lines identical to baseline lines — prefer the line-count tail above:

```bash
diff <(printf '%s\n' "$BASELINE") <(printf '%s\n' "$AFTER") | grep '^>' | sed 's/^> //'
```

**Marker alternative (most robust).** When the delta is unreliable (the pane scrolled, or the CLI rewrote earlier lines), prepend a unique marker to the prompt (e.g. a UUID) so you can re-locate the prompt boundary in the pane afterward and read everything below it:

```bash
MARK="cc-$(date +%s)-$RANDOM"
tmux send-keys -t "$TARGET" -l -- "[$MARK] <prompt>"; sleep 0.3; tmux send-keys -t "$TARGET" Enter
# ...detect-idle...
tmux capture-pane -t "$TARGET" -p -S -2000 | awk -v m="$MARK" 'found; $0 ~ m {found=1}'
```

---

## Recipe: `incremental-capture`

When the response is longer than the default 200-line capture window.

```bash
# -S -N starts the capture N lines back from the current view (negative = scrollback).
# Grow the window until the known top boundary (e.g. your marker) is included.
for N in 200 500 1000 2000; do
    BUF=$(tmux capture-pane -t "$TARGET" -p -S -"$N")
    if echo "$BUF" | grep -qF "<known-top-boundary>"; then
        break
    fi
done
printf '%s\n' "$BUF"
```

tmux's per-pane `history-limit` (default ~2000 lines) is the absolute upper bound for scrollback. If a single response exceeds it, use `copy-mode-navigation`, raise `history-limit` ahead of time, or instruct the CLI to write its output to a file instead.

---

## Recipe: `copy-mode-navigation` (rare)

When the response exceeds what a plain `capture-pane` returns and the pane didn't auto-enter copy mode. Drive copy mode programmatically.

```bash
# Enter copy mode in the pane.
tmux copy-mode -t "$TARGET"
# Jump to the oldest line still in this window's scrollback.
tmux send-keys -X -t "$TARGET" history-top
# Capture the full available range.
tmux capture-pane -t "$TARGET" -p -S -2000 -E -
# Leave copy mode.
tmux send-keys -t "$TARGET" q
```

Rarely needed — most responses fit within a 2000-line scrollback. Reach for it only when `incremental-capture` returned a buffer that's still truncated at the top.

---

## Recipe: `cancel-in-flight`

Use when the user changes their mind mid-response ("stop, ask it X instead", "never mind, cancel that"). Most TUIs bind `Esc` to cancel the current generation; drive that key, wait for idle, then send the replacement.

```bash
# 1) Cancel the in-flight generation.
tmux send-keys -t "$TARGET" Escape

# 2) Wait for the CLI to settle back to idle. Use a FRESH baseline — Esc itself
#    may produce no visible activity, so the activity-wait phase is skipped here.
PREV=""; STABLE=0; DEADLINE=$(( $(date +%s) + 30 ))
while (( $(date +%s) < DEADLINE )); do
    BUF=$(tmux capture-pane -t "$TARGET" -p -S -200)
    if [[ "$BUF" == "$PREV" ]] && echo "$BUF" | grep -qE "$IDLE_REGEX"; then
        STABLE=$(( STABLE + 1 )); (( STABLE >= 2 )) && break
    else STABLE=0; fi
    PREV="$BUF"; sleep 0.5
done

# 3) Send the replacement prompt via send-inline or send-via-tmpfile.
```

If `Escape` doesn't cancel (rare — the CLI is stuck in a tool call), fall back to `tmux send-keys -t "$TARGET" C-c`. As a last resort, kill the window and respawn (see `sync-and-lifecycle.md`).

---

## Recipe: `handle-interruption`

A driven CLI sometimes pauses on an interactive prompt that needs acknowledgement before the real response can continue. `detect-idle` will *not* match `IDLE_REGEX` while one of these is up (it's waiting for input, not idle) — so a stalled `detect-idle` is the cue to `capture-pane` and look for one of these:

| What you see in the pane | What it means | What to do |
|---|---|---|
| Trust / hooks / "review configuration" prompt (first-ever run) | One-time setup gate | Send the "trust and continue" choice (often a number or `y`): `tmux send-keys -t "$TARGET" "2" Enter`. Calibrate the exact key per CLI. |
| Approval prompt (`Apply this edit? [y/n]`, "run command?") | The CLI wants permission to write/execute | If clearly safe: `tmux send-keys -t "$TARGET" "y" Enter`. If unsafe or unclear: tell the user to attach and approve manually. |
| `Sign in` / `Not authenticated` / `login required` | No valid credentials | The CLI can't self-recover — instruct the user to run its login flow (e.g. `<tool> login`) in their terminal. |
| MCP / plugin startup warning (`MCP client for X failed`) | Usually benign | No action — the CLI typically continues. Act only if the user depends on that integration. |
| Pager (`--More--`, `:` at bottom) | Output paused in a pager | `tmux send-keys -t "$TARGET" q` to quit the pager, or `Space` to page through. |

After handling any interruption, re-run `detect-idle` to wait for the ready state to reappear.

---

## Choosing a recipe — heuristics

| Situation | Recipe |
|---|---|
| Prompt < ~500 chars, single line | `send-inline` |
| Multi-line prompt, code blocks, > ~1KB, or awkward characters | `send-via-tmpfile` |
| Need to know "is the CLI done?" (the recheck strategy) | `detect-idle` |
| Reading the latest response | `extract-delta` |
| Response > ~200 lines | `incremental-capture` |
| Response > tmux `history-limit` (~2000 lines) | `copy-mode-navigation` (rare) |
| User says "stop / cancel / never mind" mid-response | `cancel-in-flight` |
| `detect-idle` stalls and the pane shows a question, not output | `handle-interruption` |

See `sync-and-lifecycle.md` for the one-driver discipline and `flock` serialization that keep these recipes safe under concurrency, and `driving-agent-clis.md` for per-CLI `IDLE_REGEX` and interruption-key calibration.
