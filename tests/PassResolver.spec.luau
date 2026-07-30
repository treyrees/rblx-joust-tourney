--!strict
-- PassResolver.spec.luau — pins the deterministic half of the pass (GAME_SPEC §3 + §4).
--
-- The tests worth having here are the ones that fail loudly if a tuning change quietly breaks a
-- CLAUDE.md invariant: polarization, the enumerated matrix, "a correct read always beats rarity",
-- "the matrix outweighs the dice", and no order bias in simultaneous resolution.

local kit = require("./lib/testkit")
local roblox = require("./lib/robloxenv")

local Constants = roblox.requireShared("Constants")
local PR = roblox.requireShared("PassResolver")

local D = Constants.DIRECTIONS
-- The four-direction basis the design speaks in (GAME_SPEC §3)...
local FOUR = { D.IN, D.OUT, D.UP, D.DOWN }
-- ...and the full eight-notch wheel it is played on (ADR 0006).
local EIGHT = { D.UP, D.UP_IN, D.IN, D.DOWN_IN, D.DOWN, D.DOWN_OUT, D.OUT, D.UP_OUT }

local function commit(shield, aim, holdFraction)
	return { shield = shield, aim = aim, holdFraction = holdFraction or 0 }
end

local function state(balance: number, recovery: number?)
	return { balance = balance, recovery = recovery }
end

-- A fixed roll, so tests that are not ABOUT the dice never depend on them.
local function fixedRng(v: number)
	return function()
		return v
	end
end

-- Count the tiers every real aim produces against one defender.
local function tierSpread(defender)
	local spread = { blocked = 0, normal = 0, crit = 0, weak = 0, mortal = 0 }
	for _, aim in EIGHT do
		local t = PR.tier(commit(D.DOWN, aim, 1), defender)
		spread[t] += 1
	end
	return spread
end

kit.describe("PassResolver — polarization (GAME_SPEC §3)", function()
	kit.it("the Guard is always the opposite of the Aim", function()
		for _, aim in FOUR do
			kit.expectEqual(PR.guard(commit(D.IN, aim)), Constants.OPPOSITE[aim], "Guard for aim " .. aim)
		end
	end)

	kit.it("a neutral aim yields no Guard (neutral baseline 2 — maximally soft)", function()
		kit.expectEqual(PR.guard(commit(D.IN, D.NEUTRAL)), D.NEUTRAL)
	end)

	-- The Crit is opposite the Guard, which by polarization is the rider's own Aim. Asserting the
	-- round trip rather than trusting the tautology: if polarization is ever rewired (GAME_SPEC §7
	-- lists inverted-polarization kits as a candidate archetype), this is where it must be re-derived.
	kit.it("the Crit is opposite the Guard, and therefore identically the rider's own Aim", function()
		for _, aim in FOUR do
			local c = commit(D.IN, aim)
			kit.expectEqual(PR.crit(c), aim, "Crit for aim " .. aim)
			kit.expectEqual(PR.crit(c), PR.opposite(PR.guard(c)), "Crit is opposite the Guard for aim " .. aim)
		end
	end)

	kit.it("supershielding is the Shield covering the Guard — held, and never from neutral", function()
		-- Aiming OUT puts the Guard on IN; a Shield plate covering IN is the supershield.
		kit.expectEqual(PR.isSupershielded(commit(D.IN, D.OUT, 1)), true, "aim out + shield on in supershields")
		kit.expectEqual(PR.isSupershielded(commit(D.UP, D.OUT, 1)), false, "aim out + shield up does not")
		kit.expectEqual(PR.isSupershielded(commit(D.NEUTRAL, D.NEUTRAL, 1)), false, "neutral cannot supershield")
		-- Defence is prorated like offence (ADR 0009): the aligning aim must have been HELD, so a
		-- last-instant flick into alignment collects nothing.
		kit.expectEqual(
			PR.isSupershielded(commit(D.IN, D.OUT, Constants.SUPERSHIELD_MIN_HOLD - 0.01)),
			false,
			"a flick into alignment earns no supershield"
		)
	end)
end)

