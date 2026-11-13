-- ForeverDungeonComplete: boss kill toasts and a Dungeon Complete banner for WoW Forever (interface 16001).
-- Kills come from ENCOUNTER_END. Progress is saved per instance copy, identified by the zone UID
-- in creature GUIDs, so a /reload or disconnect resumes and a fresh reset starts at zero.

local ADDON, ns = ...
local Progress, UI = ns.Progress, ns.UI

local MAX_RUN_AGE = 86400
local DEFAULTS = { toasts = true, banner = true, sound = true, debug = false }
local KEY_EVENTS = { "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "NAME_PLATE_UNIT_ADDED" }

local db -- ForeverDungeonCompleteCharDB, set on ADDON_LOADED
local settingsCategory
local active -- { map, key, run, reset } while inside a supported dungeon
local frame = CreateFrame("Frame")

local function Print(msg)
	print("|cffffd200ForeverDungeonComplete|r: " .. msg)
end

local function ShowBanner(r)
	if db.settings.banner then
		UI.Banner("DUNGEON COMPLETE", r.unit,
			r.total .. "/" .. r.total .. " · " .. Progress.FormatElapsed(r.elapsed), db.settings.sound)
	end
end

-- Instance key ----------------------------------------------------------------

local function SetKeyEvents(on)
	for _, event in ipairs(KEY_EVENTS) do
		if on then
			frame:RegisterEvent(event)
		else
			frame:UnregisterEvent(event)
		end
	end
end

-- Tries to learn which instance copy we're in from a creature GUID on the given unit.
local function TryResolveKey(unit)
	if not active or active.key or not unit then
		return
	end
	local key = Progress.KeyFromGUID(UnitGUID(unit))
	if not key or key:match("^(%d+):") ~= tostring(active.map) then
		return
	end
	active.key = key
	local results
	active.run, results = Progress.Resolve(db.runs[key], active.run, active.reset)
	active.reset = nil
	db.runs[key] = active.run
	SetKeyEvents(false)
	for _, r in ipairs(results) do
		ShowBanner(r)
	end
end

-- Zone tracking ---------------------------------------------------------------

local function UpdateZone()
	local _, instanceType, _, _, _, _, _, mapID = GetInstanceInfo()
	local dungeon = instanceType == "party" and ns.Dungeons[mapID]
	if not dungeon then
		active = nil
		SetKeyEvents(false)
		return
	end
	if active and active.map == mapID then
		return
	end
	active = nil
	SetKeyEvents(false)
	if ns.Disabled[mapID] then
		Print(("%s isn't supported yet (%s)."):format(dungeon.name, ns.Disabled[mapID]))
		return
	end
	active = { map = mapID, run = Progress.New(mapID, time()) }
	SetKeyEvents(true)
	TryResolveKey("target")
end

local function OnEncounterEnd(encounterID, encounterName, success)
	if db.settings.debug then
		Print(("[debug] ENCOUNTER_END id=%s name=%s success=%s"):format(
			tostring(encounterID), tostring(encounterName), tostring(success)))
	end
	if not active then
		return
	end
	TryResolveKey("boss1")
	TryResolveKey("target")

	local r = Progress.OnEncounterEnd(active.run, encounterID, success, time())
	if not r then
		return
	end
	if db.settings.toasts then
		UI.Toast(r.name .. " defeated", r.optional and "(bonus)" or (r.done .. "/" .. r.total))
	end
	if r.completed then
		ShowBanner(r)
	end
end

-- Settings --------------------------------------------------------------------

local function BuildSettings()
	local category = Settings.RegisterVerticalLayoutCategory(ADDON)
	local function Check(key, label, tip)
		local setting = Settings.RegisterAddOnSetting(category, ADDON .. "_" .. key, key, db.settings,
			type(DEFAULTS[key]), label, DEFAULTS[key])
		Settings.CreateCheckbox(category, setting, tip)
	end
	Check("toasts", "Boss kill toasts", "Show a toast with progress when a boss dies.")
	Check("banner", "Dungeon Complete banner", "Show a banner when every counted boss in the dungeon or wing is dead.")
	Check("sound", "Banner sound", "Play a sound with the Dungeon Complete banner.")
	Settings.RegisterAddOnCategory(category)
	settingsCategory = category
end

local function OpenSettings()
	if InCombatLockdown() then
		Print("can't open settings in combat; try again afterwards.")
	elseif settingsCategory then
		Settings.OpenToCategory(settingsCategory:GetID())
	else
		Print("settings panel is unavailable.")
	end
end

local function InitDB()
	ForeverDungeonCompleteCharDB = ForeverDungeonCompleteCharDB or {}
	db = ForeverDungeonCompleteCharDB
	db.settings = db.settings or {}
	for key, value in pairs(DEFAULTS) do
		if db.settings[key] == nil then
			db.settings[key] = value
		end
	end
	db.runs = db.runs or {}
	Progress.Prune(db.runs, time(), MAX_RUN_AGE)
end

-- Events and commands ---------------------------------------------------------

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("ENCOUNTER_START")
frame:RegisterEvent("ENCOUNTER_END")
frame:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" then
		if ... == ADDON then
			InitDB()
			local ok, err = pcall(BuildSettings)
			if not ok then
				Print("settings panel failed to load: " .. tostring(err))
			end
		end
		return
	end
	if not db then
		return
	end
	if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
		UpdateZone()
	elseif event == "ENCOUNTER_START" then
		-- Learn the instance copy before the kill, so toast counts include saved progress.
		TryResolveKey("boss1")
		TryResolveKey("target")
	elseif event == "ENCOUNTER_END" then
		local encounterID, encounterName, _, _, success = ...
		OnEncounterEnd(encounterID, encounterName, success)
	elseif event == "PLAYER_TARGET_CHANGED" then
		TryResolveKey("target")
	elseif event == "UPDATE_MOUSEOVER_UNIT" then
		TryResolveKey("mouseover")
	elseif event == "NAME_PLATE_UNIT_ADDED" then
		TryResolveKey(...)
	end
end)

