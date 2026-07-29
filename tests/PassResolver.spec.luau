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
local FOUR = { D.IN, D.OUT, D.UP, D.DOWN }

local function commit(passiveGuard, aim, holdFraction)
	return { passiveGuard = passiveGuard, aim = aim, holdFraction = holdFraction or 0 }
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

-- Count the tiers the four real aims produce against one defender.
local function tierSpread(defender)
	local spread = { blocked = 0, normal = 0, punished = 0, weak = 0 }
	for _, aim in FOUR do
		local t = PR.tier(commit(D.IN, aim, 1), defender)
		spread[t] += 1
	end
	return spread
end

kit.describe("PassResolver — polarization (GAME_SPEC §3)", function()
	kit.it("active guard is always the opposite of aim", function()
		for _, aim in FOUR do
			kit.expectEqual(PR.activeGuard(commit(D.IN, aim)), Constants.OPPOSITE[aim], "active guard for aim " .. aim)
		end
	end)

	kit.it("a neutral aim yields no active guard (neutral baseline 2 — maximally soft)", function()
		kit.expectEqual(PR.activeGuard(commit(D.IN, D.NEUTRAL)), D.NEUTRAL)
	end)

	kit.it("stacking is active-guard == passive-guard, and neutral never stacks", function()
		-- Aiming OUT puts the active guard IN, so guarding IN passively is the stack.
		kit.expectEqual(PR.isStacked(commit(D.IN, D.OUT)), true, "aim out + passive in stacks")
		kit.expectEqual(PR.isStacked(commit(D.UP, D.OUT)), false, "aim out + passive up is a split")
		kit.expectEqual(PR.isStacked(commit(D.NEUTRAL, D.NEUTRAL)), false, "neutral cannot stack")
	end)
end)

kit.describe("PassResolver — the matrix, enumerated (GAME_SPEC §4)", function()
	-- Defender aims OUT throughout, so their active guard is IN and their hole is OUT.
	kit.it("stack: one deep block, one punish hole, two normals", function()
		local spread = tierSpread(commit(D.IN, D.OUT))
		kit.expectEqual(spread.blocked, 1, "blocked")
		kit.expectEqual(spread.punished, 1, "punished")
		kit.expectEqual(spread.normal, 2, "normal")
	end)

	kit.it("axis guard: covers its own hole — two thin blocks, no punish", function()
		local spread = tierSpread(commit(D.OUT, D.OUT))
		kit.expectEqual(spread.blocked, 2, "blocked")
		kit.expectEqual(spread.punished, 0, "punished")
		kit.expectEqual(spread.normal, 2, "normal")
	end)

	kit.it("split: two thin blocks, but the hole stays open", function()
		local spread = tierSpread(commit(D.UP, D.OUT))
		kit.expectEqual(spread.blocked, 2, "blocked")
		kit.expectEqual(spread.punished, 1, "punished")
		kit.expectEqual(spread.normal, 1, "normal")
	end)

	kit.it("the punish hole is always the defender's own aim direction", function()
		for _, aim in FOUR do
			-- Passive guard placed off-axis so it never covers the hole.
			local offAxis = if aim == D.IN or aim == D.OUT then D.UP else D.IN
			local defender = commit(offAxis, aim)
			kit.expectEqual(PR.tier(commit(D.IN, aim, 1), defender), "punished", "hole for aim " .. aim)
		end
	end)

	kit.it("a neutral strike is always weak — never blocked, never a punish", function()
		for _, aim in FOUR do
			for _, passive in FOUR do
				kit.expectEqual(PR.tier(commit(D.IN, D.NEUTRAL, 1), commit(passive, aim)), "weak")
			end
		end
	end)
end)

kit.describe("PassResolver — the two bonuses (GAME_SPEC §3)", function()
	kit.it("a stacked block is clean (zero damage); a split block is thin, not free", function()
		local M = Constants.MATRIX
		kit.expectEqual(PR.baseDamage("blocked", true), 0, "stacked block")
		kit.expectEqual(PR.baseDamage("blocked", false), M.NORMAL_DAMAGE * M.THIN_BLOCK_MULT, "thin block")
	end)

	kit.it("the block restore is capped well below a normal hit, so Balance still trends down", function()
		if Constants.MATRIX.STACK_BLOCK_RESTORE >= Constants.MATRIX.NORMAL_DAMAGE then
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
		local defender = commit(D.UP, D.UP) -- axis guard: no punish, so the hit lands normal
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
		-- A punish taken with NO honesty bonus must still exceed a normal hit landed with the
		-- maximum bonus. If tuning ever inverts this, reading correctly stops paying.
		local axis = commit(D.UP, D.UP)
		local offAxis = commit(D.UP, D.IN) -- hole open at IN
		local punish = PR.strikeDamage(commit(D.IN, D.IN, 0), offAxis)
		local bestNormal = PR.strikeDamage(commit(D.IN, D.IN, 1), axis)
		if punish <= bestNormal then
			error(
				"punish ("
					.. tostring(punish)
					.. ") must beat the best honest normal ("
					.. tostring(bestNormal)
					.. ") — CLAUDE.md invariant 1"
			)
		end
	end)

	kit.it("invariant 7: a punish must force a genuinely scary roll from full Balance", function()
		-- One punish out of full Balance has to move the teeter meter meaningfully, or the matrix
		-- stops mattering relative to the dice.
		local res = PR.resolve(
			commit(D.IN, D.IN, 1), -- attacker strikes into the hole
			commit(D.UP, D.IN, 1), -- defender's hole is open at IN
			state(Constants.BALANCE.START),
			state(Constants.BALANCE.START),
			fixedRng(0)
		)
		kit.expectEqual(res.b.tier, "punished")
		if res.b.stayChance == nil or res.b.stayChance > 0.8 then
			error("a punish from full Balance must leave stay-on odds at or below 80%")
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

kit.describe("PassResolver — the teeter roll (GAME_SPEC §4)", function()
	kit.it("a blocked rider takes no damage and never rolls", function()
		-- Defender stacks IN (aim OUT, passive IN); attacker aims IN, straight into the deep guard.
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
		kit.expectEqual(res.b.restore, Constants.MATRIX.STACK_BLOCK_RESTORE, "clean block restores")
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
