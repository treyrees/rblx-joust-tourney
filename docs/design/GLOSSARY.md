---
maps-to: [src/shared/PassResolver.luau, src/shared/Constants.luau#MATRIX, src/shared/Constants.luau#BREAK]
decisions: [0004, 0006, 0008, 0009]
owner: trey
updated: 2026-07-30
---

# GLOSSARY — the words the pass is played in

> The pass has a small set of load-bearing nouns. This doc is the one place they are defined, and the
> ledger of the names they replaced. [GAME_SPEC.md](GAME_SPEC.md) §3 owns the *design*;
> [pass/RESOLUTION.md](pass/RESOLUTION.md) owns the *rule as implemented*; this owns the *vocabulary*.
>
> Why a glossary this early: GAME_SPEC §2 makes the creator/meta layer a design target rather than a
> byproduct, and that layer runs on shared words. A matchup chart that fits in a thumbnail needs terms
> that fit in a thumbnail, and it needs everyone using the same ones. Fixed by
> [ADR 0004](decisions/0004-shield-guard-crit-vocabulary.md); geometry updated by
> [ADR 0006](decisions/0006-the-ring-eight-notches-chirality.md).

## The live vocabulary

| Term | Chosen when | Visible? | Definition |
|---|---|---|---|
| **Shield** | Intermission, pre-round | **Hidden** until impact | A two-notch (90°) plate placed on the wheel before the pass. The hole card — the only hidden value in the entire pass. |
| **Aim** | Run-up | Televised | The spear direction, quantized to one of eight notches (+ neutral). Where you threaten. |
| **Ring** | Derived | Public (follows the Aim) | The fixed pattern your Aim drags around the wheel: exposed at the Aim and two notches sweeping on (135°), Guard opposite, the rest ordinary. Chiral — the danger hangs off one side of your spear. |
| **Guard** | Derived | Public (follows the Aim) | The one-notch (45°) block always directly opposite your Aim. Polarization: one input carries attack and defense together. |
| **Crit** | Derived | Public (follows the Aim) | The three exposed notches of your ring. Where *you* are vulnerable. Struck there and uncovered, a strike lands at `CRIT_DAMAGE`. "You are exposed exactly where you strike — and one turn around." |
| **Supershield** | Derived | Hidden (needs the Shield) | Your Shield covering your Guard, with the aligning Aim genuinely held. Two defenses deep on one direction: the clean block plus a restore. Dormant at full Balance; the hurt rider's line (ADR 0009). |
| **Spur** | Run-up, in neutral | Public (the momentum meter) | One tap per hoofbeat while aiming neutral banks **Momentum**. Time spent spurring is time not spent holding an aim (ADR 0007). |
| **Break** | On impact | Public | A landed strike carrying enough Momentum degrades the world direction it hit, one rung, for the match: `guard → normal → crit → mortal` (ADR 0008). |
| **Mortal** | Derived (three Breaks) | Public | The rung below crit. Struck there uncovered, the rider is unhorsed with **no roll drawn** — the one finish the dice cannot touch. |

Three consequences worth stating in the same breath as the definitions, because they are what make the
vocabulary worth having:

- **Your Aim is inside your own Crit.** The spear's notch is the first exposed notch — threatening
  and being threatened are the same gesture, one turn apart.
- **The Shield is the only hidden value**, so every *tell* in the game is evidence about the Shield.
  Three exposed notches, a two-notch plate: the whole secret is *which notch stayed bare*, and the
  televised Aim narrows it to a coin flip, never further.
- **A clean block and a Crit are mutually exclusive in one pass.** A clean block needs the attacker to
  aim into your Guard; hitting their Crit needs your Aim pointed into their exposure. Both fall out of
  coverage and Crit being derived from the same single Aim input, so no tuning can make the two
  coincide.

## The three defensive shapes

The plate covers at most two of your three exposed notches:

| Shape | Shield goes | What stays bare |
|---|---|---|
| **Forward** | on your Aim | the far edge of your exposure |
| **Back** | one notch on | the tip of your own spear |
| **Deep** (Supershield) | on your Guard | your whole exposure — bought with the clean block and restore |

Forward-or-back is the healthy game and the ~1-bit guess. Deep is the hurt game: below ~85 Balance it
takes over on its own. Depth versus breadth is **resolved, not balanced** — settled by
[ADR 0009](decisions/0009-defence-is-prorated-supershield-is-state.md), which supersedes ADR 0005.

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
| `axis` / `split` (shapes) | **forward** / **back** | ADR 0006 |
| `cracked` / `cracking` | **broken** / **Breaking** | ADR 0008 |

Only the unambiguous multi-word terms are in `RETIRED_VOCAB`. `stack` / `stacked` / `stacking` are
deliberately left out: they are ordinary English elsewhere in these docs ("a stack of small merged
PRs" in WORKFLOW.md), and a check that cries wolf is a check people learn to ignore.

**`hole card` is not retired.** It is the poker term for a face-down card and it stays — it describes
the Shield's *role in the information game*, which is a different thing from the Crit's *place on the
body*. The retired term was "the hole" used as a direction.
