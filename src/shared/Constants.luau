--!strict
-- Constants.luau — the single source of truth for every tuning number. Never hardcode a number in a
-- system module; name it here and reference it. (Invariant carried from the predecessor repo.)

local Constants = {}

-- The pass cycle (GAME_SPEC §1): sub-15s target, ~45% intermission / ~45% run-up / ~10% resolution.
Constants.PASS = {
	INTERMISSION_SECONDS = 6,
	RUNUP_SECONDS = 6,
	RESOLUTION_SECONDS = 1.5,
	AIM_LOCK_BEFORE_TICK = 0.3, -- aim freezes this long before the tick — decision timing, never a ping war
}

-- The four directions plus neutral (GAME_SPEC §3). Self-relative framing — in/out/up/down — so the
-- mirrored pass carries no left/right ambiguity. Neutral is a legitimate state and the default.
Constants.DIRECTIONS = {
	IN = "in",
	OUT = "out",
	UP = "up",
	DOWN = "down",
	NEUTRAL = "neutral",
}

-- Direction opposition. Polarization (GAME_SPEC §3) derives active guard as the opposite of aim, and
-- the punished tier is "struck opposite your brace" — both read this table, so it is the single place
-- the axis pairing is defined.
Constants.OPPOSITE = {
	["in"] = "out",
	["out"] = "in",
	["up"] = "down",
	["down"] = "up",
	["neutral"] = "neutral",
}

-- The matrix (GAME_SPEC §4): aim vs guards resolves to a tier; tiers translate to Balance damage.
-- WEAK is the neutral-aim strike (§3 neutral baseline 1) — survivable chip, no punish potential, no
-- honesty buff, so cageyness stays legal but never viable.
-- STACK_BLOCK_RESTORE is the defensive bonus (§3): a *stacked* block restores Balance ("blocking is a
-- win, not a non-loss"); a split block merely nullifies. Capped well below NORMAL_DAMAGE so Balance
-- still only trends down across a match and convergence never stalls (§4).
Constants.MATRIX = {
	NORMAL_DAMAGE = 6,
	PUNISHED_DAMAGE = 18,
	WEAK_DAMAGE = 2,
	-- A stacked block is clean: zero damage, plus a restore. A split block is "thin" (§3) — it
	-- nullifies most of the strike but not all of it, and earns no restore.
	STACK_BLOCK_RESTORE = 2,
	THIN_BLOCK_MULT = 0.5,
}

-- The offensive bonus (GAME_SPEC §3): prorated by the fraction of the run-up the *final* aim was
-- held. Stored as a normalized 0–1 fraction, never seconds, so the curve is identical no matter how
-- long a given run-up actually lasts.
--   FLOOR         — hold less than this and the bonus is zero; last-instant flicking stays legal but
--                   becomes a real sacrifice.
--   EASE_EXPONENT — >1 eases in (slow start), back-loading the reward onto genuine commitment.
--   MAX_BONUS     — damage multiplier at a full-run-up hold is (1 + MAX_BONUS).
-- CURVE selects the shape. All three candidates stay implemented so `tools/sim.luau --curve` can
-- re-run the comparison; "linear" is the one M1 ships (ADR 0001). FLOOR and EASE_EXPONENT are read
-- only by the two easing curves and are kept so that comparison stays available.
Constants.PRORATION = {
	CURVE = "linear", -- "linear" | "ease_in" | "floor_ease_in"
	FLOOR = 0.25,
	EASE_EXPONENT = 2,
	MAX_BONUS = 0.35,
}

-- The Balance meter and the teeter roll (GAME_SPEC §4). Anyone hit this pass rolls against their
-- Balance *after* damage to stay mounted — at 80 Balance, 80% stay-on. Public, and printed on screen
-- before the roll (CLAUDE.md invariant 6).
Constants.BALANCE = {
	START = 100,
	MIN = 0,
	MAX = 100,
}

return Constants
