---
id: 0006
title: The ring is data, it is chiral, and it is played on eight notches — CCCNGNNN
date: 2026-07-30
status: accepted
supersedes: []
superseded-by: null
combat-axis: true
---

# 0006 — The ring is data, it is chiral, and it is played on eight notches: CCCNGNNN

## Context

The pass's core relation — what happens at each angular offset from a rider's own aim — was
hardcoded: Guard opposite the aim, Crit identically the aim. Making it a table
(`Constants.RING`) and sweeping the whole space with an equilibrium solver
(`tools/rings.luau`, fictitious play over every commitment, exploitability-checked) found that
the shipped relation was structurally dead between good players, in a way no damage number
could reach:

- **Equilibrium crit rate 0.1%.** The 3x tier existed only to punish players who had not
  solved the game yet.
- **The hidden Shield was worth 0.02 Balance** on top of the televised aim. The hole card —
  the third layer of GAME_SPEC §3's information architecture — carried nothing.

Two structural facts explain it, and both are properties of the ring's *shape*, not its numbers:

1. **Symmetric rings can only trade.** A crit is mutual exactly when the crit set contains an
   offset and its negation. Offsets 0 and half-way are their own negations, so a crit there is
   always mutual; only a **chiral** ring — one perpendicular marked, not the other — can
   produce a crit that *wins* rather than exchanges.
2. **One crit notch and one Shield means the Shield plugs it** and the crit never fires. The
   hole card is the *gap in coverage*: it exists only when the exposure is wider than the
   Shield, so the defender must choose which part to leave bare. That choice measured at
   almost exactly **one bit** in every healthy configuration — the televised aim narrows the
   Shield to a coin flip and stops.

A third finding disqualified the seductive corner: rings with read-edge above ~21 Balance are
**read-dominant** (a perfect reader beats random 97%+), which kills §4's "anyone can win any
pass". High information value and a live dice game trade off, and the trade has a cliff.

Eight notches instead of four was examined on its own terms. Held to the same geometry, the
notch count moves no crit rate; what it does is relocate information from the hidden Shield to
the televised aim (hole card roughly halves under uniform doubling), and it doubles the
equilibrium's width. Eight notches earn their keep **only** via wedge widths four cannot
express — an odd-width crit wedge — not via granularity, which is redundant by inspection
(half the new relative offsets produce no outcome pair the four-grid lacks). The wedge that
needs eight is also the wedge that fixes the game.

## Decision

1. **The ring is data.** `Constants.RING` maps notch offsets (from the rider's own aim, in
   cycle order) to `crit | guard | normal`. `Constants.CYCLE` fixes the rotational order **in
   self-relative labels** — up, up-in, in, down-in, down, down-out, out, up-out — so "one
   notch around" is well defined for both riders of a mirrored pass without any left/right
   handedness. The four cardinal directions remain the vocabulary the design speaks
   (invariant 2); the diagonals are granularity.
2. **Eight notches, ring `CCCNGNNN`.** Exposed at the notch you strike with and for two more
   notches sweeping toward the barrier side (135°); a single 45° Guard **directly opposite**
   the aim (polarization intact — one input still carries attack and defense); the remaining
   half ordinary. Chiral: the danger hangs off one side of your spear.
3. **The Shield is a two-notch (90°) plate.** The same quarter-circle it covered at four
   notches — the resolution change is not allowed to be a stealth Shield nerf. The governing
   ratio is Shield to *exposure*: two of three crit notches coverable, one always bare, and
   which one is the hole card.
4. **The damage scale is re-pinned 6/18 → 5/15.** The 3x crit:normal ratio (ADR 0001) is
   untouched; the scale drops because crits now actually fire at equilibrium (~21.5% of
   strikes) and the old scale priced a crit economy that did not exist — at 6/18 convergence
   lands at 2.98 passes, under §4's 3–5 band.

Guard-opposite was confirmed as a *balance* constraint, not only a readability preference:
walking the Guard around the ring, only the positions adjacent-past-the-wedge (+3) and
opposite (+4) stay healthy; every other position tips into read-dominance. Intuition and
equilibrium point at the same notch.

## Consequences

**Cited runs.** `tools/sim.luau` (seed 20260729, 8000 matches/pairing, 528,000 matches, the
new defaults): convergence **3.25** passes, read edge **87.2%**, long-shot falls **33.6%**,
camper **12 of 12** — all verdicts green. `tools/rings.luau --ring CCCNGNNN` (200,000 FP
iterations, exploitability 0.03): hole card **8.12 Balance**, Shield entropy **3.00 bits
before the aim is seen, 1.00 after**, equilibrium crit rate 43.7%, mutual-crit share 14.1%,
top equilibrium weight 12.6%.

**What was given up.** "You are exposed exactly where you strike" becomes "…and one turn
around" — the best sentence in the spec gets a clause. Crits fire less often per strike than
the best four-notch candidate (the cost of the wedge that keeps the hole card alive). The
mirror image of `CCCNGNNN` is the same game with the handedness flipped; which hand ships is
an art/UI call with no balance content.

**What this opens.** Rings are now a *content axis*: a collectible ring is four-to-eight cells
of data and a texture, self-documenting on the item icon — a better-behaved archetype slot
than §7's neutral-kits, with the constraint that rings must be public at the loadout. N rings
is N² matchups: the launch set stays small. One ring ships in M1.

**Instrument note.** The equilibrium solver sees a single pass at fixed Balance; the round
robin sees whole matches with scripted riders. Each has a blind spot the other covers (the
gate suite alone green-lit a structurally dead configuration during this investigation —
equilibrium metrics catch what scripted strategies cannot). Combat-axis ADRs on this surface
should cite both.
