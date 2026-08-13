---
id: 0011
title: A type-check gate, one pinned toolchain, and one definition of "the gates"
date: 2026-08-13
status: accepted
supersedes: []
superseded-by: null
combat-axis: false
---

# 0011 — A type-check gate, one pinned toolchain, and one definition of "the gates"

## Context

The project is about to grow from ~650 lines of `src/` into a server match loop, a client wheel and a
GUI layer, and three of the four `src/` directories are still empty. Everything below the game — the
harness, the gates, the toolchain, the code-structure conventions — was built for the size the repo
*was*. Four separate problems surfaced when it was audited against the size it is about to be.

**1. `--!strict` was a claim nobody checked.** Every module carried the directive; nothing ran a type
checker. Running one found **eight live type errors** in the shipped resolver. They shared a single
root cause: `Constants.DIRECTIONS`, `Constants.RING` and `Constants.CYCLE` were untyped table
literals, so their values inferred as `string` rather than as the singleton unions the design speaks
in. Every `Direction`- and `Tier`-typed signature downstream had therefore degraded to "any string
will do", while reading, in the source, as fully strict. That is the worst shape a type error can
take: the annotation is present, it is wrong, and it is load-bearing documentation for the next
person. A ninth issue rode along — the default Luau solver widens a multi-branch singleton return
back to `string` when the function is reached through a module table, which unpicks `Tier` at every
call site of `PassResolver.tier`.

**2. The toolchain was pinned twice, and the slow pin was the one people hit.** CI downloaded a
pinned Lune 0.10.5 prebuilt in seconds. The SessionStart hook ran `cargo install lune --locked` —
unpinned, and a from-source build of the whole dependency tree. A remote session is always a fresh
ephemeral container with a cold cargo registry, so "cached across sessions once built" was never true
there: it was a multi-minute build, every session, of a version CI was not testing.

**3. The hook was committed non-executable, so none of that ran anyway.**
`.claude/hooks/session-start.sh` was tracked at git mode `100644`. Every fresh clone — which is every
remote session — failed it with `Permission denied`. Sessions had been opening with no toolchain, no
gate results, and no indication anything was wrong, and each one paid to bootstrap by hand before it
could do any work. Nothing was red; the hook simply, silently, did not exist.

**4. "The gates" was a list maintained in three places, and it had drifted.** WORKFLOW.md, the CI
workflow and the hook each carried their own copy. The hook ran three of the four while both docs
said it ran all of them. Separately, `tools/sim.luau` and `tools/rings.luau` — the two instruments
whose output ADRs are required to quote — **silently ignored unknown arguments**, so a mistyped
`--machts 40000` ran the default configuration and printed a confident, citable-looking verdict about
a run nobody asked for.

## Decision

**A fifth gate: `typecheck`.** `luau-lsp analyze` over `src/`, driven by a Rojo instance sourcemap so
`require(script.Parent.X)` resolves exactly as it does in Studio, with a `.luaurc` putting the tree in
strict mode and promoting lints to errors. Scoped to `src/` deliberately: `tests/` and `tools/` are
Lune scripts whose `@lune/*` requires this checker has no definitions for. It runs on the **default**
Luau solver — the one Studio ships — rather than `LuauSolverV2`; both are clean on the current tree,
and the gate should match what the engine will actually do to this code.

**A shared type vocabulary.** `src/shared/Types.luau`, a leaf module requiring nothing, exports
`Direction`, `RingClass`, `Tier` and `DirectionNames`. `Constants` annotates its tables against it and
`PassResolver` re-exports from it. Where the old solver widens a singleton return, the receiving local
is annotated rather than left to inference. The eight errors are fixed at the root, not suppressed.

**One pinned toolchain.** `tools/toolchain.env` holds every version; `tools/install-toolchain.sh`
installs them all from prebuilt releases, idempotently. CI and the hook both call it and neither
names a version. The hook is committed `100755` and invoked as `bash "$…"` so a lost mode bit cannot
silently disable it again.

**One definition of the gates.** `tools/gates.sh` owns the list and the commands. CI, the hook and a
developer all call it; nobody re-types the commands. `QUICK=1` selects a fast configuration of every
gate — quiet tests, and the simulator's new `--smoke` mode — putting the full five-gate suite at
about nine seconds against the previous two-plus minutes.

**`--smoke` is honest about what it is.** 400 matches per pairing instead of 8000. Every verdict still
runs and every threshold still holds with margin (measured across five seeds: read edge 82.8–87.2%
against a 75–93% band, convergence 3.22–3.26 against a 3–5 band), but the run prints
`SMOKE RUN — … the printed rates are NOT citable` and its verdict line says to re-run before quoting
a number. **Unknown arguments to `tools/sim.luau` and `tools/rings.luau` are now hard errors.**

**Machine-checked, not remembered.** `tests/Purity.spec.luau` enforces `--!strict` on every module,
`src/shared`'s purity per module (with a `-- @impure: <reason>` escape hatch), and that the test shim
mirrors `default.project.json`. `tests/Toolchain.spec.luau` enforces the executable bits, that every
declared gate is implemented and dispatched and run by CI and named in WORKFLOW.md, and that no
version literal is duplicated outside `toolchain.env`.

## Consequences

**The gate found real bugs on the day it was added**, which is the argument for it. Eight type errors
in `--!strict` code that had passed every existing gate; a hook that had never run; two instruments
that would quietly mis-report a mistyped run. None of these were visible to the tests, the design
linter, the round robin or the equilibrium solver — they sat in the space between the code and the
things that check the code, which is precisely the space a project this size starts to accumulate.

**Session cost.** Toolchain provisioning goes from a multi-minute from-source build (that had been
failing outright) to a ~2s download. The gate suite in `QUICK=1` is ~9s, so a session can afford to
run *all five* between edits rather than deferring to CI. The full sim stays available and is what CI
runs; ADRs still cite full runs. The failure modes that cost the most session time are now written
down in WORKFLOW.md's "Things that make a session take an hour" table, with the fix beside each.

**Combat axis: untouched.** No tuning number moved. The typed-constants change is annotation only,
and this was verified rather than assumed: the full `tools/sim.luau` run before and after is
byte-identical on every reported figure (convergence 3.25 passes, read edge 87.2%, camper 12 of 12,
all checks pass), and `tools/rings.luau --verify` holds every equilibrium invariant (hole card 8.12
Balance, 1.00 bits, crits 43.7%, top pure line 12.6%). `combat-axis: false` is therefore accurate —
but the runs are recorded here anyway, because "annotation only" is a claim about a diff and the
instruments are how this repo settles claims about the pass.

**Costs accepted.** Three more binaries to install (luau-lsp, rojo, plus the Roblox type definitions)
— all prebuilt, all cached after the first run, and rojo was already a documented dependency for
Studio sync. The type definitions are fetched from a URL rather than a pinned release artifact, which
is the one soft spot in the pinning story; they are fetched once and not refreshed on each run, so a
gate cannot change its own inputs mid-flight. `.luaurc` turning lints into errors will occasionally
demand a change that feels like ceremony; that is the price of the setting that caught the unknown
global, and it is cheap to revisit per-lint.
