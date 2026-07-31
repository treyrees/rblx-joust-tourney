---
maps-to: [src/shared/Constants.luau, src/shared/PassResolver.luau]
decisions: [0001, 0002, 0004, 0006, 0007, 0008, 0009]
owner: trey
updated: 2026-07-30
---

# JOUST — Founding Game Spec

> The canonical design as of project start (2026-07-29), distilled from the founding design session.
> This is a living doc. Decisions that change it get ADRs in `docs/design/decisions/`.
> Origin: pivot from `treyrees/rblx-auto-br` (Grindstone Gladiators); see §11 for what carries over
> and `docs/pivot/JOUST_CONCEPT.md` in that repo for the original pivot rationale.

## 1. The game in one paragraph

A **recurring gauntlet of fast 1v1 jousts** on Roblox. Each pass is one committed mind-game decision
resolved in a single tick: the horse makes the automation diegetic (nobody asks why they can't steer
mid-charge). Matches are best-of-passes until someone is **unhorsed**. Between matches: the chase —
rarer **horses** (vertical power) and **lances** (playstyle identity, native hotbar). The lobby is a
tilt-yard where waiting is spectating. Target cycle: **sub-15-second pass = ~45% intermission
selection / ~45% run-up (active) / ~10% resolution** — 10% of the time carrying 90% of the emotion.

## 2. Comp positioning

- **Gold-standard comp: Untitled Boxing Game.** Proven format on-platform: lobby-is-the-queue,
  fast loop with cheap loss, read-based 1v1 combat, styles as collection, visceral hit moment.
- **The twist, stated honestly:** UBG's loop with the twitch removed — commit-based reads instead of
  timing execution — so the addressable audience widens (younger/mobile), plus a tycoon-grade
  collection chase UBG lacks. Gameplay is *simpler* than the comp; depth lives in reads and wagers.
- **Format playbook** (Clash Royale, 8 Ball Pool, Super Auto Pets, Marvel Snap, FOOTSIES/Divekick,
  YOMI Hustle, For Honor as the directional-guard cautionary tale):
  1. Progression and matchmaking rise together — settled as **horse-tier rooms** (ADR 0002): the
     horse you bring is the room you are in, and the room sets the speed.
  2. An ante per match makes short rounds meaningful.
  3. **Async ghosts are the population cheat code** — a ghost is just a Shield choice + an aim trace;
     mechanically indistinguishable from a live opponent. **Ghost-first is plan-of-record** (Thing 0).
  4. The mind game comes from a wager/commit layer, not mechanical inputs.
  5. Best-of-N turns RPS into yomi (earlier passes teach habits).
- **The meta/creator layer is a design target, not a byproduct.** A demonstrated analytical-content
  audience exists for the comp. Requirements: an enumerable system (matchup charts must fit in a
  thumbnail), a post-pass reveal of both commitments, and player-facing matchup data. Decision-based
  meta content transfers to every viewer (unlike execution content) — this is our structural edge.

## 3. The pass (the core mechanic)

**Directions:** a **four-direction basis** — self-relative **in / out / up / down** (self-relative
framing avoids the mirrored-pass left/right ambiguity) — played on an **eight-notch wheel** (the
four diagonals between them; ADR 0006), plus **neutral**, a legitimate state and the default. The
four cardinals remain the words the design speaks; the diagonals are granularity.

**Phase 1 — Intermission (private commit):** place your **Shield**, a two-notch (90°) plate on the
wheel. Hidden until impact — the hole card.

**Phase 2 — Run-up (one public allocation):** steer the **spear aim** on a circular touch wheel
("iPod wheel"), **quantized to the eight notches** with hard snapping (the televised state is always
one of eight clean values; the spear may animate smoothly between them, the *state* is discrete).
Aim is fully televised. Every run-up second is spent one of two ways — **holding an aim** (charging
the strike) or **spurring in neutral** (banking momentum, one tap per hoofbeat; ADR 0007) — and both
meters are public.

