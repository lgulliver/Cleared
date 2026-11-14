-- Cleared!: boss kill toasts and a Dungeon Complete banner for WoW Forever (interface 16001).
-- Kills come from ENCOUNTER_END. Creature GUIDs are secret inside Forever dungeons, so the instance
-- copy can't be identified directly. Progress is saved per dungeon and resumed when you come back
-- within RESUME_WINDOW; a reset message or an already-killed boss dying again starts a new run.

local ADDON, ns = ...
local Progress, UI = ns.Progress, ns.UI

local MAX_RUN_AGE = 86400
local RESUME_WINDOW = 1800 -- roughly when an empty instance resets
local TOUCH_INTERVAL = 60
local DEFAULTS = { toasts = true, banner = true, sound = true, debug = false }

local db -- ClearedCharDB, set on ADDON_LOADED
local settingsCategory
local active -- { map, run } while inside a supported dungeon
local ticker
local frame = CreateFrame("Frame")

local function Print(msg)
	print("|cffffd200Cleared!|r: " .. msg)
end

local function ShowBanner(r)
	if db.settings.banner then
		UI.Banner("DUNGEON COMPLETE", r.unit,
			r.total .. "/" .. r.total .. " · " .. Progress.FormatElapsed(r.elapsed), db.settings.sound)
	end
end

-- Zone tracking ---------------------------------------------------------------

local function Touch()
	if active then
		Progress.Touch(active.run, time())
	end
end

local function Leave()
	Touch()
	active = nil
	if ticker then
		ticker:Cancel()
		ticker = nil
	end
end

local function UpdateZone()
	local _, instanceType, _, _, _, _, _, mapID = GetInstanceInfo()
	local dungeon = instanceType == "party" and ns.Dungeons[mapID]
	if active and active.map == mapID then
		return
	end
	Leave()
	if not dungeon then
		return
	end
	if ns.Disabled[mapID] then
		Print(("%s isn't supported yet (%s)."):format(dungeon.name, ns.Disabled[mapID]))
		return
	end
	local now = time()
	if not Progress.ShouldResume(db.runs[mapID], now, RESUME_WINDOW) then
		db.runs[mapID] = Progress.New(mapID, now)
	end
	active = { map = mapID, run = db.runs[mapID] }
	Touch()
	ticker = C_Timer.NewTicker(TOUCH_INTERVAL, Touch)
end

local function OnEncounterEnd(encounterID, encounterName, success)
	if db.settings.debug then
		Print(("[debug] ENCOUNTER_END id=%s name=%s success=%s"):format(
			tostring(encounterID), tostring(encounterName), tostring(success)))
	end
	if not active then
		return
	end
	local now = time()
	local r = Progress.OnEncounterEnd(active.run, encounterID, success, now)
	Progress.Touch(active.run, now)
	if not r then
		return
	end
	if r.restarted then
		Print("this looks like a new instance, so progress has restarted.")
	end
	if db.settings.toasts then
		UI.Toast(r.name .. " defeated", r.optional and "(bonus)" or (r.done .. "/" .. r.total))
	end
	if r.completed then
		ShowBanner(r)
	end
end

local function OnSystemMessage(msg)
	local mapID = Progress.MapFromResetMessage(msg, INSTANCE_RESET_SUCCESS)
	if mapID and db.runs[mapID] and not (active and active.map == mapID) then
		db.runs[mapID] = nil
	end
end

-- Settings --------------------------------------------------------------------

local function BuildSettings()
	local category = Settings.RegisterVerticalLayoutCategory("Cleared!")
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
	ClearedCharDB = ClearedCharDB or {}
	db = ClearedCharDB
	db.settings = db.settings or {}
	for key, value in pairs(DEFAULTS) do
		if db.settings[key] == nil then
			db.settings[key] = value
		end
	end
	db.runs = db.runs or {}
	for key in pairs(db.runs) do
		if type(key) ~= "number" then
			db.runs[key] = nil -- 0.1.0 dev builds keyed runs by instance GUID
		end
	end
	Progress.Prune(db.runs, time(), MAX_RUN_AGE)
end

-- Events and commands ---------------------------------------------------------

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("PLAYER_LEAVING_WORLD")
frame:RegisterEvent("ENCOUNTER_END")
frame:RegisterEvent("CHAT_MSG_SYSTEM")
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
	elseif event == "PLAYER_LEAVING_WORLD" then
		Touch() -- /reload, logout and loading screens
	elseif event == "ENCOUNTER_END" then
		local encounterID, encounterName, _, _, success = ...
		OnEncounterEnd(encounterID, encounterName, success)
	elseif event == "CHAT_MSG_SYSTEM" then
		OnSystemMessage(...)
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

SLASH_CLEARED1 = "/cleared"
SlashCmdList.CLEARED = function(arg)
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
		db.runs[active.map] = active.run
		Touch()
		Print("progress for this instance cleared.")
	elseif arg == "debug" then
		db.settings.debug = not db.settings.debug
		Print("debug " .. (db.settings.debug and "on" or "off") .. ".")
	else
		Print("/cleared (settings) | status | test | reset | debug")
	end
end
