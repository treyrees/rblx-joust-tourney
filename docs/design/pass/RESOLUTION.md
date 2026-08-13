---
maps-to: [src/shared/PassResolver.luau, src/shared/Constants.luau#RING, src/shared/Constants.luau#MATRIX, src/shared/Constants.luau#BREAK, tools/sim.luau, tools/rings.luau]
decisions: [0001, 0004, 0006, 0008, 0009]
owner: trey
updated: 2026-08-13
---

# Pass resolution — the ring, Balance, breaking, and the teeter roll

> The deep doc for the deterministic half of the pass. [GAME_SPEC.md](../GAME_SPEC.md) §3 and §4
> own the *intent*; this doc owns the *rule as implemented*, in
> [`src/shared/PassResolver.luau`](../../../src/shared/PassResolver.luau). The ring and the scale are
> pinned by [ADR 0006](../decisions/0006-the-ring-eight-notches-chirality.md), breaking by
> [ADR 0008](../decisions/0008-breaking-momentum-and-the-mortal-rung.md), the defensive rules by
> [ADR 0009](../decisions/0009-defence-is-prorated-supershield-is-state.md).

## The rule, in full

A pass takes two **commitments** and two **Balance meters** and returns two outcomes. A commitment:

| field | visibility | when it is chosen |
|---|---|---|
| `shield` | hidden until impact (the hole card) | intermission |
| `aim` | televised, quantized to one of eight notches | run-up, locked shortly before the tick |
| `holdFraction` | public, as the buildup meter | accumulated over the run-up |
| `momentum` | public, as the momentum meter | banked by spurring in neutral (ADR 0007) |
| `broken` | public — the crowd saw every break land | inflicted in earlier passes, keyed to world directions |

Nothing else is chosen. Everything defensive is derived from the aim by **the ring**
([`Constants.RING`](../../../src/shared/Constants.luau), `CCCNGNNN`): at each notch offset from the
rider's own aim, in cycle order —

| offsets from aim | class | meaning |
|---|---|---|
| 0, 1, 2 | **crit** | the exposure: struck here uncovered, the rider takes the crit tier |
| 4 | **guard** | polarization survives: one notch, directly opposite the aim |
| 3, 5, 6, 7 | normal | ordinary hits |

The Shield is a two-notch plate (`SHIELD_BAND`). Three exposure notches against a two-notch plate
means **something is always bare, and which is the entire hidden information of the pass** — the
televised aim narrows the Shield to about one bit and no further (ADR 0006's cited solve).

**Supershielded** = the plate covers the Guard **and** the aligning aim was held
(`holdFraction ≥ SUPERSHIELD_MIN_HOLD`) — defence is prorated like offence (ADR 0009). Neutral
never supershields.

Resolution is then, for each rider against the other's snapshot:

1. A **neutral** aim is always `weak`. It cannot be blocked and it cannot crit.
2. Look up the strike's notch on the defender's ring, **after breaks**: each break on that world
   direction demotes its class one rung (`guard → normal → crit → mortal`).
3. Struck on a **guard** notch or under the Shield plate: `blocked` — clean if supershielded (zero
   damage, plus `SUPERSHIELD_RESTORE`), thin otherwise (`THIN_BLOCK_MULT`, no restore).
4. Struck on a **mortal** notch, uncovered: `mortal` — unhorsed, **no roll drawn**.
5. Struck on a **crit** notch, uncovered: `crit`, at 3x.
6. Otherwise `normal`.
7. A strike that lands (not weak; blocked counts, per `BLOCKED_BREAKS`) with
   `momentum ≥ MOMENTUM_THRESHOLD` **breaks** the world direction it hit (ADR 0008).

## The defensive shapes

The plate can cover at most two of the three exposed notches, so the healthy rider's real menu is
three placements, every one reachable by a beginner who just picks a Shield and an aim:

| shape | plate goes | what stays bare |
|---|---|---|
| **forward** | on the aim | the far edge of the exposure |
| **back** | one notch on | the aim notch itself — the tip of your own spear |
| **deep** (Supershield) | on the Guard | the entire exposure, in exchange for the clean block + restore |

Which of forward/back is left open is the ~1 bit the aim cannot reveal. **Deep is
state-dependent, not price-dependent** (ADR 0009): at full Balance it takes 0% of the equilibrium;
below ~85 Balance it takes over on its own, because a restore and a no-roll block are worth most
exactly when the next roll could be the last. Depth is the hurt rider's game, breadth the healthy
rider's, and the public meter tells everyone which game each rider is in.

## The numbers

Live in [`Constants.MATRIX`](../../../src/shared/Constants.luau), `Constants.PRORATION`,
`Constants.BREAK` — never inline. Scale re-pinned by ADR 0006 against the cited runs:

- a crit is **3x** a normal (the ratio the read game is priced on, ADR 0001) at **5 / 15** —
  rescaled from 6 / 18 because crits fire at equilibrium on this ring (~21.5% of strikes) where the
  old ring's never did, and 6 / 18 pushed convergence under the band
- a thin block halves a strike; a clean (supershielded) block nullifies it and restores a little
- the offensive bonus is **linear** in hold fraction, up to +35% at a full hold (ADR 0001)
- breaking: momentum threshold **0.6**; three breaks on one direction reach mortal

## The teeter roll

Anyone who took damage this pass rolls against their **post-damage** Balance to stay mounted: at 80
Balance, 80% stay-on. The roll is the only randomness in the entire resolver, it is injected by the
caller, and `stayChance` is returned alongside `roll` so the UI can print the odds *before* the dice
land (CLAUDE.md invariant 6). Horse recovery (GAME_SPEC §6) is a flat bonus to stay-on odds and
touches nothing in the matrix. The **mortal** tier bypasses the roll entirely — it is the one finish
the dice cannot touch, and it exists precisely to put the endgame back on reads (ADR 0008).

## Invariants this module is responsible for

| invariant | how it is held | where it is tested |
|---|---|---|
| 1 — reads beat rarity | rarity only ever touches `stayChance`, never a tier or a damage number | `tests/PassResolver.spec.luau` |
| 3 — one tick, simultaneous | both riders resolve from one snapshot; `resolve` never reads what it has written | swap-the-riders test |
| 4 — aim is quantized | the resolver only ever sees discrete notches | the enumerated ring tests |
| 6 — RNG is visible | the teeter is the only roll, is injected, and reports its odds; mortal draws none | `tests/PassResolver.spec.luau` |
| 7 — the matrix outweighs the dice | asserted numerically, and re-checked on every sim run | `tools/sim.luau` verdict block |

## The instruments

Two, with complementary blind spots — combat-axis ADRs on this surface should cite both:

- **`lune run tools/sim.luau`** — a twelve-strategy round robin over whole matches. Exits non-zero
  if convergence leaves the 3–5 pass band, if a perfect read stops beating random by a wide margin,
  if most falls come off near-certain rolls, or if neutral-camping climbs the table. Scripted
  riders: it cannot find an equilibrium exploit on its own.
- **`lune run tools/rings.luau`** — the one-pass equilibrium solver (fictitious play over every
  commitment, exploitability-checked). Reports what a read is worth, the hole card in Balance and in
  bits, and crit/mutual-crit rates. It caught a configuration the round robin green-lit while
  structurally dead; it cannot see multi-pass dynamics (breaking, Balance states) unless pointed at
  them (`--balance`).

Useful flags: `--matches N`, `--seed S`, `--curve …`, `--notches N`, `--ring CODE`,
`--shield-band N`, `--balance A B`, `--dump-mix`.

## Still open

- The hold-fraction *distribution* and the *aim distribution* real players produce — the same blind
  spot, twice; the likeliest reason to reopen the curve (ADR 0001) or the scale (ADR 0006).
- The break ladder's length and threshold — mortal ends ~0.8% of strikes today; rarity vs endgame
  clock is a gray-box question (GAME_SPEC §12).
- The spur's feel on a real thumb — load-bearing for the whole "later" axis and untestable headless.
- Lance and horse stat surfaces (§6) plug into these numbers and will move convergence. Re-sim
  rather than eyeball.
