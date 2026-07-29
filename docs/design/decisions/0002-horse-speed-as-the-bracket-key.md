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

### 3. Felt speed is decoupled from the decision window

High brackets must **look** sonic — camera, field of view, motion blur, sound ramp, crowd reaction,
animation rate — while the time a player actually has to think shrinks far less than proportionally.
Run-up duration is not permitted to scale linearly with visual speed.

Without this, the top of the ladder becomes an execution game, which is the exact thing §2 says was
removed to widen the audience. The spectacle is the product; the twitch is not.

### 4. The minimum run-up is derived from the ping guard, not from taste

Invariant 4 locks aim a few tenths before the tick so the pass can never become a ping war. That
guard is **absolute** — network latency is measured in seconds, not in fractions of a run-up — so as
the run-up shortens, the lock eats a larger share of it. At some speed the lock swallows the decision
window entirely and the pass stops being a decision.

So the fastest possible bracket is bounded by arithmetic:

```
MIN_RUNUP_SECONDS = AIM_LOCK_BEFORE_TICK / AIM_LOCK_MAX_RUNUP_FRACTION
```

With the current 0.3s lock and a 10% ceiling, no bracket may have a run-up under **3 seconds**,
however fast its horses look. `Constants.PASS.AIM_LOCK_MAX_RUNUP_FRACTION` encodes the ceiling and a
unit test enforces it, so a future bracket-speed change cannot quietly violate this by editing a
duration.

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
- **Presentation cost scales with bracket count.** Each tier needs its own ramp — camera, audio,
  crowd — to sell a speed difference that the rules do not implement. Cheap tiers will feel like
  reskins.
- **The speed-to-duration mapping is still open**, and so is the aim-lock ceiling itself (10% is a
  starting position, not a measured one). Both need their own `combat-axis: true` ADR. Neither can be
  settled by `tools/sim.luau`: the simulator resolves commitments, and the question here is how long
  a *human* needs to make one. That is a playtest instrument, and it does not exist yet.
- **M1 is unaffected.** The gray-box pass (GAME_SPEC §13) ships at a single speed. This ADR exists so
  the bracket structure is decided before anything is built against a contrary assumption, not
  because it is being built now.
