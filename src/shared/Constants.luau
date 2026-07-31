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

-- The directions plus neutral (GAME_SPEC §3, ADR 0006). The game is played on a FOUR-DIRECTION
-- BASIS — in/out/up/down are the words the design speaks — with the diagonals between them giving
-- the wheel its granularity: eight notches of 45 degrees. Self-relative framing throughout, so the
-- mirrored pass carries no left/right ambiguity. Neutral is a legitimate state and the default.
Constants.DIRECTIONS = {
	IN = "in",
	OUT = "out",
	UP = "up",
	DOWN = "down",
	UP_IN = "up-in",
	DOWN_IN = "down-in",
	DOWN_OUT = "down-out",
	UP_OUT = "up-out",
	NEUTRAL = "neutral",
}

-- Direction opposition: index distance 4 on the cycle, tabled so callers stay O(1) and the pairing
-- has a single home. Polarization (§3) derives the Guard from this.
Constants.OPPOSITE = {
	["up"] = "down",
	["up-in"] = "down-out",
	["in"] = "out",
	["down-in"] = "up-out",
	["down"] = "up",
	["down-out"] = "up-in",
	["out"] = "in",
	["up-out"] = "down-in",
	["neutral"] = "neutral",
}

-- The cycle: the eight notches in a fixed rotational order, so "one notch around the ring" is a
-- well-defined idea. It is stated in the self-relative labels rather than in screen geometry on
-- purpose — a clockwise/anticlockwise rule would smuggle back exactly the mirrored-pass handedness
-- ambiguity the self-relative framing exists to kill (§3). The rotational sense is "from up, sweep
-- toward the barrier side" for both riders, so the chiral ring below means the same body-relative
-- thing in a mirrored pass. Index distance 4 is opposition; CYCLE and OPPOSITE agree by construction.
Constants.CYCLE = { "up", "up-in", "in", "down-in", "down", "down-out", "out", "up-out" }

-- The RING (ADR 0006): what happens at each notch offset from the defender's own aim. Offset 0 is
-- the notch they are aiming; offset 4 is the notch they are aiming away from.
--   "crit"   — struck here and uncovered, this rider takes the crit tier
--   "guard"  — the aim-derived defense; a strike here is blocked (clean if the Shield is also here)
--   "normal" — an uncontested strike
--
-- This table IS the game's core relation. The shipped shape is CCCNGNNN: you are exposed at the
-- notch you strike with and for two more notches sweeping toward your barrier side (135 degrees),
-- your Guard is a 45-degree notch directly opposite, and the rest is ordinary. Two properties are
-- load-bearing and neither is a tuning number:
--   * CHIRALITY — the crit wedge hangs off ONE side of the aim. A mirror-symmetric ring can only
--     ever trade crits (an offset and its negation are both crits or neither), so one-sided crits —
--     reads that WIN rather than exchange — exist iff the ring is chiral. ADR 0006 cites the sweep.
--   * MORE EXPOSURE THAN SHIELD — three crit notches against a two-notch Shield means something is
--     always bare, and WHICH is the hole card. Equilibrium leaves ~1 bit of it unreadable.
Constants.RING = {
	[0] = "crit",
	[1] = "crit",
	[2] = "crit",
	[3] = "normal",
	[4] = "guard",
	[5] = "normal",
	[6] = "normal",
	[7] = "normal",
}

-- How many notches the Shield covers, counted from the notch it is placed on. Two notches is a
-- 90-degree plate — the same quarter-circle the four-notch game's one-notch Shield covered, kept
-- deliberately equal so the move to eight notches was granularity and not a stealth nerf (the ratio
-- that matters is Shield to crit surface: two of three exposure notches coverable, one always bare).
-- ADR 0006 cites the band sweep: this is a hole-card dial, not a convergence dial — widening it
-- lengthens matches AND deletes the hidden information at the same time.
Constants.SHIELD_BAND = 2

