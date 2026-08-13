#!/usr/bin/env bash
# gates.sh — THE gates, in one place. docs/design/WORKFLOW.md describes them; this file is what
# actually runs them, and CI, the session-start hook and a human at a terminal all call it. Before it
# existed, "the gates" was a list of commands copy-pasted into three files that had already drifted
# apart (the hook silently skipped one of them and no doc said so).
#
# Usage:
#   tools/gates.sh                  # every gate, in order, stop at the first red one
#   tools/gates.sh tests            # one gate by name
#   tools/gates.sh --list           # names, in order
#   tools/gates.sh --keep-going     # run them all even after a failure, then report
#
# Gate names: typecheck | tests | design-lint | sim | rings
#
# Env:
#   QUICK=1     run the fast configuration of every gate (the sim drops to a smoke-scale run).
#               Meant for the session-start hook and for a fast local loop — NOT for a citation.
#               A tuning number quoted in an ADR must come from a full run.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Prefer a toolchain installed by tools/install-toolchain.sh, but never override one already on PATH
# (CI puts its own there, and a developer may have their own Lune).
TOOLS_BIN="${JOUST_TOOLS:-$HOME/.joust-tools}/bin"
[ -d "$TOOLS_BIN" ] && export PATH="$PATH:$TOOLS_BIN"
DEFS="${JOUST_TOOLS:-$HOME/.joust-tools}/share/globalTypes.d.luau"

GATES=(typecheck tests design-lint sim rings)

if [ "${1:-}" = "--list" ]; then
  printf '%s\n' "${GATES[@]}"
  exit 0
fi

KEEP_GOING=0
if [ "${1:-}" = "--keep-going" ]; then
  KEEP_GOING=1
  shift
fi

# --- the gates ------------------------------------------------------------------------------------

# Gate: the code type-checks. Roblox's own analysis engine over src/, with the instance sourcemap so
# `require(script.Parent.Constants)` resolves the way it does in Studio. Scoped to src/ on purpose —
# tests/ and tools/ are Lune scripts whose `@lune/*` requires this checker has no definitions for.
# (ADR 0011.)
gate_typecheck() {
  if ! command -v luau-lsp >/dev/null 2>&1 || ! command -v rojo >/dev/null 2>&1; then
    echo "SKIP typecheck — luau-lsp or rojo missing (run tools/install-toolchain.sh)" >&2
    return 0
  fi
  if [ ! -s "$DEFS" ]; then
    echo "SKIP typecheck — Roblox type definitions missing (run tools/install-toolchain.sh defs)" >&2
    return 0
  fi
  rojo sourcemap default.project.json -o "$REPO_ROOT/sourcemap.json" >/dev/null
  luau-lsp analyze --sourcemap="$REPO_ROOT/sourcemap.json" --definitions="$DEFS" src/
}

# Gate: the code is correct. The robloxenv shim runs the same source Rojo syncs into Studio.
gate_tests() {
  if [ "${QUICK:-}" = "1" ]; then
    TESTKIT_QUIET=1 lune run tests/run.luau
  else
    lune run tests/run.luau
  fi
}

# Gate: docs, code and ADRs are consistent. Exit 1 on a structural problem; drift is a warning.
gate_design_lint() {
  lune run tools/design-lint.luau
}

# Gate three, half one: the round robin over whole matches with scripted riders.
gate_sim() {
  if [ "${QUICK:-}" = "1" ]; then
    lune run tools/sim.luau --smoke
  else
    lune run tools/sim.luau
  fi
}

# Gate three, half two: the equilibrium solver — what scripted riders structurally cannot see.
gate_rings() {
  lune run tools/rings.luau --verify
}

run_gate() {
  case "$1" in
    typecheck) gate_typecheck ;;
    tests) gate_tests ;;
    design-lint) gate_design_lint ;;
    sim) gate_sim ;;
    rings) gate_rings ;;
    *)
      echo "unknown gate '$1' (expected one of: ${GATES[*]})" >&2
      return 2
      ;;
  esac
}

# --- driver ---------------------------------------------------------------------------------------

if [ $# -gt 0 ]; then
  GATES=("$@")
fi

failed=()
for gate in "${GATES[@]}"; do
  echo "── gate: $gate ──"
  if run_gate "$gate"; then
    echo "✓ $gate"
  else
    echo "✗ $gate" >&2
    failed+=("$gate")
    if [ "$KEEP_GOING" -eq 0 ]; then
      break
    fi
  fi
  echo
done

if [ ${#failed[@]} -gt 0 ]; then
  echo "RED — failing gate(s): ${failed[*]}" >&2
  exit 1
fi
echo "GREEN — all gates pass: ${GATES[*]}"
