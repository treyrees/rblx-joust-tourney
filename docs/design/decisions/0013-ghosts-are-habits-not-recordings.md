---
id: 0013
title: Opponent supply is a habit register — a ghost is a habit, not a recording, and the yard has no fake people
date: 2026-08-13
status: accepted
supersedes: []
superseded-by: null
combat-axis: false
---

# 0013 — Opponent supply is a habit register — a ghost is a habit, not a recording, and the yard has no fake people

`combat-axis: false`: this pins no damage, ring or roll number. It does define the thing
`tools/sim.luau` will eventually be pointed at (§5), which is the opposite of a tuning change — it
makes a future combat-axis question measurable rather than pinning one now.

## Context

Ghost-first opponent supply is **Thing 0** (GAME_SPEC §2.3, §10): the population cheat code that turns
launch-day matchmaking from a risk into a solved problem. The spec describes a ghost as "just a Shield
choice plus an aim trace, mechanically indistinguishable from a live opponent," and ADR 0002 noted the
useful corollary that constant run-up duration makes such traces portable across brackets.

Designing the yard around it exposed that the naive reading does not survive contact:

- **A recorded pass is not a strategy.** The recording was committed against a *different* opponent's
  televised aim, at different Balance meters, with different breaks on the ring. Replayed literally, a
  ghost either reacts to a pass nobody is riding, or — worse — it is a tape, and a tape is memorizable.
  Beat it once, beat it forever, and Thing 0's opponents become a solved puzzle instead of a
  population.
- **The honesty question has to be answered out loud.** Every comp faces it and most quietly ship bots
  dressed as strangers. We have already committed to the opposite posture on randomness (invariant 6,
  odds printed on the screen before the roll), and that posture is worth more than the illusion.
- **Cold start.** A brand-new rider has no habits. Something must ride at 4am on day one.

## Decision

### 1. A ghost is a fitted habit table, sampled fresh at every commit

Not a replay. The register stores, per rider, frequencies over: defensive **shape** (forward / back /
deep), **aim family**, **hold fraction**, and **spur rate** — each conditioned on public state (own
Balance band, opponent's Balance band, pass index within the duel). At each commitment the ghost
samples from that distribution.

It therefore reacts to the pass actually being ridden, it cannot be memorized, and beating it teaches
something *true* about the rider it was fitted from. That last property is what makes scouting
(ADR 0014) coherent: the ghost and the tally board are two views of one artifact.

### 2. A ghost commits blind

No ghost ever conditions on the live rider's hidden Shield, and every ghost resolves through the same
`PassResolver` as a human. A ghost that peeks is not a hard opponent, it is a broken one — and it
would quietly void the hole card, which invariant 9 exists to keep alive.

### 3. Two honest categories, and no third

- **Ghosts** are attributed: a name, colors, heraldry, and a visible mark that this is a ghost. Whose
  habits you are riding against is *told*, not hidden — facing a friend's ghost or the champion's
  ghost is a feature.
- **House riders** are the yard's own named personalities: the scripted riders M1 already needs, kept
  forever as the tutorial ladder and the quintain's stablemates. Visibly not people.

**We never dress a bot as a stranger.** A game whose brand promise is that the dice are printed on the
screen does not get to lie about who is on the other horse, and the honest version is the better
product anyway: an attributed ghost is a social object, a fake human is one forum post away from being
the only thing anyone says about us.

### 4. A rolling window, so reinvention always works

The register remembers `LOBBY.HABIT_WINDOW_PASSES`. A rider's ghost is never older than their recent
play, and a rider who changes stops being the rider their ghost was fitted from. Being unreadable is
therefore a thing you keep doing, not a thing you achieved once.

### 5. Fielding threshold, doubling as the publicity threshold

A rider's ghost begins riding once the register holds `LOBBY.GHOST_MIN_PASSES` of them — the same
moment their tally-board record goes public (ADR 0014). One threshold, both consequences: **you become
studyable exactly when you become worth studying.**

### 6. Refusal routes to the ghost

A glove can always be declined at no cost, and a declined or expired challenge sends the challenger
against that rider's ghost instead. Both halves matter and only the ghost makes both true at once:
**nobody can duck you, and nobody can be cornered.** Grudges always resolve; the challenge system is
not a harassment surface.

### 7. The register is the sim's rider interface

The habit table is pure data and the sampling policy is a pure function with injected RNG, so it lives
in `src/shared` under the purity seam — which is *the same interface* `tools/sim.luau`'s scripted
riders already implement. Opponent supply and the tuning instrument are one abstraction.

## Consequences

- **One artifact, three jobs.** The register supplies opponents, fills the tally board, and is the
  matchup data the creator/meta layer needs (GAME_SPEC §2 wants charts that fit in a thumbnail).
  Three features that would otherwise each need their own data pipeline share one small table.
- **Ghost quality becomes a headless test.** Because of §7, a new ghost policy can be round-robined
  against the existing scripted rider set before it reaches a player, and a regression in ghost play
  is caught by the same instrument that gates the matrix. This is the strongest argument for the whole
  decision and it falls straight out of `src/shared` being pure.
- **GAME_SPEC §2.3's "a Shield choice plus an aim trace" is refined, not discarded.** That is what gets
  *recorded*; the fit is what gets *ridden*. ADR 0002's portability consequence survives intact — a
  distribution over normalized hold fractions is, if anything, more bracket-portable than a trace.
- **A habit model is a caricature.** It plays the population's read of you, not your read of the
  person in front of it, so ghost passes are systematically more readable than live ones. Accepted,
  and it is exactly why the grudge (ADR 0015) and the tourney exist: live opponents stay the top of
  the ladder, and the yard should feel that way.
- **A ghost can outperform its rider on a given night** — it samples habits without fatigue or tilt.
  Flagged as an open question in LOBBY.md §12 rather than pre-solved; if it proves true and it makes
  standing feel cheap, the dial is the conditioning set, not a stat.
- **Cold start is covered without lying**: below the threshold you meet house riders, who are labeled.
  The cost is that the very first sessions are against personalities rather than people, which is also
  the correct tutorial.
- **Fallback exists.** If habit fitting reads as noise or as a wall, the yard still functions on house
  riders alone — M1 ships those regardless — and ghosts can be reduced to a labeled subset of
  personalities. Thing 0 does not depend on the fit being good, only on something honest being
  mounted.
- **Privacy and moderation surface.** Habit tables are behavioral records attached to a name. They
  contain nothing a spectator could not collect at the rail by hand, which is the line that keeps them
  publishable — but any future field added to the table must clear that same test before it ships.
