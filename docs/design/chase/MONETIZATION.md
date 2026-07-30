---
maps-to: [src/shared/Constants.luau]
decisions: [0003]
owner: trey
updated: 2026-07-29
---

# MONETIZATION — the chase's commercial layer

> The deep monetization plan for Joust, produced from a three-lane comp survey (2026-07-29): the
> platform-standard progression meta, Untitled Boxing Game specifically, and the wider duel/collection
> comp set. Structural decision recorded in [ADR 0003](../decisions/0003-monetization-standard-meta.md).
> Nothing here ships in M1 (GAME_SPEC §13); this doc exists so the chase (§9) and the D1 economy get
> designed against a settled commercial skeleton instead of the other way round.

## 0. Doctrine: the biggest sin is reinventing the wheel

Every pattern below is proven at top-grossing scale on this platform or in this genre. Joust's
novelty budget is **fully spent on the pass** (the commit/read mechanic). The monetization layer
gets **zero novelty budget**: we ship the standard meta, arranged around our invariants, and we copy
price points, catalog shapes, and trust mechanics from games that have already run the experiment on
millions of players. Where two comps disagree, we take the one closer to our format (fast 1v1,
skill-marketed). Deviation from a proven pattern requires an ADR explaining why our situation is
actually different — the burden of proof is on the deviation, never on the copy.

Three invariants from [CLAUDE.md](../../../CLAUDE.md) are load-bearing here and predate this doc:

1. **Reads beat rarity** (invariant 1): money loads the dice, never buys immunity to being outplayed.
   This is the exact "acceptance line" the comp research found separating tolerated monetization
   (UBG, Rivals, Marvel Snap) from reputation-corroding monetization (late Clash Royale, Golf Clash
   clubs, 8 Ball Pool cues) in skill-marketed games.
2. **RNG is always visible** (invariant 6): published odds, visible pity, on-screen percentages. This
   was designed for the teeter roll, but it makes the entire gacha layer regulation-proof for free —
   odds disclosure is now mandated platform policy and converging law (Apple/Google, Korea, EU
   direction), so our invariant is a marketing asset, not a compliance cost.
3. **The matrix outweighs the dice** (invariant 7): any stat a purchase can influence is a
   combat-axis tuning number and must be sim-gated (ADR with `combat-axis: true` citing
   `tools/sim.luau`), exactly like ADR 0001's numbers.

## 1. The frame: what we are actually selling

The comp survey's unifying finding: the free loop manufactures friction (grind, odds, timers, FOMO
windows, expression scarcity) and every product is the sale of that friction's partial removal,
priced on a ladder so removal is never complete. Joust's native frictions, in order of commercial
value:

| Friction (free loop) | Product (its removal/upgrade) | Comp precedent |
|---|---|---|
| Horse acquisition odds (the vertical chase) | Luck boosts, premium eggs, pity ladders | PS99, Anime Vanguards |
| Lance/archetype variety (the horizontal chase) | Spins, slots, rate-up targeting | UBG styles |
| Soft-currency grind (antes, eggs, spins all sink it) | 2x currency pass, currency packs | universal |
| Expression in a televised duel | Taunts, unseat effects, pageantry cosmetics | TSB emotes, Rivals skins |
| Time/attention (later: any idle stable layer) | Auto/QoL passes | universal |

What we are explicitly **not** selling (the fence, §6): reads, aim, roll immunity, ranked prestige.

## 2. First pass: the standard incremental-progression meta (table stakes)

The near-universal catalog every top progression game ships. We ship all of it; none of it is
optional and none of it needs invention.

### 2.1 The permanent gamepass ladder

One SKU per price band so every wallet size has a "next purchase." Standard bands: impulse (≤200 R$,
buyable from a typical existing Robux balance), committed (300–500), invested (800–1200), whale
(2500+, exists partly to anchor the rest as cheap). Draft catalog:

