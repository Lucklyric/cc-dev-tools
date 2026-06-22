#!/usr/bin/env bash
# Mock codex that records the argv it was launched with (to "mock-codex-argv.log"
# in its working directory, which the script sets via `-c <cwd>`), then behaves
# like a live TUI (stays alive reading stdin). Lets tests assert the exact codex
# flags the script passes through tmux without relying on env propagation.
set -uo pipefail
printf '%s\n' "$*" > "mock-codex-argv.log" 2>/dev/null || true
echo "mock-codex (logargs) ready"
printf "▌ \n"
echo "  gpt-5.5 xhigh · /mock-cwd"
while IFS= read -r line; do
    [[ "$line" == "/exit" ]] && exit 0
    echo "[mock] $line"
done
