---
id: 0004
title: The pass is played in four words — Shield, Guard, Crit, Supershield
date: 2026-07-30
status: accepted
supersedes: []
superseded-by: null
combat-axis: false
---

# 0004 — The pass is played in four words: Shield, Guard, Crit, Supershield

`combat-axis: false` because this ADR changes **no** behavior and pins **no** tuning number. It is a
rename plus one new named accessor. `tools/sim.luau` reproduces every figure in ADR 0001
byte-identically before and after, which is the evidence that it is a pure rename — a sim run is cited
below for that reason, not because the gate requires one.

## Context

ADR 0001 named the pass's parts descriptively, from the implementer's side: `passiveGuard`,
`activeGuard`, "the hole", "stacking", the `punished` tier. Those names were accurate and they got M1's
resolver built. They also have four problems, which only became visible when we tried to talk about
the mechanic out loud rather than write it down.

**"Passive" and "active" describe the wrong distinction.** They read as a difference in *intensity* —
one guard idling, one guard working. The real difference is *who chose it and when*: one is committed
pre-round and hidden, one is derived from a public input every frame. Two players trying to discuss
depth-vs-breadth had to first agree which "guard" they meant, every time.

**"Guard somewhere + aim somewhere" was quietly wrong.** GAME_SPEC §3 and CLAUDE.md invariant 5 both
stated the beginner's contract that way. But the guard cannot be chosen — it is `OPPOSITE[aim]`. The
sentence naming our most important accessibility promise described an input that does not exist.

**"The hole" had no term of art and collided with "hole card."** The same document used "hole" for the
crit direction and "hole card" for the hidden commitment — two different concepts, one word, three
lines apart.

**The `punished` tier named the verdict rather than the event.** "Punished" is what the *matrix* did to
you; the thing players actually point at is the tripled hit.

This matters more than internal tidiness. GAME_SPEC §2 makes the meta/creator layer a design target
rather than a byproduct, and requires "an enumerable system (matchup charts must fit in a thumbnail)".
A thumbnail cannot hold "active guard (opposite of final aim) matching the passive guard". The
vocabulary is part of the product surface, and it is cheapest to fix at two ADRs old.

## Decision

Four words. Two are chosen by the player; two are derived and free.

| Term | Replaces | Chosen when | Visible? |
|---|---|---|---|
| **Shield** | `passiveGuard` | intermission, pre-round | **hidden** until impact |
| **Guard** | `activeGuard` | derived: `OPPOSITE[aim]` | public |
| **Crit** | "the hole", `punished` | derived: `OPPOSITE[guard]`, i.e. the Aim | public |
| **Supershield** | "stacking" / `stacked` | derived: Guard lands on Shield | hidden |

Rules that come with the words:

1. **The Shield and the Aim are the only two inputs.** Guard and Crit are derived and always free. The
   beginner's contract is restated everywhere as "**Shield somewhere + aim somewhere**", which is now
   true.
2. **`crit` is one word for the direction and the tier**, because they are the same fact: the direction
   is where a crit can land, the tier is what lands there. `PUNISHED_DAMAGE` → `CRIT_DAMAGE`.
3. **`PassResolver.crit(commitment)` exists** even though its body is `return commitment.aim`. The Aim
   and the Crit are one direction read for opposite purposes — where you threaten, where you are
   exposed — and the concept needs a name that player-facing copy and future kits can point at. A test
   asserts the round trip `crit == opposite(guard)` rather than trusting the tautology, so that if
   GAME_SPEC §7's inverted-polarization archetype ever rewires this, the identity must be re-derived
   deliberately.
4. **"Supershield" is the player-facing name for the defensive bonus**, and it is a verb-phrase
   definition: you supershield when your Guard lands on your Shield. `STACK_BLOCK_RESTORE` →
   `SUPERSHIELD_RESTORE`.
5. **"hole card" survives.** It is the poker term for a face-down card and it describes the Shield's
   role in the information game, which is a different thing from the Crit's place on the body. What
   retired was "the hole" as a *direction*.
6. **GAME_SPEC §5's "depleting guards" becomes "depleting coverage"**, since under the new words
   coverage is `{Shield, Guard}` and "guards" no longer names the pair.

### Two decisions about process, not vocabulary

**ADR 0001 was swept in place rather than superseded.** WORKFLOW.md step 2 says ADRs are append-only
and you supersede rather than edit. At two ADRs old, the alternative was a permanent translation table
between a dead vocabulary and a live one, which is a worse tax than the immutability break. The sweep
touched **words only** — every decision, number and cited figure in 0001 is exactly as accepted on
2026-07-29, and 0001 now carries a note saying so. **This license is explicitly early-phase: past M1,
supersede rather than edit.** ADR 0002 needed no sweep.

**`RETIRED_VOCAB` gets its first real entries.** `tools/design-lint.luau` has carried an empty
retired-vocabulary check since PR #6, waiting for the first rename. It now guards `passive guard`,
`active guard` and `punish hole`, with `docs/design/GLOSSARY.md` created as the human half of the
ledger (the linter errors if the two drift). Deliberately **not** guarded: `stack` / `stacked` /
`stacking`, which are ordinary English in these docs ("a stack of small merged PRs" in WORKFLOW.md). A
check that cries wolf is a check people learn to ignore.

## Consequences

**The rename is provably behavior-free.** `lune run tools/sim.luau` at the same seed reproduces ADR
0001's cited figures exactly:

```
standing (mean win rate vs the non-oracle field)
  1. oracle       71.2%
  2. axis         56.2%
  3. counter      55.5%
  4. supershield  48.7%
  5. honest       47.8%
  6. random       44.1%
  7. halfer       43.7%
  8. flicker      39.3%
  9. camper       18.6%

read edge: a perfect read beats random 80.2% of the time
camper ranks 9 of 9
VERDICT: all three checks pass — these numbers are citable.
```

Identical to 0001's run in every digit; only the row label changed (`stacker` → `supershield`). Tests
go 27 → 28 (the new Crit round-trip assertion). `design-lint` reports 0 errors, 0 warnings.

**The forgot-the-flag backstop stayed live.** `COMBAT_AXIS_TOKENS` listed `PUNISHED_DAMAGE` and
`STACK_BLOCK_RESTORE`; renaming the constants without updating that list would have silently made the
check inert for the two most important numbers in the game — the same class of bug PR #6 fixed. Both
tokens were updated in the same commit.

**One thing got clearer, and it is uncomfortable.** Writing the definitions down made explicit that a
clean block and a crit are **mutually exclusive in a single pass**: a clean block needs the attacker to
aim into your Guard, and hitting their Crit needs your own Aim pointed the other way. Both derive from
the same single Aim input, so no tuning can make them coincide. That is a genuine structural guarantee
against a "block their hit *and* punish them" degenerate line — and it is also the reason the
Supershield can never recover its deficit on the defensive side alone, which is
[ADR 0005](0005-supershield-pays-offense.md)'s problem.

**What this ADR does not do:** it does not touch a single number, and it does not settle whether the
Supershield is worth taking. Renaming "stacking" to "Supershield" gave the mechanic a better name
without changing that `axis` still outranks it by 7.5 points. The name now oversells the mechanic
slightly, which is an argument for fixing the mechanic rather than for renaming it back.

**Accepted cost:** every future reader of ADR 0001 sees swept prose rather than the words the decision
was actually taken in. The note at its head and the GLOSSARY ledger are the mitigation, and the
immutability rule is reasserted from M1 onward.
