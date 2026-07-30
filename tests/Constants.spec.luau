--!strict
-- Constants.spec.luau — seed spec: proves the harness runs green out of the box and pins the pass
-- cycle's shape (GAME_SPEC §1) so a tuning change to the rhythm is a conscious, tested act.

local kit = require("./lib/testkit")
local roblox = require("./lib/robloxenv")

local Constants = roblox.requireShared("Constants")

kit.describe("Constants — the pass cycle", function()
	kit.it("total cycle stays inside the sub-15-second attention target", function()
		local P = Constants.PASS
		local total = P.INTERMISSION_SECONDS + P.RUNUP_SECONDS + P.RESOLUTION_SECONDS
		if total > 15 then
			error("pass cycle exceeds 15s: " .. tostring(total))
		end
	end)

	kit.it("aim lock exists and lands inside the run-up window", function()
		local P = Constants.PASS
		if P.AIM_LOCK_BEFORE_TICK <= 0 then
			error("aim lock must exist (ping-war guard, CLAUDE.md invariant 4)")
		end
		if P.AIM_LOCK_BEFORE_TICK >= P.RUNUP_SECONDS then
			error("aim lock longer than the whole run-up")
		end
	end)

	-- ADR 0002: brackets get faster as horses get rarer, but the ping guard is absolute, so a short
	-- enough run-up would let the lock swallow the decision window. These two tests are what stop a
	-- future speed tier from being tuned into an execution game by editing a duration.
	kit.it("the ping guard never eats more than its share of the run-up", function()
		local P = Constants.PASS
		local share = P.AIM_LOCK_BEFORE_TICK / P.RUNUP_SECONDS
		if share > P.AIM_LOCK_MAX_RUNUP_FRACTION then
			error(
				string.format(
					"aim lock is %.1f%% of the run-up, ceiling is %.1f%% (ADR 0002)",
					100 * share,
					100 * P.AIM_LOCK_MAX_RUNUP_FRACTION
				)
			)
		end
	end)

	kit.it("the run-up floor is derived from the ping guard, and the run-up respects it", function()
		local P = Constants.PASS
		kit.expectNear(P.MIN_RUNUP_SECONDS, P.AIM_LOCK_BEFORE_TICK / P.AIM_LOCK_MAX_RUNUP_FRACTION, 1e-9)
		if P.RUNUP_SECONDS < P.MIN_RUNUP_SECONDS then
			error(
				string.format(
					"run-up %.2fs is below the %.2fs floor the ping guard implies (ADR 0002)",
					P.RUNUP_SECONDS,
					P.MIN_RUNUP_SECONDS
				)
			)
		end
	end)
end)
