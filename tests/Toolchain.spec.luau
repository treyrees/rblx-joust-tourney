--!strict
-- Toolchain.spec.luau — the gates, checked as a system rather than as five commands people remember.
--
-- Every assertion here exists because the thing it checks actually broke, silently, and cost session
-- time rather than producing a red build:
--
--   * The SessionStart hook was committed non-executable (git mode 100644). Every fresh clone — and
--     a remote session is ALWAYS a fresh clone — failed it with "Permission denied", so no session
--     ever had a toolchain or a gate result at startup, and every session paid to bootstrap by hand.
--     Nothing failed; the hook just quietly did not exist.
--   * `.github/workflows/gates.yml`, `.claude/hooks/session-start.sh` and WORKFLOW.md each carried
--     their own copy of the gate list, and they had already drifted: the hook silently ran three of
--     the four gates while the docs said it ran all of them.
--
-- Both are the same failure mode — a claim about the build with nothing checking it — which is
-- exactly what design-lint does for the design docs. This is that idea pointed at the toolchain.

local fs = require("@lune/fs")
local process = require("@lune/process")

local kit = require("./lib/testkit")

local gitExec = (process :: any).exec or (process :: any).spawn

kit.describe("the gate scripts are runnable from a fresh clone", function()
	-- Everything a session or CI executes directly, and therefore everything whose executable bit is
	-- load-bearing. Checked against GIT's recorded mode, not the working tree's: `chmod +x` locally
	-- fixes nothing if the mode was never committed, and the working tree of the machine writing the
	-- commit is the one place the bug is invisible.
	local EXECUTABLES = {
		".claude/hooks/session-start.sh",
		"tools/gates.sh",
		"tools/install-toolchain.sh",
	}
	for _, path in EXECUTABLES do
		kit.it(path .. " is committed executable", function()
			local res = gitExec("git", { "ls-files", "-s", "--", path })
			kit.expectTrue(res.ok, "git ls-files failed for " .. path)
			local mode = (res.stdout :: string):match("^(%d+)")
			kit.expectTrue(
				mode ~= nil,
				path .. " is not tracked by git — a script the hook or CI invokes must be committed"
			)
			kit.expectEqual(
				mode,
				"100755",
				path .. " is committed with mode " .. tostring(mode) .. ", not 100755. A fresh clone will "
					.. "fail to execute it (`Permission denied`) and whatever runs it will silently do "
					.. "nothing. Fix with: git update-index --chmod=+x " .. path
			)
		end)
	end
end)

kit.describe("one gate list, referenced everywhere", function()
	-- tools/gates.sh is the definition. Everything else must agree with it.
	local gatesSh = fs.readFile("./tools/gates.sh")
	local declared: { string } = {}
	local list = gatesSh:match("\nGATES=%((.-)%)")
	kit.it("tools/gates.sh declares a GATES list", function()
		kit.expectTrue(list ~= nil, "could not find the GATES=( … ) declaration in tools/gates.sh")
	end)
	if list then
		for name in list:gmatch("[%w%-]+") do
			table.insert(declared, name)
		end
	end

	kit.it("every declared gate has an implementation in the script", function()
		kit.expectTrue(#declared > 0, "the GATES list is empty")
		for _, name in declared do
			-- gate_design-lint would not be a legal shell function name, so underscores.
			local fn = "gate_" .. name:gsub("%-", "_")
			kit.expectTrue(
				gatesSh:find("\n" .. fn .. "() {", 1, true) ~= nil,
				"gate '" .. name .. "' is listed in GATES but has no " .. fn .. "() in tools/gates.sh"
			)
			-- Plain find: a gate name may contain `-`, which is a quantifier in a Lua pattern.
			kit.expectTrue(
				gatesSh:find("    " .. name .. ") ", 1, true) ~= nil,
				"gate '" .. name .. "' is listed in GATES but the run_gate case statement does not dispatch it"
			)
		end
	end)

	kit.it("CI runs every gate, and runs them through tools/gates.sh", function()
		local ci = fs.readFile("./.github/workflows/gates.yml")
		for _, name in declared do
			kit.expectTrue(
				ci:find("tools/gates.sh " .. name, 1, true) ~= nil,
				".github/workflows/gates.yml never runs `tools/gates.sh " .. name .. "` — CI would not be "
					.. "checking a gate the repo claims to have. Add a step for it."
			)
		end
	end)

	kit.it("the session-start hook runs the gates through the same script", function()
		local hook = fs.readFile("./.claude/hooks/session-start.sh")
		kit.expectTrue(
			hook:find("tools/gates.sh", 1, true) ~= nil,
			"the SessionStart hook no longer calls tools/gates.sh — it has its own copy of the gate list "
				.. "again, which is how the hook came to silently skip a gate the docs promised"
		)
		kit.expectTrue(
			hook:find("tools/install-toolchain.sh", 1, true) ~= nil,
			"the SessionStart hook no longer installs the pinned toolchain — it will either run whatever "
				.. "happens to be on PATH or build one from source, which is the multi-minute session "
				.. "startup this arrangement exists to delete"
		)
	end)

	kit.it("WORKFLOW.md documents the gate list the script actually runs", function()
		local workflow = fs.readFile("./docs/design/WORKFLOW.md")
		for _, name in declared do
			kit.expectTrue(
				workflow:find(name, 1, true) ~= nil,
				"docs/design/WORKFLOW.md never mentions the '" .. name .. "' gate. The doc that defines how "
					.. "we work must list every gate that can turn a build red."
			)
		end
	end)
end)

kit.describe("the toolchain is pinned, in exactly one place", function()
	local env = fs.readFile("./tools/toolchain.env")
	local PINS = { "LUNE_VERSION", "LUAU_LSP_VERSION", "ROJO_VERSION" }

	for _, key in PINS do
		kit.it(key .. " is pinned to a concrete version", function()
			local value = env:match("\n" .. key .. "=([%w%.%-]+)")
			kit.expectTrue(value ~= nil, key .. " is missing from tools/toolchain.env")
			kit.expectTrue(
				(value :: string):match("^%d+%.%d+") ~= nil,
				key .. " = " .. tostring(value) .. " is not a concrete version. An unpinned toolchain means "
					.. "CI and a session can silently disagree about what green means."
			)
		end)
	end

	kit.it("no version literal is duplicated outside tools/toolchain.env", function()
		-- The failure this prevents: CI pinned Lune 0.10.5 in its own yaml while the hook installed
		-- whatever `cargo install lune` resolved to. Two pins, one of them always about to be wrong.
		local ci = fs.readFile("./.github/workflows/gates.yml")
		local hook = fs.readFile("./.claude/hooks/session-start.sh")
		for _, key in PINS do
			local value = env:match("\n" .. key .. "=([%w%.%-]+)") :: string
			for label, text in { ci = ci, hook = hook } do
				kit.expectNil(
					text:find(value, 1, true),
					"the version " .. value .. " (" .. key .. ") appears literally in the " .. label
						.. " — it must be read from tools/toolchain.env instead, or the two pins will drift"
				)
			end
		end
	end)

	kit.it("the installer knows how to install every pinned component", function()
		local installer = fs.readFile("./tools/install-toolchain.sh")
		for _, key in PINS do
			kit.expectTrue(
				installer:find("$" .. key, 1, true) ~= nil,
				"tools/install-toolchain.sh never reads " .. key .. " — the pin would be decorative"
			)
		end
	end)
end)
