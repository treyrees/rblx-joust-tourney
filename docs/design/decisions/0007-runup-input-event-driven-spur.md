---
id: 0007
title: The run-up is event-driven — no inner tick, a beat-gated spur, and a public momentum meter
date: 2026-07-30
status: accepted
supersedes: []
superseded-by: null
combat-axis: false
---

# 0007 — The run-up is event-driven: no inner tick, a beat-gated spur, a public momentum meter

`combat-axis: false`: this ADR pins the *input model* — what the server measures and when — and
no tuning number. The one number it motivates (`BREAK.MOMENTUM_THRESHOLD`) is pinned by
[ADR 0008](0008-breaking-momentum-and-the-mortal-rung.md) with its cited run.

## Context

"One tick per pass" (invariant 3) names the single resolution snapshot, but the run-up leading
to it carries mechanics — the televised aim, the hold fraction, and now the spur. The open
question was the run-up's *clock*: how often is state sampled, and what does the neutral
default do?

Three forces settled it. Sampling hold time into discrete buckets makes the public buildup
meter steppy (ADR 0001 chose linear proration precisely so the meter reads as a dial) and
creates an exploitable boundary at every bucket edge. A scored rhythm input in neutral puts a
timing-execution test into the one state every beginner occupies, in a game whose comp
positioning (§2) is "the loop with the twitch removed". And §7 already spends
"neutral time converts to strike power" as a *kit* identity, which a baseline mechanic must
not burn.

## Decision

1. **No run-up tick.** Aim is event-driven: the client reports `(serverTime, sector)` on
   sector change; the server integrates hold time continuously. Hold fraction is a time
   integral, not a sample count. Any fixed rate that exists is display replication only — a
   networking number, never a tuning number. One authoritative tick per pass (impact), one aim
   lock at `AIM_LOCK_BEFORE_TICK`. Invariants 3 and 4 unchanged.
2. **The spur is beat-gated and forgiving.** An audible hoofbeat paces the run-up; one spur
   may be banked per beat, and any tap anywhere inside the beat counts in full — no
   perfect/good/late grading, and mashing is capped by the gate rather than rewarded. Beat
   *count* is constant across brackets; *tempo* scales with bracket speed (the ADR 0002
   equal-duration logic), and the last beat lands on the aim lock. A scored-timing variant is
   deferred to a post-M1 lance kit, where timing literacy is opt-in at the loadout screen.
3. **Spur only in neutral; the bank persists.** Tapping is available only while aiming
   neutral, and banked momentum survives leaving neutral. The run-up's six seconds are one
   allocation: every second is either held aim (proration) or spurring (momentum), and the
   two currencies buy different things (ADR 0008).
4. **The momentum meter is public**, joining the aim and the offense meter in the televised
   layer. Only the Shield is hidden — the information architecture of §3 gains a meter, not a
   secret.
5. **Skipped beats bank nothing; there is no decay and no miss penalty.** Giving no input
   remains complete, legal play (invariant 5): a rider who never taps is simply today's
   neutral baseline.

## Consequences

- The wheel input gains a diegetic drum: the horse audibly accelerates under a rider who
  spurs, and the meeting point may shift past the lane's midpoint as pure spectacle —
  **never** touching tick timing or either rider's decision window (ADR 0002's constraint).
- Ghost traces (§2.3) grow a third stream: Shield + aim trace + spur events. A ghost's
  commitment is still a short decision list; this keeps it one.
- The spur is the entire supply line for breaking (ADR 0008), so the input's feel is
  load-bearing — it is the first thing the gray box must validate by hand, since no headless
  instrument can.
- The proration curve question stays closed (linear, ADR 0001); this ADR adds no floor and no
  bend. If real players' hold-fraction distribution reopens it (§12), the event-driven
  integral is unaffected — only the curve over it moves.
