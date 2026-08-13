--!strict
-- testkit.luau — tiny describe/it/expect harness. No third-party deps; runs under Lune.
-- Collects pass/fail counts and returns a process exit code from summary().
--
-- Quiet mode: set TESTKIT_QUIET=1 to suppress the per-suite (•) and per-pass (✓) lines,
-- printing only failures and the final summary. The session-start hook runs quiet so a green
-- run costs one line instead of ~1,200; interactive `lune run tests/run.luau` stays verbose.
--
-- Filtering: set TESTKIT_FILTER to a Lua pattern and only suites/tests whose full name matches it
-- run; the rest are counted as skipped. `TESTKIT_FILTER=proration lune run tests/run.luau` is the
-- inner-loop command when you are working on one thing and 36 (soon: hundreds) of tests are not it.

local process = require("@lune/process")

local kit = {
	_passed = 0,
	_failed = 0,
	_skipped = 0,
	-- The describe stack, so nested suites read as "Outer › Inner › the test".
	_stack = {} :: { string },
	_failures = {} :: { string },
	_quiet = process.env.TESTKIT_QUIET == "1" or process.env.TESTKIT_QUIET == "true",
	_filter = process.env.TESTKIT_FILTER,
}

local function path(name: string?): string
	local parts = table.clone(kit._stack)
	if name then
		table.insert(parts, name)
	end
	return table.concat(parts, " › ")
end

local function matchesFilter(name: string): boolean
	local f = kit._filter
	if f == nil or f == "" then
		return true
	end
	-- Match against the FULL path, so filtering on a suite name runs everything inside it.
	return path(name):lower():find(f:lower()) ~= nil
end

-- A describe body runs OUTSIDE any `it`, so an error thrown there (a bad require, a nil index in
-- shared setup) used to abort the whole run with a raw traceback and no summary — losing the results
-- of every suite that had already passed, and every suite that would have followed. It is contained
-- here and reported as a failure of the suite itself.
function kit.describe(name: string, fn: () -> ())
	table.insert(kit._stack, name)
	if not kit._quiet then
		print(string.rep("  ", #kit._stack - 1) .. "• " .. name)
	end
	local ok, err = pcall(fn)
	if not ok then
		kit._failed += 1
		table.insert(kit._failures, path() .. " (suite body)\n      " .. tostring(err))
		print(string.rep("  ", #kit._stack - 1) .. "✗ " .. name .. " — suite body raised")
	end
	table.remove(kit._stack)
end

function kit.it(name: string, fn: () -> ())
	if not matchesFilter(name) then
		kit._skipped += 1
		return
	end
	local indent = string.rep("  ", #kit._stack)
	local ok, err = pcall(fn)
	if ok then
		kit._passed += 1
		if not kit._quiet then
			print(indent .. "✓ " .. name)
		end
	else
		kit._failed += 1
		table.insert(kit._failures, path(name) .. "\n      " .. tostring(err))
		print(indent .. "✗ " .. name)
	end
end

function kit.expectEqual(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error((msg or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
	end
end

function kit.expectNear(actual: number, expected: number, eps: number?, msg: string?)
	local e = eps or 1e-9
	if math.abs(actual - expected) > e then
		error((msg or "not near") .. ": expected ~" .. tostring(expected) .. ", got " .. tostring(actual), 2)
	end
end

function kit.expectTrue(actual: any, msg: string?)
	if not actual then
		error((msg or "expected truthy") .. ", got " .. tostring(actual), 2)
	end
end

function kit.expectFalse(actual: any, msg: string?)
	if actual then
		error((msg or "expected falsy") .. ", got " .. tostring(actual), 2)
	end
end

function kit.expectNil(actual: any, msg: string?)
	if actual ~= nil then
		error((msg or "expected nil") .. ", got " .. tostring(actual), 2)
	end
end

-- Structural equality over nested tables. `expectEqual` compares tables by identity, which quietly
-- passes nothing useful when what you meant was "these two results have the same contents" — the
-- shape every resolver/outcome assertion actually wants.
local function deepEqual(a: any, b: any, trail: string): string?
	if a == b then
		return nil
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return trail .. ": expected " .. tostring(b) .. ", got " .. tostring(a)
	end
	for k, v in a :: { [any]: any } do
		local mismatch = deepEqual(v, (b :: { [any]: any })[k], trail .. "." .. tostring(k))
		if mismatch then
			return mismatch
		end
	end
	for k in b :: { [any]: any } do
		if (a :: { [any]: any })[k] == nil then
			return trail .. "." .. tostring(k) .. ": missing (expected " .. tostring((b :: { [any]: any })[k]) .. ")"
		end
	end
	return nil
end

function kit.expectDeepEqual(actual: any, expected: any, msg: string?)
	local mismatch = deepEqual(actual, expected, "value")
	if mismatch then
		error((msg or "tables differ") .. " at " .. mismatch, 2)
	end
end

function kit.expectError(fn: () -> (), msg: string?)
	local ok = pcall(fn)
	if ok then
		error(msg or "expected an error, but none was raised", 2)
	end
end

-- Print summary; return 0 if all green, 1 otherwise.
function kit.summary(): number
	print("")
	if kit._skipped > 0 then
		print(string.format("filter %q — %d test(s) skipped", tostring(kit._filter), kit._skipped))
	end
	if kit._failed == 0 then
		-- A filter that matches nothing is a typo, not a green run. Reporting "PASS — 0 passed" for it
		-- is the one way this harness could tell a comfortable lie.
		if kit._passed == 0 then
			print("FAIL — no tests ran" .. (if kit._filter then " (filter matched nothing)" else ""))
			return 1
		end
		print(string.format("PASS — %d passed", kit._passed))
		return 0
	end
	print(string.format("FAIL — %d passed, %d failed", kit._passed, kit._failed))
	for _, f in kit._failures do
		print("  - " .. f)
	end
	return 1
end

return kit