-- What a Guard notch does on its own.
--   "block"     — the Guard blocks by itself, and the Shield stacked on it upgrades that block from
--                 thin to clean. This is the shipped rule. At full Balance the upgrade can never
--                 compete with spending the Shield on an undefended crit notch — the Supershield is
--                 dormant there and takes over below ~85 Balance (ADR 0009).
--   "amplifier" — the Guard defends nothing by itself. It marks where the SHIELD works best: a Shield
--                 there blocks cleanly and restores, a Shield anywhere else blocks thin, and a Guard
--                 notch with no Shield on it is an ordinary hit. Defence is never free, and "Shield
--                 and Guard matching up" becomes the actual source of the bonus rather than a rebate.
Constants.GUARD_MODE = "block"

-- What the Shield does on its own.
--   "block"     — the Shield blocks wherever it is placed, and stacking it on a Guard notch upgrades
--                 that block to clean. Shipped rule. The Shield does two jobs and the healthy rider
--                 always takes the cheaper one (covering a crit notch), which is what makes the
--                 Supershield state-dependent rather than dead (ADR 0009).
--   "amplifier" — the Shield blocks NOTHING by itself. Defence comes from the Guard, which sweeps
--                 with the aim; the Shield is placed once, in the world, and upgrades the Guard to a
--                 clean block when the rider's rotation brings the two together. The Shield then has
--                 exactly one job, cannot be spent on covering a crit, and its whole value is the
--                 second defensive axis GAME_SPEC §3 wanted it to be: a fixed home the rider is paid
--                 to come back to, priced against the crit they could be chasing instead.
Constants.SHIELD_MODE = "block"

-- Does the Supershield have to be EARNED over the run-up, or merely arrived at? (ADR 0009)
-- Offence is prorated: a last-instant flick forfeits the damage multiplier. Left unpriced, defence
-- was not — so a rider could spur the whole run-up for momentum, snap into alignment at the tick,
-- and take breaking AND perfect defence while paying only in damage. Requiring the aligning aim to
-- have been HELD prices defence the way offence is already priced: speed costs directional power on
-- both halves of the pass. The cited run has the double-dip at 36.5% with this at 0.5, against
-- 43.1% free — priced out today, and foreclosed in the low-Balance regime where free defence
-- actually pays.
Constants.SUPERSHIELD_MIN_HOLD = 0.5

