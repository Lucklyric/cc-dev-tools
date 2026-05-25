#!/usr/bin/env bash
# codex-tmux.sh — drive interactive codex sessions inside a single tmux session.
# See plugins/codex/skills/codex/references/tmux-mode.md for usage docs.
set -euo pipefail

# ---------- Constants (overridable via env) ----------
readonly SESSION_NAME="${CC_CODEX_SESSION_NAME:-cc-codex}"
readonly READY_REGEX_DEFAULT='▌'
READY_REGEX="${CC_CODEX_READY_REGEX:-$READY_REGEX_DEFAULT}"
readonly DEFAULT_TIMEOUT="${CC_CODEX_TIMEOUT:-600}"
readonly LOCK_DIR="${CC_CODEX_LOCK_DIR:-$HOME/.cache/cc-codex/locks}"
readonly CODEX_BIN="${CC_CODEX_BIN:-codex}"

# ---------- Usage ----------
usage() {
    cat <<'EOF'
Usage: codex-tmux.sh <subcommand> [args...]

Subcommands:
  new <topic> [--cwd DIR] [--full-auto|--read-only]
      Create a new codex window in the cc-codex tmux session.
      Prints the full window name on stdout plus an attach hint.

  send <window> <prompt> [--timeout SECS]
      Send a prompt to a window, wait for codex to be idle, return the delta.

  capture <window> [--lines N]
      Print the current pane buffer for inspection (does not send anything).

  ls [--mine]
      List codex windows. --mine filters to the current Claude session id.

  attach <window>
      Print the shell command the user can run to attach to a window.

  rename <old-window> <new-topic>
      Rename a window's topic portion; preserves the suffix.

  kill <window> | kill --orphaned
      Kill a specific window, or all windows whose codex process has exited.

  exec [codex-exec flags...] <prompt>
      Run codex exec one-shot outside tmux (escape hatch).

Environment:
  CC_CODEX_SESSION_NAME (default: cc-codex)
  CC_CODEX_READY_REGEX  (default: ▌)
  CC_CODEX_TIMEOUT      (default: 600)
  CC_CODEX_BIN          (default: codex)
EOF
}

# ---------- Dispatch ----------
main() {
    if [[ $# -eq 0 ]]; then
        usage >&2
        exit 2
    fi

    local cmd="$1"
    shift || true

    case "$cmd" in
        -h|--help|help)
            usage
            ;;
        new|send|capture|ls|attach|rename|kill|exec)
            # Subcommand implementations are added in later tasks.
            echo "codex-tmux: subcommand '$cmd' not yet implemented" >&2
            exit 99
            ;;
        *)
            echo "codex-tmux: unknown subcommand '$cmd'" >&2
            usage >&2
            exit 2
            ;;
    esac
}

main "$@"
