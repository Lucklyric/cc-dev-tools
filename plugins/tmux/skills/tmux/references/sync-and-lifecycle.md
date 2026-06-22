# Sync & Lifecycle — Reference

How to keep driven windows correct under concurrency, and how to manage their full lifecycle: spawn, find, reuse, kill, and clean up. The interaction recipes (`interaction-recipes.md`) assume the discipline described here. Parameterized by:

```bash
SESSION="${CC_CODEX_SESSION_NAME:-cc-codex}"
TARGET="$SESSION:$WINDOW"            # WINDOW per model-and-identity.md
```

---

## 1. One-driver discipline

**Exactly one writer per pane at a time.** A driven CLI's input box is a single shared resource. If two senders interleave `send-keys` against the same pane, their keystrokes mix into one garbled prompt, and a `detect-idle` loop reading the pane can't tell whose response it's watching. The invariants:

- **One logical driver per window.** The agent owns the pane it is driving for the duration of a send → detect-idle → extract cycle. Don't start a second send into the same window until the first cycle has read its delta.
- **Capture is read-only and always safe.** Any number of `capture-pane` calls can run concurrently; only `send-keys` mutates state.
- **The human is a second writer.** If the user attaches and types, they are now a competing driver. Treat a window the user is actively typing in as off-limits until they detach — don't send into it blind.

In the default bound-window model (one window per agent session, see `model-and-identity.md`), the agent is naturally the sole driver and no explicit locking is needed. Locking matters only when you deliberately fan out across windows or run sends in the background.

---

## 2. Serializing parallel sends with `flock`

When you genuinely run concurrent sends — e.g. background jobs each driving a window, or two tasks racing for the same bound window — guard the send→idle→extract cycle with a per-window lock so the critical section is never interleaved.

```bash
LOCKDIR="${XDG_CACHE_HOME:-$HOME/.cache}/cc-tmux/locks"
mkdir -p "$LOCKDIR"
LOCKFILE="$LOCKDIR/${WINDOW}.lock"

flock "$LOCKFILE" bash -c '
    TARGET="'"$TARGET"'"
    BASELINE=$(tmux capture-pane -t "$TARGET" -p -S -200)
    tmux send-keys -t "$TARGET" -l -- "<prompt>"
    sleep 0.3
    tmux send-keys -t "$TARGET" Enter
    # ...detect-idle and extract-delta INSIDE the lock so no other sender
    #    can write to this pane until we have read our response...
'
```

The lock is **per window** (keyed on `$WINDOW`), so sends to *different* windows still run in parallel — only same-window sends serialize. Keep the whole send→detect-idle→extract sequence inside the lock; releasing the lock right after the send would let a second sender clobber the pane while you're still reading the first response.

### Lock-free fallback (no flock — e.g. stock macOS)

`flock` is absent on stock macOS. `mkdir` is atomic on all POSIX filesystems, so use it as a portable mutex:

```bash
LOCKDIR="${TMPDIR:-/tmp}/cc-codex-<window>.lock"
until mkdir "$LOCKDIR" 2>/dev/null; do sleep 0.1; done   # acquire
trap 'rmdir "$LOCKDIR" 2>/dev/null' EXIT                 # release on exit
# ... critical section: one send → wait-idle → extract ...
rmdir "$LOCKDIR" 2>/dev/null; trap - EXIT               # release early if done
```

Because the bound-window default means one driver per window, locking is rarely needed; reach for this only when two turns might race on the same window.

---

## 3. Spawn / find / reuse / kill lifecycle

The lifecycle of a driven window:

| Phase | What happens |
|---|---|
| **Spawn** | Create the window, start the CLI in it detached, set `remain-on-exit on`, record metadata. |
| **Find** | Locate existing windows by name (token-scoped or widened) and inspect their state. |
| **Reuse** | If a matching window is alive, drive it instead of spawning a duplicate. |
| **Kill** | Remove a window when the user asks or at cleanup. Destroys its scrollback. |

### Spawn

Create the shared session if absent, then add the window with the CLI as its command:

