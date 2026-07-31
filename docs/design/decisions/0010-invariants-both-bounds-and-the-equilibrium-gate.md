---
id: 0010
title: The invariants gain both bounds and an equilibrium gate — reads must not swallow the dice, and the hole card must stay live
date: 2026-07-30
status: accepted
supersedes: []
superseded-by: null
combat-axis: false
---

# 0010 — The invariants gain both bounds and an equilibrium gate

`combat-axis: false`: this ADR pins gate thresholds and two new invariants, not gameplay tuning
numbers. Runs are cited anyway, because every threshold here was set between a measured healthy
configuration and a measured dead one — each bound has a corpse behind it, not a guess.

## Context

The ring investigation (ADRs 0006–0009) stress-tested the invariant list itself, and found three
gaps — not in the game, but in what the project *checks*:

1. **Invariant 7 had only a floor.** "The matrix outweighs the dice" was gated as *a perfect read
   beats random ≥75%*. Nothing bounded the other side, and the other side is where the strongest
   candidates failed: several rings with the highest information value measured **97.5–100%** for
   perfect information with every existing verdict green. At that point §4's "anyone can win any
   pass" — the sentence upsets, jackpots, and the whole rage-proofing thesis hang from — is dead,
   and the game is reads all the way down. Healthy configurations measured 83–87%. The failure mode
   is real, adjacent to good-looking numbers, and was invisible to the gate.
2. **The gate suite could green-light a structurally dead game — and had.** A four-notch ring with
   a half-circle Shield passed all three checks (convergence 3.64, read edge healthy, camper last)
   while its **equilibrium crit rate was 0.0% and its hole card was worth 0.01 Balance**. The
   original shipped ring itself fails 6 of 7 equilibrium checks. Scripted riders never *find* the
   exploit, so the round robin cannot see this class of death; only an equilibrium solver can. The
   project's stated invariants were not, in fact, enforced — they were hoped.
3. **A design law was found twice and recorded nowhere load-bearing.** The Supershield with free
   defence (ADR 0009) and breaking triggered by proration (ADR 0008) died of the same disease: a
   benefit attached to the line a player takes anyway is a rebate, not a decision — it either gets
   ignored or becomes mandatory, and neither is gameplay. A law that independently killed two
   mechanics in one investigation belongs with the invariants, where the next mechanic proposal
   has to walk past it.

## Decision

**Invariant 7 becomes two-sided.** The matrix outweighs the dice *and never replaces them*: perfect
information beats random within **[75%, 93%]**, both bounds enforced in `tools/sim.luau`'s verdict
block. The ceiling sits between the measured healthy band (83–87%) and the measured dominant band
(97.5–100%).

**New invariant 9 — the hole card stays live, at equilibrium.** The hidden Shield is worth real
Balance between good players; the televised aim narrows it to roughly a coin flip, never to
certainty and never to nothing; and the secret is structural — the exposure is wider than the
plate. Enforced by a new gate, **`tools/rings.luau --verify`** (~1s, full solver precision, wired
into CI and the session hook alongside the existing three):

| check | bound | shipped | the corpse behind the bound |
|---|---|---|---|
| solver exploitability | < 0.50 | 0.03 | a non-converged solve must not pass as a result |
| hole card | ≥ 3.00 Balance | 8.12 | dead configs measured 0.00–0.52 |
| Shield entropy after the aim | 0.50–2.00 bits | 1.00 | dead configs 0.00; an unreadable Shield would also fail |
| equilibrium crit rate | ≥ 10% | 43.7% | the old ring: 0.1% with all gates green |
| top pure-line weight | ≤ 35% | 12.6% | the old ring's dominant line: 39.6% |
| chirality | required | yes | mirror-symmetric rings can only trade crits (ADR 0006) |
| exposure > Shield band | required | 3 vs 2 | cover everything and there is no secret to have |

The same shape constraints are additionally pinned as unit tests that read `Constants.RING`
generically (chirality, single guard directly opposite, exposure wider than the band, offset 0
exposed), so a casual constants edit fails in tests before it fails in the solver.

**New invariant 10 — no benefit attaches to the default action.** Stated as a review law, enforced
by the pair of gates in combination (a rebate-mechanic shows up as either a dead knob at
equilibrium or a mandatory one), and by every future ADR having to argue past it.

**The two instruments are one gate.** The round robin (whole matches, scripted riders — sees
convergence, attrition, camping) and the equilibrium solver (one pass, best responses — sees
exploits, information values) have complementary blind spots. WORKFLOW already directs combat-axis
ADRs to cite both; the gate suite now runs both.

## Consequences

**Cited runs.** Positive: `lune run tools/rings.luau --verify` at the shipped defaults — all seven
checks pass (values in the table above); `lune run tools/sim.luau` (seed 20260729, 8000
matches/pairing) — read edge 87.2%, inside both bounds. Negative, reproducing the corpses:
`--notches 4 --ring CCGN --shield-band 2 --verify` fails 4 of 7 (the configuration the round robin
green-lit); `--notches 4 --ring CNGN --shield-band 1 --verify` — the game as it stood before this
investigation — fails **6 of 7**. The ceiling's corpses: four-notch `CCNG`/`CCCG` at 97.5–100%
read-dominance, recorded in ADR 0006's context.

**What this costs.** The thresholds are conservative and could reject a legitimate future design —
deliberately: loosening a bound requires superseding this ADR with the measurement that justifies
it, which is exactly the friction the change should carry. CI grows one ~1s step. The invariant
numbering 1–8 is frozen (widely cited); new invariants append.

**What this deliberately does not do.** No gate can check invariant 5 (beginner-ignorable depth) or
the spur's feel — those are playtest questions, and pretending a solver can answer them would be
this ADR's own failure mode. The gates hold the *structure* so the gray box only has to answer for
the *fun*.
