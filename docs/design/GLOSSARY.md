---
maps-to: [src/shared/PassResolver.luau, src/shared/Constants.luau#MATRIX]
decisions: [0004]
owner: trey
updated: 2026-07-30
---

# GLOSSARY — the words the pass is played in

> The pass has four load-bearing nouns. This doc is the one place they are defined, and the ledger of
> the names they replaced. [GAME_SPEC.md](GAME_SPEC.md) §3 owns the *design*;
> [pass/RESOLUTION.md](pass/RESOLUTION.md) owns the *rule as implemented*; this owns the *vocabulary*.
>
> Why a glossary this early: GAME_SPEC §2 makes the creator/meta layer a design target rather than a
> byproduct, and that layer runs on shared words. A matchup chart that fits in a thumbnail needs terms
> that fit in a thumbnail, and it needs everyone using the same ones. Fixed by
> [ADR 0004](decisions/0004-shield-guard-crit-vocabulary.md).

## The live vocabulary

| Term | Chosen when | Visible? | Definition |
|---|---|---|---|
| **Shield** | Intermission, pre-round | **Hidden** until impact | The one direction you commit before the pass. The hole card — the only hidden value in the entire pass. |
| **Aim** | Run-up | Televised | The spear direction, quantized to one of four sectors (+ neutral). Where you threaten. |
| **Guard** | Derived | Public (follows the Aim) | Always the opposite of your Aim. Polarization: one input carries attack and defense together. |
| **Crit** | Derived | Public (follows the Aim) | The direction opposite your Guard — which is identically your Aim direction. Where *you* are exposed. Struck there and uncovered, a strike lands at `CRIT_DAMAGE`. |
| **Supershield** | Derived | Hidden (needs the Shield) | Your Guard landing on your Shield. Two defenses deep on one direction: the clean block plus a restore. |

Three consequences worth stating in the same breath as the definitions, because they are what make the
vocabulary worth having:

- **Aim and Crit are the same direction**, named for opposite purposes. `aim` is where this rider
  threatens; `crit` is where this rider is exposed. "You are exposed exactly where you strike."
- **The Shield is the only hidden value**, so every *tell* in the game is evidence about the Shield.
  The Guard is where you look; the Shield is probably there too.
- **A clean block and a Crit are mutually exclusive in one pass.** A clean block needs the attacker to
  aim into your Guard; hitting their Crit needs your Aim (and so your own Crit) pointed the other way.
  Both fall out of coverage and Crit being derived from the same single Aim input, so no tuning can
  make the two coincide.

## The three defensive shapes

The Shield has four placements, but only three distinct shapes relative to a given Aim:

| Shape | Shield goes | What you get |
|---|---|---|
| **Supershield** | on your Guard | 1 clean block (+restore), your Crit bare, 2 normals |
| **Axis** | on your Crit | 2 thin blocks, no Crit at all, 2 normals |
| **Split** | on the other axis | 2 thin blocks, your Crit bare, 1 normal |

Depth versus breadth, as GAME_SPEC §3 names it. Which of these is *correct* is a live tuning question
tracked in GAME_SPEC §12, not a settled fact — see
[ADR 0005](decisions/0005-supershield-pays-offense.md).

## Retired-term ledger

The machine half of this table lives in `RETIRED_VOCAB` in
[`tools/design-lint.luau`](../../tools/design-lint.luau); the linter warns when a living doc names one
of these as current without a supersession marker. **This doc and the ADRs are exempt** — ADRs are
history and this table defines the terms.

| Retired | Replaced by | Retired by |
|---|---|---|
| `passive guard` | **Shield** | ADR 0004 |
| `active guard` | **Guard** | ADR 0004 |
| `punish hole` / the hole | **Crit** | ADR 0004 |
| `stacking` / `stacked` | **Supershield** / supershielded | ADR 0004 |
| `punished` (tier) | **crit** (tier) | ADR 0004 |
| `PUNISHED_DAMAGE` | `CRIT_DAMAGE` | ADR 0004 |
| `STACK_BLOCK_RESTORE` | `SUPERSHIELD_RESTORE` | ADR 0004 |

Only the unambiguous multi-word terms are in `RETIRED_VOCAB`. `stack` / `stacked` / `stacking` are
deliberately left out: they are ordinary English elsewhere in these docs ("a stack of small merged
PRs" in WORKFLOW.md), and a check that cries wolf is a check people learn to ignore.

**`hole card` is not retired.** It is the poker term for a face-down card and it stays — it describes
the Shield's *role in the information game*, which is a different thing from the Crit's *place on the
body*. The retired term was "the hole" used as a direction.
