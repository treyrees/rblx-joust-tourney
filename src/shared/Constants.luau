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
	-- The ping guard above is absolute (latency is measured in seconds), so as the run-up shortens
	-- the lock eats a larger share of the window a player actually gets to decide in. This ceiling is
	-- what stops that: the lock may never exceed this fraction of the run-up. It is the reason a
	-- bracket cannot be made arbitrarily fast (ADR 0002) — the floor on run-up duration falls out of
	-- it as AIM_LOCK_BEFORE_TICK / AIM_LOCK_MAX_RUNUP_FRACTION, currently 3 seconds.
	AIM_LOCK_MAX_RUNUP_FRACTION = 0.1,
}

-- The shortest run-up any bracket may use, derived rather than declared: below this the ping guard
-- would swallow the decision window and the pass would stop being a decision (ADR 0002). Speed tiers
-- may make the joust look faster than this implies, but not think faster.
Constants.PASS.MIN_RUNUP_SECONDS = Constants.PASS.AIM_LOCK_BEFORE_TICK / Constants.PASS.AIM_LOCK_MAX_RUNUP_FRACTION

-- The four directions plus neutral (GAME_SPEC §3). Self-relative framing — in/out/up/down — so the
-- mirrored pass carries no left/right ambiguity. Neutral is a legitimate state and the default.
Constants.DIRECTIONS = {
	IN = "in",
	OUT = "out",
	UP = "up",
	DOWN = "down",
	NEUTRAL = "neutral",
}

-- Direction opposition. Polarization (GAME_SPEC §3) derives the Guard as the opposite of the Aim, and
-- the Crit direction as the opposite of the Guard — both read this table, so it is the single place
-- the axis pairing is defined.
Constants.OPPOSITE = {
	["in"] = "out",
	["out"] = "in",
	["up"] = "down",
	["down"] = "up",
	["neutral"] = "neutral",
}

-- The cycle: the four directions in a fixed rotational order, so "one sector around the ring" is a
-- well-defined idea. It is stated in the self-relative labels rather than in screen geometry on
-- purpose — a clockwise/anticlockwise rule would smuggle back exactly the mirrored-pass handedness
-- ambiguity the self-relative framing exists to kill (§3). Index distance 2 is opposition, so
-- CYCLE and OPPOSITE agree by construction.
Constants.CYCLE = { "up", "in", "down", "out" }

-- The RING: what happens at each quarter-turn offset from the defender's own aim. Offset 0 is the
-- direction they are aiming; offset 2 is the direction they are aiming away from.
--   "crit"   — struck here and uncovered, this rider takes the crit tier
--   "guard"  — the aim-derived defense; a strike here is blocked (clean if the Shield is also here)
--   "normal" — an uncontested strike
--
-- This table IS the game's core relation, and its shape decides something the damage numbers cannot
-- touch. Whether a crit can ever be one-sided depends only on symmetry: on a four-ring, offsets 0
-- and 2 are their own negatives, so a crit there is ALWAYS mutual, while offsets 1 and 3 are each
-- other's negatives. A ring is chiral — capable of a one-sided crit — if and only if it marks
-- exactly one of the two perpendicular offsets as "crit". `tools/rings.luau` sweeps the whole space.
Constants.RING = { [0] = "crit", [1] = "normal", [2] = "guard", [3] = "normal" }

-- How many notches the Shield covers, counted from the notch it is placed on. 1 means the Shield
-- defends exactly one direction, which is the shipped rule. It exists as a knob because a ring with
-- more notches than the Shield can cover shrinks the hole card's reach: on an eight-notch ring a
-- one-notch Shield defends half as much of the circle as it does on a four-notch one, which is a
-- balance change smuggled in by an input-resolution change. Kept explicit so it cannot happen by
-- accident.
Constants.SHIELD_BAND = 1

-- What a Guard notch does on its own.
--   "block"     — the Guard blocks by itself, and the Shield stacked on it upgrades that block from
--                 thin to clean. This is the shipped rule, and it makes the Supershield redundant:
--                 the bonus only ever improves a direction the ring already defended, so it can never
--                 compete with spending the Shield on an undefended crit notch.
--   "amplifier" — the Guard defends nothing by itself. It marks where the SHIELD works best: a Shield
--                 there blocks cleanly and restores, a Shield anywhere else blocks thin, and a Guard
--                 notch with no Shield on it is an ordinary hit. Defence is never free, and "Shield
--                 and Guard matching up" becomes the actual source of the bonus rather than a rebate.
Constants.GUARD_MODE = "block"

-- What the Shield does on its own.
--   "block"     — the Shield blocks wherever it is placed, and stacking it on a Guard notch upgrades
--                 that block to clean. Shipped rule. It makes the Shield do two competing jobs, and
--                 the cheaper one always wins: covering a crit notch saves ~21 Balance, stacking on
--                 the Guard saves ~5, so the Supershield is never taken.
--   "amplifier" — the Shield blocks NOTHING by itself. Defence comes from the Guard, which sweeps
--                 with the aim; the Shield is placed once, in the world, and upgrades the Guard to a
--                 clean block when the rider's rotation brings the two together. The Shield then has
--                 exactly one job, cannot be spent on covering a crit, and its whole value is the
--                 second defensive axis GAME_SPEC §3 wanted it to be: a fixed home the rider is paid
--                 to come back to, priced against the crit they could be chasing instead.
Constants.SHIELD_MODE = "block"

-- The matrix (GAME_SPEC §4): Aim vs Shield/Guard resolves to a tier; tiers translate to Balance damage.
-- CRIT_DAMAGE is the tier for a strike into the Crit — the direction opposite the defender's Guard,
-- which by polarization is the direction they are themselves aiming ("you are exposed exactly where
-- you strike"). WEAK is the neutral-aim strike (§3 neutral baseline 1) — survivable chip, no crit
-- potential, no honesty buff, so cageyness stays legal but never viable.
-- SUPERSHIELD_RESTORE is the defensive bonus (§3): a *supershielded* block restores Balance ("blocking
-- is a win, not a non-loss"); an unsupershielded block merely nullifies. Capped well below
-- NORMAL_DAMAGE so Balance still only trends down across a match and convergence never stalls (§4).
Constants.MATRIX = {
	NORMAL_DAMAGE = 6,
	CRIT_DAMAGE = 18,
	WEAK_DAMAGE = 2,
	-- A supershielded block is clean: zero damage, plus a restore. Any other block is "thin" (§3) — it
	-- nullifies most of the strike but not all of it, and earns no restore.
	SUPERSHIELD_RESTORE = 2,
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
