--!strict
-- run.luau — test entry point. Run from the repo root:  lune run tests/run.luau
--
-- Builds the Roblox environment shim against ./src, then loads every *.spec.luau in tests/ (each
-- spec self-registers via testkit). Exits non-zero if any test fails so CI / session-start-hook can
-- gate on it.

local fs = require("@lune/fs")
local process = require("@lune/process")

local roblox = require("./lib/robloxenv")
local kit = require("./lib/testkit")

roblox.build("./src")

-- Auto-discover and load specs (alphabetical for stable output).
local specs = {}
for _, entry in fs.readDir("./tests") do
	if entry:match("%.spec%.luau$") then
		table.insert(specs, entry)
	end
end
table.sort(specs)
for _, spec in specs do
	require("./" .. spec:gsub("%.luau$", ""))
end

process.exit(kit.summary())