| Pass | R$ (band) | Effect |
|---|---|---|
| 2x Gold | 399 | Doubles the soft-currency faucet. The canonical first pass; converts best everywhere because value is legible, permanent, and compounds with playtime. |
| Lucky | 275 | Permanent horse-egg luck tier 1. |
| Ultra Lucky | 800 | Permanent luck tier 2 (stacks). PS99's two-tier luck ladder, copied verbatim. |
| +2 Lance Slots | 149 each ×2 | UBG's extra style slots, remapped. Slots are scarcity sold sideways: the right to keep more of what you already pulled. |
| Stable Room (+capacity) | 375 | Extra horse capacity; the "+pets" pass remapped. |
| VIP | 449 | Bundle: chat tag, lobby flourish, small daily premium drip, private-server perk. |
| Multi-Spin / Skip Animation | 99 / 25 | UBG's convenience micro-passes, copied verbatim. |
| Signature flex pass (e.g. Dual Barding, custom unseat sound) | 199–399 | Cosmetic flex; UBG's Dual Gloves / Custom Sounds pattern. |

Auto-farm passes are deferred until an idle/stable-tending layer exists to automate (GAME_SPEC §9
leaves it undesigned); when it exists, the auto pass is table stakes there too.

### 2.2 Dev products (the recurring layer)

Gamepasses front-load revenue; consumables carry mature-game revenue. Standard split, no deviation:

- **Gold packs** (soft currency), 5–6 quantity tiers with escalating bonus percentages and a decoy
  top tier (PS99 bundle shape).
- **Egg/spin bundles**, ditto.
- **Luck potions** (timed consumable luck, stacks with the passes), ~99/199 R$ (Anime Vanguards
  shape). Selling luck rather than the horse keeps the slot machine intact and the invariant clean.
- **Starter pack**: 99–199 R$, one-time, first-session surfaced, countdown-timed, containing gold +
  an exclusive cosmetic-leaning horse. Near-universal; converts during peak novelty. The research's
  key stat: ~95% of Robux buyers buy more than once, so the entire job is the *first* conversion.
- **Escalating personalized offer** (PS99 Forever Pack shape — weekly rotating, price scales with
  spend history): flagged as a later-phase product; requires offer infrastructure, not launch-blocking.

### 2.3 Currency architecture

Standard multi-currency, one sink per currency so each is tunable (and sellable) independently:

- **Gold** (soft): faucet = passes ridden, wins, the post-match wheel, quests, codes, rank
  milestones. Sinks = **antes** (§4.3), horse eggs, lance spins, cosmetic crates. Priced directly in
  R$ at point of sale for top-ups (pet-sim convention — skip an intermediate premium currency;
  players already hold Robux and extra abstraction just adds friction).
- **Spins** as item-currency (UBG convention): quantized, giftable in codes, droppable from the
  wheel — item-currencies read as gifts, not numbers.
