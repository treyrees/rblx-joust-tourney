---
maps-to: [src/shared/PassResolver.luau, src/shared/Constants.luau#MATRIX, src/shared/Constants.luau#PRORATION, tools/sim.luau]
decisions: [0001]
owner: trey
updated: 2026-07-29
---

# Pass resolution — the matrix, Balance, and the teeter roll

> The deep doc for the deterministic half of the pass. [GAME_SPEC.md](../GAME_SPEC.md) §3 and §4
> own the *intent*; this doc owns the *rule as implemented*, in
> [`src/shared/PassResolver.luau`](../../../src/shared/PassResolver.luau). The numbers and the three
> design calls behind them are pinned by
> [ADR 0001](../decisions/0001-pass-resolution-matrix-and-balance-numbers.md).

## The rule, in full

A pass takes two **commitments** and two **Balance meters** and returns two outcomes. A commitment is
three values:

| field | visibility | when it is chosen |
|---|---|---|
| `passiveGuard` | hidden until impact (the hole card) | intermission |
| `aim` | televised, quantized to a sector | run-up, locked shortly before the tick |
| `holdFraction` | public, as the buildup meter | accumulated over the run-up |

Two things are derived, not chosen:

- **Active guard** = the opposite of the aim. Polarization: one input carries attack and defense
  together, so you cannot aim at their weakness without configuring your own exposure.
- **Stacked** = active guard equals passive guard. This is the binary defensive bonus. Neutral never
  stacks.

Resolution is then four clauses, evaluated for each rider against the other's snapshot:

1. A **neutral** aim is always `weak`. It cannot be blocked and it cannot punish.
2. **Coverage** is `{active guard, passive guard}`. A strike into coverage is `blocked` — clean if
   the defender stacked (zero damage, plus a restore), **thin** if they split (half damage, no
   restore).
3. The **hole** is the direction opposite the active guard, which is exactly the direction the
   defender is aiming. Struck there and uncovered: `punished`.
4. Otherwise: `normal`.

Clause 3 is the whole game in one sentence: **you are exposed exactly where you strike.** ADR 0001
records why the hole keys off the active guard rather than the hidden passive guard — the alternative
makes a punish-immune line strictly dominant.

## The three defensive shapes

Because coverage is two directions and the hole is fixed by aim, exactly three shapes exist. Every
one of them is reachable by a beginner who just picks a guard and an aim, which is the point:

| shape | passive guard | outcome spread across the four aims |
|---|---|---|
| **stack** | onto the active guard | 1 clean block (+restore), 1 punish hole, 2 normals |
| **axis** | onto its own aim direction, covering the hole | 2 thin blocks, 0 punish holes, 2 normals |
| **split** | onto the other axis | 2 thin blocks, 1 punish hole, 1 normal |

Depth versus breadth, as GAME_SPEC §3 frames it: stack defends one direction deeply and pays for it
with an open hole; axis is the safe line and earns no bonus for it; split covers the most ground
thinly and still leaves the hole open.

## The numbers

Live in [`Constants.MATRIX`](../../../src/shared/Constants.luau) and `Constants.PRORATION`, never
inline. Pinned by ADR 0001 against a cited `tools/sim.luau` run:

- a punish is **3x** a normal, which is the ratio the read game is priced on
- a thin block halves a strike; a clean block nullifies it and restores a little Balance
- the offensive bonus is **linear** in hold fraction, up to +35% at a full hold

## The teeter roll

Anyone who took damage this pass rolls against their **post-damage** Balance to stay mounted: at 80
Balance, 80% stay-on. The roll is the only randomness in the entire resolver, it is injected by the
caller, and `stayChance` is returned alongside `roll` so the UI can print the odds *before* the dice
land (CLAUDE.md invariant 6). Horse recovery (GAME_SPEC §6) is a flat bonus to stay-on odds and
touches nothing in the matrix — that separation is what keeps "rarity loads the dice, it never beats
a read" true by construction.

## Invariants this module is responsible for

| invariant | how it is held | where it is tested |
|---|---|---|
| 1 — reads beat rarity | rarity only ever touches `stayChance`, never a tier or a damage number | `tests/PassResolver.spec.luau` |
| 3 — one tick, simultaneous | both riders resolve from one snapshot; `resolve` never reads what it has written | swap-the-riders test |
| 4 — aim is quantized | the resolver only ever sees one of five discrete directions | the enumerated matrix tests |
| 6 — RNG is visible | the teeter is the only roll, is injected, and reports its odds | `tests/PassResolver.spec.luau` |
| 7 — the matrix outweighs the dice | asserted numerically, and re-checked on every sim run | `tools/sim.luau` verdict block |

## The instrument

`lune run tools/sim.luau` plays a nine-strategy round robin and exits non-zero if convergence leaves
the 3–5 pass band, if a perfect read stops beating random by a wide margin, if most falls start
coming off near-certain rolls, or if neutral-camping climbs the table. Per
[WORKFLOW.md](../WORKFLOW.md), no ADR may pin a number on this surface without citing a run of it.

Useful flags: `--matches N`, `--seed S`, `--curve linear|ease_in|floor_ease_in`.

## Still open

- The hold-fraction *distribution* real players produce — the sim's riders hold fixed fractions, so
  it cannot speak to this yet. It is the thing most likely to reopen the curve decision.
- Depleting guards (GAME_SPEC §5) are not implemented. When they land they change the coverage rule,
  so they need their own ADR and their own sim run.
- Lance and horse stat surfaces (§6) plug into these numbers and will move convergence. Re-sim rather
  than eyeball.
