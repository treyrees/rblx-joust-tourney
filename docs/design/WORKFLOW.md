---
maps-to: [tools/gates.sh, tools/toolchain.env, tools/install-toolchain.sh, tools/design-lint.luau, tests/run.luau, tools/sim.luau, tools/rings.luau, .github/workflows/gates.yml, .claude/hooks/session-start.sh]
decisions: [0011]
owner: trey
updated: 2026-08-13
---

# WORKFLOW — how we work (the stewardship loop)

> The repeatable loop for changing this codebase without letting **design** and **code** drift apart.
> The *mechanics* (front-matter, ADR format, linting) are defined in [README.md](README.md); **this**
> doc is the **loop that uses them** — read it once, then it's muscle memory. [CLAUDE.md](../../CLAUDE.md)
> links here and stays lean; this is the single home for "how we work."
> (Carried over from the predecessor repo, where it was proven across 200+ ADRs.)

## The one-paragraph model

We keep three things in sync: **the design** (living docs under `docs/design/`, anchored by
[GAME_SPEC.md](GAME_SPEC.md)), **the decisions** (append-only ADRs in `decisions/` — the durable
"why"), and **the code** (`src/`, built *to* the design). Machines check the seams: `design-lint`
verifies every doc still maps to real code and every ADR resolves; `tests/run.luau` verifies the code
itself; the type checker verifies that `--!strict` means something. Status is **computed from git,
never asserted in prose** — so no doc can quietly lie about being current. That is the entire
discipline; everything below is how you uphold it on a given change.

The same rule applies one level down, to the build itself: a claim about the gates
(*"CI runs all of them"*, *"the hook installs the toolchain"*) is checked by
`tests/Toolchain.spec.luau` rather than trusted, because those claims had already drifted once.
Code layout and the seams `src/` is built on: [ARCHITECTURE.md](ARCHITECTURE.md).

## The loop (run it on every change)

1. **Orient from the source of truth.** GAME_SPEC.md → the system's deep doc (once they exist) → its
   ADRs. Trust git history + ADRs for "what's true now," never a prose status line (those rot — which
   is the whole reason the linter exists).
2. **Classify the change — decision or implementation?**
   - *Implementing an already-accepted ADR* → **no new ADR**; just update the living doc.
   - *A new or changed design call* → write a **new ADR** (next free id; append-only;
     **Context → Decision → Consequences**) **and** update/create the living doc. Changed your mind
     about an old decision? A *new* ADR with `supersedes: [N]`, and set the old one's
     `superseded-by`. **Never rewrite an ADR** — you supersede history, you don't edit it.
   - *Touching a balance/tuning axis?* Mark the ADR `combat-axis: true` and **cite a sim run** in its
     `## Consequences` — decide *after* the tool, not before. Two instruments with complementary
     blind spots: `tools/sim.luau` (whole matches, scripted riders) and `tools/rings.luau` (one-pass
     equilibrium; catches exploits scripted riders never find — it once failed a configuration the
     round robin green-lit). Combat-axis ADRs on the pass surface should cite both. `design-lint`
     enforces the citation. Not tuning? `combat-axis: false`.
3. **Build in `src/`** to the design. Honor the [CLAUDE.md invariants](../../CLAUDE.md).
   **Constants are the single source of truth** — never hardcode a tuning number.
4. **Re-sync the doc↔code seam.** In the living doc you touched: add any new files to `maps-to`, and
   bump `updated:` to today *after* you've eyeballed the doc against the code. That date is exactly
   what the linter's drift check reads.
5. **Verify — every gate green: `QUICK=1 tools/gates.sh` (~9s).** Run it between edits, not once at
   the end; at nine seconds there is no reason to batch. Add or extend a `tests/*.spec.luau` for new
   logic — no Studio needed, the `robloxenv` shim runs the *same source* Rojo syncs. Before pinning a
   tuning number in an ADR, drop `QUICK=1` so the simulator runs at citable scale.
6. **Keep CLAUDE.md a map, not a status board.** It owns invariants / commands / where-things-live.
   If you find a status claim there that git contradicts, fix it or turn it into a pointer — the same
   anti-rot rule we apply to design docs applies to CLAUDE.md.

## What to create, and where

| You're adding… | Create | Conventions |
|---|---|---|
| A new system's design | `docs/design/<area>/NAME.md` **with front-matter** (`maps-to`, `decisions`, `owner`, `updated`) | [README.md](README.md) |
| A durable decision | `docs/design/decisions/NNNN-kebab.md` (next id, four-digit) + a ledger row | [README.md](README.md) |
| New game code | `src/{server,client,gui,shared}/…` + a `tests/*.spec.luau` | [CLAUDE.md](../../CLAUDE.md) |

## The gates (one definition, three callers)

```bash
tools/gates.sh              # every gate, in order, stopping at the first red one
tools/gates.sh tests        # just one
tools/gates.sh --list       # the names, in order
QUICK=1 tools/gates.sh      # the fast configuration of every gate: ~9s instead of ~2min
```

There are five, and [`tools/gates.sh`](../../tools/gates.sh) is what defines them. Do not re-type the
underlying commands into a workflow file or a hook — that is exactly how the list drifted before
(the hook silently ran three of four while this doc promised all of them), and
`tests/Toolchain.spec.luau` now fails the build if any caller stops going through the script.

