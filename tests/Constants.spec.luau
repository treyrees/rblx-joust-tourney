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

-- The yard's budgets (docs/design/loop/LOBBY.md, ADR 0012). Every one of these is measured against the
-- pass cycle rather than declared in isolation: the lobby's job is to spend as little of the player's
-- time as possible, and "as little" only means anything relative to the thing they came to do. M1's
-- success criterion (a) — testers say "one more" unprompted — is a measurement of the first two.
kit.describe("Constants — the yard's budgets", function()
	local function cycleSeconds(): number
		local P = Constants.PASS
		return P.INTERMISSION_SECONDS + P.RUNUP_SECONDS + P.RESOLUTION_SECONDS
	end

	kit.it("losing costs less time than playing — re-entry fits inside one pass cycle", function()
		local L = Constants.LOBBY
		if L.REMOUNT_SECONDS > cycleSeconds() then
			error(
				string.format(
					"re-mount budget %.1fs exceeds the %.1fs pass cycle — a loss now costs more than a pass "
						.. "(ADR 0012 §5)",
					L.REMOUNT_SECONDS,
					cycleSeconds()
				)
			)
		end
	end)

	kit.it("the ceremony fits inside the re-mount budget, with room for the offer", function()
		local L = Constants.LOBBY
		if L.CEREMONY_SECONDS >= L.REMOUNT_SECONDS then
			error(
				string.format(
					"ceremony %.1fs leaves nothing of the %.1fs re-mount budget for the next offer (ADR 0012 §5)",
					L.CEREMONY_SECONDS,
					L.REMOUNT_SECONDS
				)
			)
		end
	end)

	kit.it("nobody waits for an opponent longer than the loop's own budget", function()
		local L = Constants.LOBBY
		if L.GHOST_FILL_SECONDS >= L.REMOUNT_SECONDS then
			error(
				string.format(
					"ghost fill %.1fs does not fit inside the %.1fs re-mount budget — the lists would become a "
						.. "queue, and the rail's whole premise is that they are not (ADR 0014 §2)",
					L.GHOST_FILL_SECONDS,
					L.REMOUNT_SECONDS
				)
			)
		end
	end)

	kit.it("arrival costs less than one pass — the first session starts with a joust", function()
		local L = Constants.LOBBY
		if L.FIRST_PASS_SECONDS > cycleSeconds() then
			error(
				string.format(
					"spawn-to-first-commit %.1fs exceeds the %.1fs pass cycle — move the gate, not the number "
						.. "(ADR 0012 §4)",
					L.FIRST_PASS_SECONDS,
					cycleSeconds()
				)
			)
		end
	end)

	kit.it("a glove outlives a re-mount, so a rematch offer cannot eat it", function()
		local L = Constants.LOBBY
		if L.CHALLENGE_EXPIRY_SECONDS <= L.REMOUNT_SECONDS then
			error("a thrown glove must survive at least one re-mount window (ADR 0013 §6)")
		end
	end)

	kit.it("the register remembers at least as much as it needs to field a ghost", function()
		local L = Constants.LOBBY
		if L.HABIT_WINDOW_PASSES < L.GHOST_MIN_PASSES then
			error(
				string.format(
					"habit window %d is shorter than the %d-pass fielding threshold — ghosts would be fitted on "
						.. "passes the register has already forgotten (ADR 0013 §4/§5)",
					L.HABIT_WINDOW_PASSES,
					L.GHOST_MIN_PASSES
				)
			)
		end
	end)
end)
