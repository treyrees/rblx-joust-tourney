---
id: 0005
title: The Supershield pays offense as well as defense — the committed lance
date: 2026-07-30
status: superseded
supersedes: []
superseded-by: 0009
combat-axis: false
---

# 0005 — The Supershield pays offense as well as defense: the committed lance

`combat-axis: false` because this ADR deliberately pins **no** tuning number, in the same shape as
[ADR 0002](0002-horse-speed-as-the-bracket-key.md). It fixes the *structure* of the fix and the *target*
it aims at; all three magnitudes it implies need their own `combat-axis: true` ADR with its own cited
sim run. A run is cited below to establish the **problem**, not to pin a solution.

## Context

GAME_SPEC §3 calls depth-versus-breadth "a named strategic axis." On ADR 0001's numbers it is not an
axis — it has a known right answer, and the answer is breadth.

From ADR 0001's cited run (seed 20260729, 720,000 matches), reproduced unchanged on the current tool:

```
standing (mean win rate vs the non-oracle field)
  1. oracle       71.2%
  2. axis         56.2%
  3. counter      55.5%
  4. supershield  48.7%
```

Two things in that table are worse than they look.

**`axis` beats `supershield` by 7.5 points.** ADR 0001 noted this and proposed `SUPERSHIELD_RESTORE` as
the dial. It cannot be — see below.

**`axis` beats the `oracle`, 57.3% to 42.7%.** A strategy with no read at all beats perfect
clairvoyance, because plugging your own Crit removes the only thing a perfect read can exploit. When
the safe shape defeats the reading shape, CLAUDE.md invariant 7 ("the matrix outweighs the dice") is
technically satisfied while the spirit is inverted: the correct play is to make yourself unreadable
rather than to read.

### Why no defensive lever can fix it

Fix a defender with Guard **G** and Crit **O**, attacker aiming uniformly. The Supershield and the axis
shape differ on exactly two of the four incoming aims: on **G** the Supershield upgrades a thin block to
a clean one plus a restore, and on **O** it turns a thin block into a full crit. In the constants of
ADR 0001, the EV-damage gap is:

```
gap = (CRIT_DAMAGE − SUPERSHIELD_RESTORE − 2 × NORMAL_DAMAGE × THIN_BLOCK_MULT) / 4
```

which is **2.5 Balance per pass** against the Supershield, and the condition for it to close is
`2 × NORMAL_DAMAGE × THIN_BLOCK_MULT + SUPERSHIELD_RESTORE > CRIT_DAMAGE`. Every defensive knob in that
inequality is already spent:

- **`SUPERSHIELD_RESTORE`** is capped below `NORMAL_DAMAGE` so Balance still trends down (§4
  convergence). Even pushed to that cap it does not close the gap.
- **`THIN_BLOCK_MULT`** helps on both terms at once, but its ceiling is 1.0 — a thin block doing
  *nothing* — and at that ceiling the gap narrows without closing. Reaching for it also deletes the
  breadth half of the axis we are trying to preserve.
- **`CRIT_DAMAGE`** would work, and it is the 3x ratio ADR 0001 priced the entire read game on.

The structural reason is one sentence: **the axis shape deletes a crit; the Supershield only upgrades an
already-cheap block.** With a crit set at 3x on purpose, deleting one is worth more than perfecting a
block, so no rebalancing of the defensive terms can reverse it. And per
[ADR 0004](0004-shield-guard-crit-vocabulary.md), a clean block and a crit are mutually exclusive in one
pass, so the Supershield cannot be compensated by making its good case *also* offensive by accident.

The Supershield therefore has to earn its keep on **offense** or not at all.

## Decision

**The Supershield pays an offensive bonus as well as its defensive one.** The committed lance: Shield,
Guard and lance all loaded on one axis, so the point lands harder. Four structural calls, no numbers.

1. **In addition to the defensive bonus, not instead of it.** The clean block and the restore stay. A
   player who puts two pieces of coverage on one direction and receives only an *attack* buff is
   nonsense as fiction, and dropping the restore would cost §4's "blocking is a win, not a non-loss."
