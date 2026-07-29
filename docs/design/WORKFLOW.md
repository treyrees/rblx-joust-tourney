---
maps-to: [tools/design-lint.luau, tests/run.luau]
decisions: []
owner: trey
updated: 2026-07-29
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
itself. Status is **computed from git, never asserted in prose** — so no doc can quietly lie about
being current. That is the entire discipline; everything below is how you uphold it on a given change.

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
     `## Consequences` — decide *after* the tool, not before. The M1 pass-simulator is that tool
     here; `design-lint` enforces the citation. Not tuning? `combat-axis: false`.
3. **Build in `src/`** to the design. Honor the [CLAUDE.md invariants](../../CLAUDE.md).
   **Constants are the single source of truth** — never hardcode a tuning number.
4. **Re-sync the doc↔code seam.** In the living doc you touched: add any new files to `maps-to`, and
   bump `updated:` to today *after* you've eyeballed the doc against the code. That date is exactly
   what the linter's drift check reads.
5. **Verify — both gates green.**
   - `lune run tests/run.luau` — add or extend a `tests/*.spec.luau` for new logic. No Studio needed:
     the `robloxenv` shim runs the *same source* Rojo syncs.
   - `lune run tools/design-lint.luau` — every `maps-to` path exists, every link resolves, every
     referenced ADR exists and isn't superseded, no id collisions, no drift.
6. **Keep CLAUDE.md a map, not a status board.** It owns invariants / commands / where-things-live.
   If you find a status claim there that git contradicts, fix it or turn it into a pointer — the same
   anti-rot rule we apply to design docs applies to CLAUDE.md.

## What to create, and where

| You're adding… | Create | Conventions |
|---|---|---|
| A new system's design | `docs/design/<area>/NAME.md` **with front-matter** (`maps-to`, `decisions`, `owner`, `updated`) | [README.md](README.md) |
| A durable decision | `docs/design/decisions/NNNN-kebab.md` (next id, four-digit) + a ledger row | [README.md](README.md) |
| New game code | `src/{server,client,gui,shared}/…` + a `tests/*.spec.luau` | [CLAUDE.md](../../CLAUDE.md) |

## The two gates (wired into CI / the SessionStart hook)

```bash
lune run tests/run.luau          # the code is correct
lune run tools/design-lint.luau  # docs ↔ code ↔ ADRs are consistent
```

Green on both ⇒ the change is consistent by construction. Red ⇒ fix before you push. Nothing else
gates — these two *are* the safety net, on purpose. The `.claude/hooks/session-start.sh` hook runs
both automatically at the start of every remote session.

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
