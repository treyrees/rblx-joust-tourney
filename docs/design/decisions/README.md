# ADR Ledger — index

The append-only decision log. Conventions live in [../README.md](../README.md); the loop that
produces these lives in [../WORKFLOW.md](../WORKFLOW.md). Ids are four-digit, zero-padded,
monotonically increasing from `0001`. **Check this ledger for the next free id before creating an
ADR, and add your row in the same commit** — the ledger is the id-collision guard.

| id | title | date |
|----|-------|------|
| [0001](0001-pass-resolution-matrix-and-balance-numbers.md) | Pass resolution — the matrix rule, the Balance numbers, and a linear proration curve | 2026-07-29 |
| [0002](0002-horse-speed-as-the-bracket-key.md) | Horse speed is the bracket key, and felt speed is decoupled from the decision window | 2026-07-29 |
| [0003](0003-monetization-standard-meta.md) | Monetization adopts the platform-standard meta, arranged around the read invariant | 2026-07-29 |
| [0004](0004-shield-guard-crit-vocabulary.md) | The pass is played in four words — Shield, Guard, Crit, Supershield | 2026-07-30 |
| [0005](0005-supershield-pays-offense.md) | The Supershield pays offense as well as defense — the committed lance | 2026-07-30 |

> Next free id is **0006**.
