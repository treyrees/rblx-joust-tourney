# ADR Ledger — index

The append-only decision log. Conventions live in [../README.md](../README.md); the loop that
produces these lives in [../WORKFLOW.md](../WORKFLOW.md). Ids are four-digit, zero-padded,
monotonically increasing from `0001`. **Check this ledger for the next free id before creating an
ADR, and add your row in the same commit** — the ledger is the id-collision guard.

| id | title | date |
|----|-------|------|
| [0001](0001-pass-resolution-matrix-and-balance-numbers.md) | Pass resolution — the matrix rule, the Balance numbers, and a linear proration curve | 2026-07-29 |
| [0002](0002-horse-speed-as-the-bracket-key.md) | Horse speed is the bracket key, and felt speed is decoupled from the decision window | 2026-07-29 |
| [0004](0004-shield-guard-crit-vocabulary.md) | The pass is played in four words — Shield, Guard, Crit, Supershield | 2026-07-30 |
| [0005](0005-supershield-pays-offense.md) | The Supershield pays offense as well as defense — the committed lance *(superseded by 0009)* | 2026-07-30 |
| [0006](0006-the-ring-eight-notches-chirality.md) | The ring is data, it is chiral, and it is played on eight notches — CCCNGNNN | 2026-07-30 |
| [0007](0007-runup-input-event-driven-spur.md) | The run-up is event-driven — no inner tick, a beat-gated spur, and a public momentum meter | 2026-07-30 |
| [0008](0008-breaking-momentum-and-the-mortal-rung.md) | Breaking — momentum degrades the slice it strikes, down a ladder that ends at mortal | 2026-07-30 |
| [0009](0009-defence-is-prorated-supershield-is-state.md) | Defence is prorated like offence, and the Supershield is a state, not a price | 2026-07-30 |
| [0010](0010-invariants-both-bounds-and-the-equilibrium-gate.md) | The invariants gain both bounds and an equilibrium gate | 2026-07-30 |
| [0011](0011-typecheck-gate-and-one-toolchain.md) | A type-check gate, one pinned toolchain, and one definition of "the gates" | 2026-08-13 |
| [0012](0012-tilt-yard-is-the-interface.md) | The tilt-yard is the interface — one room, and the walk is the price of changing your mind | 2026-08-13 |
| [0013](0013-ghosts-are-habits-not-recordings.md) | Opponent supply is a habit register — a ghost is a habit, not a recording, and the yard has no fake people | 2026-08-13 |
| [0014](0014-the-rail-is-a-scouting-stand.md) | The rail is a scouting stand, and information parity is absolute | 2026-08-13 |
| [0015](0015-one-duel-is-a-match-the-gauntlet-is-the-run.md) | One duel is a match, the gauntlet is the run, and the stake that escalates is exposure | 2026-08-13 |

> **0003 is reserved, not free.** It belongs to the monetization ADR on the open branch
> `claude/game-monetization-analysis-s1avst` (PR #5), which was written before 0004/0005 and is not yet
> merged. The gap above is deliberate: taking 0003 would trip the duplicate-id check the moment that PR
> lands. Next free id is **0016**.
