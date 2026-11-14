-- Encounter IDs come from the real generated data (Forever build 1.60.1.70938).

-- Copies a value keeping only what SavedVariables can hold, like a /reload round trip.
local function roundtrip(v)
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, val in pairs(v) do
		local kt, vt = type(k), type(val)
		if (kt == "string" or kt == "number") and vt ~= "function" and vt ~= "userdata" then
			out[k] = roundtrip(val)
		end
	end
	return out
end

local function finishEast(P, run)
	for _, id in ipairs({ 343, 344, 345, 346 }) do
		P.OnEncounterEnd(run, id, 1, 200)
	end
end

return {
	units_plain = function(ns, t)
		local units = ns.Progress.Units(36)
		t.eq(#units, 1, "unit count")
		t.eq(units[1].name, "Deadmines", "unit name")
		local run = ns.Progress.New(36, 0)
		t.eq(ns.Progress.OnEncounterEnd(run, 2747, 1, 10).total, 8, "total")
	end,

	units_winged = function(ns, t)
		local units = ns.Progress.Units(189)
		t.eq(#units, 4, "unit count")
		t.eq(units[2].name, "Scarlet Monastery: Library", "second wing")
		t.eq(#units[2].encounters, 2, "library size")
		t.eq(units[2].encounters[1], 446, "library first")
		t.eq(units[2].encounters[2], 447, "library second")
	end,

	units_plain_skips_optional = function(ns, t)
		local units = ns.Progress.Units(230)
		t.eq(#units, 1, "unit count")
		t.eq(#units[1].encounters, 16, "BRD counted encounters (21 minus 5 optional)")
	end,

	kill_counts = function(ns, t)
		local run = ns.Progress.New(189, 100)
		local r = ns.Progress.OnEncounterEnd(run, 446, 1, 150)
		t.eq(r.name, "Houndmaster Loksey", "name")
		t.eq(r.unit, "Scarlet Monastery: Library", "unit")
		t.eq(r.done, 1, "done")
		t.eq(r.total, 2, "total")
		t.eq(r.completed, false, "completed")
		t.eq(r.optional, false, "optional")
	end,

	wing_completes = function(ns, t)
		local run = ns.Progress.New(189, 100)
		ns.Progress.OnEncounterEnd(run, 446, 1, 150)
		local r = ns.Progress.OnEncounterEnd(run, 447, 1, 400)
		t.eq(r.completed, true, "completed")
		t.eq(r.done, 2, "done")
		t.eq(r.elapsed, 300, "elapsed")
		t.eq(run.done["Scarlet Monastery: Library"], true, "run.done")
	end,

	duplicate_ignored = function(ns, t)
		local run = ns.Progress.New(189, 100)
		ns.Progress.OnEncounterEnd(run, 446, 1, 150)
		ns.Progress.OnEncounterEnd(run, 447, 1, 400)
		t.eq(ns.Progress.OnEncounterEnd(run, 447, 1, 410), nil, "re-fire after completion")
		t.eq(ns.Progress.OnEncounterEnd(run, 447, 1, 460), nil, "re-fire at the 60s edge")
	end,

	second_wing_independent = function(ns, t)
		local run = ns.Progress.New(429, 100)
		finishEast(ns.Progress, run)
		t.eq(run.done["Dire Maul: East"], true, "east done")
		local r = ns.Progress.OnEncounterEnd(run, 350, 1, 300)
		t.eq(r.unit, "Dire Maul: West", "unit")
		t.eq(r.done, 1, "done")
		t.eq(r.total, 5, "total")
		t.eq(r.completed, false, "completed")
		t.eq(run.done["Dire Maul: East"], true, "east still done")
	end,

	failed_and_foreign_ignored = function(ns, t)
		local run = ns.Progress.New(36, 0)
		t.eq(ns.Progress.OnEncounterEnd(run, 2747, 0, 10), nil, "failed attempt")
		t.eq(ns.Progress.OnEncounterEnd(run, 227, 1, 10), nil, "other dungeon")
		t.eq(ns.Progress.OnEncounterEnd(run, 999999, 1, 10), nil, "unknown encounter")
		t.eq(next(run.killed), nil, "nothing recorded")
	end,

	optional_kill = function(ns, t)
		local run = ns.Progress.New(329, 0)
		ns.Progress.OnEncounterEnd(run, 479, 1, 10)
		local r = ns.Progress.OnEncounterEnd(run, 2799, 1, 20)
		t.eq(r.optional, true, "optional")
		t.eq(r.completed, false, "completed")
		t.eq(r.name, "Skul", "name")
		t.eq(r.unit, nil, "unit")
		local r2 = ns.Progress.OnEncounterEnd(run, 480, 1, 30)
		t.eq(r2.done, 2, "undead count unaffected by bonus")
	end,

	saved_roundtrip = function(ns, t)
		local run = ns.Progress.New(189, 100)
		ns.Progress.OnEncounterEnd(run, 446, 1, 150)
		ns.Progress.OnEncounterEnd(run, 447, 1, 400)
		local copy = roundtrip(run)
		t.eq(ns.Progress.OnEncounterEnd(copy, 447, 1, 430), nil, "no second banner")
		t.eq(copy.done["Scarlet Monastery: Library"], true, "done kept")
	end,

	-- GUIDs are secret in Forever dungeons, so a new copy shows up as an old boss dying again.
	repeat_kill_restarts_run = function(ns, t)
		local run = ns.Progress.New(189, 100)
		ns.Progress.OnEncounterEnd(run, 446, 1, 150)
		ns.Progress.OnEncounterEnd(run, 447, 1, 400)
		local r = ns.Progress.OnEncounterEnd(run, 446, 1, 2000)
		t.eq(r.restarted, true, "restarted")
		t.eq(r.done, 1, "counts only the new kill")
		t.eq(r.completed, false, "no banner")
		t.eq(run.killed[447], nil, "old kills cleared")
		t.eq(run.done["Scarlet Monastery: Library"], nil, "old completion cleared")
		t.eq(run.entered, 2000, "new run starts at the repeat kill")
		local r2 = ns.Progress.OnEncounterEnd(run, 447, 1, 2300)
		t.eq(r2.completed, true, "new copy completes again")
		t.eq(r2.elapsed, 300, "elapsed in the new copy")
	end,

	repeat_kill_clears_other_wings = function(ns, t)
		local run = ns.Progress.New(429, 100)
		finishEast(ns.Progress, run)
		ns.Progress.OnEncounterEnd(run, 350, 1, 300)
		local r = ns.Progress.OnEncounterEnd(run, 343, 1, 5000)
		t.eq(r.restarted, true, "restarted")
		t.eq(run.killed[350], nil, "west kill from old copy cleared")
		t.eq(r.unit, "Dire Maul: East", "unit")
		t.eq(r.done, 1, "done")
	end,

	optional_repeat_restarts = function(ns, t)
		local run = ns.Progress.New(329, 0)
		ns.Progress.OnEncounterEnd(run, 479, 1, 10)
		ns.Progress.OnEncounterEnd(run, 2799, 1, 20)
		local r = ns.Progress.OnEncounterEnd(run, 2799, 1, 3000)
		t.eq(r.restarted, true, "restarted")
		t.eq(run.killed[479], nil, "old kill cleared")
	end,

	should_resume = function(ns, t)
		local run = ns.Progress.New(36, 0)
		ns.Progress.Touch(run, 1000)
		t.eq(ns.Progress.ShouldResume(run, 1000 + 1800, 1800), true, "inside window")
		t.eq(ns.Progress.ShouldResume(run, 1000 + 1801, 1800), false, "outside window")
		t.eq(ns.Progress.ShouldResume(nil, 1000, 1800), false, "no run")
		t.eq(ns.Progress.ShouldResume({ map = 36, entered = 0, killed = {}, done = {} }, 100, 1800), false, "never touched")
	end,

	reset_message = function(ns, t)
		local fmt = "%s has been reset."
		t.eq(ns.Progress.MapFromResetMessage("Deadmines has been reset.", fmt), 36, "plain")
		t.eq(ns.Progress.MapFromResetMessage("Zul'Farrak has been reset.", fmt), 209, "apostrophe")
		t.eq(ns.Progress.MapFromResetMessage("Scarlet Monastery has been reset.", fmt), 189, "winged map")
		t.eq(ns.Progress.MapFromResetMessage("Deadmines (Heroic) is full.", fmt), nil, "other message")
		t.eq(ns.Progress.MapFromResetMessage("Molten Core has been reset.", fmt), nil, "not a dungeon")
		t.eq(ns.Progress.MapFromResetMessage("Deadmines has been reset.", nil), nil, "no format")
	end,

	reset_message_secret = function(ns, t)
		local msg = "Deadmines has been reset."
		local saved = _G.issecretvalue
		_G.issecretvalue = function(v)
			return v == msg
		end
		local ok, mapID = pcall(ns.Progress.MapFromResetMessage, msg, "%s has been reset.")
		_G.issecretvalue = saved
		t.ok(ok, "does not error")
		t.eq(mapID, nil, "secret message ignored")
	end,

	prune = function(ns, t)
		local now = 1000000
		local runs = {
			old = { entered = now - 90000, lastSeen = now - 90000 },
			fresh = { entered = now - 100, lastSeen = now - 100 },
			longRun = { entered = now - 90000, lastSeen = now - 10 },
		}
		ns.Progress.Prune(runs, now, 86400)
		t.eq(runs.old, nil, "old removed")
		t.ok(runs.fresh, "fresh kept")
		t.ok(runs.longRun, "judged by last seen")
	end,

	format = function(ns, t)
		t.eq(ns.Progress.FormatElapsed(65), "1m 05s", "minutes")
		t.eq(ns.Progress.FormatElapsed(6120), "1h 42m", "hours")
		t.eq(ns.Progress.FormatElapsed(0), "0m 00s", "zero")
	end,

	status = function(ns, t)
		local run = ns.Progress.New(189, 0)
		local s = ns.Progress.Status(run)
		t.eq(#s, 0, "winged map with no kills lists nothing")
		ns.Progress.OnEncounterEnd(run, 449, 1, 10)
		s = ns.Progress.Status(run)
		t.eq(#s, 1, "one started wing")
		t.eq(s[1].name, "Scarlet Monastery: Cathedral", "name")
		t.eq(s[1].done, 1, "done")
		t.eq(s[1].total, 2, "total")
		t.eq(s[1].remaining[1], "High Inquisitor Whitemane", "remaining")

		local plain = ns.Progress.Status(ns.Progress.New(36, 0))
		t.eq(#plain, 1, "plain map listed before any kill")
		t.eq(plain[1].done, 0, "plain done")
	end,
}