| gate | what it proves | cost |
|---|---|---|
| `typecheck` | `src/` type-checks under Roblox's own analysis engine, with the Rojo sourcemap so `require(script.Parent.X)` resolves as it does in Studio (ADR 0011) | ~1s |
| `tests` | the code is correct — `tests/run.luau` through the `robloxenv` shim, on the same source Rojo syncs | ~1s |
| `design-lint` | docs ↔ code ↔ ADRs are consistent | ~1s |
| `sim` | the tuning numbers hold over whole matches, with scripted riders | ~2min (`--smoke`: ~7s) |
| `rings` | ...and at equilibrium, which scripted riders structurally cannot see | ~1s |

Green on all five ⇒ the change is consistent by construction. Red ⇒ fix before you push. Nothing else
gates — these *are* the safety net, on purpose. The last two are one gate with two halves: the round
robin once green-lit a configuration whose equilibrium was structurally dead (crit rate 0.0%, hole
card worth 0.01 Balance), which is why the solver half exists (ADR 0010).

**`QUICK=1` and the sim.** Quick mode puts the tests in quiet mode and the simulator in `--smoke`
(400 matches per pairing instead of 8000). Every verdict still runs and every threshold still holds
with margin — but the printed *rates* are not citable, and the run says so. A number quoted in an
ADR's `## Consequences` must come from a full run.

They run in three places, and the difference matters:

- **[`.github/workflows/gates.yml`](../../.github/workflows/gates.yml)** on every PR and every push
  to `main`, at full scale. This is the one that actually protects the branch: it does not depend on
  anyone having a session open.
- **`.claude/hooks/session-start.sh`** at the start of every remote session, in `QUICK=1` mode, so a
  session opens already knowing whether the tree is green — in about nine seconds.
- **You, at a terminal**, before you push.

The toolchain all three run is pinned in [`tools/toolchain.env`](../../tools/toolchain.env) and
installed by [`tools/install-toolchain.sh`](../../tools/install-toolchain.sh) — prebuilt downloads,
never a from-source build. One pin, so CI and a session cannot disagree about what green means.

The simulator is listed here as a gate because it is one: it exits non-zero if convergence leaves
GAME_SPEC §4's 3–5 pass band, if reading stops beating random by a wide margin, if most falls start
coming off near-certain rolls, or if neutral-camping climbs the table. That makes
[CLAUDE.md invariant 7](../../CLAUDE.md) a thing CI enforces rather than a thing someone remembers.

## Session & token discipline (proven the hard way)

- **One topic per session.** A focused scope (one system / one PR) keeps context small and reviews
  fast. Open a new session for an unrelated task.
- **Default every search to `src/`, `tests/`, `docs/design/`**; scope Grep/Glob with a path.
- **Don't read whole large files to orient** — Grep for the symbol, read the hit ± a window.
- **Keep PRs small and merge them quickly.** One system per PR; a stack of small merged PRs beats one
  sprawling branch.
- **Tool calls are context too** — prefer narrow calls (small perPage, specific files) over dumps.
- **Docs grow fast.** Enter through GAME_SPEC.md or a specific doc; don't fan out across the tree to
  answer one question.

## Things that make a session take an hour (and the fix for each)

Every entry below is something that actually happened in this repo, cost real session time, and
produced no signal while it did. They are collected here because none of them look like a problem
from inside the session — the session just feels slow.

| Symptom | Cause | Fix |
|---|---|---|
| Session opens with no `lune`, no gate results, no idea if the tree is green | The SessionStart hook was committed **non-executable** (git mode `100644`), so every fresh clone failed it with `Permission denied` — silently, since the hook's output is not the session's problem | Committed `100755`, invoked via `bash "$…"` in `.claude/settings.json` so the mode cannot break it twice, and asserted by `tests/Toolchain.spec.luau` |
| Several minutes of startup, then still no toolchain | The hook ran `cargo install lune --locked` — a **from-source build** in a container with a cold cargo registry, which an ephemeral remote session never gets to reuse | `tools/install-toolchain.sh`: pinned prebuilt downloads, whole toolchain in ~2s |
| A gate command returns nothing after a long wait, and gets run again | `lune run tools/sim.luau` takes **~2 minutes**, which exceeds the default 120s command timeout. It times out, reports nothing, and the natural response is to re-run it | `tools/gates.sh sim` in `QUICK=1`/`--smoke` (~7s) for the inner loop. Only run the full sim when a number is going into an ADR — and raise the command timeout when you do |
| A command appears to hang for the full timeout | Piping a chatty process into `head` — the writer blocks when the reader exits early | Redirect to a file and `grep`/`tail` it, or use `TESTKIT_QUIET=1` |
| Turns get slower and slower for no visible reason | One command dumped enormous output into context (`ps aux` in this environment prints the entire system prompt of the running agent) | Ask for the narrow thing: `grep -o`, `--format`, `head` on a *file*, never a firehose |
| Long stalls with nothing running | A tool call needed a permission the allowlist did not cover, and a remote session has nobody sitting there to approve it | `.claude/settings.json` allows the whole read-only shell vocabulary plus `tools/gates.sh`. Add to it rather than working around it |

The general rule behind the table: **a slow session is almost never slow thinking — it is a gate, a
tool, or a prompt that produced no signal.** When a session feels long, ask which command last
returned nothing useful, and fix that.
