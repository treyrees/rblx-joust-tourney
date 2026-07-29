--!strict
-- Constants.lua — the single source of truth for every tuning number. Never hardcode a number in a
-- system module; name it here and reference it. (Invariant carried from the predecessor repo.)

local Constants = {}

-- The pass cycle (GAME_SPEC §1): sub-15s target, ~45% intermission / ~45% run-up / ~10% resolution.
Constants.PASS = {
	INTERMISSION_SECONDS = 6,
	RUNUP_SECONDS = 6,
	RESOLUTION_SECONDS = 1.5,
	AIM_LOCK_BEFORE_TICK = 0.3, -- aim freezes this long before the tick — decision timing, never a ping war
}

return Constants
