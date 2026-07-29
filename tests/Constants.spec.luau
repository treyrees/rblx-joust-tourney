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
end)
