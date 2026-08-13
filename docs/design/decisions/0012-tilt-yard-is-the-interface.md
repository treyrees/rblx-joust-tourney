---
id: 0012
title: The tilt-yard is the interface — one room, and the walk is the price of changing your mind
date: 2026-08-13
status: accepted
supersedes: []
superseded-by: null
combat-axis: false
---

# 0012 — The tilt-yard is the interface — one room, and the walk is the price of changing your mind

`combat-axis: false`: nothing here touches the matrix, the ring, proration or the roll. It pins
timing numbers for the *loop* (arrival, ceremony, re-entry), which no combat instrument can speak to —
`tools/sim.luau` resolves commitments and has no opinion about how long a player spends not riding.

## Context

The pass is designed, implemented and gated. Everything around it was a single paragraph
(GAME_SPEC §8) and one line of scope doctrine ("the loop — mostly staging, not systems"). That is
enough to keep building the pass against, and not enough to build a lobby against, because the two
standard ways to build a Roblox lobby fail in opposite directions:

- **A menu bolted to a world.** The world is a screensaver, every mechanic lives behind a button, and
  nothing that happens in the space means anything. Cheap, fast, and it throws away the one asset a
  jousting game starts with — a tilt-yard is a *place* everybody already understands.
- **A world that makes you walk to play.** Diegetic charm bought with the loop's own budget. On mobile
  this is fatal: GAME_SPEC §1 targets a sub-15-second pass, and a 20-second walk to a stable is longer
  than the product.

Two more constraints bear on the shape. M1's success criterion (a) is behavioral — testers
voluntarily say "one more" — which makes re-entry latency a measured quantity rather than a matter of
taste. And ADR 0002 already settled brackets as horse-tier rooms with one physical lane each, so the
yard has a spine before anyone draws it.

## Decision

### 1. Every mechanic is somewhere; interaction is screen-space

Nothing exists in a menu that does not exist in the world. Each station in
[loop/LOBBY.md](../loop/LOBBY.md) §2 is a real place, and approaching it opens an ordinary UI panel.
**The world carries the map and the theater; the panel carries the speed.** We do not scroll a stable
through a keyhole for immersion's sake, and we do not ship a hub whose geography means nothing.

### 2. The walk is the price of changing your mind, never the price of playing again

**Playing again is always zero-walk. Changing your loadout costs a trip to the pavilion.** Friction is
placed on reconsideration and never on repetition.

This is the inverse of the usual lobby, where the store is in your face and the rematch is three taps
deep, and it buys three things at once: the "one more" impulse is protected, the horse choice reads as
a commitment rather than a dropdown, and — because the horse is the bracket (ADR 0002) — changing
lanes is a thing you physically do, which keeps lane populations legible and stable.

### 3. The yard is one room

Every station visible from the mounting block. No corridors, no second floor, no zones. This is a hard
constraint rather than a style preference: it is what makes §4's and §5's second budgets achievable at
all, and a hub world with districts spends them on walking.

### 4. Arrival: the first pass comes before the yard

From spawn to a new player's first commitment: `LOBBY.FIRST_PASS_SECONDS` — less than one pass cycle.
The gate faces lane one, a house rider is already mounted, and nothing is read, chosen or waited for
first. **The pass explains the yard, never the reverse**; the yard introduces itself on the walk back
from a fight the player has already had. This is legal because two inputs are complete play
(invariant 5), so there is nothing a first-timer must be told before their first commit.

### 5. The re-mount contract

You get up where you fell, and the next pass is offered where you land. From unhorse to the next
commitment being live: `LOBBY.REMOUNT_SECONDS`, ceremony (`LOBBY.CEREMONY_SECONDS`) included, with no
walk, no menu, no loading screen, no lobby return. The whole between-match interval must be shorter
than a single pass, which is asserted in `tests/Constants.spec.luau` rather than remembered.

### 6. Practice exists, and it pays nothing

The quintain is an ante-free lane that awards no gold, no standing and no drops. Practice buys
knowledge, which is the only currency in this game a bot cannot farm. A quintain that paid would be
the optimal way to spend a risk-free session, which is invariant 10 read backwards.

## Consequences

- **The numbers land in `Constants.LOBBY`** and four of them are cross-checked against the pass cycle
  in `tests/Constants.spec.luau`. A future "just a two-second flourish" on the ceremony fails the
  build instead of quietly eating the loop.
- **M1 gains exactly one yard mechanic**: the re-mount contract (§5). GAME_SPEC §13 says the gray-box
  pass and nothing else; this is the single exception and it earns it, because success criterion (a)
  is a measurement of precisely this budget. Everything else in LOBBY.md is designed-not-built.
- **The yard can never grow by adding rooms.** New mechanics must earn a station inside the one room
  or replace one that is there. That is the intended cost — it forces the same "three things" scope
  pressure onto the lobby that GAME_SPEC §10 puts on the game.
- **The pavilion trip is a deliberate tax** of a few seconds on loadout changes. If telemetry later
  shows loadout churn cratering, the fix is to move the pavilion nearer, never to add a menu — the
  moment loadout is one tap from the mounting block, the store is one tap from the loop, and the
  distinction §2 draws stops existing.
- **Art and build cost concentrate**, which is good: one room, built well, rather than a campus. The
  dais gets a place before the tourney exists (LOBBY.md §7.4), because retrofitting a stage into a
  finished lobby is the expensive kind of change.
- **`FIRST_PASS_SECONDS` at 12 is a design ceiling, not a measurement.** It forces the gate adjacent to
  lane one and leaves roughly nine seconds for spawn, mount and pairing after ghost-fill's share. If a
  real build cannot hit it, the correct response is to move the gate, not to raise the number — the
  number is the promise that a first session begins with a joust rather than with a lobby tour.