- **Shards** (long-tail dust): drip from dupes and wins; fixed-price redemption for a chosen
  cosmetic variant (UBG's 500-shard shiny). This is the dupe floor — every dupe has nonzero value.
- Trading currency: **deferred with trading itself** (§5.4).

### 2.4 The engagement-loop hooks (free tier, feeds discovery)

All standard, all carried or cheap: group-join boost + chat tag; like/favorite reminder cadence
(`LikeReminder.lua`, ported); promo codes as the creator/SEO channel (UBG's biggest ongoing
marketing loop); daily login streaks (`StreakMath.lua`, ported); global rare-hatch broadcasts
("X just pulled a MYTHIC destrier" server-wide — free in-game advertising for the egg, universal in
pet sims); private servers at ~99–299 R$/month (minor revenue, standard offering); Premium-player
perk gating (+payout share incentive).

### 2.5 Event cadence

The content cadence *is* the purchase cadence: ~2-week limited events with event-exclusive eggs,
event quests, and event cosmetics that do not return (PS99/UBG cadence). Season/battle pass at the
canonical 799 R$ is a **later-phase** product (§7) — it needs a live content pipeline behind it, and
BedWars is the cautionary tale for pass-gating gameplay content.

## 3. Second pass: the UBG import (the format-fit layer)

UBG is the gold-standard comp (GAME_SPEC §2) and its monetization is the proven answer to our exact
problem: monetizing a fast, skill-marketed 1v1 where the community will torch any paid advantage.
Its store page literally advertises "not pay-to-win" and the community agrees. We import the whole
trust stack:

1. **Gacha the identity layer, never the matrix.** UBG's styles are shallow-stat, all-viable,
   free-obtainable; rarity buys *cool*, skill decides matches. Mapping: **lances are our styles** —
   horizontal matrix-personality spread, gacha'd via spins, stat deltas shallow and sim-gated.
   Horses carry the vertical chase instead (§4.1), which UBG lacks — that's our tycoon-grade
   addition, and it's exactly the §2 "twist" the spec already claims.
2. **The trust stack, copied verbatim:** published odds on every egg/spin table; **visible pity
   counter, guarantee ≤100 spins** for top rarity; **rate-up targeting** (pre-select a hoped-for
   legendary: 1% → 3%) as soft dupe protection; premium spin tiers that roll only high rarities
   (lucky spins: 25% legendary / 75% mythic) rather than different items.
3. **Slots as the scarcity lever:** rerolling overwrites unless you own slots → slots become a
   most-wanted purchase without touching power.
4. **The post-match reward wheel, win or lose.** The retention/monetization hinge for a fast loop:
   every sub-two-minute match ends in a variable-ratio drop (gold, spins, rare cosmetic chance,
   shard drip). This slots directly into our PostGame ceremony patterns (ported per §11) and feeds
   every sink in §2.3.
5. **Prestige is earned-only.** Ranked gloves/titles in UBG cannot be bought; that's why the top of
   the status ladder reads as credibility. Same rule here: ranked barding, champion titles, tourney
   laurels are never for sale, ever.
6. **Cash-per-spin pricing** (spins buyable with earned gold at a fixed rate) so free players are
   never spin-starved and the gacha reads as honest.

## 4. Third pass: the rest of the comp set (targeted imports)

### 4.1 The vertical chase: PS99 egg economy on horses

Horses are the tycoon chase UBG lacks (GAME_SPEC §2, §9). Import the pet-sim egg loop wholesale:
rarity ladder with a **status tier at the top** (the "huge/titanic" analog — call it the
*destrier/mythic* tier: visually oversized/resplendent, lottery odds, global broadcast on hatch,
the trading asset if trading ever ships); luck stacking (passes × potions × event boosts ×
group-join); **Robux-exclusive rotating limited eggs** whose horses never return (PS99's signature
move — FOMO + collection + future trading value in one SKU).

**The Joust-specific constraint the pet sims don't have:** horse stats are combat numbers (max
Balance, soak, recovery — GAME_SPEC §6). The rarity→stat curve is therefore a combat axis. Two
bounds pin it: (a) invariant 1 read literally — sim-verify that a correct read beats the rarest
horse on the flattest read edge we ship; (b) ADR 0001's convergence band (3.32 passes, little
slack) — every rarity stat delta gets re-simmed, not eyeballed. Marvel Snap's flat-power stance
(sell breadth and art, not bigger numbers) is the fallback posture if tuning can't hold the line:
higher tiers widen the *odds profile variety* (different dice shapes, clutch-recovery fantasy)
rather than strictly better dice.

### 4.2 The expression economy: TSB taunts + Rivals cosmetics, televised by design

Two structural facts make cosmetics unusually valuable in Joust, and the comps prove each half:

- **TSB** does top-15 grossing on 25 R$ emotes alone: in PvP, humiliation/expression *is* the
  product. In a mind-game duel, taunts are also gameplay-adjacent (tilt induction between passes).
  Product line, not afterthought: taunts, victory laps, horse rears, lance salutes, unseat
  celebrations at 25–100 R$ micro-price points, hundreds of SKUs over time, limited FOMO drops.
- **Rivals** proves a competitive audience pays shooter-scale money for pure-cosmetic cases
  (249 R$ case → ~700 R$ bundle → ~5000 R$ prestige key ladder). Our format multiplies this: the
  lobby is a tilt-yard where **waiting is spectating** (GAME_SPEC §8) — barding, caparisons, lance
  skins, charge trails, and unseat effects (the teeter is the signature clip; its VFX is prime SKU
  real estate) all perform to a guaranteed rail audience every single pass. Cosmetic crates use the
  Blade Ball premium-odds pattern: premium tier sells better odds on the same pool, never different
  items.

