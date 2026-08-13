---
maps-to: [src/shared/Types.luau, src/shared/Constants.luau, src/shared/PassResolver.luau, default.project.json, tests/lib/robloxenv.luau, tools/gates.sh]
decisions: [0011]
owner: trey
updated: 2026-08-13
---

# ARCHITECTURE — how the code is laid out, and which seams are load-bearing

> `docs/design/` had a canonical doc for the game and none for the codebase, while three of the four
> `src/` directories were empty. This is the doc M1 gets built against: where a module goes, what it
> is allowed to touch, and which of those rules are checked by machine rather than remembered.
> The design itself lives in [GAME_SPEC.md](GAME_SPEC.md); the stewardship loop in
> [WORKFLOW.md](WORKFLOW.md); this is the third leg.

## The four mounts

`default.project.json` maps four directories, and `tests/lib/robloxenv.luau` mirrors that mapping
exactly so every one of them is testable headlessly. The mirror is asserted, not assumed
(`tests/Purity.spec.luau`) — `src/client` and `src/gui` were absent from the shim for a while, which
quietly exempted half the tree from the headless-first rule.

| Directory | Roblox home | Owns | May require |
|---|---|---|---|
| `src/shared` | `ReplicatedStorage.Shared` | numbers, rules, pure resolution | `src/shared` only |
| `src/server` | `ServerScriptService` | authority: match state, the tick, persistence | `src/shared` |
| `src/client` | `StarterPlayer.StarterPlayerScripts` | input, prediction, presentation | `src/shared` |
| `src/gui` | `StarterGui` | screens and widgets | `src/shared` |

The arrows only ever point *down* into `shared`. Server and client never require each other — they
cannot; they are different machines. That is why anything both of them need is, by definition, a
shared module.

## The one seam that is genuinely load-bearing: `src/shared` is pure

Shared modules are **engine-free and deterministic**: no `GetService`, no `Instance.new`, no
`math.random`, no clock read, no yield. This is not tidiness. Three separate things rest on it:

1. **The instruments.** `tools/sim.luau` runs `PassResolver` through half a million matches and
   `tools/rings.luau` enumerates its full payoff matrix. Neither has an engine. The moment shared
   touches one, both stop being able to load the thing they exist to measure — and they will not say
   so, they will simply stop being about the shipped game.
2. **[CLAUDE.md invariant 3](../../CLAUDE.md).** One tick, simultaneous resolution, no order bias. A
   yield inside resolution spreads the pass across frames and the invariant is gone.
3. **[CLAUDE.md invariant 6](../../CLAUDE.md).** The only randomness is the teeter roll, and the
   *caller* injects it — which is what lets the UI print the odds before the dice land, and what
   makes a seeded sim run reproducible. Ambient `math.random` inside shared makes the sim's fixed
   seed a fiction.

`tests/Purity.spec.luau` enforces this per module, with a deliberate escape hatch: a module may
declare `-- @impure: <reason>` in its header. Use it when the reason is real; the point is that it is
greppable and reviewable, not that it is impossible.

## Where M1's pieces go

[GAME_SPEC §13](GAME_SPEC.md) scopes M1 to the gray-box pass and nothing else. Its parts split across
the mounts like this, and the split is what keeps the pure core testable:

- **`src/shared`** — `Types` (the vocabulary), `Constants` (every tuning number), `PassResolver` (the
  matrix, proration, breaking, the teeter). *Already exists; this is the finished part of M1.*
  Wheel-angle → notch quantization belongs here too: it is pure arithmetic, and both the client
  (to snap the wheel) and the server (to validate what it is told) need the identical function.
- **`src/server`** — the match loop: intermission → run-up → the aim lock → the tick. It owns the
  Shield (the hole card never leaves the server until impact), it owns the clock, and it is the only
  thing that ever calls `PassResolver.resolve`.
- **`src/client`** — the wheel, the spur taps, the two public meters. It *displays* state and
  *sends* intent. It never decides an outcome; during resolution it is a television.
- **`src/gui`** — the meters, the odds readout, the post-pass reveal.

**Server-authoritative, client display-only during resolution** (CLAUDE.md invariant 3) has a
concrete consequence worth stating once: the client may show anything it likes about its *own*
commitment, but the opponent's Shield does not exist on the client until the server sends the
reveal. A client that has been told the hole card early has no hole card.

## Conventions

- **Luau, `--!strict` on every module.** Checked: `tests/Purity.spec.luau` asserts the directive is
  present, and `tools/gates.sh typecheck` runs Roblox's analysis engine over `src/` with `.luaurc`
  putting the tree in strict mode and turning lints into errors.
- **Types live in `src/shared/Types.luau`**, a leaf module that requires nothing. Both `Constants`
  and `PassResolver` annotate against it, which is what stops `Direction` and `Tier` from quietly
  widening to `string` — ADR 0011 documents the eight live type errors that had already accumulated
  behind an unchecked `--!strict`.
- **Constants are the single source of truth.** Never hardcode a tuning number in a system module.
- **OOP via metatables** (`Module.new()`), for the stateful things — the match runner, the wheel
  controller. The pure resolution layer stays a plain function table.
- **Headless-first.** A pure system gets a `tests/*.spec.luau` before it gets a UI. All four mounts
  are requireable from the shim (`roblox.requireShared/Server/Client/Gui`), so "it needs the engine"
  is a claim to check rather than assume — most of what looks client-only is arithmetic in a costume.

## The gates

Five, defined in [`tools/gates.sh`](../../tools/gates.sh), documented in
[WORKFLOW.md](WORKFLOW.md#the-gates-one-definition-three-callers). Run `QUICK=1 tools/gates.sh`
(~9 seconds) while working; CI runs them at full scale on every PR.
