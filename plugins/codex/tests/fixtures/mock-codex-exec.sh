#!/usr/bin/env bash
# Mock for codex-exec: print each argument on its own line, exit 0.
for arg in "$@"; do printf '%s\n' "$arg"; done
