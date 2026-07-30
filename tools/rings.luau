--!strict
-- rings.luau — sweep every possible ring over the four directions. Run from the repo root:
--     lune run tools/rings.luau [--top N] [--all] [--ring CODE]
--
-- A RING is the defender's map: what happens at each quarter-turn offset from their own aim.
-- Four offsets, three classes (crit / guard / normal) — 81 rings, 45 once mirror images are folded
-- together. `Constants.RING` picks one; this tool asks which one makes the best game.
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
		else
			i += 1
		end
	end
end

-- ---- the strategy space ------------------------------------------------------------------------
-- One rider's whole commitment, minus the hold fraction: a Shield direction and an Aim direction,
-- each of the four plus neutral. Neutral is included on both axes because §3 insists both are legal.
type Strat = { shield: string, aim: string, holdFraction: number }
local ALL_DIRS = { D.IN, D.OUT, D.UP, D.DOWN, D.NEUTRAL }

local STRATS: { Strat } = {}
for _, shield in ALL_DIRS do
	for _, aim in ALL_DIRS do
		table.insert(STRATS, { shield = shield, aim = aim, holdFraction = 1 })
	end
end
local N = #STRATS

local function stratName(s: Strat): string
	return string.format("shield %s / aim %s", s.shield, s.aim)
end

-- ---- ring enumeration --------------------------------------------------------------------------
local function ringCode(r: { [number]: string }): string
	return LETTER[r[0]] .. LETTER[r[1]] .. LETTER[r[2]] .. LETTER[r[3]]
end

local function parseRing(code: string): { [number]: string }
	local r = {}
	for i = 0, 3 do
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
	return code:sub(1, 1) .. code:sub(4, 4) .. code:sub(3, 3) .. code:sub(2, 2)
end

local RINGS: { { [number]: string } } = {}
do
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
	return (dmgToB - restB) - (dmgToA - restA), tierA, tierB
end

-- ---- the solver --------------------------------------------------------------------------------
-- Fictitious play on a symmetric zero-sum game. Each step best-responds to the opponent's empirical
-- mix, then folds that response into the mix. The running payoff vector makes a step O(N) rather
-- than O(N^2), which is what keeps a 45-ring sweep instant.
local ITERS = 40000

local function solve(M: { { number } }): { number }
	local acc = table.create(N, 0)
	local counts = table.create(N, 0)
	for _ = 1, ITERS do
		local best, bestV = 1, -math.huge
		for i = 1, N do
			if acc[i] > bestV then
				best, bestV = i, acc[i]
			end
		end
		counts[best] += 1
		-- acc[i] must accumulate i's payoff AGAINST the response just played, i.e. the `best` COLUMN.
		-- Reading the `best` row instead silently solves the negated game, since the payoff matrix is
		-- antisymmetric.
		for i = 1, N do
			acc[i] += M[i][best]
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
	critRate: number,
	mutualCrit: number, -- share of crits that are traded rather than landed one-sided
	blockRate: number,
	topStrat: string,
}

local function analyse(r: { [number]: string }): Report
	for i = 0, 3 do
		Constants.RING[i] = r[i]
	end

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
	local aimEdge = 0
	for _, aim in ALL_DIRS do
		local mass = 0
		for j = 1, N do
			if STRATS[j].aim == aim then
				mass += p[j]
			end
		end
		if mass > 0 then
			local best = -math.huge
			for i = 1, N do
				local v = 0
				for j = 1, N do
					if STRATS[j].aim == aim then
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

	-- Chirality is a property of the ring alone: exactly one of the two perpendicular offsets is a
	-- crit. It is the only way a four-ring can ever produce a one-sided crit.
	local chiral = (r[1] == "crit") ~= (r[3] == "crit")

	return {
		code = ringCode(r),
		chiral = chiral,
		maxWeight = maxWeight,
		support = support,
		entropy = entropy,
		fullEdge = fullEdge,
		aimEdge = aimEdge,
		exploit = exploit,
		critRate = crits,
		mutualCrit = if crits > 0 then mutual / crits else 0,
		blockRate = blocks / strikes,
		topStrat = stratName(STRATS[top]),
	}
end

-- ---- run ---------------------------------------------------------------------------------------
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
table.sort(reports, function(x, y)
	local xs = if x.maxWeight > 0.9 then -1 else x.fullEdge
	local ys = if y.maxWeight > 0.9 then -1 else y.fullEdge
	return xs > ys
end)

print("ring   chiral  top-wt  supp  read-edge  aim-edge  hole-card   crit%  mutual-crit%  block%  exploit")
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
		))
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