### 4.3 The ante economy: 8 Ball Pool's sink, with the pipes kept separate

GAME_SPEC §8 already commits to "loss costs an ante, never a session," and matchmaking is settled
as **horse-tier rooms** (ADR 0002): the horse you bring is the room you are in. 8 Ball Pool is the
canonical proof for the ante itself: entry-fee rooms laddered from trivial to aspirational, winner
takes the pot minus rake, make the wager currency self-renewingly scarce and every match feel like
poker — a perfect thematic fit for a game whose core layer *is* a poker hand. Here the ante ladder
maps onto the horse-tier brackets: higher brackets carry higher stakes, so the bracket climb (the
chase) and the stakes climb (the sink) are the same aspiration.

The comp's failure mode is equally clear (8BP cues, Golf Clash clubs): the ante economy metastasizes
into pay-to-win when the same currency feeds both stakes and power. Our pipe-separation rule:
**gold buys antes and pulls on chases; nothing bought with gold or Robux modifies the matrix, the
roll, or information.** Loss-streak top-up pressure (buying gold at the moment of highest emotion)
is accepted — that's buying more attempts at the slot machine and the poker table, which is the
platform-standard sale — but the table itself is never tilted.

Horse-tier rooms already stratify matchmaking (ADR 0002); scaling antes by bracket gets the
8 Ball Pool sink for free without adding a second room system.

### 4.4 Horse attachment: the Star Stable hedge and the breeding sink

- **Star Stable** proves horse-attachment supports *direct* premium purchase (~$15–25/horse, no
  gacha) for a young audience. Hedge: alongside the egg chase, keep a small rotating **direct-buy
  stable** (a named horse, bought outright, cosmetic-forward). Attachment monetizes better as
  certainty than as a slot machine, and a direct-buy path is also the gacha-fairness "ceiling is
  reachable" release valve.
- **Rival Stars** breeding — two owned horses in, RNG foal out, lineage as narrative — is the
  natural **v2 dupe sink** and long-tail chase: a gacha where the player authors the roll, which
  lands far softer than banner pulls. Explicitly post-launch (scope doctrine); recorded here so the
  egg system reserves dupes (don't auto-delete; dust to shards now, breeding stock later).

### 4.5 The cautionary tales (what we refuse)

- **Late Clash Royale** (card levels, Evolutions): power progression in a skill-marketed 1v1
  permanently flipped the community narrative. Structurally our nearest mobile comp, and our most
  important negative example. We take its Pass Royale era (praised, out-earned loot boxes) and
  refuse its card-level era.
- **Golf Clash / 8BP cues**: wager pressure funding stat upgrades — the pipe-separation rule (§4.3)
  exists because of these two.
- **BedWars**: pass-gating gameplay kits → balance treadmill + community friction + revenue decay.
  Our battle pass, when it ships, is cosmetic/currency/booster only.
- **Blade Ball abilities**: selling gameplay-affecting items "with a fig leaf of earnability" works
  commercially but buys permanent P2W discourse. Our abilities (GAME_SPEC §6) are earned, not sold.
- **Trading, for now** (MM2/Adopt Me/PS99): the biggest revenue multiplier where present (exclusives
  become appreciating assets; endgame trade metagame retains maxed players at zero content cost) and
  the biggest scope/moderation commitment (anti-dupe, anti-scam, RMT, policy scrutiny). Violates the
  scope doctrine at launch. Deferred, not rejected — the §4.1 limited eggs and status tier are
  designed to be trading-compatible later.

## 5. The fence: what money can never buy

The single sentence every SKU is checked against (invariant 1): *skill is the trump suit; money buys
better odds, never immunity to being outplayed.* Concretely, never for sale at any price, in any
bundle, under any event:

1. **Information**: opponent's passive guard, aim tendencies beyond the public matchup data everyone
   gets, any peek not equally available free.
2. **The matrix**: damage tiers, punish ratios, proration, bonuses.
3. **The roll**: no purchased rerolls, no stay-mounted consumables, no revives. (The one-shot
   ability in §6 of the spec may touch rolls — which is exactly why abilities are earned-only.)
4. **Ranked prestige**: rank cosmetics, titles, laurels are earned-only forever.
5. **Undisclosed odds**: every random purchase ships with published tables, pity, and rate-up —
   invariant 6 applied to the store.

What money *does* buy: time (multipliers, spins, gold), odds-on-the-chase (luck), breadth (slots,
capacity), and expression (the entire §4.2 line). Rarity's stat edge exists (that's the chase's
point) but is bounded by the sim gate in §4.1.

