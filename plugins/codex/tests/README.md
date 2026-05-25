# codex-tmux tests

## Install bats

```bash
brew install bats-core
```

## Run all tests

```bash
bats plugins/codex/tests/test_codex_tmux.bats
```

## Mock codex

Tests use `tests/fixtures/mock-codex.sh` to simulate codex's TUI without burning OpenAI tokens. The mock prints a `▌` ready marker between prompts; the ready regex in the script is configured to match it via `CC_CODEX_READY_REGEX`.

Real-codex calibration is done by Task 18 (manual smoke test).