- **The ring (automatic; ADR 0006):** your aim drags a fixed pattern around the wheel — you are
  **exposed** at the notch you strike with and for two more notches sweeping to one side (135°),
  your **Guard** is a one-notch (45°) block directly opposite, and the rest is ordinary. "You are
  exposed exactly where you strike — and one turn around." The lopsidedness is the point: the ring
  is **chiral**, so a correct read can land a crit that is *not* traded back.
- **Polarization (automatic):** the Guard is always directly opposite the aim. One input carries
  attack AND defense; you cannot aim at their weakness without configuring your own exposure. (For
  Honor's turtling failure is dodged because defense is never free or independent.)
- **The hole card is the gap:** exposure is three notches, the Shield covers two — something is
  always bare, and *which* is the one secret in the pass. The televised aim narrows the Shield to a
  coin flip and no further (~1 bit survives; ADR 0006).
- **Neutral is the opening state for everyone** — so the spawn frame leaks nothing, and *when you
  first leave neutral is itself a tell* (bet-timing; the run-up has poker streets for free).

**What the two run-up currencies buy (ADR 0008):**
- **Held aim — proration, paying NOW:** the strike scales with the fraction of the run-up the
  *final* aim was held. The buildup meter is **public** — the crowd watches your commitment charge.
  A late switch is the bluff, and it has a mechanical price (reset buff = weaker strike), not just an
  informational one. **Proration curve: linear** (ADR 0001). The floor+ease-in lean recorded here
  originally was overturned by the sim: a floor collapses a half-held aim to within a point of a pure
  last-instant flick, which turns the bluffing spectrum into a binary. Linear keeps the meter
  readable as a dial and still costs the flicker 8 points of win rate.
- **Spurred momentum — breaking, paying LATER:** a landed strike carrying enough momentum **breaks**
  the slice it hit, degrading it one rung for the rest of the match (`guard → normal → crit →
  mortal`). Breaks anchor to world directions, so they are permanent holes the defender must steer
  around. Spurring is the only line that pays when your read was wrong — crashing into their guard
  at speed still breaks it.
- **Defensive bonus — binary, and held (ADR 0009):** a **Supershield** — clean block plus a small
  restore — iff the Shield covers the Guard *and* the aligning aim was genuinely held (defence is
  prorated like offence; a last-instant flick into alignment earns nothing). At full Balance the
  Supershield is dormant — covering exposure is simply better — and below ~85 Balance it takes over
  on its own: depth is the hurt rider's game, breadth the healthy rider's, and the public Balance
  meter tells everyone which game each rider is in.

**Information architecture (three layers):** public offense + momentum meters + televised aim →
derived ring (exposure and Guard) → hidden Shield (the hole card), revealed at impact. Every pass is
a readable poker hand.

**Guardrails:**
- **Aim locks a few tenths before the tick** — decision timing, never a ping war (UBG's ping meta is
  the cautionary tale).
- **Beginners must be able to ignore every layer** — Shield somewhere + aim somewhere is complete,
  legal jousting (those two are the only inputs; Guard and Crit are derived for you). The signaling game is emergent depth, never required literacy. Protect this in tuning.

**Neutral baseline (settled by ADR 0001; spur added by ADR 0007):**
1. Neutral aim at the tick → weak center strike, no crit potential, zero honesty buff
   (survivable, not viable). In the sim, neutral-camping ranks last of twelve strategies.
2. Neutral Guard → none (maximally soft; cageyness is priced by softness + proration tax).
3. Neutral as a Shield → legal, and it covers nothing. It cannot supershield, so it forfeits the
   defensive bonus and leaves coverage at a single direction: a real option that is never a good one.

## 4. Resolution: the matrix, Balance, and the unhorse roll

> Implemented and pinned: [pass/RESOLUTION.md](pass/RESOLUTION.md) is the deep doc; ADR 0001 pinned
> the original numbers, ADR 0006 the ring and the re-pinned scale. The crit keys off the **ring**,
> not the hidden Shield, so the rule reads *you are exposed exactly where you strike, and one turn
> around*; a crit is 3x a normal.

**The matrix beat (deterministic — the gameable layer):** aim vs the defender's ring (and Shield)
resolves to an outcome tier — **blocked / normal / crit / mortal** (crit = struck on an uncovered
exposure notch; mortal = the same, on a slice broken three times — unhorsed, **no roll at all**).
Tiers translate to **Balance damage**, modified by lance stats, honesty bonus, breaks, and
abilities. A clean block grants the defender a small Balance restore (blocking is a win, not a
non-loss) — capped well below typical hit damage so convergence never stalls.

**The roll beat (the slot machine):** both riders carry a public **Balance meter (0–100)**. Anyone hit
this pass **rolls against current Balance to stay mounted** — at 80 Balance, 80% stay-on. The roll is
diegetic: the rider **teeters in slow motion** with the live percentage shown, and recovers or goes
into the dirt. **Unhorsed = match over.** The teeter-and-recover at low odds is the signature clip.
The mortal end is its opposite and complement: the one finish the dice cannot touch, arriving only
after three telegraphed breaks — the endgame belongs to reads, not rolls (ADR 0008).

**Why this shape:** converges by construction (Balance only trends down; tune for 3–5 passes average);
anyone can win any pass (upsets are jackpots, not bugs); RNG is exactly where intended and printed on
screen (every loss decomposes to "read" or "roll" — visible-odds RNG is the rage-proof kind); public
meters fuel endgame bluffing (a 20-Balance opponent HAS to gamble, and everyone knows it).

**THE INVARIANT: reads resolve deterministically; survival resolves stochastically; rarity loads the
dice — and a correct read always beats a rarer horse.** Skill is the trump suit; money buys better
odds, never immunity to being outplayed. Everything downstream (matchmaking, monetization, meta
content) hangs off this sentence.

**Tuning guardrail, both bounds:** the crit tier must usually force a genuinely scary roll — the
matrix must matter more than the dice on average, or the read game dies and it's only a slot
machine. And the mirror bound, learned the hard way: information must never matter so much that a
perfect reader simply *wins* — several candidate rings measured 97%+ for perfect information with
every other check green, and at that point "anyone can win any pass" is dead and the game is chess
wearing dice as jewelry. Both bounds are gated (CLAUDE.md invariant 7; sim verdicts ≥75%, ≤93%).
A second guardrail rides with it: the hole card must stay live *at equilibrium* — worth real
Balance between good players, narrowed by the televised aim to a coin flip and no further — which
no scripted-rider instrument can check and `tools/rings.luau --verify` exists to enforce
(CLAUDE.md invariant 9, ADR 0010).

## 5. Escalation & win condition

- Balance attrition is the primary convergence engine (§4).
- **Depleting coverage — settled as Breaking (ADR 0008):** the trigger moved from being-struck to
  attacker momentum, so it is a currency you *buy* with run-up time rather than a side effect.
  Repeatedly broken directions still force conclusion mechanically AND generate escalating
  information (a broken up-side narrows your real options — later passes get sharper reads exactly
  when the match needs to end). Imports UBG's "defense is a depleting resource, never a safe
  default", with the ladder ending at the mortal rung.
- Optional dramatic layers: rising per-pass wager (Snap-style raise/yield — diegetic as raising the
  lance / yielding before the charge), shortened aim window in sudden death.

## 6. Stat surfaces (everything plugs into §4's numbers)

- **Horse (vertical, rarity, the chase):** max Balance, damage soak, and **recovery** (bonus to the
  teeter roll — the rarest horses are the *clutch* horses; better fantasy than damage sponge).
- **Horse speed (the odd one out — an *access* stat, not an in-match stat):** speed is set by the
  **bracket**, not by the rider, and rarity determines which brackets a horse may enter (ADR 0002).
  There is one run-up and one tick, so there can only be one speed in a match; a per-rider speed would
  shrink the opponent's decision window, which is rarity beating a read. Rarity buys admission to a
  faster, louder tier — never an edge inside it. **Each bracket is its own physical lane, and lane
  length scales with speed so run-up duration is identical everywhere** — the sub-15s cycle (§1) holds
  at every tier, and speed is a pure spectacle axis that never trades against the read game.
- **Lance (horizontal, playstyle, native hotbar):** Balance damage profile + matrix personality
  (heavy lance = harder normals; fine lance = doubled crit tier; etc.).
- **Ability (active, one-shot per match):** manipulates one number or one roll — reroll, guaranteed
  stay-on, "next honest hit crits," a peek, a fake tell. Nature derived from what the matrix needs
  in playtesting, not decided in advance. Lives in the neutral state and/or UI space (§7).

## 7. Archetype architecture: base rules + exceptions

**The four directions are the rules; neutral is the exceptions slot.** The directional poker game
stays forever un-gimmicked; archetype identity is expressed by what a kit does to neutral (or the UI
layer). MtG structure: airtight base rulebook, kits as licensed exceptions — keeps the baseline
legible while archetypes stay arguable (tier-list fuel).

- **Neutral-kit archetypes** (directional game untouched): charge-storing lance (neutral time
  converts to strike power — the anti-proration kit); feint kits (leave-and-return re-arms the prior
  direction); warden kits (Balance regen during neutral).
- **Directional-kit archetypes** (neutral boring, directions rewired): inverted polarization (the
  meta's scissors); double-speed proration with harsher bluff penalty (the honest knight);
  direction-asymmetric damage (identity telegraphed at the loadout screen).
- **Balance discipline:** neutral-kits are the dangerous ones (they change the value of
  information-denial for the whole lobby). Neutral time must always cost real offense for everyone;
  neutral-kits *convert* that cost, never erase it.

## 8. The loop & the lobby

Tilt-yard lobby where **waiting is spectating** (the UBG masterstroke): visible queue, rail crowd
watching live passes — both public aims and offense meters visible, guards revealed at impact; every
pass is legible to the rail. Instant requeue; loss costs an ante, never a session. **Post-pass
reveal** ("you leaned HIGH, they shielded LOW — counter!") turns every loss into a lesson and every
clip into content. Player-facing matchup data (per-matchup win rates, pass history, commit-sequence
replays — cheap, a match is a short decision list).

## 9. The chase

Horses across rarity tiers (the vertical/tycoon chase, the dice-loader per §4's invariant); lances as
the horizontal playstyle spread (equip via native hotbar). v1 can be embarrassingly small: a handful
of horses × 3 rarities, 3–4 lances with distinct matrix-tilts. The acquisition loop (currency faucet,
gacha/eggs/breeding, any idle/stable-tending layer) is **undesigned** — it is the D1 half of the game
and needs its own design session (see §12). Launch with a deliberately debatable tier list: games
that ship with an arguable meta get their first content wave made for them.

## 10. Scope doctrine: three things (plus Thing 0)

1. **The pass** — §3+§4. ~80% of the product; deserves the majority of total dev time.
2. **The loop** — §8. Mostly staging, not systems.
3. **The chase** — §9. The only real "system"; ships small.
- **Thing 0: opponent supply** — ghost-first (§2.3) makes population a solved problem, not a launch risk.

Explicitly NOT load-bearing at launch: crafting, gathering, multi-stat math, match orchestration
beyond 1v1, ranked/guilds/trading/seasons, even the ability (shippable in update two). Small surface,
zero slack: every shipped piece must be excellent because there is nowhere to hide.

## 11. Carry-over manifest (from treyrees/rblx-auto-br)

**Port nearly whole** (game-agnostic, all unit-tested there): `Telemetry.lua` + the five
AnalyticsService families and funnel discipline; `LikeReminder.lua`; native favorite-prompt cadence;
`ReengageNotify.lua`/`PushSender.lua`/`NotifyOptIn.client.lua`; `StreakMath.lua` + streak profile
logic; `BadgeManager.lua`; the reveal/reward suite + PostGame ceremony patterns; `Persistence.lua`/
`Profile.lua` architecture; Lune headless test harness + `tools/design-lint.luau`; the
WORKFLOW.md/ADR discipline itself.

**Port with adaptation:** simultaneous-snapshot tick resolution (IS the pass); `StatCalculator`'s
derive(playerData, gear) shape with a small stat set; `ProcDispatcher`'s hook-point model for
horse/lance/ability effects; party (cap 2).

**Left behind:** Ring topology, 36/6/3 funnel + MatchDirector bracket, 6-stat/6-slot economy,
elimination stakes, the craft web as the front door.

## 12. Open questions (the honest list)

- ~~Proration curve shape~~ / ~~neutral as a Shield option~~ / ~~neutral baseline numbers~~ —
  settled by ADR 0001. What replaces them: the hold-fraction *distribution* real players produce. The
  sim's riders hold fixed fractions, so it cannot speak to this, and it is the most likely reason to
  reopen the curve.
- ~~Depleting coverage~~ / ~~the Supershield's magnitudes~~ — settled by ADR 0008 (Breaking, with
  momentum as the trigger and the mortal rung) and ADR 0009 (the Supershield is a state, not a
  price; 0005 superseded — its motivating anomaly was an instrument artifact, and no bonus can
  produce a mixed placement equilibrium). What replaces them:
  - **The ladder length and the momentum threshold** (`BREAK.MOMENTUM_THRESHOLD`, three-breaks-to-
    mortal): mortal currently ends ~0.8% of strikes. Whether it should be a rarity or an endgame
    clock is a gray-box question; shorten the ladder, not the threshold, if it moves.
  - **The spur's feel** — momentum is the entire "later" axis, and no headless instrument can test a
    thumb on a beat gate. First thing the gray box must validate by hand.
- **The aim distribution real players produce** — the sim's riders use fixed aim policies; the real
  distribution is the same blind spot as the hold-fraction one above, and it is what would reopen
  ADR 0006's scale or ADR 0008's threshold.
- Wager layer (raise/yield): in v1 or update two?
- The chase's faucet + acquisition loop + any idle layer (undesigned — the D1 half; own session).
- ~~Matchmaking: trophy gating vs stakes rooms~~ — settled by ADR 0002 with a third option neither
  listed: **horse-tier rooms**. The horse you bring is the room you are in. What replaces it: the
  speed-to-run-up-duration mapping per bracket, which `tools/sim.luau` cannot answer (it resolves
  commitments; the open question is how long a *human* needs to make one) and which needs a playtest
  instrument that does not exist yet.
- Match wrapper: is a "match" one duel to unhorse, or best-of-duels? Session rhythm target.
- The charge's kinesthetic/presentation layer (camera, sound ramp, crowd) — designed only by feel,
  in-engine.
- Does the mind game survive contact with the real population? (Random-mashing kids are unreadable
  noise → the game degrades to matrix-EV + slot machine at the median. Acceptable if reads emerge in
  ranked/older cohorts — the Pokémon shape — but verify: do playtesters start bluffing unprompted
  within ~10 matches?)
- Name / thumbnail / title-hook (platform-meta phrasing). **Working title: Turbo Jousting**
  (tentative). It reads well on platform — two words, a familiar intensifier plus the fantasy named
  outright, searchable and thumbnail-able — and since ADR 0002 it has mechanical backing rather than
  being packaging: bracket lanes make speed a real escalating axis, so the top bracket genuinely *is*
  the turbo one. **The caution that comes with it:** §2 positions this game as the comp's loop with
  the twitch *removed*, and "Turbo" promises speed that a chunk of players will read as *reflexes*.
  Store copy and thumbnails must lean "fast and dramatic", never "fast reflexes" — get that wrong and
  we recruit exactly the players most likely to bounce off a commit-based game, and the resulting D1
  numbers will look like a retention problem when they are a marketing-promise problem.

## 13. Milestone 1: the gray-box pass (and nothing else)

One pass, two riders, no art, no economy: wheel input with sector snapping, Shield commit,
polarization, both bonuses, the matrix, Balance + the teeter roll, post-pass reveal. Scripted rider
personalities stand in for opponents. **Success criteria:** (a) testers voluntarily say "one more";
(b) testers start bluffing unprompted within ~10 matches. Every downstream decision — the chase, the
ability, the pivot itself — gets cheaper the moment this exists. Resist putting anything else in it.
