--!strict
-- Types.luau — the shared type vocabulary of the pass. A leaf module: it requires nothing, so every
-- other module may require it without any risk of a cycle.
--
-- Why this exists rather than living in Constants or PassResolver: the words below are used by both,
-- and by everything above them (the server match runner, the client wheel, the GUI reveal). Declared
-- in one of those two, the other has to either duplicate them or take a require it does not otherwise
-- want. Declared here, `Constants` can annotate its tables with the SAME singleton unions the
-- resolver's signatures speak, which is what makes the type checker able to see the pass at all —
-- untyped, `Constants.RING[n]` widens to `string` and every `Tier`/`Direction` signature downstream
-- silently degrades to "any string will do". (ADR 0011.)

local Types = {}

-- The eight notches of the wheel plus neutral (GAME_SPEC §3, ADR 0006). The four cardinals are the
-- words the design speaks; the diagonals are granularity. Self-relative throughout — a mirrored pass
-- carries no left/right ambiguity.
export type Direction =
	"up" | "up-in" | "in" | "down-in" | "down" | "down-out" | "out" | "up-out" | "neutral"

-- What a notch of a defender's ring is, before breaking degrades it. This is the RING table's value
-- type: `Constants.RING` maps a notch offset to one of these (ADR 0006's CCCNGNNN).
--   crit   — struck here and uncovered, this rider takes the crit tier
--   guard  — the aim-derived defense; a strike here is blocked
--   normal — an uncontested strike
--   mortal — only reachable by breaking (ADR 0008); never authored in a ring literal
export type RingClass = "crit" | "guard" | "normal" | "mortal"

-- The outcome tier of one strike (GAME_SPEC §4).
--   blocked — the strike met the Shield or the Guard (clean if the defender supershielded, thin otherwise)
--   normal  — an uncontested strike
--   crit    — struck in the Crit the defender's own aim opened, and left uncovered
--   weak    — a neutral-aim strike: chip damage, no crit potential, no honesty buff (§3 baseline 1)
--   mortal  — a crit slice broken once more: unhorsed with no roll at all (ADR 0008)
export type Tier = "blocked" | "normal" | "crit" | "weak" | "mortal"

-- The named-direction record `Constants.DIRECTIONS` carries. Spelled out field by field rather than
-- as `{ [string]: Direction }` so a typo in a key is still a type error at the call site.
export type DirectionNames = {
	IN: Direction,
	OUT: Direction,
	UP: Direction,
	DOWN: Direction,
	UP_IN: Direction,
	DOWN_IN: Direction,
	DOWN_OUT: Direction,
	UP_OUT: Direction,
	NEUTRAL: Direction,
}

return Types
