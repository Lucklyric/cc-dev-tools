# Tmux Model & Identity — Reference

This file covers two things an agent must understand before driving another CLI through tmux: (1) the **tmux object model** (what a session, window, and pane actually are, and when to use which), and (2) the **identity and naming contract** — how an agent stamps its own identity onto the windows it owns so it can find, reuse, and clean them up later.

Everything here is tool-agnostic. Substitute your driven CLI's name for `<tool>` (e.g. `codex`, `gemini`, `aider`) throughout. The codex plugin is the reference implementation of these patterns — see `driving-agent-clis.md`.

---

## 1. The tmux object model for agents

tmux is a terminal multiplexer. For an agent driving another CLI, four nested objects matter:

```
tmux server                 one background process per user; holds all state
└── session                 a named group of windows (e.g. "cc-codex")
    └── window              a full-screen "tab" — one driven CLI lives here
        └── pane            a rectangular split of a window; runs one process
```

- **Server** — a single long-lived background process (`tmux` starts it on first use). It survives after every client detaches; this is what lets a driven CLI keep running between agent turns. The agent never manages the server directly.
- **Session** — a named container for windows. Agents put *all* the CLIs they drive into **one shared session** (default name `cc-codex`, override with `CC_CODEX_SESSION_NAME`). One session keeps `attach`, listing, and cleanup simple: the human attaches once and tabs through everything.
- **Window** — a placement for a driven CLI. A window has a name (which we control — see §2) and per-window user options we use to store metadata (`@...` keys, see `sync-and-lifecycle.md`). Identity rides in the name.
- **Pane** — a process inside a window, with an **immutable pane-id (`%NN`)** and per-pane user options. By default a window has exactly one pane; splits create more. A pane has no name, but its pane-id is a perfectly stable target and a `@...` user-option set on the pane carries identity (see §2).

### Two placements for a driven worker — window vs. pane

One logical worker lives in **either** a dedicated window **or** a single pane — never both:

| Want | Use | Why |
|---|---|---|
| A worker the human attaches to watch / many parallel workers | A dedicated **window** | Isolated scrollback, name-carried identity + metadata, easy to tab to on `attach`. |
| The agent runs inside tmux; a human wants the driven CLI visible **beside the agent, no attach** | A **pane** split into the agent's **current window** | The CLI appears in the window the human is already looking at — live progress, zero attach. Identity is pane-bound (`@`-marker + pane-id). The **codex default**. |
| Two views of one worker at once (CLI + log tail) | **Split panes** in one window | The human sees both at once. |
| Drive one CLI, observe its output | One window or one pane | The normal case. Capture from `<session>:<window>` or from the pane-id. |

**A pane is as addressable as a window.** The pane *index* is volatile (panes renumber as they open/close), but the **pane-id (`%NN`) is immutable for the pane's whole life and targets verbatim** in every `send-keys` / `capture-pane` recipe — exactly as reliable as a window name. `send-keys`, `capture-pane`, and the two-phase idle loop are **identical** whether the target is `<session>:<window>` or `%NN`. The only fair caveat: finding/killing "my" panes across a whole session needs a server-wide `list-panes -a` filtered by the `@`-marker (see `sync-and-lifecycle.md`), slightly more involved than listing windows — but interaction and idle-detection are not harder for panes.

### Targeting syntax

Every tmux command that acts on a window takes `-t <target>`:

```
<session>                    the session (e.g. cc-codex)
<session>:<window>           a specific window      ← target for window placement
<session>:<window>.<pane>    a pane by its (volatile) index — avoid for identity
%NN                          a pane by its immutable pane-id  ← target for pane placement
```

Prefer the **pane-id (`%NN`)** over the `.<pane>` index whenever you target a pane: the id never changes for the life of the pane, so it is as stable a handle as a window name. Throughout the recipes we write `TARGET=...` and target everything at `$TARGET` — set it once per driven worker to either the window or the pane-id:

```bash
# Window placement:
SESSION="${CC_CODEX_SESSION_NAME:-cc-codex}"
WINDOW="<tool>-<claude6>"        # see §2 for how the name is built
TARGET="$SESSION:$WINDOW"

# Pane placement (pane split into the agent's current window):
TARGET="%53"                     # the pane-id returned by split-window -P -F '#{pane_id}'
```

### Attach / detach basics

The agent's bash is **non-interactive**, so it never `attach`es itself. It drives windows blind via `send-keys` / `capture-pane`, and hands the human an attach command when they want to watch:

```bash
# Print (do NOT exec) the attach command for the human to run in their terminal.
echo "tmux attach -t $SESSION \\; select-window -t $WINDOW"
```

Once attached, the human uses tmux's default prefix `Ctrl-b`:

- `Ctrl-b w` — interactive window list (pick the driven CLI).
- `Ctrl-b n` / `Ctrl-b p` — next / previous window.
- `Ctrl-b d` — detach (the CLI keeps running on the server).

Detaching never stops the driven CLI; only `kill-window` / `kill-session` (or the CLI exiting) does.

---

## 2. Identity token & naming patterns

The agent must be able to answer "is one of my windows already running this?" cheaply, across many turns and even after a conversation is resumed. It does this by stamping a short **identity token** into every window name.

### The identity token: `claude6`

`claude6` is a 6-character token that identifies the **current agent session**:

```bash
claude6() {
    if [[ -n "${CLAUDE_CODE_SESSION_ID:-}" ]]; then
        printf '%s' "${CLAUDE_CODE_SESSION_ID:0:6}"     # first 6 chars of the session id
    else
        printf '%s' "$PPID:$PWD" | shasum -a 256 | cut -c1-6   # deterministic fallback
    fi
}
```

