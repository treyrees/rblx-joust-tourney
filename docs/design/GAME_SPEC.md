---
maps-to: [src/shared/Constants.luau, src/shared/PassResolver.luau]
decisions: [0001]
owner: trey
updated: 2026-07-29
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
  1. Progression and matchmaking rise together (trophy gating or stakes rooms — decide once).
  2. An ante per match makes short rounds meaningful.
  3. **Async ghosts are the population cheat code** — a ghost is just a guard choice + an aim trace;
     mechanically indistinguishable from a live opponent. **Ghost-first is plan-of-record** (Thing 0).
  4. The mind game comes from a wager/commit layer, not mechanical inputs.
  5. Best-of-N turns RPS into yomi (earlier passes teach habits).
- **The meta/creator layer is a design target, not a byproduct.** A demonstrated analytical-content
  audience exists for the comp. Requirements: an enumerable system (matchup charts must fit in a
  thumbnail), a post-pass reveal of both commitments, and player-facing matchup data. Decision-based
  meta content transfers to every viewer (unlike execution content) — this is our structural edge.

## 3. The pass (the core mechanic)

**Directions:** four, self-relative — **in / out / up / down** (self-relative framing avoids the
mirrored-pass left/right ambiguity) — plus **neutral**, a legitimate state and the default.

**Phase 1 — Intermission (private commit):** pick your **passive guard** direction. Hidden until impact.

**Phase 2 — Run-up (one public input):** steer the **spear aim** on a circular touch wheel
("iPod wheel"), **quantized to the four sectors** with hard snapping (the televised state is always
one of four clean values; the spear may animate smoothly between them, the *state* is discrete).
Aim is fully televised to the opponent and spectators.