```bash
# Ensure the shared session exists (idempotent).
tmux has-session -t "$SESSION" 2>/dev/null || tmux new-session -d -s "$SESSION" -n _placeholder -x 200 -y 50

# Spawn the driven CLI in a new, detached window.
tmux new-window -t "$SESSION" -n "$WINDOW" -d -c "$cwd" <tool> [tool-flags...]

# CRITICAL: keep the window after the CLI exits (see §5), set ASAP after new-window.
tmux set-option -w -t "$TARGET" remain-on-exit on

# Record metadata as per-window user options (@-prefixed) for later find/cleanup.
tmux set-option -w -t "$TARGET" '@cc_cwd'     "$cwd"
tmux set-option -w -t "$TARGET" '@cc_created' "$(date '+%Y-%m-%dT%H:%M:%S%z')"
tmux set-option -w -t "$TARGET" '@cc_topic'   "$topic"     # extra windows only
```

`new-window -d` (and `split-window` for a pane) returns immediately — it does **not** wait for the CLI's TUI to be input-ready, and it does **not** guarantee the CLI even survived launch. Always run a **readiness-or-dead** check before the first prompt:

```bash
# 1) Did it die at launch? (bad flag, missing auth, crash). Cheaper than waiting
#    out the full idle timeout against a corpse.
if [[ "$(tmux display -p -t "$TARGET" '#{pane_dead}')" == 1 ]]; then     # pane placement
    echo "Driven CLI exited at launch — reason:"
    tmux capture-pane -t "$TARGET" -p -S -50      # surface the error, then respawn/fix
    return 1
fi
# For a window placement use process state instead of #{pane_dead}: window_state "$WINDOW" == dead.

# 2) Only if alive: wait for the input-ready prompt (detect-idle-style readiness wait,
#    poll until IDLE_REGEX appears) before sending the first prompt.
```

Driving a dead target wastes the entire idle timeout and loses the real failure message; the dead-check turns that into an immediate, actionable error.

### Find & reuse

List candidate windows and decide reuse vs. spawn. For the **bound** window the check is a direct name test; for **extra** windows, filter by topic + cwd metadata:

```bash
# Bound window: does <tool>-<claude6> already exist and is it alive?
if tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null | grep -Fxq "$WINDOW"; then
    case "$(window_state "$WINDOW")" in
        alive) : ;;                 # reuse: drive it
        dead)  : ;;                 # respawn the CLI in it, or kill + recreate
    esac
else
    : # create it
fi
```

This is the **idempotent bind**: it converges on exactly one live bound window no matter how many times it's called. Widen the search across agent sessions (drop the `claude6` filter) only when the user references prior work — see `model-and-identity.md` §3.

### Kill

```bash
tmux kill-window -t "$TARGET"        # remove one window (destroys its scrollback)
```

