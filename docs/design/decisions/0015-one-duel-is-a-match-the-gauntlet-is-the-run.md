---
id: 0015
title: One duel is a match, the gauntlet is the run, and the stake that escalates is exposure
date: 2026-08-13
status: accepted
supersedes: []
superseded-by: null
combat-axis: false
---

# 0015 — One duel is a match, the gauntlet is the run, and the stake that escalates is exposure

`combat-axis: false`: this pins no combat number. It settles the *wrapper* around matches — how many
duels make a match, what accumulates across them, and what a streak actually risks. The ante values
underneath it are economy numbers and belong to the chase's own session.

## Context

GAME_SPEC §12 has carried an open question since founding: *"Match wrapper: is a 'match' one duel to
unhorse, or best-of-duels? Session rhythm target."* It cannot stay open once the yard is designed,
because the wrapper determines what the mounting block offers, what the pennant marks, what a tourney
brackets, and what the ceremony celebrates.

The pull toward best-of-duels comes from §2's format playbook, item 5: *best-of-N turns RPS into yomi,
because earlier passes teach habits.* That argument is real. It is also already satisfied — a duel is
3–5 passes (ADR 0001's convergence band), and those passes teach habits inside the duel. Best-of-duels
would buy a second helping of the same thing at a steep price: double the ceremony, double the time
cost of a loss, and a slower "one more."

The other half of the question is what a session *accumulates*. Single duels alone are shapeless — a
hundred cheap fights with nothing on top is a training mode, not a game.

## Decision

### 1. A match is one duel, to unhorse

One ante, one purse, one ceremony. Loss costs an ante, never a session (GAME_SPEC §8). §12's match
wrapper question is closed.

### 2. The gauntlet is the run

A gauntlet is a run of consecutive wins on one horse, and it is the session's shape — the "recurring
gauntlet" GAME_SPEC §1 names in its first sentence, made literal.

### 3. It is a scoreboard, not a wager

The purse banks at every win. Nothing is clawed back when a run ends, and there is no cash-out
decision. This is deliberate and it is the one place we decline an obvious mechanic: a bank-or-continue
choice is loss aversion pointed directly at the impulse the entire loop exists to manufacture. We are
not going to spend M1's success criterion on a tension mechanic we do not need.

### 4. What escalates is exposure, not gold

A run raises neither your ante nor your opponents' stats. It raises your **stage**: the pennant holder
rides the center lane, in front of the rail, on the dais side of the yard. The longer the run, the more
people are watching — and watching is scouting (ADR 0014). Difficulty rises as *information*.

Three properties make this the right escalation:

- It is invariant 1 clean. Nobody's dice improve against a champion; they simply know more.
- It is symmetric and free. The counter to being read is available to every player at every rank:
  change, inside the register's rolling window (ADR 0013 §4).
- It needs no system. Standing is stage position, and stage position is a place in a room that already
  exists (ADR 0012 §3). The mechanic is architecture.

### 5. The rematch is the default requeue

The offer at the mounting block is aimed at the rider who just beat you — not the lane, not a random
opponent. The grudge is the strongest requeue in every duel game ever shipped, and it is the middle of
the three timescales in LOBBY.md §1. If they leave, their ghost takes the offer (ADR 0013 §6), so the
rematch always exists.

### 6. The tourney is the periodic form of the same thing

A bracket over ordinary duels, run on the lanes on a cadence, empty seats ghost-filled so it fires on
a quiet server. It is the one time the rail fills by construction, because during a final there is
only one match happening. Update 2, not launch — but the dais gets its place in the yard now.

## Consequences

- **GAME_SPEC §12's match-wrapper question closes**, and the session rhythm falls out of it: a duel is
  about a minute, a gauntlet is as long as you keep winning, and a tourney is the evening's event.
- **"One more" becomes the structural default.** §5 aims the requeue at a person rather than a queue,
  which is the difference between a lobby that ends sessions and one that extends them.
- **Three yomi timescales now each have a home**: passes inside a duel (the pass itself), duels inside
  a grudge (the rematch default), and habits across a career (the register and the tally board). The
  yard is an extension of the pass's mind game rather than a shell around it — which is the whole
  claim this design rests on.
- **A scoreboard with no cash-out has no decision in it**, and that is a real cost, honestly taken. If
  streaks read as weightless in playtest, the fix is more *stage* — the dais, a broadcast, a longer
  pennant — never a wager. Adding risk to the run is the one change that would trade against the cheap
  loss the loop is built on.
- **The center lane punishes winning**, on purpose. A scouted champion loses more often than an
  unscouted one, and that negative feedback is the meta's anti-stagnation valve. Its dial is the
  register's window (ADR 0013 §4), not any stat — if the pressure is too harsh, riders forget faster;
  if it is too weak, they remember longer. No combat number moves either way.
- **The tourney is cheap because it is a bracket over things that already exist.** No new match type,
  no new resolver path, no new opponent source. That is what makes it a reasonable Update 2 item
  rather than a second game.
- **Antes and purses are still undesigned** and stay that way here: the per-bracket ladder is an
  economy question that depends on M1 telemetry about real match length, and it rides with the chase's
  session and the open monetization work (PR #5).
