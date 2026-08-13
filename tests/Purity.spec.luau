--!strict
-- Purity.spec.luau — the code-side invariants, checked by machine rather than remembered.
--
-- CLAUDE.md states two conventions about `src/` that nothing verified: `--!strict` on new modules,
-- and headless-first ("every pure system gets Lune unit tests before it gets a UI"). The second one
-- rests on a property of `src/shared/` that is easy to break by accident and expensive to discover
-- late: shared modules are PURE — no engine, no clock, no hidden randomness. That property is why
-- `tools/sim.luau` can run PassResolver half a million times without an engine, why the equilibrium
-- solver can enumerate the payoff matrix at all, and why CLAUDE.md invariant 3's simultaneous
-- resolution is reproducible under a seeded rng (invariant 6: the ONLY randomness is the teeter
-- roll, and the caller injects it).
--
-- The day someone reaches for `math.random` or `tick()` inside shared, both instruments quietly stop
-- measuring the shipped game — they keep running, and they keep printing verdicts. This spec is what
-- turns that into a red gate on the commit that does it instead.
--
-- Escape hatch, because a rule with no exit is a rule people delete: a module may opt out by
-- carrying `-- @impure: <reason>` in its header. That is a deliberate, reviewable, greppable act;
-- reaching for `os.clock()` inside a resolver is not.

local fs = require("@lune/fs")

local roblox = require("./lib/robloxenv")
local kit = require("./lib/testkit")

-- Every ModuleScript under src/, by mount. Sourced from the shim's tree rather than a hand-kept
-- list, so a module added tomorrow is covered the moment it exists.
local MOUNTS: { { label: string, root: any } } = {
	{ label = "shared", root = (roblox :: any)._shared },
	{ label = "server", root = (roblox :: any)._server },
	{ label = "client", root = (roblox :: any)._client },
	{ label = "gui", root = (roblox :: any)._gui },
}

-- Comments are prose about the code, not the code. `-- no math.random here, the caller injects it`
-- must not trip a check that exists to catch an actual call, so scanning happens on source with
-- comments removed. Block comments first, then trailing line comments.
local function stripComments(src: string): string
	local out = src:gsub("%-%-%[%[.-%]%]", " ")
	out = out:gsub("([^\n]*)", function(line)
		return (line:gsub("%-%-.*$", ""))
	end)
	return out
end

local function header(src: string): string
	return src:sub(1, 2000)
end

-- ---- --!strict on every module -------------------------------------------------------------------

kit.describe("src/ conventions — every module is --!strict (CLAUDE.md)", function()
	for _, mount in MOUNTS do
		for name, inst in roblox.modulesUnder(mount.root) do
			kit.it(mount.label .. "/" .. name .. " opens with --!strict", function()
				local src = roblox.sourceOf(inst)
				kit.expectTrue(
					src:match("^%-%-!strict") ~= nil,
					mount.label .. "/" .. name .. ".luau must open with `--!strict` — the type-check gate "
						.. "(tools/gates.sh typecheck) only checks what the file asks it to"
				)
			end)
		end
	end
end)

-- ---- src/shared stays pure -----------------------------------------------------------------------

-- Each rule is a pattern plus the reason it exists. The patterns are deliberately narrow: this gate
-- is only worth having if a red result always means a real problem.
type Rule = { pattern: string, what: string, why: string }

local PURITY_RULES: { Rule } = {
	{
		pattern = "GetService",
		what = "a Roblox service",
		why = "shared runs headless in Lune under tools/sim.luau and tools/rings.luau; a service lookup "
			.. "there means the instruments can no longer load the module they are supposed to measure",
	},
	{
		pattern = "Instance%.new",
		what = "Instance.new",
		why = "instance construction is presentation. Shared owns numbers; src/client and src/gui own "
			.. "the things the player looks at",
	},
	{
		pattern = "math%.random",
		what = "math.random",
		why = "CLAUDE.md invariant 6 — the only randomness in the pass is the teeter roll, and the "
			.. "CALLER injects it, so a seeded run reproduces exactly. Ambient rng makes the sim's "
			.. "fixed-seed determinism a fiction",
	},
	{
		pattern = "Random%.new",
		what = "Random.new",
		why = "same as math.random: rng arrives as a parameter, never from inside",
	},
	{
		pattern = "os%.time",
		what = "os.time",
		why = "a clock read makes the same inputs resolve differently on two runs, which breaks both "
			.. "the unit tests and CLAUDE.md invariant 3's snapshot semantics",
	},
	{
		pattern = "os%.clock",
		what = "os.clock",
		why = "same as os.time — shared resolves snapshots, it does not observe the passage of time",
	},
	{
		pattern = "%f[%w]tick%s*%(",
		what = "tick()",
		why = "same as os.time — and it is the one that tends to sneak in as a 'temporary' timestamp",
	},
	{
		pattern = "task%.wait",
		what = "task.wait",
		why = "yielding inside the resolver would make the pass resolve across frames, which is exactly "
			.. "what CLAUDE.md invariant 3 (one tick, simultaneous, no order bias) forbids",
	},
	{
		pattern = "%f[%w]wait%s*%(",
		what = "wait()",
		why = "same as task.wait, and deprecated besides",
	},
}

kit.describe("src/shared stays pure — headless, deterministic, engine-free", function()
	for name, inst in roblox.modulesUnder((roblox :: any)._shared) do
		local src = roblox.sourceOf(inst)
		local optOut = header(src):match("@impure:%s*([^\n]*)")
		if optOut then
			kit.it("shared/" .. name .. " declares itself impure: " .. optOut, function()
				-- The opt-out must say WHY. An unexplained one is worse than no rule at all: it reads
				-- as approved and carries none of the reasoning that would let a reviewer judge it.
				kit.expectTrue(
					#(optOut:gsub("%s", "")) >= 10,
					"shared/" .. name .. " carries `@impure:` with no real reason given"
				)
			end)
			continue
		end
		local code = stripComments(src)
		for _, rule in PURITY_RULES do
			kit.it("shared/" .. name .. " does not reach for " .. rule.what, function()
				kit.expectNil(
					code:match(rule.pattern),
					"shared/" .. name .. ".luau uses " .. rule.what .. " — " .. rule.why
						.. ". If this is genuinely justified, declare `-- @impure: <reason>` in the header"
				)
			end)
		end
	end
end)

-- ---- the shim mirrors the project file -----------------------------------------------------------

-- robloxenv's whole promise is "the same source Rojo syncs into Studio". A mount present in
-- default.project.json but absent from the shim silently exempts a quarter of the tree from every
-- headless test — which is precisely what had happened to src/client and src/gui.
kit.describe("robloxenv mirrors default.project.json", function()
	local project = fs.readFile("./default.project.json")
	for _, mount in MOUNTS do
		kit.it("src/" .. mount.label .. " is mounted in the shim and mapped by Rojo", function()
			kit.expectTrue(
				project:find('"src/' .. mount.label .. '"', 1, true) ~= nil,
				"default.project.json no longer maps src/" .. mount.label
					.. " — update tests/lib/robloxenv.luau to match, or drop the mount from both"
			)
			kit.expectTrue(mount.root ~= nil, "robloxenv does not mount src/" .. mount.label)
		end)
	end
end)
