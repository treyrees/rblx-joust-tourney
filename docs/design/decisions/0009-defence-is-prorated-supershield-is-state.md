---
id: 0009
title: Defence is prorated like offence, and the Supershield is a state, not a price
date: 2026-07-30
status: accepted
supersedes: [0005]
superseded-by: null
combat-axis: true
---

# 0009 — Defence is prorated like offence, and the Supershield is a state, not a price

## Context

ADR 0005 set out to price the Supershield back into competitiveness with an offensive bonus,
motivated by a measured anomaly: `axis` beating even the clairvoyant `oracle`. That anomaly
was an **instrument artifact** — the oracle maximised damage dealt while ignoring damage
taken, so it walked into crits. Scored as a true best response over both inputs, the oracle
beats `axis` 84%+ and the founding motivation dissolves.

What replaced it was better measurement, and three findings:

1. **There is no parity to find.** Sweeping the offensive bonus 0 → 3.0: the flat bonus is a
   cliff, not a dial (hole card 8.85 at +0.25, 0.52 at +0.5, zero forever after), because an
   unconditional bonus cannot produce mixing — it either fails to clear the bar or clears it
   always. The conditional restore erodes instead of cliffing and arrives at the same place.
   The Shield has one slot: near any crossover the equilibrium does not hedge between
   placements, it **flips**. A bonus everybody takes is not a decision.
2. **The hole card was never "which plan".** It is *which part of my exposure did I leave
   open* — a choice inside a single plan, worth ~one bit in every healthy configuration. The
   Supershield cannot be the source of hidden information at any price: unpriced it is
   ignored, priced it is mandatory, and neither hides anything.
3. **The Supershield was never dead — the payoff was state-blind.** Every equilibrium had been
   solved at 100 vs 100 Balance under a linear payoff that cannot see state. Solved on
   unhorse-probability at real Balance states (`tools/rings.luau --balance`), the Supershield
   takes **0%** of the equilibrium at 90+ Balance and **~100% at 80 and below**, *at the
   shipped restore of 2, with no bonus at all*. It is dormant, then dominant: the match
   changes genre partway down the meter, from poker toward siege, and `SUPERSHIELD_RESTORE`
   is the dial for **when** — not a healing number.

One exploit remained. The Supershield was evaluated purely at the tick, so defence — unlike
offence — did not care whether the aligning aim was *held* or merely arrived at. A rider could
spur the whole run-up for momentum (ADR 0008), snap into alignment at the lock, and collect
breaking AND perfect defence, paying only the damage multiplier.

## Decision

1. **Defence is prorated like offence.** The Supershield is earned only if the aligning aim's
   hold fraction meets `SUPERSHIELD_MIN_HOLD` (0.5). A flick into alignment collects nothing.
   Speed now costs directional power on both halves of the pass: focusing the run-up on
   momentum surrenders the damage multiplier *and* the clean block, while still choosing where
   you end up.
2. **The Supershield ships with no offensive bonus.** `SUPERSHIELD_STRIKE_BONUS` stays 0 (the
   key remains so the sweep instrument can exercise it). Its value is delivered by *state*:
   the mechanic activates on its own exactly when riders are hurt, which is the "pin" it was
   designed to be — a static factor a falling rider is pulled back to.
3. **ADR 0005 is superseded**, on both grounds: its motivating measurement was an artifact,
   and its mechanism (pricing) is structurally unable to produce the mixed equilibrium it
   aimed at. What survives of it is the diagnosis that the Supershield needed a reason to
   exist — the reason turned out to be the Balance meter, not a bonus.

## Consequences

**Cited runs.** Bonus/restore sweeps: `tools/rings.luau --ring CCCNGNNN --ss-bonus {0, 0.25,
0.5, 0.75, 1.0+}` (hole card 8.85 / 8.87 / 0.52 / 0.00 / 0.00) and `--ss-restore {2, 5, 8,
12}` (8.85 / 7.15 / 4.15 / 0.17). State solve: `--balance B B --ss-restore 2` — Supershield
weight 0% at 100 and 90, ~100% at 80/70/60/40/25; asymmetric 25-vs-85 pins the hurt rider at
0.26 bits of Shield entropy while the healthy one keeps 2.99. Double-dip pricing:
`tools/sim.luau` — the `opportunist` (full spur, flick into alignment) at 43.1% with free
defence, **36.5%** with the hold at 0.5; at the shipped defaults (seed 20260729, 8000
matches/pairing) it stands 10th of 12 at **37.9%** while honest buildup lines sit above 50%.

**Costs, stated plainly.** Once the Supershield activates in the low-Balance regime, the hole
card there collapses (~0 bits): the hurt rider becomes readable, pinned to their plate, while
their healthy opponent stays opaque — an information asymmetry that tracks the Balance
asymmetry. That is accepted as the drama of the endgame (the crowd knows where the wounded
knight must hide), not fought with tuning. The depth-versus-breadth "axis" of GAME_SPEC §3 is
resolved rather than balanced: breadth is the healthy game, depth is the hurt game, and the
meter — public, per §4 — tells everyone which game each rider is in.

**The tripwires 0005 posted are inherited** where they still apply: mutual-Supershield
restore inflation is bounded by the restore cap (§4's "Balance only trends down" survives:
the restore fires only on a *struck* clean block), and the convergence band was re-verified
in the ADR 0006 citable run after all of this landed (3.25 passes).
