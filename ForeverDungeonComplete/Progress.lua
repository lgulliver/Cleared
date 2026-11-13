-- Run progress logic. No WoW API calls here, so it can be tested outside the game:
-- the current time is always passed in.
local _, ns = ...

local Progress = {}
ns.Progress = Progress

-- A "unit" is what completes: a whole dungeon, or one wing of a winged map.
local unitsCache = {}

function Progress.Units(mapID)
	if unitsCache[mapID] then
		return unitsCache[mapID]
	end
	local units = {}
	if ns.Wings[mapID] then
		for _, wing in ipairs(ns.Wings[mapID]) do
			units[#units + 1] = { name = wing.name, encounters = wing.encounters }
		end
	elseif ns.Dungeons[mapID] then
		local counted = {}
		for _, id in ipairs(ns.Dungeons[mapID].encounters) do
			if not ns.Optional[id] then
				counted[#counted + 1] = id
			end
		end
		units[1] = { name = ns.Dungeons[mapID].name, encounters = counted }
	end
	unitsCache[mapID] = units
	return units
end

local function unitFor(mapID, encID)
	for _, unit in ipairs(Progress.Units(mapID)) do
		for _, id in ipairs(unit.encounters) do
			if id == encID then
				return unit
			end
		end
	end
end

local function countKilled(run, unit)
	local n = 0
	for _, id in ipairs(unit.encounters) do
		if run.killed[id] then
			n = n + 1
		end
	end
	return n
end

function Progress.New(mapID, now)
	return { map = mapID, entered = now, killed = {}, done = {} }
end

-- Returns nil when the event should be ignored, otherwise a result describing the kill.
function Progress.OnEncounterEnd(run, encID, success, now)
	local enc = ns.Encounters[encID]
	if success ~= 1 or not enc or enc.map ~= run.map or run.killed[encID] then
		return nil
	end
	run.killed[encID] = now

	if ns.Optional[encID] then
		return { name = enc.name, optional = true, completed = false }
	end

	local unit = unitFor(run.map, encID)
	if not unit then
		-- Not optional and in no wing: check_data.lua prevents this, so treat it as a bonus.
		return { name = enc.name, optional = true, completed = false }
	end

	local done, total = countKilled(run, unit), #unit.encounters
	local completed = done == total and not run.done[unit.name]
	if completed then
		run.done[unit.name] = true
	end
	return {
		name = enc.name,
		optional = false,
		unit = unit.name,
		done = done,
		total = total,
		completed = completed,
		elapsed = completed and (now - run.entered) or nil,
	}
end

function Progress.Status(run)
	local units = Progress.Units(run.map)
	local list = {}
	for _, unit in ipairs(units) do
		local done = countKilled(run, unit)
		if done > 0 or not ns.Wings[run.map] then
			local remaining = {}
			for _, id in ipairs(unit.encounters) do
				if not run.killed[id] then
					remaining[#remaining + 1] = ns.Encounters[id].name
				end
			end
			list[#list + 1] = { name = unit.name, done = done, total = #unit.encounters, remaining = remaining }
		end
	end
	return list
end

-- Combines a run restored from SavedVariables with kills recorded before the instance key was known.
function Progress.Merge(saved, pending)
	for id, time in pairs(pending.killed) do
		if not saved.killed[id] then
			saved.killed[id] = time
		end
	end
	for name in pairs(pending.done) do
		saved.done[name] = true
	end
	return saved
end

-- "Creature-0-serverID-mapID-zoneUID-npcID-spawnUID" -> "mapID:zoneUID".
-- The zone UID identifies one instance copy, so a reset gives a new key.
function Progress.KeyFromGUID(guid)
	if type(guid) ~= "string" then
		return nil
	end
	local kind, mapID, zoneUID = guid:match("^(%a+)%-%d+%-%d+%-(%d+)%-(%d+)%-")
	if kind == "Creature" or kind == "Vehicle" or kind == "GameObject" then
		return mapID .. ":" .. zoneUID
	end
	return nil
end

function Progress.Prune(runs, now, maxAge)
	for key, run in pairs(runs) do
		if not run.entered or now - run.entered > maxAge then
			runs[key] = nil
		end
	end
end

function Progress.FormatElapsed(sec)
	sec = math.floor(sec)
	if sec >= 3600 then
		return string.format("%dh %02dm", math.floor(sec / 3600), math.floor(sec % 3600 / 60))
	end
	return string.format("%dm %02ds", math.floor(sec / 60), sec % 60)
end
