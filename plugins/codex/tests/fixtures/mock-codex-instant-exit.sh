#!/usr/bin/env bash
# Mock codex that exits immediately on launch — simulates the real-world case
# where codex dies during init (transient $CODEX_HOME / MCP hiccup). Used to
# exercise the script's dead-on-arrival handling (no crash; exit 4 after retry).
exit 0
