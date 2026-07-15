#!/usr/bin/env bash
# UserPromptSubmit hook: when the user's prompt names codex, inject a reminder
# to invoke the codex skill before driving the codex CLI. Skill-description
# triggering is probabilistic; this makes the nudge deterministic.
set -euo pipefail

input=$(cat)

# Extract the prompt field (jq preferred; python3 fallback; else give up silently).
prompt=$(printf '%s' "$input" | jq -r '.prompt // .user_prompt // empty' 2>/dev/null) \
  || prompt=$(printf '%s' "$input" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("prompt") or d.get("user_prompt") or "")' 2>/dev/null) \
  || prompt=""

[[ -z "$prompt" ]] && exit 0

# Word-boundary match without \b (portable across BSD and GNU grep).
if printf '%s' "$prompt" | grep -qiE '(^|[^a-zA-Z0-9_])codex([^a-zA-Z0-9_]|$)'; then
  cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "[codex plugin] This prompt names codex. If it asks codex to perform ANY task (any phrasing: use/using codex, ask/run/call codex, have/let/tell/get codex, delegate to codex, 'codex: <task>', bare 'codex review/fix/...'), invoke the codex skill via the Skill tool (skill: codex) BEFORE running any codex CLI command or tmux interaction with codex — do not drive codex from memory. Codex is a co-worker in a visible tmux pane beside Claude: reuse the existing pane (spawn only if absent), give parallel workers their own panes, and NEVER run headless 'codex exec' unless the user explicitly asked for headless or confirmed it. Skip this only if the codex skill is already loaded in this conversation, or if codex is merely being discussed rather than asked to act."
  }
}
EOF
fi

exit 0