-- BREAKING (GAME_SPEC §5's depleting coverage, with the trigger moved).
-- A strike that lands carrying enough buildup BREAKS the direction it hit, degrading that slice of
-- the defender's ring one step down the ladder for the rest of the match:
--     guard -> normal -> crit -> (stays crit)
-- The trigger is deliberately slice-AGNOSTIC. Crits are already the slice-keyed reward, so breaking
-- is keyed to MOMENTUM alone - the speed built by spurring in neutral during the run-up.
-- Deliberately not proration: proration already owns the damage multiplier, and giving it breaking
-- too would have one currency doing both jobs. Speed owned nothing, and structural force is what a
-- fast horse should diegetically do. The run-up's single allocation - hold an aim or spur - then
-- becomes the game's now-versus-later: a bigger roll this pass, or a worse ring for the rest of the
-- match.
-- Breaks attach to ABSOLUTE directions, not ring offsets, or they would rotate with the defender and
-- mean nothing. Anchored to the world they become a hole the defender must steer around, which puts
-- them on the same footing as the Shield and gives rotation a second, growing cost.
Constants.BREAK = {
	ENABLED = true,
	-- Which buildup currency breaks slices, and by implication which one keeps the damage multiplier.
	-- "momentum" is the argued default; "proration" swaps the two so the pairing can be tested rather
	-- than assumed.
	TRIGGER = "momentum",
	MOMENTUM_THRESHOLD = 0.6,
	-- The ladder continues past crit into a MORTAL slice: struck there and uncovered, the rider goes
	-- down with no roll at all. It inverts how the match ends — falls are normally decided by a
	-- teeter the rider was usually favoured to win, so a mortal slice moves the endgame from the dice
	-- back onto a read, which is what invariant 1 says should decide things. Reaching it takes three
	-- breaks on the same absolute direction, so it stays the rare, telegraphed execution.
	MORTAL = true,
	BLOCKED_BREAKS = true, -- battering a guard should break it, so blocked strikes break it too
}

-- The matrix (GAME_SPEC §4): Aim vs the ring resolves to a tier; tiers translate to Balance damage.
-- CRIT_DAMAGE is the tier for a strike into an uncovered crit notch — the defender's own aim and the
-- two notches sweeping on from it ("you are exposed exactly where you strike, and one turn around").
-- The 3x ratio is the price the whole read game runs on (ADR 0001); the SCALE was re-pinned 6/18 →
-- 5/15 by ADR 0006, because crits fire at equilibrium on the eight-notch ring where the old ring's
-- never did, and the old scale priced a crit economy that did not exist. WEAK is the neutral-aim
-- strike (§3 neutral baseline 1) — survivable chip, no crit potential, no honesty buff.
-- SUPERSHIELD_RESTORE is the defensive bonus (§3): a *supershielded* block restores Balance
-- ("blocking is a win, not a non-loss"); an unsupershielded block merely nullifies. Capped well
-- below NORMAL_DAMAGE so Balance still only trends down and convergence never stalls (§4).
Constants.MATRIX = {
	NORMAL_DAMAGE = 5,
	CRIT_DAMAGE = 15,
	WEAK_DAMAGE = 2,
	-- A supershielded block is clean: zero damage, plus a restore. Any other block is "thin" (§3) — it
	-- nullifies most of the strike but not all of it, and earns no restore.
	SUPERSHIELD_RESTORE = 2,
	THIN_BLOCK_MULT = 0.5,
	-- ADR 0005 proposed pricing the Supershield back into the equilibrium with an offensive bonus.
	-- ADR 0009 supersedes it: the sweep found no parity to find — the bonus is a cliff (ignored below
	-- ~+0.25, mandatory above +0.5, hole card dead either way), and the Supershield's real value is
	-- STATE-dependent, arriving on its own below ~85 Balance with no bonus at all. Kept at 0; kept as
	-- a key because the sweep instrument (`tools/rings.luau --ss-bonus`) still exercises it.
	SUPERSHIELD_STRIKE_BONUS = 0,
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

-- The wheel input's FEEL (invariant 4: animation may be smooth, the televised state is always the
-- discrete notch). Client-side only — the server never sees anything but the quantized notch — so
-- none of these numbers touch the combat model. Tuned by hand in the browser feel rig
-- (prototypes/ring-feel.html); this is its "Magnet" preset: easy to steer, takes a little attention
-- to confirm the notch you want. Units: angle in notches (1.0 = 45 degrees), time in seconds.
Constants.WHEEL = {
	-- While the finger is down, the needle is biased toward the nearest notch by this fraction:
	-- 0 is a free glide, 1 is a fully quantized click-wheel.
	DETENT = 0.45,
	-- On release the needle beds into the nearest notch under a per-notch spring potential
	-- (torque = -STIFFNESS * sin(2*pi*theta) / 2*pi) with viscous damping.
	STIFFNESS = 180,
	DAMPING = 14, -- applied while settling into a notch
	FRICTION = 3, -- applied instead of DAMPING while spinning from a flick
	-- Release speeds below FLICK_MIN (notches/second) snap straight back instead of spinning; the
	-- release speed itself is the median over the last FLICK_WINDOW seconds of drag.
	FLICK_MIN = 0.6,
	FLICK_WINDOW = 0.09,
	-- Above SPIN_OMEGA the wheel is "spinning" (FRICTION governs); below it, "settling" (DAMPING).
	SPIN_OMEGA = 0.5,
	-- Close enough to call it landed: the needle clamps exactly onto the notch.
	SETTLE_OMEGA = 0.02,
	SETTLE_DIST = 0.002,
	-- Integration guards: clamp a hitchy frame, sub-step so high stiffness stays stable.
	MAX_DT = 0.032,
	SUBSTEP = 0.004,
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
