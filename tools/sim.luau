--!strict
-- sim.luau — the headless pass simulator. Run from the repo root:
--     lune run tools/sim.luau [--matches N] [--seed S] [--curve linear|ease_in|floor_ease_in]
--
-- This is the instrument the WORKFLOW's combat-axis rule points at: no tuning number in
-- Constants.MATRIX / Constants.PRORATION gets pinned by an ADR until a run of this tool is cited in
-- that ADR's Consequences. It answers the three questions the design actually asks of the numbers:
--
--   1. Does the match CONVERGE on schedule?   GAME_SPEC §4 wants 3–5 passes on average.
--   2. Does the MATRIX outweigh the DICE?     CLAUDE.md invariant 7. Measured as the win rate of a
--                                             perfect reader against a random one — if reading well
--                                             barely beats mashing, the numbers are wrong.
--   3. Is NEUTRAL-CAMPING punished?           Also invariant 7. The camper must not sit near the top
--                                             of the round-robin table.
--
-- It drives src/shared/PassResolver.luau through the same robloxenv shim the unit tests use, so the
-- numbers it reports come from the exact source Rojo syncs into Studio.

local process = require("@lune/process")
local roblox = require("../tests/lib/robloxenv")

roblox.build("./src")
local Constants = roblox.requireShared("Constants")
local PR = roblox.requireShared("PassResolver")