Batch kills (this agent's windows, or all dead ones) are covered under cleanup (§6).

---

## 4. Orphan & dead detection

A window can outlive the CLI it hosted (the process exited, but `remain-on-exit` kept the window). "Is the CLI still running?" is answered from **tmux + process state**, never by parsing pane text:

```bash
# pid of the window's first pane.
window_pane_pid() { tmux list-panes -t "$SESSION:$1" -F '#{pane_pid}' 2>/dev/null | head -n1; }

# alive = pane process is running OR it has live children (nested-shell case).
window_alive() {
    local pid; pid="$(window_pane_pid "$1")"
    [[ -z "$pid" ]] && return 1
    kill -0 "$pid" 2>/dev/null || pgrep -P "$pid" >/dev/null
}

# state: alive | dead | unknown.
window_state() {
    tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null | grep -Fxq "$1" || { echo unknown; return; }
    if window_alive "$1"; then echo alive; else echo dead; fi
}
```

- **`alive`** — the CLI (or a child of it) is running. Safe to drive.
- **`dead`** — the window exists (`remain-on-exit` preserved it) but the CLI exited. Scrollback is still readable; salvage context before killing, then respawn.
- **`unknown`** — no such window.

Checking **children** (`pgrep -P`) as well as the pane pid matters: some CLIs run under a wrapper shell, so the pane pid is a shell that's still alive while the real CLI has exited, or vice-versa. The OR-of-both check avoids both false-dead and false-alive readings.

Salvage a dead window's context before discarding it:

```bash
if [[ "$(window_state "$WINDOW")" == dead ]]; then
    PRIOR=$(tmux capture-pane -t "$TARGET" -p -S -2000)   # rescue scrollback
    tmux kill-window -t "$TARGET"
    # respawn, then feed $PRIOR back as context in the first prompt.
fi
```

---

## 5. `remain-on-exit` — surviving scrollback

By default tmux destroys a window the instant its process exits, taking the scrollback with it. Set `remain-on-exit on` immediately after `new-window` so that when the driven CLI exits — cleanly, by crash, or by `Esc`-cancel-then-quit — the window stays as a **dead** window with its full output intact:

```bash
tmux set-option -w -t "$TARGET" remain-on-exit on
```

This is what makes dead-window recovery (§4) possible: the human can attach and read the final output / error, and the agent can salvage context before respawning. Without it, a CLI that exits mid-task leaves nothing to diagnose.

**Pane placement caveat.** `remain-on-exit on` is unambiguously good for a *window* (a dead window is just an idle tab). But for a **pane split into a human's live window**, a dead pane keeps **occupying screen space** in the window the human is actively using — half their view is now a frozen corpse. So with pane placement, salvage the scrollback and then **prune the dead pane promptly** before re-spawning (see §6), rather than letting it linger.

---

## 6. Cleanup etiquette & batch operations

Windows accumulate across a long conversation. Offer cleanup at natural breakpoints ("we're done", "wrap up", or the task is clearly complete) — but **never kill silently**: killing destroys scrollback irreversibly, and the user may want to attach to a finished window. State exactly which windows you will remove and wait for confirmation, unless the user explicitly said "kill all of them".

Batch operations:

```bash
# Remove only DEAD windows for this tool (any agent session) — the safest sweep.
tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null | grep -E '^<tool>-' | while read -r w; do
    [[ "$(window_state "$w")" == dead ]] && tmux kill-window -t "$SESSION:$w"
done

# Remove all of THIS agent session's windows (alive or dead) — token-scoped.
MY="$(claude6)"
tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null \
    | grep -E "^<tool>-($MY\$|.*-$MY-)" | while read -r w; do
    tmux kill-window -t "$SESSION:$w"
done
```

**Pane placement: prune dead panes server-wide.** Panes can live in *any* window (including a
human's live window in some other session), so enumerate them with `list-panes -a` — not just
`list-windows` — and kill the dead, `@`-marked ones. Do this **before re-spawning** so a stale
corpse never sits in the human's view (see §5):

```bash
# Kill dead panes carrying our marker, anywhere on the server. -a = all panes, all windows.
tmux list-panes -a -F '#{pane_id} #{@<tool>_<claude6>} #{pane_dead}' 2>/dev/null \
    | awk '$2==1 && $3==1 {print $1}' | while read -r p; do
    # Salvage scrollback first if you need the failure context, then:
    tmux kill-pane -t "$p"
done
```

Killing a pane removes only that split; the human's window and its other panes are untouched.
For a worker whose pane is still alive but no longer needed, the same confirm-before-kill
etiquette applies as for windows.

| Situation | Offer the user |
|---|---|
| One alive bound window, still useful | Leave it. It can be resumed next session via the widened (any-session) search. |
| Some windows dead, some alive | "Want me to clear the finished (dead) windows and keep the live one?" |
| All windows stale | "Want me to remove all of this session's windows?" |
| User explicitly says "clean up" / "kill all" | Remove and report exactly what was removed. |

---

## 7. Scrollback / history-limit semantics

- `tmux capture-pane -t "$TARGET" -p -S -N` captures starting `N` lines back from the current view; negative `N` reaches into scrollback. `-E -` extends the end to the last line.
- Each pane has a `history-limit` (default ~2000 lines). Once exceeded, the **oldest** lines are dropped permanently — this is the hard upper bound for any capture.
- Raise it per session *before* a CLI produces a large response (it doesn't retroactively recover dropped lines):

  ```bash
  tmux set-option -t "$SESSION" history-limit 10000
  ```

- For responses that may blow past even a raised limit, prefer instructing the CLI to write its output to a file over fighting scrollback — file output is unbounded and trivially captured with the `Read` tool.

`window_state` and `window_pane_pid` are defined above; `claude6` is defined in `model-and-identity.md`. A real plugin (see `driving-agent-clis.md`) ships them in a lifecycle helper script so the agent calls one subcommand instead of inlining these blocks.
