---
maps-to: [src/shared/Constants.luau#LOBBY]
decisions: [0012, 0013, 0014, 0015]
owner: trey
updated: 2026-08-13
---

# LOBBY — the tilt-yard: everything before, around and after the pass

> [GAME_SPEC.md](../GAME_SPEC.md) §3–§5 own **the pass**, and it is designed, implemented and
> instrumented. Everything *outside* the pass was one paragraph (§8). This is that paragraph's deep
> doc: the yard the pass happens in, and the social game that makes a pass worth riding twice.
> Decisions: [0012](../decisions/0012-tilt-yard-is-the-interface.md) (the yard is the interface),
> [0013](../decisions/0013-ghosts-are-habits-not-recordings.md) (opponent supply),
> [0014](../decisions/0014-the-rail-is-a-scouting-stand.md) (the rail and information parity),
> [0015](../decisions/0015-one-duel-is-a-match-the-gauntlet-is-the-run.md) (the match wrapper).
>
> Almost none of this ships in M1 (§13: the gray-box pass, and nothing else). The one exception is
> named in §6.2, and it is there because an M1 success criterion depends on it.

## 0. What the yard is for

The pass is the product. The yard has four jobs, and every station in it does one of them:

| Job | The question it answers | Where it lives |
|---|---|---|
| **Supply** | who do I ride against, right now, at 4am, on day one? | the register (§5) |
| **Re-entry** | how fast is "one more"? | the mounting block (§6) |
| **Standing** | what do a hundred passes add up to? | the pennant, the dais, the tourney (§7) |
| **The information market** | why am I here when I am not riding? | the rail and the tally board (§4) |

The fourth is the one only *this* game gets to have, and it is the spine of the whole design. In a
read-based duel the scarcest resource is not gold or rarity — it is knowing what a rider does with a
90 Balance meter and a broken up-side. That resource is produced by watching, stored on a board,
carried by ghosts, and spent by challenging. **The mind game does not stop when the pass ends; the
yard is where its slow half is played.**

## 1. The spine: three timescales of the same read

Everything below hangs off one observation. The game's mind game already runs at three speeds, and
each one needs a home:

| Timescale | The read | Home |
|---|---|---|
| **Within a duel** (3–5 passes) | they went forward twice; are they due to go back? | the pass itself (§3–§4) |
| **Within a grudge** (a rematch chain) | they only spur when they are behind | the rematch default (§6.3) |
| **Across a career** (hundreds of passes) | Sir X is a deep-shield rider under 60 Balance | the tally board and the register (§4.4, §5) |

The pass was designed for the first. The yard exists to build the second and third — and it does so
with *one* artifact (the habit register, §5), which simultaneously supplies opponents, fills the
tally board, and feeds the creator/meta layer GAME_SPEC §2 makes a design target.

## 2. The map: one room, and every mechanic is somewhere

The yard is **one room** — every station visible from the mounting block, nothing behind a corridor
or up a staircase. That is a hard constraint, not a style: the arrival budget in §3.1 and the
re-entry budget in §6.2 are both measured in seconds a mobile player spends *not* jousting, and a
hub world with zones spends them on walking.

| Place | What it houses | Phase |
|---|---|---|
| **The lists** (the lanes) | The pass. One lane per horse-tier bracket, lane length scaled to speed so run-up duration is identical everywhere (ADR 0002). | M2 |
| **The mounting block** | Re-entry. Where you land after a fall, and where the next offer appears (§6.2). | **M1** |
| **The rail** | Spectating-as-scouting, the crowd, cheers and taunts, the watched-ness signal (§4). | M2 |
| **The pavilion** (your tent) | Loadout: horse, lance, heraldry. Deliberately a walk away (§3.3). | M2 |
| **The stable** | The vertical chase: horses, eggs, capacity. | M2 |
| **The armory** | The horizontal chase: lances, slots, spins. | M2 |
| **The tally board** | Records, matchup rates, recent-pass replays, the ghost register (§4.4). | M2 |
| **The quintain** | Ante-free practice that pays nothing but knowledge (§3.2). | M2 |
| **The dais** | The pennant holder's stand; the center lane; the tourney stage (§7). | Update 2 |
| **The gate** | Arrival, the first pass, and nothing else (§3.1). | M2 |

**Diegetic placement, screen-space interaction.** Every station is a real place, and approaching it
opens a real UI panel. The world carries the map and the theater; the panel carries the speed. We do
not make players scroll a stable through a keyhole in the name of immersion, and we do not ship a
menu bolted to a screensaver. ADR 0012 owns this.

## 3. Before the pass

### 3.1 Arrival: the first pass comes before the yard

A new player reaches their **first commit inside `LOBBY.FIRST_PASS_SECONDS`** of spawning — less
time than a single pass takes to ride. The gate faces lane one; a house rider (§5.2) is already
mounted; nobody reads anything, waits for anyone, or chooses a loadout first.

The yard introduces itself *on the walk back* from a fight you have already had. This is the whole
onboarding design, and the ordering is the point: the pass explains the yard, never the reverse. Two
inputs (Shield somewhere, aim somewhere) is complete legal play (invariant 5), so there is nothing a
first-time rider must be told before their first commit.

### 3.2 The quintain

A pivoting practice dummy on its own short lane: ride at it, hit it, and it swings back and hits you
if your aim was late. Free, ante-free, always open, and **it pays nothing at all** — no gold, no
standing, no drops. Practice buys knowledge, which is the only currency in this game that cannot be
farmed by a bot. A quintain that paid would immediately become the optimal way to spend a session
that never risks anything, which is invariant 10 read backwards.

It is also the natural home for feel-testing the spur — GAME_SPEC §12 lists "a thumb on a beat gate"
as the first thing the gray box must validate by hand.

### 3.3 The pavilion: the walk is the price of changing your mind

**Playing again is always zero-walk. Changing your loadout costs a trip.** Friction is placed on
reconsideration and never on repetition — which is the opposite of most lobbies, where the store is
in your face and the rematch is three taps away.

This is deliberate in three directions: it protects the "one more" impulse (§6.2), it makes the horse
choice feel like a commitment rather than a dropdown, and it keeps lane populations stable, because
switching brackets means physically walking your horse to another lane.

### 3.4 The lane is the bracket

ADR 0002 settled matchmaking as horse-tier rooms: the horse you bring is the room you are in. In the
yard that stops being a matchmaking rule and becomes a *place* — the brackets are adjacent lanes, so
the ladder is legible at a glance from the mounting block, and the tier you are climbing toward is
something you can walk over and watch (§4). Speed is a pure spectacle axis (ADR 0002), and lanes make
it visible: the top lane is longer, louder and faster, and thinks at exactly the same speed.

## 4. Around the pass: the rail and the information market

### 4.1 The wait is gone, so spectating needs a real reason

GAME_SPEC §1 and §8 inherited "the lobby is a tilt-yard where waiting is spectating" from Untitled
Boxing Game. Ghost-first supply (§5) deletes the wait — nobody ever queues for more than
`LOBBY.GHOST_FILL_SECONDS` — and with the wait goes the crowd that the comp gets for free.

That is not a loss, it is a correction: **the rail is not a waiting room, it is a scouting stand.**
The pass you are watching is a pass you are not riding, so watching costs real passes, and what it
buys is knowledge of a specific rider — the exact thing the duel is decided by. Invariant 10 is
satisfied structurally: spectating is a deviation from the default line (ride again), and it is paid
for in the currency the game is actually about.

### 4.2 Parity is absolute: the rail sees what the opponent sees, never more

**No spectator client is ever sent a value the opponent's client does not hold at the same moment.**
The Shield reaches the rail at impact, together with the opponent — never a frame earlier. This is
CLAUDE.md invariant 3's server authority extended to a third party, it is now
[invariant 11](../../../CLAUDE.md), and it holds for every future observer surface: replays, streams,
private servers, tourney broadcast, any developer "spectate" affordance.

It is worth stating as a rule rather than assuming, because the natural implementation leaks. A
spectator client that receives full match state "because it is only watching" hands a friend on the
rail the hole card over voice chat, and the entire pass collapses. Parity kills that exploit
structurally instead of policing it.

### 4.3 Being watched is public

A rider can see their rail: who is on it and how many. Two consequences, both good — you know when
your habits are being harvested, and playing to a crowd becomes a legal bluff (throw a pattern for
three passes while a known rival watches, then break it when they challenge you). Information flows
both ways or it is not a mind game, it is surveillance.

### 4.4 The tally board

The yard's public record, free to everyone, sold to no one: per-rider win rate, recent-pass
commitment traces, per-matchup rates, and short replays of the last `LOBBY.GHOST_MIN_PASSES` passes.
This is the same data the creator/meta layer needs (GAME_SPEC §2 wants matchup charts that fit in a
thumbnail), the same data a ghost is fitted from (§5.1), and the same data a scout collects by
standing at the rail. One artifact, three audiences.

### 4.5 Fame costs privacy

A rider's record goes public at the same moment their ghost starts riding — one threshold,
`LOBBY.GHOST_MIN_PASSES`, with both consequences. Play enough to be worth studying and you become
studyable. The counter is free and available to everyone: change. The register only remembers
`LOBBY.HABIT_WINDOW_PASSES`, so reinvention always works, and it is the top of the ladder's actual
skill — being unreadable is a thing you have to keep doing.

This is also the game's difficulty curve, and it is made of information rather than stats: the better
you do, the more is known about you (§7.3). Invariant 1 stays intact, because nothing anybody buys or
wins makes their dice better against a champion — they just know more.

## 5. Opponent supply: the register

### 5.1 A ghost is a habit, not a recording

The naive ghost replays a recorded pass. It cannot work: that pass was committed against a *different
opponent's* televised aim, on different Balance meters, with different breaks on the ring. Replayed,
it is either nonsense (it reacts to a pass nobody is riding) or memorizable (beat the tape once, beat
it forever).

So a ghost is a **fitted habit table**: frequencies over defensive shape (forward / back / deep), aim
family, hold fraction, and spur rate, each conditioned on public state — own Balance band, opponent's
Balance band, pass index within the duel. At every commit the ghost samples fresh. It reacts to the
pass actually being ridden, it cannot be memorized, and beating it teaches you something true about
the rider it was fitted from. ADR 0013 owns this.

**A ghost commits blind.** It never conditions on the live rider's hidden Shield, and it resolves
through the same `PassResolver` as everyone else. A ghost that peeks is not a hard opponent, it is a
broken one.

### 5.2 Two honest categories, and no fake people

- **Ghosts** are attributed. They carry a name, colors and heraldry, and they are visibly ghosts —
  you are told whose habits you are riding against, and it is a feature (face a friend's ghost, face
  the champion's ghost) rather than a thing we hide.
- **House riders** are the yard's own named personalities — the scripted riders M1 already needs, kept
  forever as the tutorial ladder and the quintain's stablemates. They are visibly not people.

There is no third category. **We never dress a bot as a stranger.** A game whose brand promise is
"the odds are printed on the screen" (invariant 6) does not get to lie about who is on the other
horse, and the honest version is better anyway: an attributed ghost is a social object, and a fake
human is a betrayal waiting for one forum post.

### 5.3 Nobody can duck you, and nobody is cornered

Challenges are diegetic — throw the glove at a rider from the rail or the board. A challenge can
always be declined, costs nothing to decline, and if it is declined or expires
(`LOBBY.CHALLENGE_EXPIRY_SECONDS` of the challenged rider's *mountable* time, so it survives the duel
they are in the middle of), **the challenger rides that rider's ghost instead**.

Both halves matter. Grudges always resolve, so a rematch is never something an opponent can withhold;
and nobody can be forced into an interaction, so the challenge system is not a harassment surface.
The ghost is what lets both be true at once.

### 5.4 The register is instrument-shaped by construction

The habit table is pure data and the sampling policy is a pure function with injected RNG, so it
lives in `src/shared` under the purity seam ([ARCHITECTURE.md](../ARCHITECTURE.md)) — which means it
is *the same interface* `tools/sim.luau`'s scripted riders already implement. The instrument that
gates our tuning and the thing that supplies half our opponents are one abstraction. A new ghost
policy can be round-robined against the existing rider set before it ever reaches a player, and a
regression in ghost quality is a headless test rather than a bug report.

## 6. After the pass

### 6.1 The fall, and the ceremony

The unhorse is the signature clip (GAME_SPEC §4), so the yard gives it a beat and then gets out of
the way: the teeter resolves, the rider goes into the dirt, the Shields are revealed, the purse
changes hands, the pennant moves (§7). `LOBBY.CEREMONY_SECONDS`, and it is a hard ceiling — a
ceremony that outlives the emotion it is celebrating is how a fast loop dies.

The post-pass reveal ("you leaned high, they shielded low") is per-*pass*, not per-match: it belongs
to the pass and is already in GAME_SPEC §8's brief. The post-*match* ceremony is only the fall, the
purse and the offer.

### 6.2 The re-mount contract

**You get up where you fell, and the next pass is offered where you land.** From the unhorse to the
next commitment being live: `LOBBY.REMOUNT_SECONDS`, ceremony included, with no walking, no menu, no
loading screen and no lobby return.

The budget is checked against the pass cycle in `tests/Constants.spec.luau`: the dead time between
two matches must be shorter than one pass. If losing costs more time than playing, "one more" stops
being an impulse and becomes a decision — and M1's success criterion (a) is precisely that testers
say "one more" without being asked.

**This is the one yard mechanic M1 builds** (GAME_SPEC §13 says the gray-box pass and nothing else;
this is the exception, and it earns it by being the thing the milestone's own success criterion is
measured on). Everything else in this document is designed-not-built.

### 6.3 The rematch is the default requeue

The offer at the mounting block is aimed at **the rider who just beat you**. Not a random opponent,
not the lane — them. The grudge is the strongest requeue in every duel game ever shipped, it is the
engine that turns rock-paper-scissors into yomi (GAME_SPEC §2's format playbook, item 5), and it is
the middle timescale of §1.

If they leave, their ghost takes the offer. The rematch always exists.

### 6.4 The purse

The ante is diegetic — a purse on the stakes post, the winner takes it. Antes scale with the bracket,
which is the same ladder as the lanes, so the chase climb and the stakes climb are one motion. The
economy itself (faucet sizing, ante values, rake) is the chase's design session, not this one; the
lobby's only requirement is structural and already in GAME_SPEC §8: **loss costs an ante, never a
session.**

## 7. Standing: the match, the gauntlet, the tourney

### 7.1 A match is one duel

Settled by ADR 0015, closing GAME_SPEC §12's match-wrapper question. One duel, to unhorse, one ante.
Best-of-duels was the alternative and it loses: the yomi argument for best-of-N is already satisfied
*inside* a duel (3–5 passes teach habits), while best-of-duels doubles the ceremony and makes losing
expensive in the one currency the loop cannot afford to spend — time.

### 7.2 The gauntlet is the run

Consecutive wins on one horse. It is a **scoreboard, not a wager**: the purse banks at every win and
nothing is ever clawed back, so there is no cash-out decision, deliberately. A cash-out mechanic
would point loss aversion straight at the "one more" impulse the entire loop is built to manufacture.

### 7.3 What escalates is exposure

A run does not raise your opponents' stats, your ante, or your risk. It raises your **stage**: the
pennant holder rides the center lane, in front of the rail, on the dais side of the yard. The longer
the run, the more people are watching, and (§4.5) watching is scouting. Difficulty rises as
information — organically, symmetrically, and without a single stat touching invariant 1.

This is also the anti-stagnation valve for the whole meta: a dominant rider's habits become public
property at exactly the rate they dominate, so the top of the ladder is held by riders who can
change, not riders who found a line.

### 7.4 The tourney

The periodic form of the same thing, and the repo's own name: a bracket over ordinary duels, run on
the lanes on a cadence, with empty seats ghost-filled so it can never fail to fire on a quiet server.
It is the one time the rail fills by construction — during a final there is only one match happening
— and the champion holds the dais until the next one.

Update 2, not launch. But **the yard is laid out for it before it exists** (§2 gives the dais a
place), because retrofitting a stage into a finished lobby is the expensive kind of change.

## 8. Expression, and the occlusion rule

Taunts, salutes, victory laps, unseat effects and heraldry are the yard's expression layer, and in a
televised duel they are gameplay-adjacent: tilt induction between passes is a real read-game move.
Two rules keep them from eating the thing they decorate:

1. **Expression never occludes information.** Taunts play on the rider, in the world. The wheel, both
   meters, the odds readout and the aim are never covered, dimmed or animated over. Mobile-first means
   the screen belongs to the pass.
2. **Expression never touches the matrix.** Nothing bought or equipped for looks changes a number, a
   tier, or a roll — the same fence the monetization work draws (PR #5, ADR 0003, still open).

## 9. What the yard may never do

The lobby half of the fence, checked against the pass's invariants:

1. **Never sell information.** The tally board is free and identical for everyone. No paid analytics,
   no premium scouting tier, no observer view with extra columns (invariant 11).
2. **Never leak the hole card sideways** — to a spectator, a replay, a stream overlay, or a party
   member (invariant 11, §4.2).
3. **Never become required literacy.** A player who never visits the rail, the board or the pavilion
   can play forever: walk in, ride the lane, ride again (invariant 5).
4. **Never pay for the default line.** Practice pays nothing; watching pays nothing; being logged in
   pays nothing (invariant 10). Rewards attach to riding and winning.
5. **Never make the requeue cost a walk** (§3.3, ADR 0012).
6. **Never let a house rider pass as a person** (§5.2).

## 10. Sequencing

| Phase | Ships | Why here |
|---|---|---|
| **M1** | The re-mount contract only (§6.2). | Success criterion (a) is a re-entry measurement; everything else is out of scope by GAME_SPEC §13. |
| **M2** | The yard proper: lanes as brackets, the mounting block, the rail, the pavilion, the gate and arrival, the quintain, the tally board, the register with house riders and named ghosts, the rematch default, antes and purses. | This is the minimum yard that makes a session out of a pass, and the register is load-bearing for population on day one. |
| **Update 2** | Challenges and grudges at scale, the dais and pennants, the tourney, the taunt/expression line, party (cap 2). | Each needs a live population to mean anything; each is additive to a yard that already works. |
| **Post-launch** | Rail wagering, cross-server ladders, spectator broadcast surfaces. | Each is a system, not staging — and each must re-clear §9's fence before it is designed. |

## 11. The words the yard is played in

[GLOSSARY.md](../GLOSSARY.md) owns the pass's vocabulary; these are the yard's. Same reason for
fixing them early: the meta layer runs on shared words.

| Term | Meaning |
|---|---|
| **The yard** (tilt-yard) | The whole lobby space. One room. |
| **The lists** | The lanes. One per bracket; "riding the lists" is being in a match. |
| **The rail** | The spectator line alongside a lane. Where scouting happens. |
| **The mounting block** | Where you land after a fall and where the next offer appears. |
| **The pavilion** | Your tent: horse, lance, heraldry. |
| **The quintain** | The practice dummy. Pays nothing. |
| **The tally board** | The public record: rates, traces, replays, the ghost register. |
| **The glove** | A direct challenge to a named rider. Declinable, always. |
| **The purse** | The ante at stake in a duel. |
| **A duel** | One match: passes until someone is unhorsed. |
| **A gauntlet** | A run of consecutive wins on one horse. |
| **The pennant** | The public marker of a run. Moves to whoever ends yours. |
| **The dais** | The center lane and the champion's stand. The tourney stage. |
| **A ghost** | A rider's fitted habits, riding under their name and colors. |
| **A house rider** | One of the yard's own named personalities. Visibly not a person. |

## 12. Open questions

- **Ghost fidelity.** How coarse can the habit table be before ghosts read as random noise (the game
  degrades to matrix-EV plus a slot machine) or as a wall (a caricature nobody enjoys)? Answerable
  headlessly the day the register exists, because it plugs into `tools/sim.luau`'s rider interface
  (§5.4) — round-robin a fitted ghost against the scripted set and read the same verdicts.
- **The conditioning set.** §5.1 proposes Balance bands, opponent Balance band and pass index. Which
  of those actually carries signal is a telemetry question and needs real passes.
- **`LOBBY.GHOST_MIN_PASSES` at 20** is a first guess doing two jobs (when a ghost is fielded, when a
  record goes public). If those two want different thresholds, splitting them is cheap — but the
  unification is the point of §4.5, so split it only with evidence.
- **Does a ghost lose to its own rider?** A fitted model samples from your habits without your bad
  nights. If ghosts systematically outperform the riders they came from, standing means less than it
  should — measurable once the register is live.
- **Rail wagering** (bet on the joust you are watching): thematically perfect, a real reason to stand
  at the rail beyond scouting, and a system rather than staging. Deferred by §10; it needs to clear
  §9.1 first, since a wager is information-adjacent.
- **Tourney cadence and seeding** — every N minutes, seeded by pennant? By bracket? Undesigned.
- **Yard population on a quiet server.** Ghosts riding ghosts in the background lanes would keep the
  yard alive and scoutable at 4am at almost no cost (a pass is two decision lists and a resolver
  call). Attractive, cheap, and unproven: it may also read as a fake crowd, which is §5.2's line.
  Prototype before committing.
- **Party (cap 2)** carries over from the predecessor repo, but what a party *does* in a 1v1 game
  (ride the same lane together? share a rail? tourney doubles?) is undesigned.
