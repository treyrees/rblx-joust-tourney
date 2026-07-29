--!strict
-- robloxenv.luau — a minimal Roblox-environment shim for running game ModuleScripts under Lune.
--
-- Why: the game modules use Roblox-idiomatic requires (`require(script.Parent.Constants)`) and the
-- `game:GetService(...)` tree. Lune is a plain Luau runtime with string requires. This shim builds an
-- instance tree from the filesystem and runs each module in an environment where `script`, `require`,
-- and `game` behave like Roblox — so the SAME source that Rojo syncs into Studio also runs in CI with
-- zero modification. Keep this thin; grow it only as ported modules need more of the Roblox API.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local task = require("@lune/task")

local M = {}

-- ---- fake Instance -----------------------------------------------------------------------------
local Instance = {}
Instance.__index = function(self, key)
	local method = rawget(Instance, key)
	if method then
		return method
	end
	local children = rawget(self, "_children")
	if children and children[key] then
		return children[key]
	end
	return nil
end

function Instance.FindFirstChild(self, name: string)
	local c = rawget(self, "_children")
	return c and c[name] or nil
end

function Instance.WaitForChild(self, name: string)
	local child = Instance.FindFirstChild(self, name)
	if not child then
		error("WaitForChild: no child '" .. name .. "' under " .. tostring(rawget(self, "Name")))
	end
	return child
end

local function newInstance(name: string, className: string)
	return setmetatable({ Name = name, ClassName = className, Parent = nil, _children = {} }, Instance)
end

local function addChild(parent, child)
	rawset(child, "Parent", parent)
	rawget(parent, "_children")[rawget(child, "Name")] = child
end

-- ---- module loading with a Roblox-like env -----------------------------------------------------
local requireInstance -- forward declaration

local function makeEnv(scriptInst)
	-- Roblox-specific globals. injectGlobals=true (below) layers the Luau stdlib on top, plus we
	-- add `typeof` and `warn` which Roblox code expects but Lune doesn't inject.
	return {
		script = scriptInst,
		require = function(target)
			return requireInstance(target)
		end,
		game = M._game,
		typeof = type,
		warn = print,
		task = task, -- Lune's task lib matches the Roblox task API surface the game code uses (spawn/wait/…)
	}
end

function requireInstance(inst)
	if type(inst) ~= "table" then
		error("require expected an Instance, got " .. type(inst))
	end
	if rawget(inst, "_loaded") then
		return rawget(inst, "_result")
	end
	local src = rawget(inst, "_source")
	if not src then
		error("require target is not a ModuleScript: " .. tostring(rawget(inst, "Name")))
	end
	local chunk = luau.load(src, {
		debugName = rawget(inst, "Name"),
		environment = makeEnv(inst),
		injectGlobals = true,
	})
	local result = chunk()
	rawset(inst, "_result", result)
	rawset(inst, "_loaded", true)
	return result
end

-- ---- tree builder ------------------------------------------------------------------------------
local function isModuleFile(entry: string): boolean
	if entry:match("%.server%.lua$") or entry:match("%.client%.lua$") then
		return false -- Script / LocalScript — not require()-able modules
	end
	return entry:match("%.lua$") ~= nil or entry:match("%.luau$") ~= nil
end

local function buildTree(dirPath: string, name: string, className: string)
	local inst = newInstance(name, className)
	for _, entry in fs.readDir(dirPath) do
		local full = dirPath .. "/" .. entry
		if fs.isDir(full) then
			addChild(inst, buildTree(full, entry, "Folder"))
		elseif fs.isFile(full) and isModuleFile(entry) then
			local modName = entry:gsub("%.luau$", ""):gsub("%.lua$", "")
			local m = newInstance(modName, "ModuleScript")
			rawset(m, "_source", fs.readFile(full))
			addChild(inst, m)
		end
	end
	return inst
end

-- ---- public API --------------------------------------------------------------------------------
-- Build the tree from a project src/ root. `shared/` mounts under ReplicatedStorage.Shared and
-- `server/` under ServerScriptService — so server modules (the ported CombatEngine, MatchRunner)
-- can be required and unit-tested headlessly, same source Rojo syncs into Studio.
function M.build(srcRoot: string)
	local shared = buildTree(srcRoot .. "/shared", "Shared", "Folder")
	local rs = newInstance("ReplicatedStorage", "ReplicatedStorage")
	addChild(rs, shared)

	local server = buildTree(srcRoot .. "/server", "Server", "Folder")
	local sss = newInstance("ServerScriptService", "ServerScriptService")
	addChild(sss, server)

	-- In-memory DataStore mock: storeName -> { key -> value }. Lets the persistence layer be exercised
	-- headlessly (Persistence.lua reads DataStoreService/HttpService/RunService). Specs seed/read via
	-- M._datastores directly. Kept thin — grow only as persistence tests need more of the API.
	M._datastores = {}
	M._beforeUpdate = nil -- optional test hook run before each UpdateAsync transform (may yield)
	M._isStudio = false -- default: exercise the real save/load path (not the Studio memory-only short-circuit)
	local guidCounter = 0
	local function getStore(storeName: string)
		local backing = M._datastores[storeName]
		if not backing then
			backing = {}
			M._datastores[storeName] = backing
		end
		return {
			GetAsync = function(_s, key: string)
				return backing[key]
			end,
			UpdateAsync = function(_s, key: string, transform: (any) -> any)
				if M._beforeUpdate then
					M._beforeUpdate(key) -- test hook: may yield, to simulate an in-flight (slow) write
				end
				local new = transform(backing[key])
				if new ~= nil then
					backing[key] = new
				end
				return backing[key]
			end,
		}
	end

	M._game = {
		GetService = function(_self, serviceName: string)
			if serviceName == "ReplicatedStorage" then
				return rs
			elseif serviceName == "ServerScriptService" then
				return sss
			elseif serviceName == "DataStoreService" then
				return { GetDataStore = function(_s, storeName: string)
					return getStore(storeName)
				end }
			elseif serviceName == "HttpService" then
				return { GenerateGUID = function(_s, _hyphens: boolean?)
					guidCounter += 1
					return "guid-" .. tostring(guidCounter)
				end }
			elseif serviceName == "RunService" then
				return { IsStudio = function(_s) return M._isStudio end }
			elseif serviceName == "BadgeService" then
				-- BadgeManager acquires this at load; the live award/check API isn't exercised headlessly (the
				-- Studio branch short-circuits before it), so a no-op stub is enough to let the module require.
				return {
					UserHasBadgeAsync = function(_s, _userId: number, _badgeId: number)
						return false
					end,
					AwardBadge = function(_s, _userId: number, _badgeId: number) end,
				}
			end
			error("robloxenv: unsupported service '" .. serviceName .. "' (add it to the shim)")
		end,
		BindToClose = function(_self, _fn) end, -- no-op: shutdown hook is not exercised headlessly
	}
	M._shared = shared
	M._server = server
end

-- require a module that lives directly under ReplicatedStorage.Shared, by name.
function M.requireShared(name: string)
	assert(M._shared, "robloxenv.build() must be called before requireShared()")
	local inst = Instance.FindFirstChild(M._shared, name)
	if not inst then
		error("robloxenv: no Shared module named '" .. name .. "'")
	end
	return requireInstance(inst)
end

-- require a module that lives directly under ServerScriptService (src/server), by name.
function M.requireServer(name: string)
	assert(M._server, "robloxenv.build() must be called before requireServer()")
	local inst = Instance.FindFirstChild(M._server, name)
	if not inst then
		error("robloxenv: no Server module named '" .. name .. "'")
	end
	return requireInstance(inst)
end

return M
