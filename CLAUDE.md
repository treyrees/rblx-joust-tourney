# CLAUDE.md — Turbo Jousting (working title)

Roblox game: a recurring gauntlet of fast 1v1 jousts. One committed mind-game decision per pass,
resolved in a single tick. Successor project to Grindstone Gladiators (`treyrees/rblx-auto-br`).

**Start every design or gameplay task by reading [docs/design/GAME_SPEC.md](docs/design/GAME_SPEC.md)**
— the canonical design. This file owns only invariants, conventions, and commands.

## Invariants (do not violate)

1. **Reads beat rarity.** Reads resolve deterministically; survival resolves stochastically; rarity
   loads the dice — and a correct read always beats a rarer horse. (GAME_SPEC §4.)
2. **Four directions are the core gameplay basis, neutral is the default.** The wheel is played at
   eight notches (ADR 0006), but in/out/up/down remain the words; archetype identity hooks neutral
   or the UI layer. (GAME_SPEC §7.)
3. **One tick per pass, simultaneous resolution.** Both commitments snapshot, resolve at once, no
   order bias. Server-authoritative; client is display-only during resolution. The run-up has no
   inner tick — aim is event-driven, hold is a time integral (ADR 0007).
4. **Aim state is quantized** to the eight notches (+ neutral). Animation may be smooth; the televised
   state is always discrete. Aim locks shortly before the tick — no ping wars.
5. **Beginner-ignorable depth.** Shield somewhere + aim somewhere is complete, legal play — plus an
   optional spur tap; everything else (ring, Guard, Crit, breaking) is derived (ADR 0004/0006/0008,
   [docs/design/GLOSSARY.md](docs/design/GLOSSARY.md)). No layer (signaling, proration, archetypes)
   may become required literacy at low ranks.
6. **RNG is always visible.** Odds on screen before the roll; every loss decomposes to "read" or
   "roll." No mystery randomness, ever.
7. **The matrix outweighs the dice — and never replaces them.** Both bounds gate: a perfect read
   must beat random wide (≥75%), and must NOT beat it so wide that information swallows the dice
   (≤93%) — several candidate rings passed every other check while a perfect reader never lost,
   which kills §4's "anyone can win any pass". If tuning ever makes neutral-camping, pure
   slot-machine play, *or pure clairvoyance* optimal, that is a bug in the numbers, not a meta.
8. **Scope doctrine: three things** — the pass, the loop, the chase (+ ghost-first opponent supply).
   New systems must justify why they aren't post-launch. (GAME_SPEC §10.)
9. **The hole card stays live, at equilibrium.** The hidden Shield must be worth real Balance
   between *good* players, and the televised aim must narrow it to roughly a coin flip — never to
   certainty, never to nothing (~1 bit survives; ADR 0006/0010). The secret is structural: the
   exposure is wider than the plate, so something is always bare. Checked by
   `tools/rings.luau --verify`, because the round robin **cannot** see this — it once green-lit a
   configuration whose equilibrium crit rate was 0.0%. Claims about the pass are settled on both
   instruments or not at all.
10. **No benefit attaches to the default action.** A reward earned by the line a player takes anyway
    is a rebate, not a decision — every bonus must cost a deviation (the Supershield costs a held
    alignment, breaking costs spurred run-up time, proration costs televised commitment). Found
    twice, from opposite directions, in ADR 0008/0009. When a mechanic is dead or mandatory, look
    here first before reaching for its price.

## Commands

```bash
rojo serve                       # sync default.project.json → src/ into Studio
lune run tests/run.luau          # unit tests (headless, no Studio — the robloxenv shim)
lune run tools/design-lint.luau  # design-doc drift / link / ADR checker
lune run tools/sim.luau          # the round robin — whole matches, scripted riders
lune run tools/rings.luau --verify  # the equilibrium gate — what scripted riders can't see (inv. 9)
```

All four run in CI on every PR and push to `main` (`.github/workflows/gates.yml`), and again at
session start via `.claude/hooks/session-start.sh` (remote sessions). CI is the one that gates.
The last two are one gate with two halves — complementary blind spots; combat-axis ADRs cite both.
Rojo maps `src/{server,client,gui,shared}` → ServerScriptService / StarterPlayerScripts / StarterGui /
ReplicatedStorage.Shared.

## How we work

**[docs/design/WORKFLOW.md](docs/design/WORKFLOW.md)** — the doc↔code↔ADR stewardship loop + the two
gates, carried over from the predecessor repo where it was proven across 200+ ADRs. Follow it on
every change. Doc conventions (front-matter, ADR format): [docs/design/README.md](docs/design/README.md).

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
