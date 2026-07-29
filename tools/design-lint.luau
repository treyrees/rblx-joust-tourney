--!strict
-- design-lint.luau — automated drift/link checker for docs/design/. Run from repo root:
--     lune run tools/design-lint.luau
--
-- Replaces manual "Draft/Locked" status labels with checks computed from the filesystem + git:
--   ERROR (exit 1): a `maps-to` path doesn't exist; a `maps-to` `#Key` anchor names no top-level key;
--                   a markdown link doesn't resolve; a referenced ADR id is missing or superseded.
--   WARN  (exit 0): a doc is possibly stale — a `maps-to` file (or, for a `path#Key` entry, that key's
--                   line range) has git commits newer than the doc's `updated` date. Drift is detected
--                   from git, never asserted by a human. A `#Key` selector (e.g.
--                   `src/shared/Constants.luau#MATRIX`) narrows staleness from a whole hub file to
--                   one section, so a doc stops re-warning on every unrelated edit.

local fs = require("@lune/fs")
local process = require("@lune/process")

local DESIGN_ROOT = "docs/design"
local errors: { string } = {}
local warnings: { string } = {}
local notes: { string } = {}

-- Grandfathered duplicate ADR ids. In the predecessor repo eight ids had each been assigned to two
-- files by parallel work streams incrementing from the same base; because ADRs are immutable those
-- were preserved rather than renumbered, and listed here so the check could pass them while still
-- catching NEW collisions.
--
-- This repo numbers from 0001 with no collisions, so the table is empty and every duplicate is an
-- error. Left in place (rather than deleted along with the check) because the collision it guards
-- against is a live risk the moment two branches add an ADR at the same time — which is exactly how
-- all eight happened over there.
local GRANDFATHERED_DUP_IDS: { [string]: string } = {}

-- Retired mechanic names — the machine half of a GLOSSARY "retired-proc ledger". The cardinal drift
-- sin is a retired name surviving as "live" in a doc after a redesign replaced it. A LIVING design
-- doc (not an ADR, not the ledger itself) may name one ONLY when marking it as history, so a bare
-- `backticked` mention with no supersession marker on the same or previous line is flagged.
--
-- Empty until Turbo Jousting retires its first mechanic name. What was here named the predecessor's
-- combat catalog (`single_mind`, `war_banner`, `divine_shield`, …) and matched nothing in this repo,
-- so it could only ever have produced confusing warnings. Add a term the day a redesign replaces
-- one, along with its row in GLOSSARY.md — the ledger-sync check below fails the build if the two
-- drift apart.
local RETIRED_PROCS: { string } = {}

-- Retired/cut design VOCABULARY — the same idea one level up: a concept a redesign removed must not
-- resurface as live in a doc. Plain prose (whole words, case-insensitive), not backticked. Keyed
-- term → the human note for the warning. Legacy-reference docs (maps-to entirely under `legacy/`)
-- are exempt.
--
-- Empty for the same reason: the one entry here named a currency cut from the predecessor's economy,
-- a concept this repo has never had.
local RETIRED_VOCAB: { [string]: string } = {}

-- Words that mark a retired-proc / retired-vocab mention as deliberate history, not a live claim.
local SUPERSESSION_MARKERS: { string } = {
	"supersede", "retired", "vestigial", "replaced", "replaces", "formerly",
	"legacy", "deprecat", "no longer", "→", "->", "ledger", "was ",
	"redesign", "reimagin", "obsolete", "folded", "used to", "cut", "old",
}

-- A marker is present if it appears with a leading word boundary (so "cut" matches "cut" but NOT
-- "exe`cut`e", while stems like "supersede" still match "superseded"). Non-alphabetic markers
-- (arrows) fall back to a plain substring search.
local function hasMarker(s: string): boolean
	for _, mark in SUPERSESSION_MARKERS do
		if mark:match("^%a") then
			if s:find("%f[%a]" .. mark) then
				return true
			end
		elseif s:find(mark, 1, true) then
			return true
		end
	end
	return false
end

-- ---- helpers -----------------------------------------------------------------------------------
local function walk(dir: string, out: { string })
	for _, entry in fs.readDir(dir) do
		local full = dir .. "/" .. entry
		if fs.isDir(full) then
			walk(full, out)
		elseif entry:match("%.md$") then
			table.insert(out, full)
		end
	end
end

-- Parse the leading `---` front-matter block into a string->string map (raw values).
local function parseFrontMatter(text: string): { [string]: string }?
	if not text:match("^%-%-%-\n") then
		return nil
	end
	local block = text:match("^%-%-%-\n(.-)\n%-%-%-")
	if not block then
		return nil
	end
	local map: { [string]: string } = {}
	for line in (block .. "\n"):gmatch("(.-)\n") do
		local k, v = line:match("^([%w%-_]+):%s*(.*)$")
		if k then
			map[k] = v
		end
	end
	return map
