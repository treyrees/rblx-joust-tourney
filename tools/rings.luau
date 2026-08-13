--!strict
-- rings.luau — sweep or solve rings over the wheel's notches. Run from the repo root:
--     lune run tools/rings.luau [--top N] [--all] [--ring CODE]
--
-- A RING is the defender's map: what happens at each notch offset from their own aim. Three classes
-- per notch (crit / guard / normal), so the space is 3^notches — 81 on the four-notch wheel this tool
-- was written for, 6561 on the eight-notch wheel ADR 0006 settled on, before mirror images and the
-- structural constraints (`--guard-opposite`, `--contiguous`) fold it down. `Constants.RING` picks
-- one; this tool asks which one makes the best game.
--
-- The instrument is a solver, not a race. For each ring it builds the one-pass payoff matrix over
-- every (Shield, Aim) a rider can commit, then finds the symmetric equilibrium by fictitious play.
-- Equilibrium is the right lens because the question is structural: a ring where one pure line
-- dominates is a solved game no matter how the damage numbers are tuned, and today's ring is
-- suspected of exactly that (`axis` beats even the `oracle` in tools/sim.luau).
--
-- Hold fraction is pinned at 1 here on purpose. In a one-shot simultaneous game the honesty bonus is
-- strictly dominant, so proration and bluffing cannot be measured on this instrument at all — they
-- need the televised run-up, which is what tools/sim.luau models. Two instruments, two questions.

local process = require("@lune/process")
local roblox = require("../tests/lib/robloxenv")

roblox.build("./src")
local Constants = roblox.requireShared("Constants")
local PR = roblox.requireShared("PassResolver")

local D = Constants.DIRECTIONS
local CLASSES = { "crit", "guard", "normal" }
local LETTER = { crit = "C", guard = "G", normal = "N" }
local FROM_LETTER = { C = "crit", G = "guard", N = "normal" }

-- ---- args --------------------------------------------------------------------------------------
local topN, showAll, onlyRing = 12, false, nil :: string?
local verify = false
local notches, anchored, contiguous = #Constants.CYCLE, false, false
local guardOpposite = false
local dumpMix = false
local sortKey = "read"
local balA, balB = 100, 100
local survivalPayoff = false
do
	local args = process.args
	local i = 1
	while i <= #args do
		if args[i] == "--top" then
			topN = tonumber(args[i + 1]) or topN
			i += 2
		elseif args[i] == "--all" then
			showAll = true
			i += 1
		elseif args[i] == "--ring" then
			onlyRing = args[i + 1]
			i += 2
		elseif args[i] == "--notches" then
			notches = tonumber(args[i + 1]) or notches
			i += 2
		elseif args[i] == "--shield-band" then
			Constants.SHIELD_BAND = tonumber(args[i + 1]) or 1
			i += 2
		elseif args[i] == "--sort" then
			sortKey = args[i + 1] or "read"
			i += 2
		elseif args[i] == "--balance" then
			-- Solve at a given Balance state instead of full health. The Supershield's whole promise is
			-- that its value RISES as a rider falls, and a Balance-differential payoff is linear and so
			-- cannot see that. This switches the payoff to unhorse-probability differential, which is
			-- what actually matters near death.
			balA = tonumber(args[i + 1]) or 100
			balB = tonumber(args[i + 2]) or balA
			survivalPayoff = true
			i += 3
		elseif args[i] == "--ss-restore" then
			Constants.MATRIX.SUPERSHIELD_RESTORE = tonumber(args[i + 1]) or 2
			i += 2
		elseif args[i] == "--ss-bonus" then
			Constants.MATRIX.SUPERSHIELD_STRIKE_BONUS = tonumber(args[i + 1]) or 0
			i += 2
		elseif args[i] == "--shield-mode" then
			Constants.SHIELD_MODE = args[i + 1]
			i += 2
		elseif args[i] == "--guard-mode" then
			Constants.GUARD_MODE = args[i + 1]
			i += 2
		elseif args[i] == "--verify" then
			-- Gate mode: solve the SHIPPED configuration at full precision and enforce the structural
			-- invariants no round robin can see (CLAUDE.md invariants 8 and 9). Exists because during
			-- the ring investigation a configuration passed every sim.luau verdict while structurally
			-- dead: equilibrium crit rate 0.0%, hole card worth 0.01 Balance. Scripted riders never
			-- find the exploit; the solver is the instrument that does.
			verify = true
			i += 1
		elseif args[i] == "--dump-mix" then
			dumpMix = true
			i += 1
		elseif args[i] == "--guard-opposite" then
			-- Readability constraint: the Guard must sit directly across from the attack notch, which
			-- is what makes polarization intuitive ("you defend away from where you strike").
			guardOpposite = true
			i += 1
		elseif args[i] == "--contiguous" then
			contiguous = true
			i += 1
		elseif args[i] == "--anchored" then
			-- Let each rider also choose WHICH of their ring's crit notches their aim occupies: the
			-- same threat with the exposure laid out differently around it.
			anchored = true
			i += 1
		else
			-- Loud, like tools/sim.luau: a silently-skipped flag means a run that is not the run the
			-- author asked for, reported with the same confidence as one that is. This tool is half of
			-- the combat-axis gate, so a mistyped `--shield-bnd 3` quietly solving the SHIPPED band is
			-- exactly the failure mode that must never be quiet.
			error(string.format("rings: unknown argument %q — see the usage line at the top of tools/rings.luau", args[i]))
		end
	end
