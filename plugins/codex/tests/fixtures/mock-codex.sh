#!/usr/bin/env bash
# Mock codex TUI for use in bats tests. Prints a startup banner, then a ready
# marker (▌), waits for stdin lines, echoes responses, and prints the marker
# again. /exit terminates with code 0.
set -euo pipefail

echo "mock-codex v0.0.0 ready"
echo "Type a message or /exit to quit"
printf "▌ \n"

while IFS= read -r line; do
    if [[ "$line" == "/exit" ]]; then
        echo "exiting"
        exit 0
    fi
    echo "[mock-response] you said: $line"
    printf "▌ \n"
done