- **Polarization (automatic):** your **active guard** is always opposite your aim. Aim out → guard in.
  One input carries attack AND defense; you cannot aim at their weakness without configuring your own
  exposure. (For Honor's turtling failure is dodged because defense is never free or independent.)
- **Neutral is the opening state for everyone** — so the spawn frame leaks nothing, and *when you
  first leave neutral is itself a tell* (bet-timing; the run-up has poker streets for free).

**The two bonuses (priced signaling):**
- **Defensive bonus — binary:** awarded iff active guard (opposite of final aim) matches the passive
  guard at the tick ("**stacking**"). Stack = one direction defended deeply; split = two directions
  covered thinly with no bonus. **Depth-vs-breadth is a named strategic axis.**
- **Offensive bonus — prorated:** scales with the fraction of the run-up you held your *final* aim
  direction. The buildup meter is **public** — the crowd watches your commitment charge. A late
  switch is the bluff, and it has a mechanical price (reset buff = weaker strike), not just an
  informational one. **Proration curve: linear** (ADR 0001). The floor+ease-in lean recorded here
  originally was overturned by the sim: a floor collapses a half-held aim to within a point of a pure
  last-instant flick, which turns the bluffing spectrum into a binary. Linear keeps the meter
  readable as a dial and still costs the flicker 8 points of win rate.

**Information architecture (three layers):** public offense meter + televised aim → inferable active
guard → hidden passive guard (the hole card), revealed at impact. Every pass is a readable poker hand.

**Guardrails:**
- **Aim locks a few tenths before the tick** — decision timing, never a ping war (UBG's ping meta is
  the cautionary tale).
- **Beginners must be able to ignore every layer** — guard somewhere + aim somewhere is complete,
  legal jousting. The signaling game is emergent depth, never required literacy. Protect this in tuning.

**Neutral baseline (settled by ADR 0001):**
1. Neutral aim at the tick → weak center strike, no punish potential, zero honesty buff
   (survivable, not viable). In the sim, neutral-camping ranks last of nine strategies.
2. Neutral active guard → none (maximally soft; cageyness is priced by softness + proration tax).
3. Neutral as a passive guard → legal, and it covers nothing. It cannot stack, so it forfeits the
   defensive bonus and leaves coverage at a single direction: a real option that is never a good one.

## 4. Resolution: the matrix, Balance, and the unhorse roll

> Implemented and pinned: [pass/RESOLUTION.md](pass/RESOLUTION.md) is the deep doc, ADR 0001 the
> decision. Punish keys off the **active** guard, so the rule reads *you are exposed exactly where you
> strike*; a punish is 3x a normal.

**The matrix beat (deterministic — the gameable layer):** aim vs guard resolves to an outcome tier —
**blocked / normal / punished** (punished = struck opposite your guard). Tiers translate to **Balance
damage**, modified by lance stats, honesty bonus, cracked guards, and abilities. A clean block grants
the defender a small Balance restore (blocking is a win, not a non-loss) — capped well below typical
hit damage so convergence never stalls.

**The roll beat (the slot machine):** both riders carry a public **Balance meter (0–100)**. Anyone hit
this pass **rolls against current Balance to stay mounted** — at 80 Balance, 80% stay-on. The roll is
diegetic: the rider **teeters in slow motion** with the live percentage shown, and recovers or goes
into the dirt. **Unhorsed = match over.** The teeter-and-recover at low odds is the signature clip.

**Why this shape:** converges by construction (Balance only trends down; tune for 3–5 passes average);
anyone can win any pass (upsets are jackpots, not bugs); RNG is exactly where intended and printed on
screen (every loss decomposes to "read" or "roll" — visible-odds RNG is the rage-proof kind); public
meters fuel endgame bluffing (a 20-Balance opponent HAS to gamble, and everyone knows it).

**THE INVARIANT: reads resolve deterministically; survival resolves stochastically; rarity loads the
dice — and a correct read always beats a rarer horse.** Skill is the trump suit; money buys better
odds, never immunity to being outplayed. Everything downstream (matchmaking, monetization, meta
content) hangs off this sentence.

**Tuning guardrail:** the punished tier must usually force a genuinely scary roll — the matrix must
matter more than the dice on average, or the read game dies and it's only a slot machine.

## 5. Escalation & win condition

- Balance attrition is the primary convergence engine (§4).
- **Depleting guards (candidate, favored):** each direction's guard takes armor damage when struck;
  repeatedly used guards crack, then break for the match. Forces conclusion mechanically AND
  generates escalating information (a broken up-guard narrows your real options — later passes get
  sharper reads exactly when the match needs to end). Imports UBG's "defense is a depleting
  resource, never a safe default."
- Optional dramatic layers: rising per-pass wager (Snap-style raise/yield — diegetic as raising the
  lance / yielding before the charge), shortened aim window in sudden death.

## 6. Stat surfaces (everything plugs into §4's numbers)

- **Horse (vertical, rarity, the chase):** max Balance, damage soak, and **recovery** (bonus to the
  teeter roll — the rarest horses are the *clutch* horses; better fantasy than damage sponge).
- **Lance (horizontal, playstyle, native hotbar):** Balance damage profile + matrix personality
  (heavy lance = harder normals; fine lance = doubled punish tier; etc.).
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
reveal** ("you leaned HIGH, they braced LOW — counter!") turns every loss into a lesson and every
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

- ~~Proration curve shape~~ / ~~neutral as a passive-guard option~~ / ~~neutral baseline numbers~~ —
  settled by ADR 0001. What replaces them: the hold-fraction *distribution* real players produce. The
  sim's riders hold fixed fractions, so it cannot speak to this, and it is the most likely reason to
  reopen the curve.
- Depleting guards: confirm as the escalation mechanism; tune crack/break thresholds. These change
  the coverage rule, so they need their own ADR and their own sim run.
- Wager layer (raise/yield): in v1 or update two?
- The chase's faucet + acquisition loop + any idle layer (undesigned — the D1 half; own session).
- Matchmaking: trophy gating vs stakes rooms (decide once, per §2.1).
- Match wrapper: is a "match" one duel to unhorse, or best-of-duels? Session rhythm target.
- The charge's kinesthetic/presentation layer (camera, sound ramp, crowd) — designed only by feel,
  in-engine.
- Does the mind game survive contact with the real population? (Random-mashing kids are unreadable
  noise → the game degrades to matrix-EV + slot machine at the median. Acceptable if reads emerge in
  ranked/older cohorts — the Pokémon shape — but verify: do playtesters start bluffing unprompted
  within ~10 matches?)
- Name / thumbnail / title-hook (platform-meta phrasing).

## 13. Milestone 1: the gray-box pass (and nothing else)

One pass, two riders, no art, no economy: wheel input with sector snapping, passive-guard commit,
polarization, both bonuses, the matrix, Balance + the teeter roll, post-pass reveal. Scripted rider
personalities stand in for opponents. **Success criteria:** (a) testers voluntarily say "one more";
(b) testers start bluffing unprompted within ~10 matches. Every downstream decision — the chase, the
ability, the pivot itself — gets cheaper the moment this exists. Resist putting anything else in it.
