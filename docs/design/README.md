# `docs/design/` — Design Docs

The living design spec. [GAME_SPEC.md](GAME_SPEC.md) is the canonical anchor; deep per-system docs
drop in as sibling folders (`pass/`, `chase/`, `loop/`, `ui/`, …) as systems earn them; `decisions/`
is the append-only ADR log. The stewardship loop that uses all of this is
[WORKFLOW.md](WORKFLOW.md).

## No status flags — drift is detected, not asserted

We deliberately do **not** put `Draft` / `Locked` / `Approved` labels on docs. Those tags drift the
moment someone edits prose without updating the label, and they create false confidence about what
can or can't change. Instead:

- **Docs are living.** The body always describes the *current* design. Edit freely.
- **Durable decisions are recorded separately**, as append-only ADRs in `decisions/`. A decision is
  the thing that's "locked" — a dated, immutable record with its rationale, not a sticky label on a
  doc you might casually rewrite.
- **Staleness is computed from git**, not claimed by a human, by
  [`tools/design-lint.luau`](../../tools/design-lint.luau).

## Doc front-matter (required on every system doc)

Every doc under a system folder starts with machine-readable front-matter — this is what the linter
checks, and what replaces a subjective status label:

```yaml
---
maps-to: [src/shared/PassResolver.lua, src/shared/Constants.lua]
decisions: [0001]
owner: trey
updated: 2026-07-29
---
```

| Field | Meaning |
|-------|---------|
| `maps-to` | The source file(s) this doc governs. The linter verifies they exist and flags drift. A `path#Key` entry (e.g. `src/shared/Constants.lua#PASS`) pins staleness to one top-level key's git history instead of the whole hub file — use it to keep a doc off the Constants noise floor. |
| `decisions` | ADR ids this doc realizes (numbers, e.g. `[0001, 0003]`). Linter verifies they exist and aren't superseded. |
| `owner` | Who to ask. |
| `updated` | `YYYY-MM-DD` of the last human review of this doc against its `maps-to` code. |

## ADRs (`decisions/`)

One file per decision: `NNNN-kebab-title.md`, four-digit zero-padded, monotonically increasing from
`0001`. Each ADR is **append-only / immutable once written** — you don't rewrite history; you
supersede it. Front-matter:

```yaml
---
id: 0001
title: <decision title>
date: 2026-07-29
status: accepted          # accepted | superseded   (the ONE place a status lives — on an immutable record)
supersedes: []            # ADR ids this replaces
superseded-by: null       # set to an ADR id when a later decision overrides this one
combat-axis: false        # true = this pins a balance/tuning number; must cite a sim run in Consequences
---
```

> The single exception to "no status flags": an ADR carries `accepted`/`superseded` because the ADR
> itself is immutable — the flag describes a historical record, not editable prose, so it can't
> drift. Changing your mind = write a *new* ADR with `supersedes: [N]` and set the old one's
> `superseded-by`.

Body sections: **Context** → **Decision** → **Consequences**.

Keep a ledger row per ADR in `decisions/README.md` (id, title, date) — it's the index and the
id-collision guard.

## Linting

```bash
lune run tools/design-lint.luau     # from repo root
```

It checks: every `maps-to` path exists; every markdown link resolves; every referenced ADR exists and
isn't superseded; tuning ADRs cite a sim run; and (warning only) flags a doc as **possibly stale**
when any `maps-to` file has git commits newer than the doc's `updated` date. Structural problems fail
the build (exit 1); drift is a warning. Wired into the `SessionStart` hook alongside
`tests/run.luau`.