2. **A flat bonus on the strike, not concentrated on the crit tier.** A crit-only "committed lance"
   was considered and rejected: it needs a much larger multiplier to move the same EV, and it pays out
   only in the rare case, making the Supershield a jackpot shape rather than a line you can choose on
   purpose. Flat keeps it legible.
3. **Additive with proration, not multiplicative.** The strike multiplier is
   `1 + proration_bonus + supershield_bonus`. Additive keeps each system's contribution separable, so
   the post-pass reveal can print them as two lines ("+X% honest, +Y% committed") — CLAUDE.md
   invariant 6 applied to damage rather than to dice. Multiplicative would let the two systems amplify
   each other and get harder to explain on screen than either is alone.
4. **The target is parity, not dominance — and parity against the aim distribution real players
   produce, not against uniform-random aim.** The Supershield does not need to be the top-EV shape. It
   needs to be the *presumed* line, which is what makes the public Guard a pointer at the hidden
   Shield. Presumption comes from the damage motive, not from EV: a rider who wants the biggest hit
   this pass needs both the full hold and the Supershield, so a maxed offense meter implies a
   Supershield implies a bare Crit. That inference works at exact parity, which means we can leave the
   two shapes even and let the read decide — which is the game.

### Why parity is measured against a distribution we do not have yet

The Supershield's entire liability is one bare Crit, so its value moves with how often opponents aim
there. Writing **q** for that frequency, the two shapes' EV-damage difference scales roughly as
`16q` in ADR 0001's constants — sixteen times faster than q itself. Tuned to parity at the uniform
q = 0.25, the Supershield becomes the losing shape as soon as players learn to hunt Crits, which is
exactly the population we are designing for.

So the offensive bonus should be set slightly **ahead** of parity on the uniform-random sim, as a
deliberate hedge — and it must stay under `MAX_BONUS`, so proration remains the loudest system on the
board rather than being demoted by shield placement.

**The number is not set here.** `tools/sim.luau` cannot answer it, because its riders use fixed aim
policies and therefore cannot produce a real q. This is the same blind spot §12 already records for the
hold-fraction distribution, and it is recorded as an open question rather than guessed at.

## Consequences

**Three numbers are now explicitly open, all `combat-axis`:** `THIN_BLOCK_MULT`,
`SUPERSHIELD_RESTORE`, and the size of the Supershield's strike bonus. They are coupled — the first two
shrink the deficit and the third closes what remains — so they should be pinned by one ADR and one sim
run, not three. GAME_SPEC §12 carries them.

**The resolver needs a change it does not currently have.** `strikeDamage(attacker, defender)` reads the
*defender's* supershield state (to pick clean-vs-thin) but never the **attacker's own**. The committed
lance is exactly that missing read. No code ships in this ADR.

**Two things the sim must catch when the numbers land:**

- **The 3–5 pass convergence band.** Raising `THIN_BLOCK_MULT` and `SUPERSHIELD_RESTORE` both slow the
  bleed, and ADR 0001 already recorded that this band has little slack.
- **Mutual Supershield on opposite directions.** Both riders clean block, both take the restore, neither
  is hit, so neither rolls — and Balance goes *up* for both. It is 25% of the Supershield-vs-Supershield
  mirror, it gets worse as the restore rises, and if the Supershield becomes the presumed line it stops
  being a curiosity and becomes a quarter of high-level passes. This is the specific tripwire.

**A risk worth stating plainly.** Making the Supershield attractive makes the Guard a reliable pointer
at the Shield, which is the intent — but it also means the hidden commitment carries less information
the more predictable the book move becomes. The escape hatch is real and already in the numbers: the
axis shape wearing a Supershield's clothes (a long honest hold with the Shield on the Crit instead of
the Guard) punishes the read, and `counter` at 55.5% is that line already scoring well. If tuning ever
makes the Supershield so attractive that the fake stops being worth playing, the mind game collapses
into a script, and that failure would show up as `counter` falling away from `axis` in the standing.

**Accepted cost:** the Supershield stops being a purely defensive concept, so "depth versus breadth" is
no longer a defense-only tradeoff. A future reader comparing the two shapes has to weigh a defensive
liability against an offensive bonus rather than reading one column. That is the price of the axis
having two live poles instead of one.