local function PrintStatus()
	if not active then
		Print("not in a supported dungeon.")
		return
	end
	local list = Progress.Status(active.run)
	if #list == 0 then
		Print(ns.Dungeons[active.map].name .. ": no bosses killed yet.")
	end
	for _, unit in ipairs(list) do
		local remaining = #unit.remaining > 0 and table.concat(unit.remaining, ", ") or "none"
		Print(("%s: %d/%d — remaining: %s"):format(unit.name, unit.done, unit.total, remaining))
	end
end

SLASH_FOREVERDUNGEONCOMPLETE1 = "/fdc"
SlashCmdList.FOREVERDUNGEONCOMPLETE = function(arg)
	arg = (arg or ""):lower():match("^%s*(.-)%s*$")
	if arg == "" or arg == "options" or arg == "config" then
		OpenSettings()
	elseif arg == "status" then
		PrintStatus()
	elseif arg == "test" then
		UI.Toast("High Inquisitor Whitemane defeated", "2/2")
		UI.Banner("DUNGEON COMPLETE", "Scarlet Monastery: Cathedral", "2/2 · 18m 04s", db.settings.sound)
	elseif arg == "reset" then
		if not active then
			Print("not in a supported dungeon.")
			return
		end
		active.run = Progress.New(active.map, time())
		if active.key then
			db.runs[active.key] = active.run
		else
			-- Saved progress for this copy isn't known yet; drop it when the key resolves.
			active.reset = true
		end
		Print("progress for this instance cleared.")
	elseif arg == "debug" then
		db.settings.debug = not db.settings.debug
		Print("debug " .. (db.settings.debug and "on" or "off") .. ".")
	else
		Print("/fdc (settings) | status | test | reset | debug")
	end
end
