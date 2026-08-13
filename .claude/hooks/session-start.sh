#!/bin/bash
# SessionStart hook — provision the gate toolchain for Claude Code on the web, then run the gates so
# a session opens already knowing whether the tree is green.
#
# The toolchain and the gate list are NOT defined here. They live in tools/toolchain.env and
# tools/gates.sh, the same two files .github/workflows/gates.yml uses, so a session and CI cannot
# disagree about what "green" means. They used to: this hook ran `cargo install lune --locked`
# (unpinned, built from source, minutes of every session start) while CI downloaded a pinned
# prebuilt, and the hook silently ran three of the four gates while WORKFLOW.md claimed it ran all of
# them.
#
# Async: the '{"async": true}' line below lets the session start immediately while provisioning +
# verification run in the background (their output surfaces when they finish).
set -euo pipefail

# Web (remote) only — do nothing in local/desktop sessions.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# Go async: don't block the session on toolchain install + the gates. Must be the first line on
# stdout. Everything else in this hook goes to stderr, so it never lands on stdout after this.
echo '{"async": true, "asyncTimeout": 300000}'

cd "${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Install the pinned toolchain (idempotent; cached across sessions) and put it on PATH for the whole
# session. Fatal if it can't install — the harness is the point of this hook.
echo "[session-start] installing pinned toolchain…" >&2
tools/install-toolchain.sh >&2
TOOLS_BIN="$(tools/install-toolchain.sh --print-path)"
export PATH="$TOOLS_BIN:$PATH"
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$TOOLS_BIN:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi

# Run every gate. QUICK=1 puts the unit tests in quiet mode (one summary line instead of ~1,200) and
# the simulator in --smoke mode (~7s instead of ~2min, verdicts intact, printed rates not citable).
# --keep-going so one red gate doesn't hide the state of the other four.
#
# Non-fatal: a red gate should SURFACE at session start, not block the session — the session may well
# be the one opened to fix it. CI is the gate that actually protects the branch.
echo "[session-start] running gates (quick)…" >&2
QUICK=1 tools/gates.sh --keep-going >&2 || echo "[session-start] WARN: one or more gates are RED — see above" >&2

echo "[session-start] ready." >&2
