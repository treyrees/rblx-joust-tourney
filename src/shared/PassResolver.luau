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

-- blocked — the strike met the Shield or the Guard (clean if the defender supershielded, thin otherwise)
-- normal  — an uncontested strike
-- crit    — struck in the Crit the defender's own Aim opened, and left uncovered
-- weak    — a neutral-aim strike: chip damage, no crit potential, no honesty buff (§3 baseline 1)
export type Tier = "blocked" | "normal" | "crit" | "weak"

-- One rider's snapshotted commitment at the tick.
--   shield       — chosen in intermission, hidden until impact (the hole card)
--   aim          — the televised spear direction, quantized to a sector (invariant 4)
--   holdFraction — fraction of the run-up this FINAL aim was held, 0–1. Normalized rather than
--                  measured in seconds so the proration curve is identical however long the run-up
--                  actually lasts.
export type Commitment = {
	shield: Direction,
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
	guard: Direction,
	supershielded: boolean,
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

-- Position of each direction on Constants.CYCLE, so offsets can be taken in O(1). Rebuilt whenever
-- the cycle is replaced, which `tools/rings.luau` does when it sweeps a ring of a different size.
local CYCLE_INDEX: { [string]: number } = {}
local cycleBuiltFor: any = nil

local function index(): { [string]: number }
	if cycleBuiltFor ~= Constants.CYCLE or #Constants.CYCLE ~= (CYCLE_INDEX._n or -1) then
		CYCLE_INDEX = { _n = #Constants.CYCLE }
		for i, dir in Constants.CYCLE do
			CYCLE_INDEX[dir] = i - 1
		end
		cycleBuiltFor = Constants.CYCLE
	end
	return CYCLE_INDEX
end

-- How many notches the ring has. Four is the shipped input vocabulary (invariant 4); the resolver is
-- written against #CYCLE so an eight-notch ring can be measured without a second code path.
function PassResolver.notches(): number
	return #Constants.CYCLE
end

-- Notches from `from` to `to` around the ring. Neutral has no position, so it has no offset either —
-- callers must handle it before asking.
function PassResolver.offset(from: Direction, to: Direction): number?
	local idx = index()
	local a, b = idx[from], idx[to]
	if a == nil or b == nil then
		return nil
	end
	return (b - a) % PassResolver.notches()
end

-- Where the rider's aim sits on their own ring. Zero means the ring is rigidly anchored to the aim,
-- which is the shipped behaviour. A ring with more than one crit notch can instead let the rider
-- choose WHICH of its exposed notches their aim occupies — the same threat with the vulnerability
-- laid out differently around it — and that choice is this field.
local function anchorOf(c: Commitment): number
	return (c :: any).anchor or 0
end

-- What the defender's ring says about a strike arriving from direction `aim`: "crit", "guard",
-- "normal", or nil when the defender is aiming neutral and therefore has no ring at all (§3 neutral
-- baseline 2 — maximally soft, which is what prices cageyness).
function PassResolver.ringClass(defender: Commitment, aim: Direction): string?
	local off = PassResolver.offset(defender.aim, aim)
	if off == nil then
		return nil
	end
	return Constants.RING[(off + anchorOf(defender)) % PassResolver.notches()]
end

-- Every direction whose ring class is `class`, in ring order. Shared by `guards` and `crits`.
local function directionsOfClass(commitment: Commitment, class: string): { Direction }
	local out: { Direction } = {}
	if commitment.aim == Constants.DIRECTIONS.NEUTRAL then
		return out
	end
	local n = PassResolver.notches()
	local base = index()[commitment.aim]
	local anchor = anchorOf(commitment)
	for off = 0, n - 1 do
		if Constants.RING[(off + anchor) % n] == class then
			table.insert(out, Constants.CYCLE[((base + off) % n) + 1] :: Direction)
		end
	end
	return out
end

-- The directions this rider's aim defends. Polarization (§3) still holds in the default ring, where
-- the single guard sits at offset 2 and is therefore the opposite of the aim — one input carrying
-- attack and defense together. A ring may declare zero, one, or two guard offsets.
function PassResolver.guards(commitment: Commitment): { Direction }
	return directionsOfClass(commitment, "guard")
end

-- The single guard direction, for display and for the outcome record. Under the default ring this is
-- exactly `opposite(aim)`, which is what every piece of player-facing copy says.
function PassResolver.guard(commitment: Commitment): Direction
	return PassResolver.guards(commitment)[1] or Constants.DIRECTIONS.NEUTRAL
end

-- The directions where this rider is exposed. Under the default ring there is exactly one and it is
-- identically the rider's own aim, which is where "you are exposed exactly where you strike" comes
-- from. A chiral ring moves it off the aim, and that is the whole point of sweeping the space.
function PassResolver.crits(commitment: Commitment): { Direction }
	return directionsOfClass(commitment, "crit")
end

function PassResolver.crit(commitment: Commitment): Direction
	return PassResolver.crits(commitment)[1] or Constants.DIRECTIONS.NEUTRAL
end

-- Supershielding (§3): the binary defensive bonus, awarded iff the Shield is sitting on one of the
-- ring's guard offsets — depth on a direction the aim already defends, rather than breadth across
-- two. Neutral never supershields; there is no ring to be deep on.
-- Does the defender's Shield cover a strike arriving from `aim`? The Shield covers SHIELD_BAND
-- notches starting at the notch it occupies.
function PassResolver.shielded(defender: Commitment, aim: Direction): boolean
	if defender.shield == Constants.DIRECTIONS.NEUTRAL then
		return false
	end
	local off = PassResolver.offset(defender.shield, aim)
	return off ~= nil and off < Constants.SHIELD_BAND
end

function PassResolver.isSupershielded(commitment: Commitment): boolean
	if commitment.shield == Constants.DIRECTIONS.NEUTRAL then
		return false
	end
	-- Depth: the Shield stacked onto a direction the aim already guards. With a band wider than one
	-- notch it is enough that any covered notch is a guard notch.
	for off = 0, Constants.SHIELD_BAND - 1 do
		local idx = index()[commitment.shield]
		if idx == nil then
			return false
		end
		local dir = Constants.CYCLE[((idx + off) % PassResolver.notches()) + 1]
		if PassResolver.ringClass(commitment, dir :: Direction) == "guard" then
			return true
		end
	end
	return false
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
--   1. A neutral aim is always WEAK — it cannot be blocked and it cannot crit.
--   2. The defender's coverage is {Guard, Shield}. A strike into it is BLOCKED.
--   3. The defender's Crit is the direction opposite their own Guard — which, by polarization, is
--      exactly the direction they are aiming. Struck there and uncovered: CRIT.
--      "You are exposed exactly where you strike."
--   4. Anything else is NORMAL.
--
-- Clause 3 is why the Shield matters: it is the one bit of hidden information that decides whether the
-- defender's own telegraphed Aim is a Crit or not.
function PassResolver.tier(attacker: Commitment, defender: Commitment): Tier
	local NEUTRAL = Constants.DIRECTIONS.NEUTRAL
	if attacker.aim == NEUTRAL then
		return "weak"
	end

	local class = PassResolver.ringClass(defender, attacker.aim)
	local guardBlocks = Constants.GUARD_MODE ~= "amplifier"
	if (class == "guard" and guardBlocks) or PassResolver.shielded(defender, attacker.aim) then
		return "blocked"
	end
	if class == "crit" then
		return "crit"
	end
	return "normal"
end

-- Base Balance damage for a tier, before the offensive bonus. A blocked strike is folded in here so
-- the thin/clean distinction (§3's "deeply" vs "thinly") lives in one place.
function PassResolver.baseDamage(tier: Tier, defenderSupershielded: boolean): number
	local M = Constants.MATRIX
	if tier == "blocked" then
		return if defenderSupershielded then 0 else M.NORMAL_DAMAGE * M.THIN_BLOCK_MULT
	elseif tier == "normal" then
		return M.NORMAL_DAMAGE
	elseif tier == "crit" then
		return M.CRIT_DAMAGE
	elseif tier == "weak" then
		return M.WEAK_DAMAGE
	end
	error("PassResolver.baseDamage: unknown tier: " .. tostring(tier))
end

-- Full damage for one strike: base tier damage scaled by the attacker's honesty (offensive) bonus.
-- A weak (neutral) strike takes no bonus at all — §3 baseline 1's "zero honesty buff".
function PassResolver.strikeDamage(attacker: Commitment, defender: Commitment): (number, Tier)
	local tier = PassResolver.tier(attacker, defender)
	-- A block is clean when the Shield and a Guard notch coincide AT THE STRUCK NOTCH. Under the
	-- shipped "block" mode the defender-wide test is equivalent, since the Shield-on-Guard notch is
	-- the only one that can be struck cleanly; under "amplifier" it is not, so ask per strike.
	local clean = if Constants.GUARD_MODE == "amplifier"
		then PassResolver.ringClass(defender, attacker.aim) == "guard"
			and PassResolver.shielded(defender, attacker.aim)
		else PassResolver.isSupershielded(defender)
	local base = PassResolver.baseDamage(tier, clean)
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
	local superA, superB = PassResolver.isSupershielded(commitA), PassResolver.isSupershielded(commitB)

	-- Snapshot phase: every strike reads only the pre-pass commitments.
	local damageToB, tierB = PassResolver.strikeDamage(commitA, commitB)
	local damageToA, tierA = PassResolver.strikeDamage(commitB, commitA)

	-- The defensive bonus: a clean (supershielded) block restores Balance — blocking is a win, not a
	-- non-loss (§4) — capped well below a normal hit so Balance still only trends down.
	local restoreA = if tierA == "blocked" and superA then Constants.MATRIX.SUPERSHIELD_RESTORE else 0
	local restoreB = if tierB == "blocked" and superB then Constants.MATRIX.SUPERSHIELD_RESTORE else 0

	local afterA = clampBalance(stateA.balance - damageToA + restoreA)
	local afterB = clampBalance(stateB.balance - damageToB + restoreB)

	local outA: RiderOutcome = {
		tier = tierA,
		guard = PassResolver.guard(commitA),
		supershielded = superA,
		damageTaken = damageToA,
		restore = restoreA,
		balanceBefore = stateA.balance,
		balanceAfter = afterA,
		unhorsed = false,
	}
	local outB: RiderOutcome = {
		tier = tierB,
		guard = PassResolver.guard(commitB),
		supershielded = superB,
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
