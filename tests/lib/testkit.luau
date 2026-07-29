--!strict
-- testkit.luau — tiny describe/it/expect harness. No third-party deps; runs under Lune.
-- Collects pass/fail counts and returns a process exit code from summary().
--
-- Quiet mode: set TESTKIT_QUIET=1 to suppress the per-suite (•) and per-pass (✓) lines,
-- printing only failures and the final summary. The session-start hook runs quiet so a green
-- run costs one line instead of ~1,200; interactive `lune run tests/run.luau` stays verbose.

local process = require("@lune/process")

local kit = {
	_passed = 0,
	_failed = 0,
	_current = nil :: string?,
	_failures = {} :: { string },
	_quiet = process.env.TESTKIT_QUIET == "1" or process.env.TESTKIT_QUIET == "true",
}

function kit.describe(name: string, fn: () -> ())
	kit._current = name
	if not kit._quiet then
		print("• " .. name)
	end
	fn()
	kit._current = nil
end

function kit.it(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		kit._passed += 1
		if not kit._quiet then
			print("  ✓ " .. name)
		end
	else
		kit._failed += 1
		local where = (kit._current or "?") .. " › " .. name
		table.insert(kit._failures, where .. "\n      " .. tostring(err))
		print("  ✗ " .. name)
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

function kit.expectError(fn: () -> (), msg: string?)
	local ok = pcall(fn)
	if ok then
		error(msg or "expected an error, but none was raised", 2)
	end
end

-- Print summary; return 0 if all green, 1 otherwise.
function kit.summary(): number
	print("")
	if kit._failed == 0 then
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