end

-- "[a, b, c]" or "a" -> { "a", "b", "c" } (trimmed; brackets/quotes stripped)
local function parseList(raw: string?): { string }
	local out: { string } = {}
	if not raw or raw == "" or raw == "[]" or raw == "null" then
		return out
	end
	local inner = raw:match("^%[(.*)%]$") or raw
	for item in (inner .. ","):gmatch("%s*(.-)%s*,") do
		if item ~= "" then
			item = item:gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
			table.insert(out, item)
		end
	end
	return out
end

local function fileExists(path: string): boolean
	return fs.isFile(path) or fs.isDir(path)
end

-- last git commit date (YYYY-MM-DD) touching `path`, or nil if untracked/uncommitted.
local gitExec = (process :: any).exec or (process :: any).spawn
local function lastCommitDate(path: string): string?
	local res = gitExec("git", { "log", "-1", "--format=%cd", "--date=format:%Y-%m-%d", "--", path })
	if not res.ok then
		return nil
	end
	local out = (res.stdout :: string):gsub("%s+$", "")
	return out ~= "" and out or nil
end

-- A `maps-to` entry may pin a single top-level key with a `#Anchor` selector
-- ("src/shared/Constants.luau#MATRIX") so staleness tracks just that section's git history
-- instead of the whole hub file — otherwise every doc mapped to Constants re-warns on every edit.
-- splitAnchor returns (path, anchor?); a bare path keeps the whole-file behavior.
local function splitAnchor(entry: string): (string, string?)
	local path, anchor = entry:match("^(.-)#([%w_]+)$")
	if path and anchor then
		return path, anchor
	end
	return entry, nil
end

-- Resolve a top-level key `anchor` to its 1-based [start,finish] line range in a flat Lua
-- module (the `Constants.KEY = { … }` / `Constants.KEY = value` shape). The block runs from
-- the key's definition line to the line before the next top-level sibling (another `X = …`,
-- a `local …`, or `return …` at column 0), or EOF. Returns nil if the key isn't defined.
local function anchorRange(path: string, anchor: string): { start: number, finish: number }?
	local lines: { string } = {}
	for line in (fs.readFile(path) .. "\n"):gmatch("(.-)\n") do
		table.insert(lines, line)
	end
	local startLine: number? = nil
	for i, line in lines do
		-- `Constants.ANCHOR =` / `ANCHOR =` at column 0 (optional single dotted prefix).
		if line:match("^[%w_]*%.?" .. anchor .. "%s*=") then
			startLine = i
			break
		end
	end
	if not startLine then
		return nil
	end
	local finish = #lines
	for i = startLine + 1, #lines do
		local line = lines[i]
		local isSibling = line:match("^[%w_][%w_%.]*%s*=") ~= nil
			or line:match("^return%f[%s]") ~= nil
			or line:match("^local%f[%s]") ~= nil
		if isSibling then
			finish = i - 1
			break
		end
	end
	return { start = startLine, finish = finish }
end

-- Last git commit date (YYYY-MM-DD) touching lines [start,finish] of `path`, via `git log -L`.
local function lastCommitDateRange(path: string, startLine: number, finish: number): string?
	local res = gitExec("git", {
		"log", "-1", "--format=%cd", "--date=format:%Y-%m-%d",
		"-L", tostring(startLine) .. "," .. tostring(finish) .. ":" .. path, "-s",
	})
	if not res.ok then
		return nil
	end
	local out = (res.stdout :: string):gsub("%s+$", "")
	-- Take the first non-empty line in case -L emits a leading header.
	out = out:match("^%s*([^\n]*)") or out
	return out ~= "" and out or nil
end

-- ---- collect ADRs ------------------------------------------------------------------------------
-- adrId -> { exists=true, superseded=bool }
local adrs: { [string]: { superseded: boolean } } = {}
local adrFilesById: { [string]: { string } } = {} -- id -> { filename, ... } to catch duplicate ids
local decisionsDir = DESIGN_ROOT .. "/decisions"
if fs.isDir(decisionsDir) then
	for _, entry in fs.readDir(decisionsDir) do
		local id = entry:match("^(%d%d%d%d)%-.*%.md$")
		if id then
			local fm = parseFrontMatter(fs.readFile(decisionsDir .. "/" .. entry)) or {}
			local supersededBy = fm["superseded-by"]
			local superseded = supersededBy ~= nil and supersededBy ~= "" and supersededBy ~= "null"
			-- Collision-aware: a numeric `decisions:[]` reference can't name WHICH same-id file it means,
			-- so the id reads as superseded only when EVERY file bearing it is superseded (otherwise a
			-- live twin, e.g. enchant-0087, would be poisoned by its superseded sibling, weather-0087).
			local a = adrs[id] or { superseded = true }
			a.superseded = a.superseded and superseded
			adrs[id] = a
			adrFilesById[id] = adrFilesById[id] or {}
			table.insert(adrFilesById[id], entry)
		end
	end
