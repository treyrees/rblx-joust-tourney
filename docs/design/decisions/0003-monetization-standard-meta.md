---
id: 0003
title: Monetization adopts the platform-standard meta, arranged around the read invariant
date: 2026-07-29
status: accepted
supersedes: []
superseded-by: null
combat-axis: false
---

# 0003 — Monetization adopts the platform-standard meta, arranged around the read invariant

## Context

GAME_SPEC §9 and §12 left the chase's acquisition loop and economy undesigned ("the D1 half of the
game"), and §2 names Untitled Boxing Game as the gold-standard comp. Before that economy can be
designed in numbers, its commercial skeleton needed a structural decision: invent a bespoke
monetization model, or adopt the proven platform meta?

A three-lane comp survey was run (2026-07-29): (1) the standard incremental-progression meta across
top-grossing Roblox titles (PS99, Adopt Me, Bee Swarm, Blox Fruits, Anime Vanguards, Grow a Garden);
(2) UBG's monetization in depth; (3) the wider duel/collection comp set (Rivals, TSB, Blade Ball,
8 Ball Pool, Clash Royale, Marvel Snap, Star Stable, Rival Stars, plus gacha-fairness regulation).
Findings are distilled in [chase/MONETIZATION.md](../chase/MONETIZATION.md).

The survey's two decisive observations:

1. The standard meta is remarkably convergent — the same pass ladder, consumable split, luck-stacked
   gacha, event cadence, and price points recur across every top earner. These patterns have been
   validated on hundreds of millions of players; a bespoke model forfeits that validation for no
   identified benefit.
2. In skill-marketed 1v1 games specifically, there is a bright acceptance line: purchased randomness
   that decides matches (late Clash Royale card levels, Golf Clash clubs, 8 Ball Pool cues)
   permanently corrodes the game's reputation, while identity/odds/expression monetization at equal
   or greater revenue (UBG, Rivals, TSB, Marvel Snap) does not. Joust's invariant 1 ("reads beat
   rarity") is already exactly this line.

## Decision

**Adopt the platform-standard monetization meta wholesale; spend zero novelty budget on
monetization; treat deviation from a proven pattern as the exception requiring justification.**
Concretely:

1. **Structure**: the standard-meta stack — permanent gamepass ladder (multipliers, luck, slots,
   VIP, QoL), consumable dev products (currency, spins, potions, starter pack), multi-currency with
   one sink per currency, ~2-week event cadence, engagement hooks (codes, group, streaks,
   broadcasts), standard R$ price bands.
2. **Format fit**: import UBG's trust stack verbatim — published odds, visible pity (guarantee ≤100),
   rate-up targeting, slots as the scarcity lever, post-match reward wheel, cash-per-spin,
   earned-only ranked prestige.
3. **The Joust arrangement**: horses carry the vertical egg chase (pet-sim economy), lances carry the
   horizontal spin chase (UBG styles), expression is a first-class product line (TSB taunts + Rivals
   cosmetics, televised by the tilt-yard format), antes are the perpetual soft-currency sink
   (8 Ball Pool) with pipes kept separate from power.
4. **The fence**: money never buys information, the matrix, the roll, ranked prestige, or
   undisclosed odds. Rarity's stat edge is bounded by invariant 1 and sim-gated: any rarity→stat
   curve is a combat axis requiring its own `combat-axis: true` ADR citing `tools/sim.luau`.
5. **Sequencing**: nothing in M1; the minimum standard meta (with the full trust stack) at chase v1;
   expression/event/pass/trading layers staged behind it per the scope doctrine.

## Consequences

- The chase's economy design session (§12) now starts from a fixed skeleton: it designs numbers
  (faucet sizing, egg odds, ante ladders, the rarity→stat curve) inside this structure, not the
  structure itself.
- The rarity→stat curve becomes the single riskiest monetization surface and is explicitly deferred
  to a future combat-axis ADR with a sim run; ADR 0001's narrow convergence band (3.32 passes) is
  the cited reason eyeballing is forbidden.
- Trading, breeding, and the battle pass are deferred-not-rejected; the egg system must remain
  trading-compatible (limited exclusives, dupes preserved) so the door stays open.
- `combat-axis: false` on this ADR because it pins structure only; every tuning number it implies is
  explicitly punted to later sim-gated ADRs.
- Monetization funnels join the ported telemetry stack's instrumentation list from chase v1 day one.
