#!/bin/bash
# SessionStart hook — provision the headless Luau test/lint harness for Claude Code on the web.
# Installs Lune (the only dependency) if missing, then runs the unit tests and the design-doc linter.
#
# Async: the '{"async": true}' line below lets the session start immediately while provisioning +
# verification run in the background (their output surfaces when they finish). Tests run with
# TESTKIT_QUIET=1 so a green run reports one summary line instead of ~1,200 per-test lines — the
# startup latency + transcript noise this hook used to add is the point of both changes.
set -euo pipefail

# Web (remote) only — do nothing in local/desktop sessions.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# Go async: don't block the session on Lune install + the full test/lint pass. Must be the first
# line on stdout. Everything else in this hook goes to stderr, so it never lands on stdout after this.
echo '{"async": true, "asyncTimeout": 300000}'

cd "${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Lune installs to ~/.cargo/bin. Put it on PATH now and persist for the whole session.
export PATH="$HOME/.cargo/bin:$PATH"
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> "$CLAUDE_ENV_FILE"
fi

# Install Lune if absent (cached across sessions once built). Fatal if it can't install — the harness
# is the point of this hook.
if ! command -v lune >/dev/null 2>&1; then
  echo "[session-start] installing lune (first run compiles; cached afterwards)…" >&2
  cargo install lune --locked
fi
echo "[session-start] lune $(lune --version)" >&2

# Run the harness. Non-fatal: a red test or stale-doc warning should surface, not block the session.
# Quiet: only failures + the PASS/FAIL summary print (set TESTKIT_QUIET= to restore per-test output).
echo "[session-start] running unit tests…" >&2
TESTKIT_QUIET=1 lune run tests/run.luau >&2 || echo "[session-start] WARN: unit tests failed" >&2

echo "[session-start] running design-lint…" >&2
lune run tools/design-lint.luau >&2 || echo "[session-start] WARN: design-lint failed" >&2

echo "[session-start] running equilibrium verify…" >&2
lune run tools/rings.luau --verify >&2 || echo "[session-start] WARN: equilibrium verify failed" >&2

echo "[session-start] ready." >&2