kit.describe("PassResolver — the matrix, enumerated (GAME_SPEC §4, ring CCCNGNNN)", function()
	-- Defender aims OUT throughout. On the shipped ring their exposure is {out, up-out, up} (the aim
	-- and two notches sweeping on), their Guard is IN (directly opposite), and everything else is
	-- ordinary. The Shield is a two-notch plate, so it covers two of the three exposed notches at
	-- best: something is ALWAYS bare, and which one is the hole card (ADR 0006).
	kit.it("deep (supershield): plate on the Guard — all three crit notches stay bare", function()
		local spread = tierSpread(commit(D.IN, D.OUT, 1))
		kit.expectEqual(spread.blocked, 2, "blocked")
		kit.expectEqual(spread.crit, 3, "crit")
		kit.expectEqual(spread.normal, 3, "normal")
	end)

	kit.it("forward: plate on the aim — covers the near exposure, the far notch stays bare", function()
		local spread = tierSpread(commit(D.OUT, D.OUT, 1))
		kit.expectEqual(spread.blocked, 3, "blocked")
		kit.expectEqual(spread.crit, 1, "crit")
		kit.expectEqual(spread.normal, 4, "normal")
	end)

	kit.it("back: plate one notch on — covers the far exposure, the aim itself stays bare", function()
		local spread = tierSpread(commit(D.UP_OUT, D.OUT, 1))
		kit.expectEqual(spread.blocked, 3, "blocked")
		kit.expectEqual(spread.crit, 1, "crit")
		kit.expectEqual(spread.normal, 4, "normal")
	end)

	kit.it("the Crit is always the defender's own Aim direction", function()
		for _, aim in FOUR do
			-- Shield placed off-axis so it never covers the Crit.
			local offAxis = if aim == D.IN or aim == D.OUT then D.UP else D.IN
			local defender = commit(offAxis, aim)
			kit.expectEqual(PR.tier(commit(D.IN, aim, 1), defender), "crit", "crit for aim " .. aim)
		end
	end)

	kit.it("a neutral strike is always weak — never blocked, never a crit", function()
		for _, aim in FOUR do
			for _, shieldDir in FOUR do
				kit.expectEqual(PR.tier(commit(D.IN, D.NEUTRAL, 1), commit(shieldDir, aim)), "weak")
			end
		end
	end)
end)

kit.describe("PassResolver — the two bonuses (GAME_SPEC §3)", function()
	kit.it("a supershielded block is clean (zero damage); any other block is thin, not free", function()
		local M = Constants.MATRIX
		kit.expectEqual(PR.baseDamage("blocked", true), 0, "supershielded block")
		kit.expectEqual(PR.baseDamage("blocked", false), M.NORMAL_DAMAGE * M.THIN_BLOCK_MULT, "thin block")
	end)

	kit.it("the supershield restore is capped well below a normal hit, so Balance still trends down", function()
		if Constants.MATRIX.SUPERSHIELD_RESTORE >= Constants.MATRIX.NORMAL_DAMAGE then
			error("block restore must stay well below normal damage or convergence stalls (§4)")
		end
	end)

	-- All three candidate curves stay live (Constants.PRORATION.CURVE selects one; `tools/sim.luau
	-- --curve` compares them), so all three are tested here regardless of which M1 ships — otherwise
	-- the two unselected shapes rot until the next time someone re-opens the question.
	kit.it("every curve pins the endpoints: no hold pays nothing, a full hold pays the full bonus", function()
		local P = Constants.PRORATION
		local original = P.CURVE
		for _, curve in { "linear", "ease_in", "floor_ease_in" } do
			P.CURVE = curve
			kit.expectEqual(PR.proration(0), 0, curve .. ": no hold")
			kit.expectNear(PR.proration(1), 1, 1e-9, curve .. ": full hold")
		end
		P.CURVE = original
	end)

	kit.it("every curve is monotonic — holding longer is never worse", function()
		local P = Constants.PRORATION
		local original = P.CURVE
		for _, curve in { "linear", "ease_in", "floor_ease_in" } do
			P.CURVE = curve
			local prev = -1
			for i = 0, 20 do
				local v = PR.proration(i / 20)
				if v < prev then
					error(curve .. ": proration decreased at h=" .. tostring(i / 20))
				end
				prev = v
			end
		end
		P.CURVE = original
	end)

	kit.it("the floored curve pays nothing below its floor (the anti-flick shape)", function()
		local P = Constants.PRORATION
		local original = P.CURVE
		P.CURVE = "floor_ease_in"
		kit.expectEqual(PR.proration(P.FLOOR), 0, "exactly at the floor")
		kit.expectEqual(PR.proration(P.FLOOR / 2), 0, "below the floor")
		P.CURVE = original
	end)

	kit.it("an unknown curve fails loudly rather than silently scoring zero", function()
		local P = Constants.PRORATION
		local original = P.CURVE
		P.CURVE = "not-a-curve"
		kit.expectError(function()
			PR.proration(0.5)
		end, "an unknown proration curve must error")
		P.CURVE = original
	end)

	kit.it("the honesty bonus scales a strike, but never a neutral one (zero honesty buff)", function()
		local defender = commit(D.UP, D.UP) -- axis: no crit, so the hit lands normal
		local honest = PR.strikeDamage(commit(D.IN, D.IN, 1), defender)
		local flick = PR.strikeDamage(commit(D.IN, D.IN, 0), defender)
		if honest <= flick then
			error("a held aim must out-damage a last-instant flick")
		end
		local weakHeld = PR.strikeDamage(commit(D.IN, D.NEUTRAL, 1), defender)
		local weakFlick = PR.strikeDamage(commit(D.IN, D.NEUTRAL, 0), defender)
		kit.expectEqual(weakHeld, weakFlick, "neutral takes no honesty bonus")
		kit.expectEqual(weakHeld, Constants.MATRIX.WEAK_DAMAGE, "weak damage")
	end)
end)