end

-- ADR id uniqueness. Two files sharing an id make `decisions:[]` / bare `ADR NNNN`
-- references resolve to whichever file readDir returned last (the other is silently
-- overwritten in `adrs` above). New collisions are an ERROR; the four historical pairs
-- are grandfathered to a NOTE (immutable + recorded in decisions/README.md).
for id, files in adrFilesById do
	if #files > 1 then
		table.sort(files)
		local key = table.concat(files, "|")
		if GRANDFATHERED_DUP_IDS[id] == key then
			table.insert(
				notes,
				"known historical ADR id collision " .. id .. " (" .. key
					.. ") — preserved as immutable history; see docs/design/decisions/README.md"
			)
		else
			table.insert(errors, "duplicate ADR id " .. id .. ": " .. key .. " (ADR ids must be unique)")
		end
	end
end

-- ---- lint each doc -----------------------------------------------------------------------------
local docs: { string } = {}
walk(DESIGN_ROOT, docs)
table.sort(docs)

local function normalizeAdrId(s: string): string
	-- accept "0001", "1", "ADR 0001"
	local digits = s:match("(%d+)")
	if not digits then
		return s
	end
	return string.format("%04d", tonumber(digits) :: number)
end

for _, doc in docs do
	local text = fs.readFile(doc)
	local dir = doc:match("^(.*)/[^/]+$") or "."
	local isAdr = doc:match("/decisions/") ~= nil
	local isReadme = doc:match("/README%.md$") ~= nil
	local fm = parseFrontMatter(text)

	-- System docs (not README, not ADR) must carry front-matter with maps-to + updated.
	if not isReadme and not isAdr then
		if not fm then
			table.insert(errors, doc .. ": missing front-matter (maps-to/decisions/owner/updated)")
		else
			-- maps-to existence + drift
			for _, mapped in parseList(fm["maps-to"]) do
				local mpath, anchor = splitAnchor(mapped)
				if not fileExists(mpath) then
					table.insert(errors, doc .. ": maps-to path does not exist: " .. mpath)
				elseif anchor then
					local range = anchorRange(mpath, anchor)
					if not range then
						table.insert(errors, doc .. ": maps-to anchor not found: " .. mpath .. "#" .. anchor)
					else
						local commit = lastCommitDateRange(mpath, range.start, range.finish)
						local updated = fm["updated"]
						if commit and updated and commit > updated then
							table.insert(
								warnings,
								doc .. ": possibly STALE — " .. mpath .. "#" .. anchor .. " changed " .. commit
									.. " (doc updated " .. updated .. "); re-review."
							)
						end
					end
				else
					local commit = lastCommitDate(mpath)
					local updated = fm["updated"]
					if commit and updated and commit > updated then
						table.insert(
							warnings,
							doc .. ": possibly STALE — " .. mapped .. " changed " .. commit
								.. " (doc updated " .. updated .. "); re-review."
						)
					end
				end
			end
			-- decisions reference validity
			for _, ref in parseList(fm["decisions"]) do
				local id = normalizeAdrId(ref)
				local adr = adrs[id]
				if not adr then
					table.insert(errors, doc .. ": references missing ADR " .. id)
				elseif adr.superseded then
					table.insert(errors, doc .. ": references SUPERSEDED ADR " .. id .. " as current")
				end
			end
			if not fm["updated"] then
				table.insert(errors, doc .. ": front-matter missing 'updated'")
			end
		end
	end

	-- markdown link resolution (local links only; skip http(s), mailto, anchors)
	for label, target in text:gmatch("%[([^%]]*)%]%(([^%)]+)%)") do
		local _ = label
		if not target:match("^%a[%w+.-]*:") and not target:match("^#") then
			local path = target:gsub("#.*$", "")
			if path ~= "" then
				local resolved
				if path:match("^/") then
					resolved = path:sub(2)
				else
					resolved = dir .. "/" .. path
				end
				-- collapse ../ segments
				local parts: { string } = {}
				for seg in (resolved .. "/"):gmatch("(.-)/") do
					if seg == ".." then
						parts[#parts] = nil
					elseif seg ~= "." and seg ~= "" then
						table.insert(parts, seg)
					end
				end
				local clean = table.concat(parts, "/")
				if not fileExists(clean) then
					table.insert(errors, doc .. ": broken link → " .. target)
				end
			end
		end
	end

	-- Retired-proc / retired-vocab drift: a living design doc must not name a retired proc or a cut
	-- concept as current. ADRs are immutable history and the GLOSSARY ledger DEFINES these terms (both
	-- exempt); a LEGACY-reference doc (maps-to entirely under `legacy/`) describes the pre-rebuild game,
	-- where they were live (exempt too). A mention is allowed when the same/previous line marks it history.
	local isGlossary = doc:match("/GLOSSARY%.md$") ~= nil
	-- A legacy-reference doc describes the pre-rebuild game (where retired terms were live): either it
	-- declares `legacy-reference: true`, or every maps-to entry points under `legacy/`.
	local mapsTo = fm and parseList(fm["maps-to"]) or {}
	local isLegacyDoc = fm ~= nil and (fm["legacy-reference"] == "true")
	if not isLegacyDoc and #mapsTo > 0 then
		isLegacyDoc = true
		for _, m in mapsTo do
			if not m:match("^legacy/") then
				isLegacyDoc = false
				break
			end
		end
	end
	if not isAdr and not isGlossary and not isLegacyDoc then
		local lineNo, prevLower = 0, ""
		for line in (text .. "\n"):gmatch("(.-)\n") do
			lineNo += 1
			local lower = line:lower()
			-- A marker on this line OR the previous one counts (prose wraps a clause across lines).
			local marked = hasMarker(lower) or hasMarker(prevLower)
			if not marked then
				for _, proc in RETIRED_PROCS do
					if line:find("`" .. proc .. "`", 1, true) then
						table.insert(
							warnings,
							doc .. ":" .. lineNo .. ": retired proc `" .. proc
								.. "` named without a supersession marker — is this stale-as-live? "
								.. "(see the GLOSSARY retired-proc ledger)"
						)
					end
				end
				-- Strip markdown link TARGETS `](...)` first: an ADR filename slug (e.g.
				-- `0065-cut-primal-crafting-...`) is not a prose use of the term.
				local prose = lower:gsub("%]%([^%)]*%)", "]")
				for term, note in RETIRED_VOCAB do
					-- whole-word, case-insensitive (`%f` frontier brackets the word)
					if prose:find("%f[%w]" .. term:lower() .. "%f[%W]") then
						table.insert(
							warnings,
							doc .. ":" .. lineNo .. ": retired term \"" .. term
								.. "\" (" .. note .. ") named without a supersession marker — stale-as-live? "
								.. "(see the GLOSSARY retired-proc ledger)"
						)
					end
				end
			end
			prevLower = lower
		end
	end
end

-- Ledger sync: every id the lint treats as retired must be documented in GLOSSARY's ledger, so the
-- human reference and the machine check can't drift apart.
local glossaryPath = DESIGN_ROOT .. "/GLOSSARY.md"
if fs.isFile(glossaryPath) then
	local glossary = fs.readFile(glossaryPath)
	for _, proc in RETIRED_PROCS do
		if not glossary:find("`" .. proc .. "`", 1, true) then
			table.insert(
				errors,
				"retired-proc ledger out of sync: `" .. proc
					.. "` is in design-lint's RETIRED_PROCS but absent from docs/design/GLOSSARY.md"
			)
		end
	end
	for term in RETIRED_VOCAB do
		if not glossary:find(term, 1, true) then
			table.insert(
				errors,
				"retired-vocab ledger out of sync: \"" .. term
					.. "\" is in design-lint's RETIRED_VOCAB but absent from docs/design/GLOSSARY.md"
			)
		end
	end
end

-- Enacted-rename guard — the machine half of the GLOSSARY "Legacy → rebuild constant-rename ledger".
-- Once a rename is ENACTED in code, the legacy token must never resurface in the source it was renamed
-- out of. Keyed legacy token → { file, note }. Empty here: the two entries this carried guarded a
-- reagent rename in the predecessor's `src/shared/Economy.lua`, a file this repo does not have.
local ENACTED_RENAMES: { { token: string, file: string, note: string } } = {}
for _, r in ENACTED_RENAMES do
	if fs.isFile(r.file) then
		if fs.readFile(r.file):find(r.token, 1, true) then
			table.insert(
				errors,
				"not-yet-renamed legacy token `" .. r.token .. "` in " .. r.file .. " — " .. r.note
			)
		end
	end
end

-- Combat-axis ADRs must cite a sim run in their Consequences. The rule was carried over from the
-- predecessor repo, where deciding before simulating was measurably expensive: one balance axis
-- burned three ADRs and a purpose-built probe in four days because the instrument came last.
--
-- The gate: any ADR touching a combat balance axis must show it consulted a headless run before
-- locking the number. Combat-axis is opt-in via front-matter `combat-axis: true` (the recommended,
-- unambiguous path) with a token backstop below for authors who forget the flag; `combat-axis: false`
-- is the escape hatch for a token false-positive.
-- No cutoff here: the predecessor needed one to grandfather 100+ ADRs written before the rule
-- existed, but this repo's first ADR postdates the rule, so every dated ADR is checked.
--
-- High-signal combat balance identifiers — ALL_CAPS constant names that essentially never appear in a
-- non-combat ADR by accident (kept deliberately narrow to avoid prose false-positives; the explicit
-- `combat-axis: true` flag is the real signal, this is only the forgot-the-flag backstop).
-- These are Joust's actual tuning constants. The list this replaced named the predecessor's combat
-- system (BASE_SPEED, TICKS_BY_AGGRO, ARMOR_MITIGATION, …), none of which exist here — so the
-- backstop could not have caught a single Joust combat ADR that forgot its flag.
local COMBAT_AXIS_TOKENS: { string } = {
	"NORMAL_DAMAGE", "PUNISHED_DAMAGE", "WEAK_DAMAGE", "THIN_BLOCK_MULT", "STACK_BLOCK_RESTORE",
	"MAX_BONUS", "EASE_EXPONENT", "AIM_LOCK_BEFORE_TICK", "AIM_LOCK_MAX_RUNUP_FRACTION",
	"MIN_RUNUP_SECONDS",
}
-- A citation = a reference to a headless combat instrument. Only one exists here; the two others
-- this listed (tools/aggro-probe.luau, tools/match-demo.luau) were predecessor tools that do not
-- exist in this repo, so an ADR could have "cited" a file that was never there and passed the gate.
local SIM_CITATIONS: { string } = { "tools/sim.luau" }
if fs.isDir(decisionsDir) then
	for _, entry in fs.readDir(decisionsDir) do
		if entry:match("^%d%d%d%d%-.*%.md$") then
			local path = decisionsDir .. "/" .. entry
			local text = fs.readFile(path)
			local fm = parseFrontMatter(text) or {}
			local date = fm["date"]
			-- Only forward-looking; untracked/dateless ADRs are skipped (nothing to compare against).
			if date then
				local flag = fm["combat-axis"]
				local isCombat
				if flag == "true" then
					isCombat = true
				elseif flag == "false" then
					isCombat = false
				else
					isCombat = false
					for _, tok in COMBAT_AXIS_TOKENS do
						if text:find(tok, 1, true) then
							isCombat = true
							break
						end
					end
				end
				if isCombat then
					-- Scope the citation to the ## Consequences section: grab from that heading to the
					-- next `## ` heading or EOF.
					local conseq = text:match("\n##%s+Consequences%s*\n(.-)\n##%s") or text:match("\n##%s+Consequences%s*\n(.*)$")
					if not conseq then
						table.insert(
							errors,
							"combat-axis ADR " .. entry .. " has no `## Consequences` section — it must cite a "
								.. "sim run there. If this ADR is not combat-tuning, set `combat-axis: false`."
						)
					else
						local cited = false
						for _, c in SIM_CITATIONS do
							if conseq:find(c, 1, true) then
								cited = true
								break
							end
						end
						if not cited then
							-- The expected list is built from SIM_CITATIONS rather than spelled out, so the
							-- message can never again tell an author to cite an instrument that doesn't exist.
							table.insert(
								errors,
								"combat-axis ADR " .. entry .. " locks a combat axis but its `## Consequences` cites no "
									.. "sim run (expected one of: " .. table.concat(SIM_CITATIONS, ", ") .. ") — "
									.. "run the tool before pinning the number. Not combat-tuning? set `combat-axis: false`."
							)
						end
					end
				end
			end
		end
	end
end

-- ---- report ------------------------------------------------------------------------------------
for _, n in notes do
	print("NOTE  " .. n)
end
for _, w in warnings do
	print("WARN  " .. w)
end
for _, e in errors do
	print("ERROR " .. e)
end
print("")
print(
	string.format(
		"design-lint: %d error(s), %d warning(s), %d note(s) across %d doc(s)",
		#errors,
		#warnings,
		#notes,
		#docs
	)
)
process.exit(#errors == 0 and 0 or 1)
