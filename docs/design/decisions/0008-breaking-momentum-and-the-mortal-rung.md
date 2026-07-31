---
id: 0008
title: Breaking — momentum degrades the slice it strikes, down a ladder that ends at mortal
date: 2026-07-30
status: accepted
supersedes: []
superseded-by: null
combat-axis: true
---

# 0008 — Breaking: momentum degrades the slice it strikes, down a ladder that ends at mortal

## Context

The offensive landscape had one currency doing everything. Crit and proration both feed the
same teeter roll on the same pass — they differ in size, not timing — and at ~3.3 passes per
match there is no "later" for a banked payoff to be spent in. Meanwhile the fall histogram
says what the win metric actually is: **nearly 60% of falls happen above 70 Balance**, under
2% below 20. The bottom half of the meter is scenery; damage is not depletion but rate-of-fire
on a weighted coin, and the median match ends on a lost roll the rider was favoured to win.

Two design inputs shaped the fix. GAME_SPEC §5 already names *depleting coverage* as the
favoured escalation mechanism, with being-struck as the implied trigger. And the spur
(ADR 0007) produces a buildup currency — momentum — that owned no benefit at all.

## Decision

1. **A landed strike carrying enough momentum BREAKS the direction it hit.** The struck slice
   of the defender's ring degrades one rung, for the rest of the match:
   `guard → normal → crit → mortal`.
2. **Momentum is the trigger — deliberately not proration.** Proration already owns the damage
   multiplier; giving one currency both jobs oversaturates it. The trigger is also
   slice-agnostic on purpose: crits are the slice-keyed reward, so breaking must not be. The
   run-up allocation thereby becomes the game's now-versus-later — hold for a bigger roll this
   pass, or spur to wreck their ring for the rest of the match — and spurring is the only line
   that pays *when you were wrong* (a blocked strike still breaks; `BLOCKED_BREAKS`).
3. **Breaks anchor to ABSOLUTE directions, never ring offsets.** Anchored to an offset they
   would rotate with the defender and mean nothing; anchored to the world they are a hole the
   defender must steer around — the same footing as the Shield, and a second, growing cost on
   rotation.
4. **The ladder's last rung is MORTAL.** Struck on a mortal slice and uncovered, the rider is
   unhorsed with **no roll drawn at all**. Three breaks on the same world direction are needed
   to expose it, so it stays a rare, telegraphed execution — and it moves the endgame off the
   dice and back onto a read, which is where invariant 1 wants match-deciding power to live.
5. **Balance stays the one-dimensional win metric.** Breaking never touches the number; it
   changes the *conversion rate* of future strikes. Balance is the win condition; breaking is
   the interest rate.

## Consequences

**Cited run** (`tools/sim.luau`, seed 20260729, 8000 matches/pairing, 528,000 matches, shipped
defaults — breaking on, mortal on, `MOMENTUM_THRESHOLD 0.6`): **1.60 slices broken per
match**; mortal ends **0.82%** of strikes; convergence **3.25** passes; the mixed
hold-and-spur line (`splitter`) tops the non-oracle field at **53.0%** with both pure lines
below it — the allocation has an interior optimum, not a corner solution. All three gate
verdicts green.

**The swap was measured, not assumed.** With proration as the trigger (`--swap`), breaking
fires 3.41 times per match because it rides the line a rider takes anyway, the oracle climbs
to 85.3% vs random at the old scale's baseline, and the mixed line collapses to fifth below
both pure lines. The principle, found twice on this branch from opposite sides: **a benefit
attached to the default action is not a decision.** `BREAK.TRIGGER` keeps the swap runnable.

**Supersession of §5's trigger.** This is depleting coverage with the trigger moved from
being-struck to attacker buildup; GAME_SPEC §5's candidate paragraph is replaced by this ADR
rather than sitting alongside it.

**Open, deliberately.** The ladder length (three breaks to mortal) sets mortal's rarity; if it
should be an endgame clock rather than a rarity, shorten the ladder, not the threshold. The
threshold itself (0.6) and the momentum a full six-beat bank represents are coupled to the
spur's feel and belong to the gray box. Depleting-coverage *visuals* (cracked shield art on
the wheel) are presentation and carry no rule.
