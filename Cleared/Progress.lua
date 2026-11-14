-- Run progress logic. No WoW API calls here, so it can be tested outside the game:
-- the current time is always passed in.
local _, ns = ...

local Progress = {}
ns.Progress = Progress

local REPEAT_GAP = 60 -- seconds; a repeat ENCOUNTER_END within this is the same kill re-firing

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

-- Marks the run as still in use, for the resume window.
function Progress.Touch(run, now)
	run.lastSeen = now
end

-- A saved run is resumed when the dungeon is re-entered within the window (an empty
-- instance resets after about 30 minutes), e.g. after a /reload, disconnect or run-back.
function Progress.ShouldResume(run, now, window)
	return run ~= nil and run.lastSeen ~= nil and now - run.lastSeen <= window
end

-- Returns nil when the event should be ignored, otherwise a result describing the kill.
-- A boss already in the run dying again more than REPEAT_GAP seconds later means this is a
-- new instance copy (GUIDs that would identify the copy are secret), so the run restarts.
function Progress.OnEncounterEnd(run, encID, success, now)
	local enc = ns.Encounters[encID]
	if success ~= 1 or not enc or enc.map ~= run.map then
		return nil
	end
	local restarted = false
	if run.killed[encID] then
		if now - run.killed[encID] <= REPEAT_GAP then
			return nil
		end
		run.killed, run.done, run.entered = {}, {}, now
		restarted = true
	end
	run.killed[encID] = now

	local unit = not ns.Optional[encID] and unitFor(run.map, encID)
	if not unit then
		-- Optional, or in no wing (check_data.lua prevents that), so it's a bonus kill.
		return { name = enc.name, optional = true, completed = false, restarted = restarted }
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
		restarted = restarted,
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

-- Turns the client's "%s has been reset." system message into a dungeon map ID.
function Progress.MapFromResetMessage(msg, fmt)
	if type(msg) ~= "string" or type(fmt) ~= "string" or (issecretvalue and issecretvalue(msg)) then
		return nil
	end
	local pattern = "^" .. fmt:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"):gsub("%%%%s", "(.+)") .. "$"
	local name = msg:match(pattern)
	if not name then
		return nil
	end
	for mapID, dungeon in pairs(ns.Dungeons) do
		if dungeon.name == name then
			return mapID
		end
	end
	return nil
end

function Progress.Prune(runs, now, maxAge)
	for key, run in pairs(runs) do
		local seen = run.lastSeen or run.entered
		if not seen or now - seen > maxAge then
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
