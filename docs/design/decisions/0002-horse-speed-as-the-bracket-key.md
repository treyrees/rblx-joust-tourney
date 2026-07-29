---
id: 0002
title: Horse speed is the bracket key, and felt speed is decoupled from the decision window
date: 2026-07-29
status: accepted
supersedes: []
superseded-by: null
combat-axis: false
---

# 0002 — Horse speed is the bracket key, and felt speed is decoupled from the decision window

`combat-axis: false` because this ADR deliberately pins **no** tuning number. It fixes the structure
and one hard constraint; the speed-to-duration numbers it defers will need their own ADR, and that
one will be `combat-axis: true`.

## Context

The design call, as stated: competitive brackets correlate to horse speeds, horse speeds correlate
to horse rarity and type, so higher brackets see jousts at blazing, sonic-like speeds.

This lands on three things the spec had left loose:

- **GAME_SPEC §12** carries an open question: matchmaking by trophy gating vs stakes rooms, "decide
  once".
- **GAME_SPEC §6** lists three horse stats — max Balance, damage soak, recovery. Speed is not among
  them.
- **GAME_SPEC §2** positions the whole game as "UBG's loop with the twitch removed — commit-based
  reads instead of timing execution — so the addressable audience widens (younger/mobile)." That is
  the central audience bet, and speed is the one axis that can quietly undo it.

## Decision

### 1. Speed is a horse stat, and it is the bracket key

Rarity and type determine speed; speed determines which bracket a horse can enter. This resolves
§12's matchmaking question with a third option that neither listed: **horse-tier rooms**. Not trophy
gating, not stakes rooms — the horse you bring is the room you are in.

### 2. Speed is a property of the match, not of the rider

This is the load-bearing corollary, and it is forced rather than chosen. Both riders share one
run-up and one tick (invariant 3). There is only one clock, so there can only be one speed. It
follows that:

- A bracket fixes the speed. Horses **within** a bracket are speed-normalized.
- A horse's rarity buys **access to a bracket**, never an edge inside a match.

Had speed varied per rider inside a match, the faster horse would shrink its opponent's decision
window — which is precisely rarity beating a read, and a direct violation of invariant 1. Making
speed an *access* stat rather than an *in-match* stat is what keeps the chase and the invariant
compatible. Note that this makes speed unlike the other three stats in §6: max Balance, soak and
recovery all apply per-rider, and speed applies per-match.

### 3. Each bracket gets its own lane, and distance scales with speed

**Every bracket is a physically distinct jousting lane, and its length scales with its speed so that
run-up duration is identical in every bracket.** A sonic horse covers a proportionally longer lane.
Speed and distance rise together; time does not move.

This is what makes the whole design safe, and it is a structural guarantee rather than a discipline
to maintain. The obvious way to build "faster brackets" is to keep one lane and shorten the clock,
which would compress the decision window exactly as rank rises and turn the top of the ladder into an
execution game — the precise thing §2 says was removed to widen the audience. Scaling the lane
instead means:

- the decision window is **constant across every bracket**, by construction
- §1's sub-15-second pass cycle holds at every tier, with no per-bracket retuning of the
  intermission / run-up / resolution split
- **speed becomes a pure spectacle axis with no gameplay cost at all**, so it can be pushed as far as
  the presentation can carry without ever trading against the read game

The spectacle is the product; the twitch is not. The lane is the free variable that buys the first
without the second.

### 4. The minimum run-up is a backstop, derived from the ping guard

With §3 in place, run-up duration is constant and this bound should never be approached. It is kept
as a guard against the failure mode §3 exists to prevent: someone later adding a fast bracket by
shortening a lane rather than lengthening it.

Invariant 4 locks aim a few tenths before the tick so the pass can never become a ping war. That
guard is **absolute** — network latency is measured in seconds, not in fractions of a run-up — so a
short enough run-up lets the lock swallow the decision window and the pass stops being a decision:

```
MIN_RUNUP_SECONDS = AIM_LOCK_BEFORE_TICK / AIM_LOCK_MAX_RUNUP_FRACTION
```

With the current 0.3s lock and a 10% ceiling, no bracket may have a run-up under **3 seconds**.
`Constants.PASS.AIM_LOCK_MAX_RUNUP_FRACTION` encodes the ceiling and two unit tests enforce it, so
that failure mode fails the build rather than shipping.

## Consequences

- **§12's matchmaking question is closed** and §6 gains a fourth stat, flagged as the odd one out:
  it is an access stat, not an in-match stat.
- **The resolver needs no changes at all**, which is worth stating explicitly because it was not
  guaranteed. `PassResolver` takes `holdFraction` as a normalized 0–1 value rather than seconds
  (ADR 0001), so the proration curve, the matrix and the teeter roll are already duration-invariant.
  A 3-second run-up and a 9-second run-up produce identical resolution for identical commitments.
  Every per-bracket difference lives in presentation and in the wall-clock length of the run-up.
- **The chase gets a cleaner pitch than "bigger numbers."** A rare horse is not a stat check, it is
  admission to a faster, louder tier of the tournament. That is a better fantasy and it is invariant
  1 compliant by construction rather than by tuning.
- **Speed can no longer be sold as raw power**, which forecloses one obvious monetization line. This
  is the cost of the invariant and it is accepted deliberately.
- **Build cost moves from tuning to art.** Each bracket is a real lane asset at a real length, not a
  parameter on a shared track, and each needs its own presentation ramp — camera, audio, crowd — to
  sell a speed difference the rules do not implement. Cheap tiers will read as reskins. The upside is
  that this is *content* work, which parallelizes and can ship incrementally, rather than *balance*
  work, which cannot.
- **Long lanes at high speed are a rendering and streaming problem**, not a design one, but it is the
  constraint most likely to cap how far the spectacle axis can actually be pushed. Worth a technical
  probe before committing to the top bracket's speed.
- **Ghost traces stay portable across brackets.** A ghost is a guard choice plus an aim trace
  (§2.3, Thing 0). Because duration is constant everywhere, a ghost recorded in any bracket replays
  faithfully in any other, so the ghost pool is one pool rather than one per tier. For the mechanism
  that is meant to solve opponent supply at launch, that matters a great deal.
- **The speed-to-lane-length mapping is still open**, and so is the aim-lock ceiling (10% is a
  starting position, not a measured one). Both need their own `combat-axis: true` ADR. Neither can be
  settled by `tools/sim.luau`: the simulator resolves commitments, and these questions are about
  physical staging and human reaction. That is a playtest instrument, and it does not exist yet.
- **M1 is unaffected.** The gray-box pass (GAME_SPEC §13) ships at a single speed. This ADR exists so
  the bracket structure is decided before anything is built against a contrary assumption, not
  because it is being built now.
