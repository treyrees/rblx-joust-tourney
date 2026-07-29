# CLAUDE.md — Joust (working title)

Roblox game: a recurring gauntlet of fast 1v1 jousts. One committed mind-game decision per pass,
resolved in a single tick. Successor project to Grindstone Gladiators (`treyrees/rblx-auto-br`).

**Start every design or gameplay task by reading [docs/design/GAME_SPEC.md](docs/design/GAME_SPEC.md)**
— the canonical design. This file owns only invariants, conventions, and commands.

## Invariants (do not violate)

1. **Reads beat rarity.** Reads resolve deterministically; survival resolves stochastically; rarity
   loads the dice — and a correct read always beats a rarer horse. (GAME_SPEC §4.)
2. **Four directions are the rules; neutral is the exceptions slot.** The directional game is never
   gimmicked; archetype identity hooks neutral or the UI layer. (GAME_SPEC §7.)
3. **One tick per pass, simultaneous resolution.** Both commitments snapshot, resolve at once, no
   order bias. Server-authoritative; client is display-only during resolution.
4. **Aim state is quantized** to the four sectors (+ neutral). Animation may be smooth; the televised
   state is always discrete. Aim locks shortly before the tick — no ping wars.
5. **Beginner-ignorable depth.** Guard somewhere + aim somewhere is complete, legal play. No layer
   (signaling, proration, archetypes) may become required literacy at low ranks.
6. **RNG is always visible.** Odds on screen before the roll; every loss decomposes to "read" or
   "roll." No mystery randomness, ever.
7. **The matrix outweighs the dice on average.** If tuning ever makes neutral-camping or pure
   slot-machine play optimal, that is a bug in the numbers, not a meta.
8. **Scope doctrine: three things** — the pass, the loop, the chase (+ ghost-first opponent supply).
   New systems must justify why they aren't post-launch. (GAME_SPEC §10.)

## Conventions

- Luau, `--!strict` on new modules; OOP via metatables (`Module.new()`).
- Constants are the single source of truth — never hardcode tuning numbers.
- Headless-first: every pure system (matrix resolution, Balance math, proration, ghost replay) gets
  Lune unit tests before it gets a UI. Port the test harness from rblx-auto-br.
- Design lives in `docs/design/`; decisions are append-only ADRs in `docs/design/decisions/`
  (numbered from 0001). Meaningful design calls get an ADR — same WORKFLOW discipline as the
  predecessor repo.
- No em dashes in player-facing copy.
- Mobile-first UI; the wheel input is the primary control surface.

## Carry-over

Port list and adaptation notes: GAME_SPEC §11. Source repo: `treyrees/rblx-auto-br` (add via
`add_repo` when needed). Lift the telemetry/retention stack rather than rewriting it — it is
unit-tested and game-agnostic.

## Current milestone

**M1: the gray-box pass, and nothing else** (GAME_SPEC §13). Success = "one more round" behavior +
unprompted bluffing within ~10 matches.
