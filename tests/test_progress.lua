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
		t.eq(ns.Progress.OnEncounterEnd(run, 447, 1, 410), nil, "repeat after completion")
		t.eq(ns.Progress.OnEncounterEnd(run, 446, 1, 420), nil, "repeat earlier kill")
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
		t.eq(ns.Progress.OnEncounterEnd(copy, 447, 1, 500), nil, "no second banner")
		t.eq(copy.done["Scarlet Monastery: Library"], true, "done kept")
	end,

	merge = function(ns, t)
		local saved = { map = 189, entered = 100, killed = { [446] = 150 }, done = {} }
		local pending = { map = 189, entered = 200, killed = { [447] = 210 }, done = { ["Scarlet Monastery: Library"] = true } }
		local m = ns.Progress.Merge(saved, pending)
		t.eq(m.entered, 100, "entered")
		t.eq(m.killed[446], 150, "saved kill")
		t.eq(m.killed[447], 210, "pending kill")
		t.eq(m.done["Scarlet Monastery: Library"], true, "done")
	end,

	merge_then_complete = function(ns, t)
		local saved = ns.Progress.New(189, 100)
		ns.Progress.OnEncounterEnd(saved, 446, 1, 150)
		local pending = ns.Progress.New(189, 300)
		local m = ns.Progress.Merge(saved, pending)
		local r = ns.Progress.OnEncounterEnd(m, 447, 1, 400)
		t.eq(r.completed, true, "completes with saved kill")
		t.eq(r.elapsed, 300, "elapsed from saved entry")
	end,

	-- Review finding: the last kill lands in the pending run before the key resolves.
	resolve_completes_after_late_merge = function(ns, t)
		local saved = ns.Progress.New(189, 100)
		ns.Progress.OnEncounterEnd(saved, 449, 1, 150)
		local pending = ns.Progress.New(189, 300)
		local r = ns.Progress.OnEncounterEnd(pending, 450, 1, 400)
		t.eq(r.completed, false, "pending alone can't see the saved kill")
		local run, results = ns.Progress.Resolve(saved, pending, false)
		t.eq(#results, 1, "one unit completes on resolve")
		t.eq(results[1].unit, "Scarlet Monastery: Cathedral", "unit")
		t.eq(results[1].completed, true, "completed")
		t.eq(results[1].done, 2, "done")
		t.eq(results[1].total, 2, "total")
		t.eq(results[1].elapsed, 300, "elapsed to the last kill from saved entry")
		t.eq(run.done["Scarlet Monastery: Cathedral"], true, "marked done")
		local _, again = ns.Progress.Resolve(run, ns.Progress.New(189, 500), false)
		t.eq(#again, 0, "never completes twice")
	end,

	resolve_without_saved = function(ns, t)
		local pending = ns.Progress.New(36, 0)
		ns.Progress.OnEncounterEnd(pending, 2747, 1, 10)
		local run, results = ns.Progress.Resolve(nil, pending, false)
		t.eq(run, pending, "pending becomes the run")
		t.eq(#results, 0, "nothing newly complete")
	end,

	-- Review finding: /fdc reset before the key resolves must not pull old kills back.
	resolve_discards_saved_after_reset = function(ns, t)
		local saved = ns.Progress.New(189, 100)
		ns.Progress.OnEncounterEnd(saved, 449, 1, 150)
		local pending = ns.Progress.New(189, 300)
		local run = ns.Progress.Resolve(saved, pending, true)
		t.eq(run, pending, "pending wins")
		t.eq(run.killed[449], nil, "old kill gone")
	end,

	guid_key = function(ns, t)
		t.eq(ns.Progress.KeyFromGUID("Creature-0-4372-189-12345-3974-0000ABCDEF"), "189:12345", "creature")
		t.eq(ns.Progress.KeyFromGUID("Vehicle-0-4372-189-12345-3974-0000ABCDEF"), "189:12345", "vehicle")
		t.eq(ns.Progress.KeyFromGUID("GameObject-0-4372-189-12345-3974-0000ABCDEF"), "189:12345", "gameobject")
		t.eq(ns.Progress.KeyFromGUID("Player-4372-0ABCDEF1"), nil, "player")
		t.eq(ns.Progress.KeyFromGUID(nil), nil, "nil")
	end,

	-- In-game error: UnitGUID on a nameplate returns a secret string that errors when indexed.
	guid_key_secret = function(ns, t)
		local secret = "Creature-0-4372-189-12345-3974-0000ABCDEF"
		local saved = _G.issecretvalue
		_G.issecretvalue = function(v)
			return v == secret
		end
		local ok, key = pcall(ns.Progress.KeyFromGUID, secret)
		_G.issecretvalue = saved
		t.ok(ok, "does not error")
		t.eq(key, nil, "secret GUID gives no key")
	end,

	prune = function(ns, t)
		local now = 1000000
		local runs = { old = { entered = now - 90000 }, fresh = { entered = now - 100 } }
		ns.Progress.Prune(runs, now, 86400)
		t.eq(runs.old, nil, "old removed")
		t.ok(runs.fresh, "fresh kept")
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
