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
-- Build the tree from a project src/ root, mirroring default.project.json exactly:
--   src/shared → ReplicatedStorage.Shared      src/server → ServerScriptService
--   src/client → StarterPlayer.StarterPlayerScripts    src/gui → StarterGui
-- so any module Rojo syncs can be required and unit-tested headlessly, from the same source.
--
-- client/ and gui/ were absent from this shim until the four mounts were made to match the project
-- file. The consequence was structural, not cosmetic: client-side logic that is pure and eminently
-- testable — wheel-angle-to-notch quantization, hold-fraction accounting, the reveal's formatting —
-- had nowhere to be tested, so CLAUDE.md's headless-first rule silently applied to half the tree.
function M.build(srcRoot: string)
	local shared = buildTree(srcRoot .. "/shared", "Shared", "Folder")
	local rs = newInstance("ReplicatedStorage", "ReplicatedStorage")
	addChild(rs, shared)

	local server = buildTree(srcRoot .. "/server", "Server", "Folder")
	local sss = newInstance("ServerScriptService", "ServerScriptService")
	addChild(sss, server)

	local client = buildTree(srcRoot .. "/client", "StarterPlayerScripts", "Folder")
	local starterPlayer = newInstance("StarterPlayer", "StarterPlayer")
	addChild(starterPlayer, client)

	local gui = buildTree(srcRoot .. "/gui", "StarterGui", "StarterGui")

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
			elseif serviceName == "StarterPlayer" then
				return starterPlayer
			elseif serviceName == "StarterGui" then
				return gui
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
	M._client = client
	M._gui = gui
end

-- require a module that lives directly under one of the four mounts, by name.
local function requireFrom(root: any, label: string, name: string)
	assert(root, "robloxenv.build() must be called before require" .. label .. "()")
	local inst = Instance.FindFirstChild(root, name)
	if not inst then
		error("robloxenv: no " .. label .. " module named '" .. name .. "'")
	end
	return requireInstance(inst)
end

-- src/shared → ReplicatedStorage.Shared
function M.requireShared(name: string)
	return requireFrom(M._shared, "Shared", name)
end

-- src/server → ServerScriptService
function M.requireServer(name: string)
	return requireFrom(M._server, "Server", name)
end

-- src/client → StarterPlayer.StarterPlayerScripts
function M.requireClient(name: string)
	return requireFrom(M._client, "Client", name)
end

-- src/gui → StarterGui
function M.requireGui(name: string)
	return requireFrom(M._gui, "Gui", name)
end

-- Every ModuleScript under one of the four mounts, as { name → instance }, recursing into folders.
-- Exists so a spec can assert something about EVERY module rather than about a list someone has to
-- remember to extend — which is how tests/Purity.spec.luau covers files that do not exist yet.
function M.modulesUnder(root: any, out: { [string]: any }?, prefix: string?): { [string]: any }
	local acc = out or {}
	local children = rawget(root, "_children") or {}
	for name, child in children do
		local full = if prefix then prefix .. "/" .. name else name
		if rawget(child, "_source") then
			acc[full] = child
		else
			M.modulesUnder(child, acc, full)
		end
	end
	return acc
end

-- The raw source text of a module instance, for specs that lint rather than execute.
function M.sourceOf(inst: any): string
	return rawget(inst, "_source")
end

return M
