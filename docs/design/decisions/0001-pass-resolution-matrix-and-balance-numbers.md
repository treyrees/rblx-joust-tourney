---
id: 0001
title: Pass resolution — the matrix rule, the Balance numbers, and a linear proration curve
date: 2026-07-29
status: accepted
supersedes: []
superseded-by: null
combat-axis: true
---

# 0001 — Pass resolution: the matrix rule, the Balance numbers, and a linear proration curve

## Context

GAME_SPEC §3 and §4 describe the pass in prose: polarization, the two bonuses, the
blocked/normal/punished tiers, Balance and the teeter roll. Prose was enough to start building, but
three things had to be pinned before M1's gray-box could exist, and §12 listed two of them as open:

1. **What exactly does the punished tier key off?** §4 says "punished = struck opposite your guard",
   and a rider has two guards.
2. **The proration curve shape** — linear, ease-in, or floor-plus-ease-in. §3 recorded a lean toward
   floor+ease-in but explicitly deferred it as a gray-box question.
3. **The neutral baseline** — §3 lists three sub-questions, the third ("neutral as a passive-guard
   option") fully open.

Nothing here could be settled from a chair. `tools/sim.luau` was built alongside the resolver for
exactly this, and every number below is a reading off it rather than a guess.

## Decision

### The matrix rule

Four clauses, resolved simultaneously for both riders from one pre-pass snapshot:

1. A **neutral** aim is always `weak`: it cannot be blocked and cannot punish.
2. The defender's **coverage** is `{active guard, passive guard}`. A strike into coverage is
   `blocked` — clean (zero damage, plus a restore) if the defender stacked, **thin** (half damage, no
   restore) if they split.
3. The defender's **hole** is the direction opposite their active guard, which by polarization is
   exactly the direction they are aiming. Struck there, and not covered: `punished`.
4. Anything else is `normal`.

Clause 3 is the load-bearing one, and it is deliberately keyed to the **active** guard rather than
the passive guard. Keying the hole to the hidden passive guard was tried first and is degenerate: it
lets a rider spend their passive guard covering their own exposure and become punish-immune, which
prices out to a strictly dominant, entirely boring "guard your own axis" line. Keying it to the
active guard yields the rule the game can actually be taught with, in one sentence:

> **You are exposed exactly where you strike.**

The hidden passive guard's whole job then becomes the single interesting bit of information in the
pass: did they spend it covering that hole, or somewhere else?

### The numbers

| constant | value | note |
|---|---|---|
| `NORMAL_DAMAGE` | 6 | |
| `PUNISHED_DAMAGE` | 18 | exactly 3x a normal — the ratio is meant to be quotable |
| `WEAK_DAMAGE` | 2 | the neutral chip strike |
| `THIN_BLOCK_MULT` | 0.5 | a split block halves the strike instead of nullifying it |
| `STACK_BLOCK_RESTORE` | 2 | the defensive bonus; well under `NORMAL_DAMAGE`, so Balance still only trends down |
| `MAX_BONUS` | 0.35 | the offensive bonus at a full-run-up hold |

### The proration curve: linear

`CURVE = "linear"`, which **overturns the floor+ease-in lean recorded in GAME_SPEC §3**. All three
shapes stay implemented and unit-tested so the comparison can be re-run with
`lune run tools/sim.luau --curve <shape>`.

### The neutral baseline

All three of §3's sub-questions are answered, including the open one:

1. **Neutral aim** → the `weak` tier: chip damage, no punish potential, and no honesty bonus.
2. **Neutral active guard** → none. A neutral aim yields no active guard at all, so it covers nothing.
3. **Neutral as a passive guard** → **legal, and it covers nothing.** It cannot stack, so it forfeits
   the defensive bonus, and it leaves coverage at a single direction. It is a real option that is
   never a good one, which is the correct shape for a state we want legal but not viable.

## Consequences

Every number above is a reading from `tools/sim.luau` (seed 20260729, 20,000 matches per pairing
across a nine-strategy round robin, 720,000 matches total). The tool asserts three things and exits
non-zero on any of them, so these numbers cannot silently drift out of band:

```
convergence: 3.32 passes per match on average
attrition:   riders fall at 71.0 Balance on average; 33.8% of falls came off a roll
             they were 80%+ favoured to make
read edge:   a perfect read beats random 80.2% of the time
camper ranks 9 of 9
VERDICT: all three checks pass — these numbers are citable.
```

- **Convergence lands at 3.32 passes**, inside GAME_SPEC §4's 3–5 band. The band is narrow: at
  `NORMAL_DAMAGE = 9` convergence drops to 2.83 and falls out of it, so this axis has little slack
  and any future damage source (lances, abilities) has to be re-simmed, not eyeballed.
- **The matrix outweighs the dice** (CLAUDE.md invariant 7) by two independent measures: a perfect
  read beats a random opponent 80.2% of the time, and only 33.8% of falls come off a roll the rider
  was heavily favoured to make. The second measure was added specifically because read edge alone
  can look healthy while matches are still being decided by near-certain rolls at high Balance.
- **Neutral-camping ranks last of nine** at 18.6%, roughly half the win rate of pure random play.
- **The curve decision rests on a narrower base than the others.** The three shapes are
  indistinguishable on convergence and read edge; they separate only on how they price a *partially*
  held aim, which needed a purpose-built `halfer` strategy (fixed 0.5 hold) to see at all:

  | curve | honest (hold 1.0) | halfer (hold 0.5) | flicker (hold 0.0) |
  |---|---|---|---|
  | linear | 47.4% | 43.8% | 39.3% |
  | ease_in | 48.4% | 42.3% | 39.9% |
  | floor_ease_in | 48.6% | 41.3% | 40.3% |

  Under floor+ease-in a half-held aim scores within one point of a pure last-instant flick, which
  collapses the middle of the bluffing spectrum into a binary: commit fully or do not bother. Linear
  keeps a gradient across the whole meter while still punishing the flicker by 8 points, which is
  what makes the public buildup meter legible as a dial rather than a light switch. That the
  gradient is *better* is a design judgment, not a measurement — the measurement is only that the
  gradient exists under linear and does not under the floored shape.
- **The sim's riders hold fixed fractions**, so it cannot yet say anything about the hold
  *distribution* real players produce. If playtesters cluster at some hold value the curve treats
  oddly, this decision is the one to revisit, and it should be revisited with a new ADR rather than
  by editing this one.
- **`axis` (56.2%) and `counter` (55.5%) top the non-oracle field**, ahead of `stacker` (48.7%).
  Covering your own hole is the safest line, and it is meant to be — it earns no defensive bonus, and
  it is readable, which is what `counter` and `oracle` exploit. The gap is small enough that no shape
  is dead, but if `axis` pulls further ahead once real players are in the loop, `STACK_BLOCK_RESTORE`
  is the dial to raise.