end

-- A ring of a different size than the shipped cycle needs its own direction names; they are
-- generated, since only the tool ever sees them.
if notches ~= #Constants.CYCLE then
	local cycle = {}
	for i = 1, notches do
		cycle[i] = "n" .. tostring(i - 1)
	end
	Constants.CYCLE = cycle
	Constants.RING = {}
	for i = 0, notches - 1 do
		Constants.RING[i] = "normal"
	end
end

-- ---- the strategy space ------------------------------------------------------------------------
-- One rider's whole commitment, minus the hold fraction: a Shield direction and an Aim direction,
-- each of the four plus neutral. Neutral is included on both axes because §3 insists both are legal.
type Strat = { shield: string, aim: string, holdFraction: number, anchor: number }
local ALL_DIRS = {}
for _, dir in Constants.CYCLE do
	table.insert(ALL_DIRS, dir)
end
table.insert(ALL_DIRS, D.NEUTRAL)

local STRATS: { Strat } = {}
local N = 0

local function buildStrats(critNotches: { number })
	STRATS = {}
	local anchors = if anchored and #critNotches > 0 then critNotches else { 0 }
	for _, shield in ALL_DIRS do
		for _, aim in ALL_DIRS do
			for _, anchor in anchors do
				table.insert(STRATS, { shield = shield, aim = aim, holdFraction = 1, anchor = anchor })
			end
		end
	end
	N = #STRATS
end

local function stratName(s: Strat): string
	return string.format("shield %s / aim %s / anchor %d", s.shield, s.aim, s.anchor)
end

-- ---- ring enumeration --------------------------------------------------------------------------
local function ringCode(r: { [number]: string }): string
	local s = ""
	for i = 0, notches - 1 do
		s ..= LETTER[r[i]]
	end
	return s
end

