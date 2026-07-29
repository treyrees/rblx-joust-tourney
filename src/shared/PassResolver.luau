--!strict
-- PassResolver.luau — the deterministic heart of the pass (GAME_SPEC §3 + §4).
--
-- Pure and headless on purpose: no Roblox services, no state, no yielding. Two snapshotted
-- commitments in, one resolved pass out. Everything above this module (the wheel, the run-up, the
-- teeter animation, the post-pass reveal) is presentation over these numbers, and `tools/sim.luau`
-- runs it thousands of times without an engine.
--
-- Two invariants live in this file's shape rather than in its comments:
--   * Simultaneous resolution (CLAUDE.md invariant 3) — both riders resolve from the SAME pre-pass
--     snapshot, so there is no order bias. `resolve` never reads a value it has already written.
--   * Visible RNG (invariant 6) — the only randomness is the teeter roll, it is injected by the
--     caller, and the odds it rolls against are returned alongside the roll so the UI can print them
--     BEFORE the dice land.

local Constants = require(script.Parent.Constants)

local PassResolver = {}

export type Direction = "in" | "out" | "up" | "down" | "neutral"

-- blocked  — the strike met a guard (clean if the defender stacked, thin otherwise)
-- normal   — an uncontested strike
-- punished — struck in the hole the defender's own aim opened, and left uncovered
-- weak     — a neutral-aim strike: chip damage, no punish potential, no honesty buff (§3 baseline 1)
export type Tier = "blocked" | "normal" | "punished" | "weak"

-- One rider's snapshotted commitment at the tick.
--   passiveGuard — chosen in intermission, hidden until impact (the hole card)
--   aim          — the televised spear direction, quantized to a sector (invariant 4)
--   holdFraction — fraction of the run-up this FINAL aim was held, 0–1. Normalized rather than
--                  measured in seconds so the proration curve is identical however long the run-up
--                  actually lasts.
export type Commitment = {
	passiveGuard: Direction,
	aim: Direction,
	holdFraction: number,
}

-- A rider's meter state going into the pass. `recovery` is the horse's teeter bonus (GAME_SPEC §6);
-- M1 has no horses, so it defaults to 0 and exists only as the seam §6 plugs into.
export type RiderState = {
	balance: number,
	recovery: number?,
}

export type RiderOutcome = {
	tier: Tier, -- the tier of the strike this rider RECEIVED
	activeGuard: Direction,
	stacked: boolean,
	damageTaken: number,
	restore: number,
	balanceBefore: number,
	balanceAfter: number,
	-- Teeter roll: present only when this rider was hit (damageTaken > 0).
	stayChance: number?,
	roll: number?,
	unhorsed: boolean,
}

export type PassResult = {
	a: RiderOutcome,
	b: RiderOutcome,
}

-- ---- direction helpers -------------------------------------------------------------------------

function PassResolver.opposite(dir: Direction): Direction
	local opp = Constants.OPPOSITE[dir]
	if not opp then
		error("PassResolver.opposite: not a direction: " .. tostring(dir))
	end
	return opp :: Direction
end

-- Polarization (§3): the active guard is ALWAYS the opposite of the aim, so one input carries attack
-- and defense together. A neutral aim yields no active guard at all (§3 neutral baseline 2) —
-- maximally soft, which is what prices cageyness.
function PassResolver.activeGuard(commitment: Commitment): Direction
	return PassResolver.opposite(commitment.aim)
end

-- Stacking (§3): the binary defensive bonus, awarded iff the active guard matches the passive guard
-- at the tick. Neutral never stacks — there is nothing to stack onto.
function PassResolver.isStacked(commitment: Commitment): boolean
	local active = PassResolver.activeGuard(commitment)
	return active ~= Constants.DIRECTIONS.NEUTRAL and active == commitment.passiveGuard
end

-- ---- proration ---------------------------------------------------------------------------------

-- The offensive bonus curve (§3), mapping hold fraction 0–1 to bonus fraction 0–1. The shape is
-- selected by Constants.PRORATION.CURVE; all three candidates from GAME_SPEC §12 stay implemented so
-- `tools/sim.luau` can compare them without a code change.
function PassResolver.proration(holdFraction: number): number
	local P = Constants.PRORATION
	local h = math.clamp(holdFraction, 0, 1)

	if P.CURVE == "linear" then
		return h
	elseif P.CURVE == "ease_in" then
		return h ^ P.EASE_EXPONENT
	elseif P.CURVE == "floor_ease_in" then
		if h <= P.FLOOR then
			return 0
		end
		-- Rescale the above-floor remainder to 0–1, then ease in. A full-run-up hold still pays the
		-- full bonus; anything below the floor pays nothing, which is what makes a last-instant
		-- flick a genuine sacrifice rather than a free bluff.
		local t = (h - P.FLOOR) / (1 - P.FLOOR)
		return t ^ P.EASE_EXPONENT
	end
	error("PassResolver.proration: unknown curve: " .. tostring(P.CURVE))
end

-- ---- the matrix --------------------------------------------------------------------------------

