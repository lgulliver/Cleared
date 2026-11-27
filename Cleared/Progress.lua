-- Run progress logic. No WoW API calls here, so it can be tested outside the game:
-- the current time is always passed in.
local _, ns = ...

local Progress = {}
ns.Progress = Progress

local REPEAT_GAP = 60 -- seconds; a repeat ENCOUNTER_END within this is the same kill re-firing

-- A "unit" is what completes: a whole dungeon, or one wing of a winged map. Its encounters are
-- slots: an encounter ID, or an ns.OneOf group that any one member's kill fills.
local unitsCache, groupOf = {}, nil

local function slots(ids)
	if not groupOf then
		groupOf = {}
		for _, group in ipairs(ns.OneOf) do
			for _, id in ipairs(group.encounters) do
				groupOf[id] = group
			end
		end
	end
	local list, added = {}, {}
	for _, id in ipairs(ids) do
		local group = groupOf[id]
		if not ns.Optional[id] and not (group and added[group]) then
			list[#list + 1] = group or id
			if group then
				added[group] = true
			end
		end
	end
	return list
end

local function slotHas(slot, encID)
	if type(slot) == "number" then
		return slot == encID
	end
	for _, id in ipairs(slot.encounters) do
		if id == encID then
			return true
		end
	end
	return false
end

-- The member that died, or nil.
local function slotKill(run, slot)
	if type(slot) == "number" then
		return run.killed[slot] and slot
	end
	for _, id in ipairs(slot.encounters) do
		if run.killed[id] then
			return id
		end
	end
end

-- A group shows the boss that was fought once one has died, and its own name until then.
local function slotName(run, slot)
	local id = slotKill(run, slot) or slot
	return type(id) == "number" and ns.Encounters[id].name or slot.name
end

function Progress.Units(mapID)
	if unitsCache[mapID] then
		return unitsCache[mapID]
	end
	local units = {}
	if ns.Wings[mapID] then
		for _, wing in ipairs(ns.Wings[mapID]) do
			units[#units + 1] = { name = wing.name, encounters = slots(wing.encounters) }
		end
	elseif ns.Dungeons[mapID] then
		units[1] = { name = ns.Dungeons[mapID].name, encounters = slots(ns.Dungeons[mapID].encounters) }
	end
	unitsCache[mapID] = units
	return units
end

local function unitFor(mapID, encID)
	for _, unit in ipairs(Progress.Units(mapID)) do
		for _, slot in ipairs(unit.encounters) do
			if slotHas(slot, encID) then
				return unit
			end
		end
	end
end

local function countKilled(run, unit)
	local n = 0
	for _, slot in ipairs(unit.encounters) do
		if slotKill(run, slot) then
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
			for _, slot in ipairs(unit.encounters) do
				if not slotKill(run, slot) then
					remaining[#remaining + 1] = slotName(run, slot)
				end
			end
			list[#list + 1] = { name = unit.name, done = done, total = #unit.encounters, remaining = remaining }
		end
	end
	return list
end

local function bossRows(run, list)
	local rows = {}
	for _, slot in ipairs(list) do
		rows[#rows + 1] = { name = slotName(run, slot), killed = slotKill(run, slot) ~= nil }
	end
	return rows
end

-- What the boss list shows. On a winged map with no counted kill yet it's an overview of the wings;
-- otherwise it's the dungeon, or the wing of the most recent counted kill, boss by boss.
-- Optional bosses on the map are always listed separately as bonus rows.
function Progress.TrackerView(run)
	local dungeon = ns.Dungeons[run.map]
	local optional = {}
	for _, id in ipairs(dungeon.encounters) do
		if ns.Optional[id] then
			optional[#optional + 1] = id
		end
	end
	local view = { completed = false, bosses = {}, bonus = bossRows(run, optional) }

	local units = Progress.Units(run.map)
	local unit, latest = nil, -math.huge
	if ns.Wings[run.map] then
		for _, u in ipairs(units) do
			for _, slot in ipairs(u.encounters) do
				local id = slotKill(run, slot)
				if id and run.killed[id] > latest then
					unit, latest = u, run.killed[id]
				end
			end
		end
	else
		unit = units[1]
	end

	if not unit then
		view.title = dungeon.name
		view.wings = {}
		local prefix = dungeon.name .. ": "
		for _, u in ipairs(units) do
			local name = u.name:sub(1, #prefix) == prefix and u.name:sub(#prefix + 1) or u.name
			view.wings[#view.wings + 1] = {
				name = name,
				done = countKilled(run, u),
				total = #u.encounters,
				completed = run.done[u.name] == true,
			}
		end
		return view
	end

	view.title = unit.name
	view.done = countKilled(run, unit)
	view.total = #unit.encounters
	view.completed = view.done == view.total
	view.bosses = bossRows(run, unit.encounters)
	return view
end

-- Turns the client's "%s has been reset." system message into a dungeon map ID. Raids are skipped:
-- their lockouts can't be reset, and one (Naxxramas) shares its name with a dungeon.
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
		if dungeon.name == name and not dungeon.raid then
			return mapID
		end
	end
	return nil
end

-- Raid runs are kept for raidMaxAge (a lockout) instead of maxAge.
function Progress.Prune(runs, now, maxAge, raidMaxAge)
	for key, run in pairs(runs) do
		local seen = run.lastSeen or run.entered
		local dungeon = ns.Dungeons[run.map]
		local age = dungeon and dungeon.raid and raidMaxAge or maxAge
		if not seen or now - seen > age then
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