local function parseRing(code: string): { [number]: string }
	if #code ~= notches then
		error(string.format("ring code %q has %d letters but --notches is %d", code, #code, notches))
	end
	local r = {}
	for i = 0, notches - 1 do
		local cls = FROM_LETTER[code:sub(i + 1, i + 1):upper()]
		if not cls then
			error("bad ring code: " .. code .. " (letters must be C, G or N)")
		end
		r[i] = cls
	end
	return r
end

-- Mirroring a ring swaps the two perpendicular offsets. A ring and its mirror are the same game with
-- the handedness flipped, so only one of each pair is worth solving.
local function mirrorCode(code: string): string
	local s = code:sub(1, 1)
	for i = #code, 2, -1 do
		s ..= code:sub(i, i)
	end
	return s
end

-- The full space is 3^notches, which is only worth enumerating exhaustively at four (--notches 4).
-- Larger rings are examined one at a time via --ring, or as contiguous-wedge families via
-- --contiguous — the shapes you could actually paint on a shield.
local RINGS: { { [number]: string } } = {}
if notches == 4 then
	local seen: { [string]: boolean } = {}
	for _, a in CLASSES do
		for _, b in CLASSES do
			for _, c in CLASSES do
				for _, d in CLASSES do
					local r = { [0] = a, [1] = b, [2] = c, [3] = d }
					local code = ringCode(r)
					if not seen[code] and not seen[mirrorCode(code)] then
						seen[code] = true
						table.insert(RINGS, r)
					end
				end
			end
		end
	end
elseif contiguous then
	-- The design-relevant slice of a larger ring space: one contiguous crit wedge, one contiguous
	-- guard wedge, everything else normal — rings that look like something you can paint on a shield.
	-- The crit wedge is required to contain offset 0, which is the rule "you are exposed exactly
	-- where you strike" stated as a constraint on the search rather than assumed in the code.
	local seen: { [string]: boolean } = {}
	for critLen = 1, notches - 2 do
		for critStartOff = 0, critLen - 1 do
			local critStart = (notches - critStartOff) % notches
			local isCrit: { [number]: boolean } = {}
			for k = 0, critLen - 1 do
				isCrit[(critStart + k) % notches] = true
			end
			for guardLen = 1, notches - critLen do
				for guardStart = 0, notches - 1 do
					local ok = true
					for k = 0, guardLen - 1 do
						if isCrit[(guardStart + k) % notches] then
							ok = false
						end
					end
					if ok then
						local r = {}
						for i = 0, notches - 1 do
							r[i] = if isCrit[i] then "crit" else "normal"
						end
						for k = 0, guardLen - 1 do
							r[(guardStart + k) % notches] = "guard"
						end
						local code = ringCode(r)
						local keep = not guardOpposite or r[notches // 2] == "guard"
						if keep and not seen[code] and not seen[mirrorCode(code)] then
							seen[code] = true
							table.insert(RINGS, r)
						end
					end
				end
			end
		end
	end
elseif not onlyRing and not verify then
	error(string.format("--notches %d needs an explicit --ring CODE, or --contiguous", notches))
end

-- ---- payoff ------------------------------------------------------------------------------------
-- Zero-sum by construction: A's payoff is the Balance B loses minus the Balance A loses, restores
-- included. Balance differential rather than win probability, because the teeter roll is monotone in
-- Balance — whatever maximises the differential maximises the odds of staying mounted.
local function payoff(a: Strat, b: Strat): (number, string, string)
	local dmgToB, tierB = PR.strikeDamage(a, b)
	local dmgToA, tierA = PR.strikeDamage(b, a)
	local restA = if tierA == "blocked" and PR.isSupershielded(a) then Constants.MATRIX.SUPERSHIELD_RESTORE else 0
	local restB = if tierB == "blocked" and PR.isSupershielded(b) then Constants.MATRIX.SUPERSHIELD_RESTORE else 0
	if not survivalPayoff then
		return (dmgToB - restB) - (dmgToA - restA), tierA, tierB
	end
	-- Survival mode: what a pass is worth is the chance it puts the other rider in the dirt, minus the
	-- chance it puts you there. Only a rider who took damage rolls at all (GAME_SPEC §4), so a restore
	-- is worth nothing at full Balance and a great deal at twenty.
	local function fallChance(bal: number, dmg: number, rest: number): number
		if dmg <= 0 then
			return 0
		end
		local after = math.clamp(bal - dmg + rest, Constants.BALANCE.MIN, Constants.BALANCE.MAX)
		return 1 - math.clamp(after / Constants.BALANCE.MAX, 0, 1)
	end
	return fallChance(balB, dmgToB, restB) - fallChance(balA, dmgToA, restA), tierA, tierB
end

-- ---- the solver --------------------------------------------------------------------------------
-- Fictitious play on a symmetric zero-sum game. Each step best-responds to the opponent's empirical
-- mix, then folds that response into the mix. The running payoff vector makes a step O(N) rather
-- than O(N^2), which is what keeps a 45-ring sweep instant.
-- A sweep trades solver precision for breadth; a single named ring gets the precise treatment.
local ITERS = if onlyRing or verify then 200000 else 20000

local function solve(M: { { number } }): { number }
	local acc = table.create(N, 0)
	local counts = table.create(N, 0)
	-- The column player needs its own population once the two riders sit at different Balance: the
	-- game is still zero sum, but no longer symmetric, so a single mix cannot stand in for both.
	local accCol = table.create(N, 0)
	local colBest = 1
	for _ = 1, ITERS do
		local best, bestV = 1, -math.huge
		for i = 1, N do
			if acc[i] > bestV then
				best, bestV = i, acc[i]
			end
		end
		if balA ~= balB then
			local cb, cv = 1, -math.huge
			for j = 1, N do
				if accCol[j] > cv then
					cb, cv = j, accCol[j]
				end
			end
			colBest = cb
			for j = 1, N do
				accCol[j] -= M[best][j]
			end
		else
			colBest = best
		end
		counts[best] += 1
		-- acc[i] must accumulate i's payoff AGAINST the response just played, i.e. the `best` COLUMN.
		-- Reading the `best` row instead silently solves the negated game, since the payoff matrix is
		-- antisymmetric.
		for i = 1, N do
			acc[i] += M[i][colBest]
		end
	end
	local p = table.create(N, 0)
	for i = 1, N do
		p[i] = counts[i] / ITERS
	end
	return p
end

-- ---- metrics -----------------------------------------------------------------------------------
type Report = {
	code: string,
	chiral: boolean,
	maxWeight: number,
	support: number,
	entropy: number,
	fullEdge: number, -- Balance points a clairvoyant gains over the equilibrium player
	aimEdge: number, -- ...knowing only the televised Aim, which is what a real opponent sees
	exploit: number, -- how far the solved mix still is from equilibrium; near 0 or the row is noise
	priorBits: number, -- uncertainty about the Shield before seeing anything
	residBits: number, -- ...and after seeing the televised aim. The hole card's actual information.
	critRate: number,
	mutualCrit: number, -- share of crits that are traded rather than landed one-sided
	blockRate: number,
	topStrat: string,
}

local function analyse(r: { [number]: string }): Report
	local critNotches: { number } = {}
	for i = 0, notches - 1 do
		Constants.RING[i] = r[i]
		if r[i] == "crit" then
			table.insert(critNotches, i)
		end
	end
	buildStrats(critNotches)

	-- payoff matrix, plus the tier pair for each cell so the equilibrium's texture is measurable
	local M: { { number } } = table.create(N)
	local tierA: { { string } } = table.create(N)
	local tierB: { { string } } = table.create(N)
	for i = 1, N do
		M[i] = table.create(N, 0)
		tierA[i] = table.create(N, "")
		tierB[i] = table.create(N, "")
	end
	for i = 1, N do
		for j = 1, N do
			local v, ta, tb = payoff(STRATS[i], STRATS[j])
			M[i][j], tierA[i][j], tierB[i][j] = v, ta, tb
		end
	end

	local p = solve(M)

	local maxWeight, top, support, entropy = 0, 1, 0, 0
	for i = 1, N do
		if p[i] > maxWeight then
			maxWeight, top = p[i], i
		end
		if p[i] > 0.01 then
			support += 1
		end
		if p[i] > 0 then
			entropy -= p[i] * math.log(p[i])
		end
	end

	-- What the equilibrium actually plays, expressed relative to the rider's own aim so the shape is
	-- readable: where the Shield sits, whether it earns the Supershield, and how much of the ring's
	-- exposure it leaves bare.
	if dumpMix then
		local rows = {}
		for i = 1, N do
			if p[i] > 0.005 then
				table.insert(rows, { i = i, w = p[i] })
			end
		end
		table.sort(rows, function(a, b)
			return a.w > b.w
		end)
		print("  equilibrium mix (weight >= 0.5%), Shield offset measured from own aim:")
		for _, row in rows do
			local st = STRATS[row.i]
			local off = if st.aim == D.NEUTRAL or st.shield == D.NEUTRAL
				then nil
				else PR.offset(st.aim, st.shield)
			local bare = 0
			for _, c in PR.crits(st) do
				if not PR.shielded(st, c) then
					bare += 1
				end
			end
			print(string.format(
				"    %5.1f%%  aim %-8s shield %+3s  %-13s  bare crit notches: %d",
				100 * row.w,
				if st.aim == D.NEUTRAL then "neutral" else "committed",
				if off then tostring(off) else "--",
				if PR.isSupershielded(st) then "SUPERSHIELD" else "",
				bare
			))
		end
	end

	-- How much the televised aim gives away about the hidden Shield, in bits. H(Shield) is what an
	-- opponent faces before the run-up; H(Shield | aim) is what survives once the rider has pointed.
	-- The gap is the leak. This is "hints but does not reveal" stated as a number rather than a hope.
	local function entropy(w: { [string]: number }, total: number): number
		local h = 0
		for _, v in w do
			if v > 0 then
				local q = v / total
				h -= q * math.log(q, 2)
			end
		end
		return h
	end

	local shieldMass: { [string]: number } = {}
	local byAim: { [string]: { mass: number, sh: { [string]: number } } } = {}
	for i = 1, N do
		if p[i] > 0 then
			local st = STRATS[i]
			shieldMass[st.shield] = (shieldMass[st.shield] or 0) + p[i]
			local slot = byAim[st.aim]
			if not slot then
				slot = { mass = 0, sh = {} }
				byAim[st.aim] = slot
			end
			slot.mass += p[i]
			slot.sh[st.shield] = (slot.sh[st.shield] or 0) + p[i]
		end
	end
	local priorBits = entropy(shieldMass, 1)
	local residBits = 0
	for _, slot in byAim do
		residBits += slot.mass * entropy(slot.sh, slot.mass)
	end

	-- Solver self-check. At a true equilibrium no pure strategy beats the mix, so the best response's
	-- value is 0. Anything meaningfully above that means fictitious play has not converged and every
	-- other number in this row should be distrusted.
	local exploit = -math.huge
	for i = 1, N do
		local v = 0
		for j = 1, N do
			if p[j] > 0 then
				v += p[j] * M[i][j]
			end
		end
		if v > exploit then
			exploit = v
		end
	end

	-- Value of perfect information: best response to the opponent's ACTUAL commitment, averaged over
	-- the equilibrium mix. This is the invariant-1 headline — what a read is worth in Balance.
	local fullEdge = 0
	for j = 1, N do
		if p[j] > 0 then
			local best = -math.huge
			for i = 1, N do
				if M[i][j] > best then
					best = M[i][j]
				end
			end
			fullEdge += p[j] * best
		end
	end

	-- Value of the televised half only: the opponent's Aim is public, their Shield is not. This is
	-- the read a real player actually gets to make during the run-up.
	-- The public half is the aim AND the anchor: the ring is painted on the shield, so however it is
	-- rotated is plainly visible. Treating the anchor as hidden would credit the hole card with
	-- information the opponent can simply look at.
	local publicKeys: { string } = {}
	local seenKey: { [string]: boolean } = {}
	for j = 1, N do
		local k = STRATS[j].aim .. "|" .. tostring(STRATS[j].anchor)
		if not seenKey[k] then
			seenKey[k] = true
			table.insert(publicKeys, k)
		end
	end

	local aimEdge = 0
	for _, key in publicKeys do
		local mass = 0
		for j = 1, N do
			if STRATS[j].aim .. "|" .. tostring(STRATS[j].anchor) == key then
				mass += p[j]
			end
		end
		if mass > 0 then
			local best = -math.huge
			for i = 1, N do
				local v = 0
				for j = 1, N do
					if STRATS[j].aim .. "|" .. tostring(STRATS[j].anchor) == key then
						v += (p[j] / mass) * M[i][j]
					end
				end
				if v > best then
					best = v
				end
			end
			aimEdge += mass * best
		end
	end

	-- Texture of the equilibrium: how often anyone crits, how often a crit is traded rather than won,
	-- how much of the game is spent blocking.
	local crits, mutual, blocks, strikes = 0, 0, 0, 0
	for i = 1, N do
		if p[i] > 0 then
			for j = 1, N do
				if p[j] > 0 then
					local w = p[i] * p[j]
					local ca, cb = tierA[i][j] == "crit", tierB[i][j] == "crit"
					if ca or cb then
						crits += w
						if ca and cb then
							mutual += w
						end
					end
					if tierA[i][j] == "blocked" then
						blocks += w
					end
					if tierB[i][j] == "blocked" then
						blocks += w
					end
					strikes += 2 * w
				end
			end
		end
	end

	-- Chirality is a property of the ring alone: some offset is a crit while its negation is not.
	-- That is the only way a ring of any size can ever produce a one-sided crit.
	local chiral = false
	for off = 0, notches - 1 do
		if (r[off] == "crit") ~= (r[(notches - off) % notches] == "crit") then
			chiral = true
		end
	end

	return {
		code = ringCode(r),
		chiral = chiral,
		maxWeight = maxWeight,
		support = support,
		entropy = entropy,
		fullEdge = fullEdge,
		aimEdge = aimEdge,
		exploit = exploit,
		priorBits = priorBits,
		residBits = residBits,
		critRate = crits,
		mutualCrit = if crits > 0 then mutual / crits else 0,
		blockRate = blocks / strikes,
		topStrat = stratName(STRATS[top]),
	}
end

-- ---- verify (the equilibrium gate) --------------------------------------------------------------
-- Solves the SHIPPED ring at the SHIPPED band and enforces the invariants only an equilibrium can
-- check. Thresholds sit between the measured healthy configurations and the measured dead ones —
-- each bound has a real corpse behind it, not a guess (ADR 0010 cites the runs).
if verify then
	-- With no --ring, verify the shipped Constants.RING; with one, verify that candidate instead
	-- (which is how the negative cases in ADR 0010 were produced).
	local shipped
	if onlyRing then
		shipped = parseRing(onlyRing)
	else
		shipped = {}
		for i = 0, notches - 1 do
			shipped[i] = Constants.RING[i]
		end
	end
	local rep = analyse(shipped)

	local critNotches = 0
	for i = 0, notches - 1 do
		if shipped[i] == "crit" then
			critNotches += 1
		end
	end

	type Check = { name: string, value: string, bound: string, ok: boolean }
	local checks: { Check } = {
		{
			name = "solver converged (exploitability)",
			value = string.format("%.2f", rep.exploit),
			bound = "< 0.50",
			ok = rep.exploit < 0.5,
		},
		{
			-- Invariant 9: the hole card stays live. Dead configs measured 0.00-0.52; shipped 8.12.
			name = "hole card is worth real Balance",
			value = string.format("%.2f", rep.fullEdge - rep.aimEdge),
			bound = ">= 3.00",
			ok = (rep.fullEdge - rep.aimEdge) >= 3,
		},
		{
			-- Invariant 9's other half: hidden, but not opaque — the televised aim must narrow the
			-- Shield to roughly a street of poker, never to certainty and never to nothing.
			name = "shield stays a coin flip after the aim",
			value = string.format("%.2f bits", rep.residBits),
			bound = "0.50 - 2.00",
			ok = rep.residBits >= 0.5 and rep.residBits <= 2.0,
		},
		{
			-- The crit tier must exist between good players, not only against beginners. The old ring
			-- measured 0.1% here with every match-level gate green.
			name = "crits fire at equilibrium",
			value = string.format("%.1f%%", 100 * rep.critRate),
			bound = ">= 10%",
			ok = rep.critRate >= 0.10,
		},
		{
			-- No resting spot: a pure line carrying the equilibrium is a solved game. The dead ring's
			-- top line carried 39.6%.
			name = "no dominant pure line",
			value = string.format("%.1f%%", 100 * rep.maxWeight),
			bound = "<= 35%",
			ok = rep.maxWeight <= 0.35,
		},
		{
			-- Structural: one-sided crits exist iff the ring is chiral (ADR 0006).
			name = "ring is chiral",
			value = if rep.chiral then "yes" else "NO",
			bound = "yes",
			ok = rep.chiral,
		},
		{
			-- Structural: the hole card IS the gap between exposure and plate. Cover everything and
			-- there is no secret left to have.
			name = "exposure wider than the Shield plate",
			value = string.format("%d crit vs band %d", critNotches, Constants.SHIELD_BAND),
			bound = "crit > band",
			ok = critNotches > Constants.SHIELD_BAND,
		},
	}

	print(string.format(
		"ring verify — shipped %s, %d notches, shield band %d, %d FP iterations",
		ringCode(shipped),
		notches,
		Constants.SHIELD_BAND,
		ITERS
	))
	local failed = 0
	for _, c in checks do
		if not c.ok then
			failed += 1
		end
		print(string.format("  %s %-42s %16s   (want %s)", if c.ok then "OK " else "✗✗ ", c.name, c.value, c.bound))
	end
	print("")
	if failed == 0 then
		print("VERIFY: the shipped ring holds every equilibrium invariant.")
	else
		print(string.format("VERIFY: %d invariant(s) violated — the round robin CANNOT clear these; do not ship.", failed))
	end
	process.exit(if failed == 0 then 0 else 1)
end

-- ---- run ---------------------------------------------------------------------------------------
buildStrats({})
print(string.format(
	"ring sweep — %d distinct rings (mirror images folded), %d commitments each, %d FP iterations",
	#RINGS,
	N,
	ITERS
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

local reports: { Report } = {}
if onlyRing then
	table.insert(reports, analyse(parseRing(onlyRing)))
else
	for _, r in RINGS do
		table.insert(reports, analyse(r))
	end
end

-- A ring is only interesting if the equilibrium is genuinely mixed. One pure line at ~100% weight is
-- a solved game; sort those to the bottom regardless of how good their other numbers look.
local function rank(r: Report): number
	-- A ring where one pure line carries the equilibrium is a solved game whatever else it scores.
	if r.maxWeight > 0.9 then
		return -1
	end
	return if sortKey == "hole" then r.fullEdge - r.aimEdge else r.fullEdge
end

table.sort(reports, function(x, y)
	return rank(x) > rank(y)
end)

print("ring   chiral  top-wt  supp  read-edge  aim-edge  hole-card   crit%  mutual-crit%  block%  exploit  shield-bits(before>after)")
print(string.rep("-", 101))
local shown = 0
for _, rep in reports do
	if showAll or onlyRing or shown < topN then
		print(string.format(
			"%-6s %-7s %5.1f%% %5d %10.2f %9.2f %10.2f %7.1f%% %13.1f%% %6.1f%% %8.2f",
			rep.code,
			if rep.chiral then "yes" else "no",
			100 * rep.maxWeight,
			rep.support,
			rep.fullEdge,
			rep.aimEdge,
			rep.fullEdge - rep.aimEdge,
			100 * rep.critRate,
			100 * rep.mutualCrit,
			100 * rep.blockRate,
			rep.exploit
		) .. string.format("  %.2f > %.2f", rep.priorBits, rep.residBits))
		shown += 1
	end
end
print("")
print("legend: ring code is offsets 0,1,2,3 from the defender's own aim. C=crit G=guard N=normal.")
print("  offset 0 = the direction they are aiming, offset 2 = the direction they are aiming away from.")
print("  read-edge = Balance a rider gains by seeing the opponent's full commitment (invariant 1).")
print("  aim-edge  = the same, seeing only the televised Aim — the read a real run-up actually offers.")
print("  hole-card = read-edge minus aim-edge: what the HIDDEN Shield is worth on top of the public aim.")
print("  mutual-crit% = share of crits that are traded both ways rather than landed one-sided.")
print("  exploit   = solver residual. Near 0 means the mix really is an equilibrium.")
print("")

-- Named landmarks, always printed so the sweep can be read against the design conversation.
local LANDMARKS = {
	{ code = "CNGN", note = "today's ring — crit on your own aim, guard opposite" },
	{ code = "NCGC", note = "both perpendiculars crit (the symmetric variant)" },
	{ code = "NCGN", note = "minimal chiral — crit one notch around, guard opposite" },
}
print("landmarks")
for _, l in LANDMARKS do
	for _, rep in reports do
		if rep.code == l.code then
			print(string.format(
				"  %-6s %-52s read-edge %5.2f  top-weight %5.1f%%  mutual-crit %5.1f%%",
				rep.code,
				l.note,
				rep.fullEdge,
				100 * rep.maxWeight,
				100 * rep.mutualCrit
			))
		end
	end
end