- **Primary source**: the first 6 chars of `$CLAUDE_CODE_SESSION_ID`. Stable for the life of one conversation.
- **Fallback** (env var unset): the first 6 chars of `sha256("$PPID:$PWD")` — deterministic for the duration of the parent shell, so the token stays consistent within a turn even without the session id.

The token is short on purpose: it is a *namespace prefix*, not a security boundary. Collisions across users are irrelevant because each user has their own tmux server.

### Naming patterns (the contract)

Two window shapes, generic across any driven CLI:

| Kind | Pattern | Example | When |
|---|---|---|---|
| **Bound** (default) | `<tool>-<claude6>` | `codex-0d61e6` | Exactly **one per agent session**, topic-agnostic, **reused for every task**. |
| **Extra** (explicit only) | `<tool>-<topic>-<claude6>-<rand2>` | `codex-auth-0d61e6-x7` | **Only** when the user explicitly asks for a separate / parallel task. |

Field rules:

- `<tool>` — the driven CLI's name, lowercase (`codex`, `gemini`, `aider`).
- `<claude6>` — the identity token from above.
- `<topic>` — a content-derived slug, **2–15 chars**, `[a-z0-9-]` only. Derive it from the user's request (the primary noun/verb: `auth`, `refactor`, `tests`, `migration`); default to `task` if none is identifiable.
- `<rand2>` — two random chars from `[a-z0-9]`, so two parallel extra windows on the same topic never collide.

Concrete generator for an extra window's name:

```bash
rand2() { local c='abcdefghijklmnopqrstuvwxyz0123456789'; printf '%s%s' "${c:RANDOM%36:1}" "${c:RANDOM%36:1}"; }
EXTRA_WINDOW="<tool>-${topic}-$(claude6)-$(rand2)"
```

The regex `^<tool>-[a-z0-9]{6}$` matches the bound window; `^<tool>-[a-z0-9-]+-[a-z0-9]{6}-[a-z0-9]{2}$` matches extra windows.

### Pane-bound identity (pane placement)

A pane has **no name to stamp**, so its identity lives in a **per-pane user-option** instead. The contract mirrors the window one — same `<claude6>` token, just a different carrier:

| Placement | Identity carrier | Target |
|---|---|---|
| **Window** | real window **name** `<tool>-<claude6>` | `<session>:<window>` |
| **Pane** | `@<tool>_<claude6>` **pane user-option** (no name) | the pane-id `%NN` |

Stamp the marker on the pane right after splitting (note `-p`, the *pane* scope, vs `-w` for windows):

```bash
# Split a pane into the agent's CURRENT window, capture its immutable pane-id.
PANE=$(tmux split-window -P -F '#{pane_id}' -c "$cwd" <tool> [tool-flags...])
tmux set-option -p -t "$PANE" "@<tool>_<claude6>" 1     # the identity marker
TARGET="$PANE"
```

Discover "my" panes server-wide by listing every pane with its id, marker, and liveness, then filtering on the marker:

```bash
# pane-id, marker value, dead-flag for every pane on the server.
tmux list-panes -a -F '#{pane_id} #{@<tool>_<claude6>} #{pane_dead}' 2>/dev/null \
    | awk '$2==1 {print $1, $3}'        # -> "%53 0" (id, is-dead)
```

The codex plugin is the worked example: its `find_codex_pane` lists panes with `list-panes -a` and filters on the `@cc_codex_<claude6>` marker, while `cmd_pane` splits the current window, stamps the marker with `set-option -p`, and returns the pane-id as the target. See `driving-agent-clis.md`.

---

## 3. Binding & reuse model

### One bound window per agent, by default

The **default** behavior is to keep a single, reused window per agent session:

1. Compute the bound name `<tool>-<claude6>`.
2. If it exists and the CLI inside is alive → **reuse it** (drive the same window).
3. If it exists but the CLI exited (dead) → **respawn** the CLI in it (or kill + recreate).
4. If it does not exist → **create** it.

This "bind" operation is **idempotent**: calling it repeatedly converges on exactly one live window. It is topic-agnostic — the same bound window handles every task in the conversation, so windows do not pile up and the human always knows which tab to attach to. Lifecycle mechanics (metadata, `remain-on-exit`, dead detection) live in `sync-and-lifecycle.md`.

Spawn an **extra** window (`<tool>-<topic>-<claude6>-<rand2>`) only when the user explicitly asks for a separate or parallel task ("run this in a second window", "do X in parallel", "keep the other one going"). Extra windows are never the default.

### Why the token alone isn't enough: cross-session references

`claude6` is derived from the **current** `$CLAUDE_CODE_SESSION_ID`. When a conversation is **resumed**, the harness assigns a *new* session id, so `claude6` **rolls** to a new value. Every window the agent created in the prior conversation still carries the *old* token. Consequences:

- A search scoped to the current `claude6` (the default) will **miss** all windows from before the resume — they look like they belong to a different agent.
- The user, however, may well refer to one of those prior windows ("go back to the auth window from earlier", "continue yesterday's session").

**How to widen the search.** Drop the `claude6` filter and match by `<tool>-` prefix (and optionally topic) across the whole session, listing *all* candidate windows regardless of token:

```bash
SESSION="${CC_CODEX_SESSION_NAME:-cc-codex}"
# All windows for this tool, any agent session (any claude6):
tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null \
    | grep -E '^<tool>-' || true
```

Then **confirm with the user before reusing** a window that carries a different token — it belonged to a different conversation, so its scrollback context may not be what they expect:

> "I see `codex-auth-bbbbbb-x7` (alive) from an earlier session — reuse this one?"

Lifecycle helper scripts typically expose this as an `--any-session` flag that omits the token filter. The bound-window default still applies after a resume: bind to the *new* `<tool>-<claude6>` and only fall back to the widened search when the user references prior work.