-- Resolve one direction of the pass: what tier does `attacker`'s strike land at against `defender`?
--
-- The whole rule, in four clauses:
--   1. A neutral aim is always WEAK — it cannot be blocked and it cannot punish.
--   2. The defender's coverage is {active guard, passive guard}. A strike into it is BLOCKED.
--   3. The defender's hole is the direction opposite their own active guard — which, by
--      polarization, is exactly the direction they are aiming. Struck there and uncovered: PUNISHED.
--      "You are exposed exactly where you strike."
--   4. Anything else is NORMAL.
--
-- Clause 3 is why the passive guard matters: it is the one bit of hidden information that decides
-- whether the defender's own telegraphed aim is a hole or not.
function PassResolver.tier(attacker: Commitment, defender: Commitment): Tier
	local NEUTRAL = Constants.DIRECTIONS.NEUTRAL
	if attacker.aim == NEUTRAL then
		return "weak"
	end

	local active = PassResolver.activeGuard(defender)
	local covered = (active ~= NEUTRAL and attacker.aim == active)
		or (defender.passiveGuard ~= NEUTRAL and attacker.aim == defender.passiveGuard)
	if covered then
		return "blocked"
	end

	if active ~= NEUTRAL and attacker.aim == PassResolver.opposite(active) then
		return "punished"
	end
	return "normal"
end

-- Base Balance damage for a tier, before the offensive bonus. A blocked strike is folded in here so
-- the thin/clean distinction (§3's "deeply" vs "thinly") lives in one place.
function PassResolver.baseDamage(tier: Tier, defenderStacked: boolean): number
	local M = Constants.MATRIX
	if tier == "blocked" then
		return if defenderStacked then 0 else M.NORMAL_DAMAGE * M.THIN_BLOCK_MULT
	elseif tier == "normal" then
		return M.NORMAL_DAMAGE
	elseif tier == "punished" then
		return M.PUNISHED_DAMAGE
	elseif tier == "weak" then
		return M.WEAK_DAMAGE
	end
	error("PassResolver.baseDamage: unknown tier: " .. tostring(tier))
end

-- Full damage for one strike: base tier damage scaled by the attacker's honesty (offensive) bonus.
-- A weak (neutral) strike takes no bonus at all — §3 baseline 1's "zero honesty buff".
function PassResolver.strikeDamage(attacker: Commitment, defender: Commitment): (number, Tier)
	local tier = PassResolver.tier(attacker, defender)
	local base = PassResolver.baseDamage(tier, PassResolver.isStacked(defender))
	if base == 0 or tier == "weak" then
		return base, tier
	end
	local bonus = Constants.PRORATION.MAX_BONUS * PassResolver.proration(attacker.holdFraction)
	return base * (1 + bonus), tier
end

-- ---- the pass ----------------------------------------------------------------------------------

local function clampBalance(v: number): number
	return math.clamp(v, Constants.BALANCE.MIN, Constants.BALANCE.MAX)
end

-- The teeter roll (§4): anyone hit this pass rolls against their post-damage Balance to stay
-- mounted. Returns the odds the UI must show BEFORE rolling, alongside the roll itself.
local function teeter(balanceAfter: number, recovery: number, rng: () -> number): (number, number, boolean)
	local stayChance = math.clamp(balanceAfter / Constants.BALANCE.MAX + recovery, 0, 1)
	local roll = rng()
	return stayChance, roll, roll >= stayChance
end

-- Resolve one full pass. `rng` must return a float in [0, 1); inject it so tests and the sim are
-- reproducible. Both riders are computed from the snapshot before anything is written back, so
-- resolution carries no order bias (CLAUDE.md invariant 3) — swapping a and b mirrors the result
-- exactly, which `tests/PassResolver.spec.luau` asserts directly.
function PassResolver.resolve(
	commitA: Commitment,
	commitB: Commitment,
	stateA: RiderState,
	stateB: RiderState,
	rng: () -> number
): PassResult
	local stackedA, stackedB = PassResolver.isStacked(commitA), PassResolver.isStacked(commitB)

	-- Snapshot phase: every strike reads only the pre-pass commitments.
	local damageToB, tierB = PassResolver.strikeDamage(commitA, commitB)
	local damageToA, tierA = PassResolver.strikeDamage(commitB, commitA)

	-- The defensive bonus: a clean (stacked) block restores Balance — blocking is a win, not a
	-- non-loss (§4) — capped well below a normal hit so Balance still only trends down.
	local restoreA = if tierA == "blocked" and stackedA then Constants.MATRIX.STACK_BLOCK_RESTORE else 0
	local restoreB = if tierB == "blocked" and stackedB then Constants.MATRIX.STACK_BLOCK_RESTORE else 0

	local afterA = clampBalance(stateA.balance - damageToA + restoreA)
	local afterB = clampBalance(stateB.balance - damageToB + restoreB)

	local outA: RiderOutcome = {
		tier = tierA,
		activeGuard = PassResolver.activeGuard(commitA),
		stacked = stackedA,
		damageTaken = damageToA,
		restore = restoreA,
		balanceBefore = stateA.balance,
		balanceAfter = afterA,
		unhorsed = false,
	}
	local outB: RiderOutcome = {
		tier = tierB,
		activeGuard = PassResolver.activeGuard(commitB),
		stacked = stackedB,
		damageTaken = damageToB,
		restore = restoreB,
		balanceBefore = stateB.balance,
		balanceAfter = afterB,
		unhorsed = false,
	}

	-- Rolls are drawn A-then-B for reproducibility under a seeded rng. Order cannot bias the
	-- OUTCOME (each rider rolls against their own meter, and neither roll feeds the other), only the
	-- sequence in which the two draws are consumed.
	if damageToA > 0 then
		outA.stayChance, outA.roll, outA.unhorsed = teeter(afterA, stateA.recovery or 0, rng)
	end
	if damageToB > 0 then
		outB.stayChance, outB.roll, outB.unhorsed = teeter(afterB, stateB.recovery or 0, rng)
	end

	return { a = outA, b = outB }
end

return PassResolver