kit.describe("PassResolver — the CLAUDE.md invariants", function()
	kit.it("invariant 1: a correct read beats the best-case honest normal", function()
		-- A crit taken with NO honesty bonus must still exceed a normal hit landed with the
		-- maximum bonus. If tuning ever inverts this, reading correctly stops paying.
		-- Defender aims UP: exposure {up, up-in, in}, guard DOWN, normals include OUT. The Shield on
		-- DOWN keeps every strike below uncovered by the plate.
		local defender = commit(D.DOWN, D.UP, 1)
		local crit = PR.strikeDamage(commit(D.IN, D.UP, 0), defender) -- into the bare aim, flicked
		local bestNormal = PR.strikeDamage(commit(D.IN, D.OUT, 1), defender) -- ordinary notch, full hold
		if crit <= bestNormal then
			error(
				"crit ("
					.. tostring(crit)
					.. ") must beat the best honest normal ("
					.. tostring(bestNormal)
					.. ") — CLAUDE.md invariant 1"
			)
		end
	end)

	kit.it("invariant 7: a crit must force a genuinely scary roll from full Balance", function()
		-- One crit out of full Balance has to move the teeter meter meaningfully, or the matrix
		-- stops mattering relative to the dice.
		local res = PR.resolve(
			commit(D.IN, D.IN, 1), -- attacker strikes into the Crit
			commit(D.UP, D.IN, 1), -- defender's Crit is open at IN
			state(Constants.BALANCE.START),
			state(Constants.BALANCE.START),
			fixedRng(0)
		)
		kit.expectEqual(res.b.tier, "crit")
		if res.b.stayChance == nil or res.b.stayChance > 0.8 then
			error("a crit from full Balance must leave stay-on odds at or below 80%")
		end
	end)

	kit.it("invariant 6: every hit reports the odds it rolled against", function()
		local res = PR.resolve(
			commit(D.IN, D.IN, 1),
			commit(D.UP, D.IN, 1),
			state(50),
			state(50),
			fixedRng(0.999)
		)
		if res.b.stayChance == nil or res.b.roll == nil then
			error("a hit rider must expose both the odds and the roll")
		end
		kit.expectNear(res.b.stayChance :: number, res.b.balanceAfter / Constants.BALANCE.MAX, 1e-9)
	end)

	kit.it("invariant 3: resolution has no order bias — swapping the riders mirrors the result", function()
		local x, y = commit(D.IN, D.OUT, 0.8), commit(D.UP, D.DOWN, 0.3)
		local forward = PR.resolve(x, y, state(70), state(45), fixedRng(0.5))
		local reversed = PR.resolve(y, x, state(45), state(70), fixedRng(0.5))
		kit.expectEqual(forward.a.tier, reversed.b.tier, "tier")
		kit.expectEqual(forward.a.damageTaken, reversed.b.damageTaken, "damage")
		kit.expectEqual(forward.a.balanceAfter, reversed.b.balanceAfter, "balance")
		kit.expectEqual(forward.a.unhorsed, reversed.b.unhorsed, "unhorsed")
	end)
end)

