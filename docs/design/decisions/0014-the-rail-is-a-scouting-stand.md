---
id: 0014
title: The rail is a scouting stand, and information parity is absolute
date: 2026-08-13
status: accepted
supersedes: []
superseded-by: null
combat-axis: false
---

# 0014 — The rail is a scouting stand, and information parity is absolute

`combat-axis: false`: no tuning number here. It constrains what the *server may send to whom*, which
is an authority rule, and it gives spectating a purpose, which is a loop rule. Neither is measurable
by `tools/sim.luau`, whose riders resolve commitments in a vacuum and have no rail to stand at.

## Context

GAME_SPEC §1 and §8 inherited a line from Untitled Boxing Game: *the lobby is a tilt-yard where
waiting is spectating*. It is the comp's masterstroke and it is load-bearing for their lobby's
atmosphere. Designing the yard against our own supply model breaks it:

**Ghost-first supply deletes the wait.** Nobody queues for more than `LOBBY.GHOST_FILL_SECONDS`, so
there is no captive audience, so there is no crowd — the comp gets its rail for free from a friction
we deliberately removed. "Waiting is spectating" is true of UBG and false of us, and shipping the line
unexamined would have produced a beautiful empty rail.

A second thing surfaced at the same time, and it is a live exploit rather than a design gap. The
natural way to implement spectating is to send the observer full match state, "because they are only
watching." That hands a friend on the rail the opponent's hidden Shield, over voice chat, before
impact — and the hole card is the entire pass (invariant 9).

## Decision

### 1. Parity is absolute: the rail sees what the opponent sees, never more

No spectator client is ever sent a value the opponent's client does not hold at the same moment. The
Shield reaches the rail **at impact**, together with the opponent, never a frame earlier. This is
invariant 3's server authority extended to a third party, and it is promoted to
[CLAUDE.md invariant 11](../../../CLAUDE.md) because it constrains every observer surface we will ever
build: replays, streams, private servers, tourney broadcast, party views, and any developer-convenience
"spectate" affordance.

The exploit it forecloses is structural rather than policed. There is no rail relay to detect, report
or ban, because there is nothing on the rail to relay.

### 2. Spectating is scouting — the rail's purpose is information, not patience

With the wait gone, the rail needs a reason to exist, and this game has one no other lobby can copy:
in a read-based duel, knowing what a specific rider does with an 80 Balance meter and a broken up-side
is the most valuable thing anybody owns. **The pass you are watching is a pass you are not riding**,
so the rail is where reads are bought with time.

Invariant 10 is satisfied structurally: watching is a deviation from the default line (ride again),
and it is paid for in the currency the game is actually about.

### 3. Being watched is public

A rider can see their rail — who is on it and how many. This is not a courtesy, it is the second half
of the mechanic: playing to a crowd becomes a legal bluff (throw a pattern for three passes while a
known rival watches, then break it when they throw the glove). Information flows both ways or it is
not a mind game, it is surveillance.

### 4. The tally board is free, public and identical for everyone

Per-rider rates, recent commitment traces, per-matchup numbers, short replays of the last
`LOBBY.GHOST_MIN_PASSES` passes. Never a purchase, never a tier, never an observer view with extra
columns. Information is the one thing this game cannot sell without becoming a different game
(invariant 1), and it is the fence line the monetization work already draws from the other side.

### 5. Publicity and ghosting share one threshold

A rider's record goes public at exactly the moment their ghost begins to ride (ADR 0013 §5). **Fame
costs privacy** — play enough to be worth studying and you become studyable — and the counter is free
and available to everyone: change, inside the register's rolling window.

## Consequences

- **The rail survives the loss of the wait**, with a better reason than it had. This also makes it the
  one lobby feature that is genuinely ours: scouting is only interesting because the pass is a read
  game, so no amount of copying our lobby produces it without copying the pass.
- **Standing becomes self-limiting** (ADR 0015 §3): the better you do, the more you are watched, the
  more is known. Difficulty rises as information rather than as stats, so the meta's anti-stagnation
  pressure costs no tuning and touches invariant 1 not at all.
- **A future spectator feature is now a constrained problem.** Anything that would show an observer
  more than an opponent — a coaching view, an analyst overlay, a paid "insights" tier — is dead on
  arrival, and dead early, rather than after it is built.
- **Scouting is optional depth, which brushes invariant 5.** A rail-literate player does know more
  than a beginner who never visits it. Two things keep it inside the invariant: the data is free and
  symmetric, so nothing is gated behind knowing to look; and the counter to being read is available to
  everyone, including the beginner, because changing your habits requires no literacy at all. Worth
  re-checking in playtest — if scouting turns into required literacy at low ranks, the fix is to shrink
  what the board publishes, not to hide it from some players.
- **Replays and clips inherit the parity rule**, which is a content constraint worth knowing early: a
  replay cannot reveal the Shield before the moment the pass did. That is also better content — the
  reveal beat is the clip.
- **Rail wagering is deferred and now has a gate to clear.** Betting on the joust in front of you is
  thematically perfect and it is information-adjacent, so it must clear §1 and §4 before it is
  designed at all (LOBBY.md §12).