local D = Constants.DIRECTIONS
-- The playable directions, filled in after the arguments are read because --notches can replace the
-- cycle. The shipped wheel is the eight-notch cycle of ADR 0006; other sizes exist so the instrument
-- can price them. (The name FOUR predates the eight-notch decision and means "the committed, non-
-- neutral directions".)
local FOUR: { string } = {}
local MAX_PASSES = 30 -- a match this long is a convergence failure, and is reported as one

-- ---- args --------------------------------------------------------------------------------------
-- 8000 matches per pairing over 66 pairings is ~530k matches: ample for verdicts whose thresholds
-- are coarse (a 3-5 pass band, a 75% read edge, a 50% long-shot share, a rank). The default was
-- 20000, chosen when the round robin was 36 pairings and the oracle searched four aims instead of
-- every aim-and-shield pair; at that size the gate had grown to over two minutes. Pass --matches for
-- a tighter run when pinning a number.
local matches, seed = 8000, 20260729
do
	local args = process.args
	local i = 1
	while i <= #args do
		local a = args[i]
		if a == "--matches" then
			matches = tonumber(args[i + 1]) or matches
			i += 2
		elseif a == "--seed" then
			seed = tonumber(args[i + 1]) or seed
			i += 2
		elseif a == "--curve" then
			Constants.PRORATION.CURVE = args[i + 1]
			i += 2
		elseif a == "--notches" then
			local n = tonumber(args[i + 1]) or #Constants.CYCLE
			if n ~= #Constants.CYCLE then
				local cycle = {}
				for k = 1, n do
					cycle[k] = "n" .. tostring(k - 1)
				end
				Constants.CYCLE = cycle
				Constants.RING = {}
				for k = 0, n - 1 do
					Constants.RING[k] = "normal"
				end
			end
			i += 2
		elseif a == "--breaking" then
			Constants.BREAK.ENABLED = true
			i += 1
		elseif a == "--ss-hold" then
			Constants.SUPERSHIELD_MIN_HOLD = tonumber(args[i + 1]) or 0
			i += 2
		elseif a == "--mortal" then
			Constants.BREAK.MORTAL = true
			i += 1
		elseif a == "--swap" then
			Constants.BREAK.TRIGGER = "proration"
			i += 1
		elseif a == "--break-momentum" then
			Constants.BREAK.MOMENTUM_THRESHOLD = tonumber(args[i + 1]) or 0.6
			i += 2
		elseif a == "--ss-restore" then
			Constants.MATRIX.SUPERSHIELD_RESTORE = tonumber(args[i + 1]) or 2
			i += 2
		elseif a == "--ss-bonus" then
			Constants.MATRIX.SUPERSHIELD_STRIKE_BONUS = tonumber(args[i + 1]) or 0
			i += 2
		elseif a == "--shield-mode" then
			Constants.SHIELD_MODE = args[i + 1]
			i += 2
		elseif a == "--guard-mode" then
			Constants.GUARD_MODE = args[i + 1]
			i += 2
		elseif a == "--shield-band" then
			Constants.SHIELD_BAND = tonumber(args[i + 1]) or 1
			i += 2
		elseif a == "--ring" then
			-- One letter per notch offset from the defender's own aim: C=crit G=guard N=normal. Lets a
			-- candidate ring from tools/rings.luau be played out over real matches rather than only
			-- solved in one shot.
			local FROM = { C = "crit", G = "guard", N = "normal" }
			local code = args[i + 1]
			-- One letter per notch. Bounded by the code's own length, not by four: hardcoding four
			-- here silently truncated every larger ring and left its tail as "normal".
			if #code ~= #Constants.CYCLE then
				error(string.format(
					"--ring %q has %d letters but the cycle has %d notches (pass --notches first)",
					code, #code, #Constants.CYCLE))
			end
			for k = 0, #code - 1 do
				local cls = FROM[code:sub(k + 1, k + 1):upper()]
				if not cls then
					error("bad --ring code: " .. tostring(code))
				end
				Constants.RING[k] = cls
			end
			i += 2
		else
			i += 1
		end
	end
end

-- The cycle is settled now, so the playable direction list can be built.
for _, dir in Constants.CYCLE do
	table.insert(FOUR, dir)
end

-- ---- deterministic RNG -------------------------------------------------------------------------
-- A plain LCG rather than math.random, so a cited run is reproducible from its seed alone — an ADR
-- that quotes a number here can be re-derived exactly.
local function makeRng(s: number): () -> number
	local st = s % 2147483647
	if st <= 0 then
		st += 2147483646
	end
	return function(): number
		st = (st * 16807) % 2147483647
		return (st - 1) / 2147483646
	end
end
local rng = makeRng(seed)

local function pick(list: { string }): string
	return list[math.floor(rng() * #list) + 1]
end

-- ---- strategies --------------------------------------------------------------------------------
-- Each strategy commits from what a real player could actually see: their own meter, the opponent's
-- meter, and the revealed history of past passes (§8's post-pass reveal makes guards public AFTER
-- impact). `oracle` is the deliberate exception — it is a measuring instrument, not a player.
type Ctx = {
	selfBalance: number,
	oppBalance: number,
	oppAims: { string }, -- opponent's revealed aim, oldest first
	oppShields: { string }, -- opponent's revealed Shield, oldest first
	oppCommit: any?, -- clairvoyant strategies only
}

type Strategy = {
	name: string,
	clairvoyant: boolean?,
	commit: (Ctx) -> any,
}

-- Ring-relative helpers. The three shapes GAME_SPEC §3 names — depth, breadth, split — are defined
-- against whatever Constants.RING currently says, not against the assumption that the Guard is
-- opposite and the Crit is your own aim. That assumption is exactly what tools/rings.luau is testing.
local function guardOf(aim: string): string
	return PR.guards({ shield = D.NEUTRAL, aim = aim, holdFraction = 1 })[1] or pick(FOUR)
end

local function critOf(aim: string): string
	return PR.crits({ shield = D.NEUTRAL, aim = aim, holdFraction = 1 })[1] or pick(FOUR)
end

local function mostFrequent(list: { string }): string?
	if #list == 0 then
		return nil
	end
	local counts: { [string]: number } = {}
	local best, bestN = nil, 0
	for _, v in list do
		counts[v] = (counts[v] or 0) + 1
		if counts[v] > bestN then
			best, bestN = v, counts[v]
		end
	end
	return best
end

local STRATEGIES: { Strategy } = {
	-- The floor: unreadable noise. Everything else is measured against this.
	{
		name = "random",
		commit = function(_ctx)
			return { shield = pick(FOUR), aim = pick(FOUR), holdFraction = rng() }
		end,
	},
	-- Neutral-camping: never commits an aim. Invariant 7 says this must not be viable.
	{
		name = "camper",
		commit = function(_ctx)
			return { shield = pick(FOUR), aim = D.NEUTRAL, holdFraction = 1 }
		end,
	},
	-- Always supershields: Shield stacked on a direction the Aim already guards. Maximum depth, and
	-- it leaves whatever the ring exposes wide open.
	{
		name = "supershield",
		commit = function(_ctx)
			local aim = pick(FOUR)
			return { shield = guardOf(aim), aim = aim, holdFraction = 1 }
		end,
	},
	-- Always plugs its own Crit with the Shield. The safe, bonus-less shape — and under today's ring
	-- the one that beats even the oracle, which is what put the ring itself under suspicion.
	{
		name = "axis",
		commit = function(_ctx)
			local aim = pick(FOUR)
			return { shield = critOf(aim), aim = aim, holdFraction = 1 }
		end,
	},
	-- Commits early and never flinches: full honesty bonus, fully readable.
	{
		name = "honest",
		commit = function(_ctx)
			return { shield = pick(FOUR), aim = pick(FOUR), holdFraction = 1 }
		end,
	},
	-- Always flicks at the last instant: unreadable, but pays the full proration tax.
	{
		name = "flicker",
		commit = function(_ctx)
			return { shield = pick(FOUR), aim = pick(FOUR), holdFraction = 0 }
		end,
	},
	-- Shows an aim, then switches at the halfway mark: the archetypal bluff. The proration curve
	-- exists to price exactly this, so `halfer` is what separates the three candidate shapes — the
	-- honest/flicker endpoints alone cannot, since every curve pins 0 and 1 to the same values.
	{
		name = "halfer",
		commit = function(_ctx)
			return { shield = pick(FOUR), aim = pick(FOUR), holdFraction = 0.5 }
		end,
	},
	-- Spends the run-up spurring instead of holding: no honesty bonus at all, but enough momentum to
	-- break a slice on anything that lands. The pure "later" line.
	{
		name = "spurrer",
		commit = function(_ctx)
			local aim = pick(FOUR)
			return { shield = critOf(aim), aim = aim, holdFraction = 0, momentum = 1 }
		end,
	},
	-- Splits the run-up: half the honesty bonus, and just enough momentum to break.
	{
		name = "splitter",
		commit = function(_ctx)
			local aim = pick(FOUR)
			return { shield = critOf(aim), aim = aim, holdFraction = 0.4, momentum = 0.6 }
		end,
	},
	-- The double-dip the design has to answer for: spurs the entire run-up for full momentum, then
	-- snaps into the aim whose Guard lands on its pre-placed Shield at the tick. Under the shipped
	-- rule that buys breaking AND a free Supershield, paying only the damage multiplier. This is the
	-- strategy Constants.SUPERSHIELD_MIN_HOLD exists to price.
	{
		name = "opportunist",
		commit = function(_ctx)
			local aim = pick(FOUR)
			return { shield = guardOf(aim), aim = aim, holdFraction = 0, momentum = 1 }
		end,
	},
	-- Plays the read: strikes where the opponent's habits say their Crit will be, and guards the
	-- direction they most often strike. This is the realistic skilled player.
	{
		name = "counter",
		commit = function(ctx)
			local theirAim = mostFrequent(ctx.oppAims)
			-- Strike where their habitual aim leaves them exposed, which under a general ring is not
			-- necessarily the direction they are aiming.
			local aim = if theirAim and theirAim ~= D.NEUTRAL then critOf(theirAim) else pick(FOUR)
			return { shield = critOf(aim), aim = aim, holdFraction = 0.9 }
		end,
	},
	-- The ceiling, not a player: sees the opponent's commitment and picks the best aim against it.
	-- Its win rate over `random` is the headline measure of how much reading is worth (invariant 7).
	{
		name = "oracle",
		clairvoyant = true,
		commit = function(ctx)
			local opp = ctx.oppCommit
			if not opp then
				return { shield = pick(FOUR), aim = pick(FOUR), holdFraction = 1 }
			end
			-- A true best response: search BOTH inputs and score on net Balance, not on damage dealt.
			-- Scoring the strike alone made the oracle walk into crits under rings where the aim
			-- carries most of the exposure, which understated those rings rather than the oracle.
			local best, bestNet = nil, -math.huge
			for _, aim in FOUR do
				for _, shield in FOUR do
					local me = { shield = shield, aim = aim, holdFraction = 1 }
					local dealt = PR.strikeDamage(me, opp)
					local taken = PR.strikeDamage(opp, me)
					if dealt - taken > bestNet then
						best, bestNet = me, dealt - taken
					end
				end
			end
			return best
		end,
	},
}

-- ---- one match ---------------------------------------------------------------------------------
type Tally = {
	tiers: { [string]: number },
	passes: number,
	totalPasses: number,
	timeouts: number,
	-- Attrition-vs-dice: the Balance a rider was actually sitting on when they went down, and how
	-- often that fall came off a roll they were heavily favoured to make. A match that ends at 90
	-- Balance was decided by the dice no matter how good the read edge looks in aggregate, so these
	-- two are the real test of CLAUDE.md invariant 7.
	unhorses: number,
	totalUnhorseBalance: number,
	longShotFalls: number,
	-- Where on the meter riders actually go down. "Bring the number to zero" is the natural way to
	-- describe a health bar, and it is not what this meter does: a rider rolls against Balance every
	-- time they are hit, so most matches end long before the bar empties. This histogram is how much
	-- of the bar is real.
	fallBuckets: { number },
	breaks: number,
}

local LONG_SHOT_ODDS = 0.8 -- a fall at ≥80% stay-on odds is the dice overruling the meter

local function newTally(): Tally
	return {
		tiers = { blocked = 0, normal = 0, crit = 0, weak = 0, mortal = 0 },
		passes = 0,
		totalPasses = 0,
		timeouts = 0,
		unhorses = 0,
		totalUnhorseBalance = 0,
		longShotFalls = 0,
		fallBuckets = table.create(10, 0),
		breaks = 0,
	}
end

local function recordFall(tally: Tally, out: any)
	tally.unhorses += 1
	tally.totalUnhorseBalance += out.balanceAfter
	local b = math.clamp(math.floor(out.balanceAfter / 10) + 1, 1, 10)
	tally.fallBuckets[b] += 1
	if (out.stayChance or 0) >= LONG_SHOT_ODDS then
		tally.longShotFalls += 1
	end
end

-- Returns 1 if A won, -1 if B won, 0 for a double-unhorse or a timeout.
local function playMatch(sa: Strategy, sb: Strategy, tally: Tally): number
	local balA, balB = Constants.BALANCE.START, Constants.BALANCE.START
	-- Breaks persist for the whole match and are keyed to absolute directions, so they do not rotate
	-- with the rider who took them.
	local brokenA: { [string]: number } = {}
	local brokenB: { [string]: number } = {}
	local ctxA: Ctx = { selfBalance = balA, oppBalance = balB, oppAims = {}, oppShields = {} }
	local ctxB: Ctx = { selfBalance = balB, oppBalance = balA, oppAims = {}, oppShields = {} }

	for pass = 1, MAX_PASSES do
		ctxA.selfBalance, ctxA.oppBalance = balA, balB
		ctxB.selfBalance, ctxB.oppBalance = balB, balA

		-- A clairvoyant strategy commits second so it can see its opponent. Two clairvoyants cannot
		-- both see the other, so the first commits blind — the round-robin's oracle-vs-oracle cell is
		-- therefore not meaningful, and nothing downstream reads it.
		local commitA, commitB
		if sa.clairvoyant and not sb.clairvoyant then
			commitB = sb.commit(ctxB)
			ctxA.oppCommit = commitB
			commitA = sa.commit(ctxA)
		else
			commitA = sa.commit(ctxA)
			ctxB.oppCommit = commitA
			commitB = sb.commit(ctxB)
		end

		commitA.broken, commitB.broken = brokenA, brokenB
		local res = PR.resolve(commitA, commitB, { balance = balA }, { balance = balB }, rng)
		if res.a.brokenDirection then
			brokenA[res.a.brokenDirection] = (brokenA[res.a.brokenDirection] or 0) + 1
			tally.breaks += 1
		end
		if res.b.brokenDirection then
			brokenB[res.b.brokenDirection] = (brokenB[res.b.brokenDirection] or 0) + 1
			tally.breaks += 1
		end
		tally.tiers[res.a.tier] += 1
		tally.tiers[res.b.tier] += 1
		balA, balB = res.a.balanceAfter, res.b.balanceAfter

		-- Post-pass reveal (§8): both commitments become public history.
		table.insert(ctxA.oppAims, commitB.aim)
		table.insert(ctxA.oppShields, commitB.shield)
		table.insert(ctxB.oppAims, commitA.aim)
		table.insert(ctxB.oppShields, commitA.shield)

		if res.a.unhorsed or res.b.unhorsed then
			tally.passes += 1
			tally.totalPasses += pass
			if res.a.unhorsed then
				recordFall(tally, res.a)
			end
			if res.b.unhorsed then
				recordFall(tally, res.b)
			end
			if res.a.unhorsed and res.b.unhorsed then
				return 0
			end
			return if res.b.unhorsed then 1 else -1
		end
	end
	tally.timeouts += 1
	tally.passes += 1
	tally.totalPasses += MAX_PASSES
	return 0
end

-- ---- run ---------------------------------------------------------------------------------------
local ringCode = ""
for i = 0, #Constants.CYCLE - 1 do
	ringCode ..= ({ crit = "C", guard = "G", normal = "N" })[Constants.RING[i]]
end
print(string.format(
	"sim — %d matches per pairing, seed %d, curve %s, ring %s (%d notches), shield band %d",
	matches,
	seed,
	Constants.PRORATION.CURVE,
	ringCode,
	#Constants.CYCLE,
	Constants.SHIELD_BAND
))
print(string.format(
	"matrix: normal %.1f  crit %.1f  weak %.1f  thin-block x%.2f  restore %.1f  max-bonus %.2f",
	Constants.MATRIX.NORMAL_DAMAGE,
	Constants.MATRIX.CRIT_DAMAGE,
	Constants.MATRIX.WEAK_DAMAGE,
	Constants.MATRIX.THIN_BLOCK_MULT,
	Constants.MATRIX.SUPERSHIELD_RESTORE,
	Constants.PRORATION.MAX_BONUS
))
print("")

local tally = newTally()
-- winRate[a][b] = a's win rate against b, draws excluded from the numerator but not the denominator.
local winRate: { [string]: { [string]: number } } = {}
for _, sa in STRATEGIES do
	winRate[sa.name] = {}
end

for i, sa in STRATEGIES do
	for j, sb in STRATEGIES do
		if i < j then
			local wins, losses = 0, 0
			for _ = 1, matches do
				local r = playMatch(sa, sb, tally)
				if r == 1 then
					wins += 1
				elseif r == -1 then
					losses += 1
				end
			end
			winRate[sa.name][sb.name] = wins / matches
			winRate[sb.name][sa.name] = losses / matches
		end
	end
end

-- Tier distribution.
local totalStrikes = 0
for _, n in tally.tiers do
	totalStrikes += n
end
print("tier distribution across every strike")
for _, t in { "blocked", "normal", "crit", "weak", "mortal" } do
	print(string.format("  %-9s %6.2f%%", t, 100 * tally.tiers[t] / totalStrikes))
end
print("")

-- Convergence.
local meanPasses = tally.totalPasses / tally.passes
local meanFallBalance = tally.totalUnhorseBalance / tally.unhorses
local longShotRate = tally.longShotFalls / tally.unhorses
print(string.format("convergence: %.2f passes per match on average (%d matches, %d hit the %d-pass cap)",
	meanPasses, tally.passes, tally.timeouts, MAX_PASSES))
if Constants.BREAK.ENABLED then
	print(string.format("breaking: %.2f slices broken per match (momentum threshold %.2f)",
		tally.breaks / tally.passes, Constants.BREAK.MOMENTUM_THRESHOLD))
	print("")
end
print("where riders actually go down (Balance at the moment of the fall)")
for b = 10, 1, -1 do
	local share = tally.fallBuckets[b] / tally.unhorses
	print(string.format("  %3d-%3d  %5.1f%%  %s", (b - 1) * 10, b * 10 - 1, 100 * share,
		string.rep("#", math.floor(share * 120))))
end
print("")
print(string.format("attrition: riders fall at %.1f Balance on average; %.1f%% of falls came off a roll they were "
	.. "%.0f%%+ favoured to make", meanFallBalance, 100 * longShotRate, 100 * LONG_SHOT_ODDS))
print("")

-- Round-robin table.
print("round-robin win rates (row vs column)")
local header = string.rep(" ", 10)
for _, sb in STRATEGIES do
	header ..= string.format("%9s", sb.name)
end
print(header)
for _, sa in STRATEGIES do
	local row = string.format("%-12s", sa.name)
	for _, sb in STRATEGIES do
		if sa.name == sb.name then
			row ..= string.format("%9s", "-")
		else
			row ..= string.format("%8.1f%%", 100 * winRate[sa.name][sb.name])
		end
	end
	print(row)
end
print("")

-- Overall standing, excluding the oracle's own column (it is an instrument, not an opponent).
local standing: { { name: string, score: number } } = {}
for _, sa in STRATEGIES do
	local sum, n = 0, 0
	for _, sb in STRATEGIES do
		if sa.name ~= sb.name and sb.name ~= "oracle" then
			sum += winRate[sa.name][sb.name]
			n += 1
		end
	end
	table.insert(standing, { name = sa.name, score = sum / n })
end
table.sort(standing, function(x, y)
	return x.score > y.score
end)
print("standing (mean win rate vs the non-oracle field)")
for rank, s in standing do
	print(string.format("  %d. %-11s %5.1f%%", rank, s.name, 100 * s.score))
end
print("")

-- ---- the three verdicts ------------------------------------------------------------------------
local failures: { string } = {}

if meanPasses < 3 or meanPasses > 5 then
	table.insert(failures, string.format("convergence out of band: %.2f passes (GAME_SPEC §4 wants 3–5)", meanPasses))
end

local readEdge = winRate["oracle"]["random"]
if readEdge < 0.75 then
	table.insert(failures, string.format(
		"the matrix does not outweigh the dice: a perfect read beats random only %.1f%% of the time "
			.. "(want ≥75%%) — CLAUDE.md invariant 7",
		100 * readEdge
	))
end

-- The ceiling is as load-bearing as the floor. During the ring investigation, several candidate
-- rings passed every check below while a perfect reader beat random 97%+ of the time — information
-- had become the whole game, and §4's "anyone can win any pass" was dead with all gates green.
-- Healthy configurations measured 83-87%; the dominant ones 97-100%. The ceiling sits between.
if readEdge > 0.93 then
	table.insert(failures, string.format(
		"read-dominance: a perfect read beats random %.1f%% of the time (want ≤93%%) — information has "
			.. "swallowed the dice and anyone-can-win is dead (GAME_SPEC §4, CLAUDE.md invariant 7)",
		100 * readEdge
	))
end

if longShotRate > 0.5 then
	table.insert(failures, string.format(
		"slot-machine convergence: %.1f%% of falls came off rolls the rider was %.0f%%+ favoured to make "
			.. "(want ≤50%%) — the meter, not the dice, has to decide most matches (CLAUDE.md invariant 7)",
		100 * longShotRate, 100 * LONG_SHOT_ODDS
	))
end

local camperRank = 0
for rank, s in standing do
	if s.name == "camper" then
		camperRank = rank
	end
end
if camperRank <= #standing / 2 then
	table.insert(failures, string.format(
		"neutral-camping ranks %d of %d — camping must not be competitive (CLAUDE.md invariant 7)",
		camperRank, #standing
	))
end

print(string.format("read edge: a perfect read beats random %.1f%% of the time", 100 * readEdge))
print(string.format("camper ranks %d of %d", camperRank, #standing))
print("")
if #failures == 0 then
	print("VERDICT: all checks pass — these numbers are citable.")
else
	print("VERDICT: " .. tostring(#failures) .. " check(s) failed")
	for _, f in failures do
		print("  ✗ " .. f)
	end
end
process.exit(if #failures == 0 then 0 else 1)