kit.describe("PassResolver — breaking and the mortal rung (ADR 0008)", function()
	kit.it("a landed strike carrying full momentum breaks the direction it hit", function()
		local res = PR.resolve(
			{ shield = D.DOWN, aim = D.OUT, holdFraction = 0, momentum = 1 },
			commit(D.DOWN, D.UP, 1), -- OUT is an ordinary notch for an UP-aiming defender, uncovered
			state(100),
			state(100),
			fixedRng(0)
		)
		kit.expectEqual(res.b.brokenDirection, D.OUT, "the struck direction breaks")
	end)

	kit.it("below the momentum threshold, nothing breaks — proration does not break (ADR 0008)", function()
		local res = PR.resolve(
			{ shield = D.DOWN, aim = D.OUT, holdFraction = 1, momentum = 0 },
			commit(D.DOWN, D.UP, 1),
			state(100),
			state(100),
			fixedRng(0)
		)
		kit.expectEqual(res.b.brokenDirection, nil, "a full hold with no momentum breaks nothing")
	end)

	kit.it("a break demotes the slice one rung: this defender's Guard becomes an ordinary notch", function()
		-- Defender aims UP, so their Guard is DOWN. With DOWN broken once, a strike there stops
		-- being blocked. Breaks key off ABSOLUTE directions, so the map names the world notch.
		local sound = commit(D.UP_OUT, D.UP, 1)
		local broken = { shield = D.UP_OUT, aim = D.UP, holdFraction = 1, broken = { [D.DOWN] = 1 } }
		kit.expectEqual(PR.tier(commit(D.DOWN, D.DOWN, 1), sound), "blocked", "sound guard blocks")
		kit.expectEqual(PR.tier(commit(D.DOWN, D.DOWN, 1), broken), "normal", "broken guard does not")
	end)

	kit.it("the rung below crit is mortal: struck there uncovered, the rider goes down with NO roll", function()
		-- Defender aims UP with their own aim notch broken once: crit demotes to mortal.
		local res = PR.resolve(
			commit(D.DOWN, D.UP, 1),
			{ shield = D.DOWN, aim = D.UP, holdFraction = 1, broken = { [D.UP] = 1 } },
			state(100),
			state(100),
			fixedRng(0) -- the luckiest possible roll, which must not save them
		)
		kit.expectEqual(res.b.tier, "mortal")
		kit.expectEqual(res.b.unhorsed, true, "unhorsed regardless of the roll")
		kit.expectEqual(res.b.roll, nil, "no roll is drawn at all — this end is a read, not dice")
	end)
end)

kit.describe("PassResolver — the teeter roll (GAME_SPEC §4)", function()
	kit.it("a blocked rider takes no damage and never rolls", function()
		-- Defender supershields IN (aim OUT, Shield IN); attacker aims IN, straight into it.
		local res = PR.resolve(
			commit(D.UP, D.IN, 1),
			commit(D.IN, D.OUT, 1),
			state(60),
			state(60),
			fixedRng(0.999)
		)
		kit.expectEqual(res.b.tier, "blocked")
		kit.expectEqual(res.b.damageTaken, 0, "damage")
		kit.expectEqual(res.b.roll, nil, "no roll")
		kit.expectEqual(res.b.unhorsed, false, "stays mounted")
		kit.expectEqual(res.b.restore, Constants.MATRIX.SUPERSHIELD_RESTORE, "clean block restores")
	end)

	kit.it("stay-on odds track Balance: the roll lands under the odds or the rider goes down", function()
		local lucky = PR.resolve(commit(D.IN, D.IN, 1), commit(D.UP, D.IN, 1), state(100), state(100), fixedRng(0))
		kit.expectEqual(lucky.b.unhorsed, false, "roll of 0 always stays mounted")

		local doomed = PR.resolve(commit(D.IN, D.IN, 1), commit(D.UP, D.IN, 1), state(100), state(100), fixedRng(0.999))
		kit.expectEqual(doomed.b.unhorsed, true, "a roll above the odds unhorses")
	end)

	kit.it("Balance is clamped to its meter bounds, restore included", function()
		-- A clean block at full Balance must not push the meter above its maximum.
		local res = PR.resolve(
			commit(D.UP, D.IN, 1),
			commit(D.IN, D.OUT, 1),
			state(Constants.BALANCE.START),
			state(Constants.BALANCE.START),
			fixedRng(0.5)
		)
		kit.expectEqual(res.b.balanceAfter, Constants.BALANCE.MAX, "clamped at max")

		local floored = PR.resolve(commit(D.IN, D.IN, 1), commit(D.UP, D.IN, 1), state(100), state(2), fixedRng(0.5))
		kit.expectEqual(floored.b.balanceAfter, Constants.BALANCE.MIN, "clamped at min")
	end)

	kit.it("the horse recovery seam raises stay-on odds without touching the matrix (§6)", function()
		local plain = PR.resolve(commit(D.IN, D.IN, 1), commit(D.UP, D.IN, 1), state(100), state(100), fixedRng(0.5))
		local horsed = PR.resolve(commit(D.IN, D.IN, 1), commit(D.UP, D.IN, 1), state(100), state(100, 0.15), fixedRng(0.5))
		kit.expectEqual(plain.b.damageTaken, horsed.b.damageTaken, "recovery must not change damage")
		if (horsed.b.stayChance :: number) <= (plain.b.stayChance :: number) then
			error("recovery must improve the teeter roll (GAME_SPEC §6)")
		end
	end)
end)