## 6. Sequencing (scope doctrine applied)

| Phase | Ships | Rationale |
|---|---|---|
| **M1** | Nothing. | GAME_SPEC §13: the gray-box pass, and nothing else. Monetization designed-not-built. |
| **M2 (chase v1)** | Gold + antes + post-match wheel; horse eggs (small: handful × 3 rarities, published odds, pity); lance spins + slots; the §2.1 pass ladder; starter pack; codes/group/like hooks; global hatch broadcast. | The minimum standard meta: one vertical chase, one horizontal chase, one soft currency, the trust stack from day one (retrofitting trust is impossible). |
| **Update 2+** | Taunt/emote line at scale; cosmetic crates; limited rotating eggs; ~2-week event cadence; luck potions; direct-buy stable; private servers; VIP. | Each is a proven standalone SKU line; cadence starts when the loop is proven. |
| **Post-launch** | Battle pass (799 R$, cosmetic/booster only); escalating personalized offers; breeding (dupe sink); trading + trading currency (own design session, own ADR). | Each needs infrastructure or a live population to be worth building. |

## 7. Telemetry (the ported stack, pointed at money)

`Telemetry.lua` + the five AnalyticsService families port from the predecessor (GAME_SPEC §11).
Monetization-specific funnels to instrument from M2 day one: starter-pack view→buy; first-purchase
timing vs session count; egg pulls per session by luck tier; pity-counter distribution at purchase
moments; ante-room ladder occupancy; wheel-drop → spin-spend latency; payer conversion and repeat
rate (platform baseline: mid-single-digit payer conversion; ~95% of buyers repeat). Roblox
economics for planning: ~30% marketplace fee, DevEx $0.0038/R$ (rising for verified-18+ US spend) —
net roughly 25–30¢ per player dollar, so the model is volume-and-conversion, never margin.

## 8. Open questions (feed §12 of the spec)

- Ante ladder sizing per horse-tier bracket (§4.3): matchmaking is settled (ADR 0002, horse-tier
  rooms); the per-bracket ante values and rake are economy-session numbers.
- The rarity→stat curve and the read-edge floor under it: needs its own `combat-axis: true` ADR with
  a sim run before any egg ships (§4.1).
- Egg pricing/pull-rate numbers, gold faucet sizing, ante ladder values: undesigned; they depend on
  M1 telemetry about real match length and session shape. Constants land in
  `src/shared/Constants.luau` when designed.
- Does the direct-buy stable cannibalize eggs, or lift them (Star Stable evidence says attachment
  spend is additive)? A/B when live.
- Name the currencies (player-facing copy; no em dashes).

## Appendix: research provenance

Three-lane survey, 2026-07-29. Lane 1 (standard meta): PS99/PSX, Adopt Me, Bee Swarm, Blox Fruits,
Arm Wrestle Sim, Anime Vanguards, Grow a Garden — catalog shapes, price bands, luck stacking, Forever
Pack, trading economics, DevEx math. Lane 2 (UBG deep-dive): spin odds (1% legendary, pity ≤100,
1%→3% rate-up, lucky spins 25/75), full gamepass table (25–399 R$, zero power), cash-per-spin, wheel,
shiny shards, earned-only ranked prestige. Lane 3 (comp set): Blade Ball, Rivals, TSB, BedWars, Clash
Royale arc, 8 Ball Pool, Marvel Snap, Super Auto Pets, Golf Clash, Star Stable, Rival Stars,
Genshin-pattern pity, odds-disclosure regulation. Primary sources: game wikis (Fandom/Miraheze),
Rolimon's/RoMonitor/RoWatcher, Naavik/Deconstructor of Fun/Mobile Dev Memo deconstructions, Roblox
DevEx docs and devforum.
