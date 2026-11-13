-- Verifies Overrides.lua against the generated Data.lua. Run from the repo root:
--   luajit tools/check_data.lua
-- Exits 1 and prints one line per problem if anything is inconsistent.

local ns = {}
for _, file in ipairs({ "Data.lua", "Overrides.lua" }) do
	local chunk = assert(loadfile("ForeverDungeonComplete/" .. file))
	chunk("ForeverDungeonComplete", ns)
end

local problems = {}
local function problem(fmt, ...)
	problems[#problems + 1] = string.format(fmt, ...)
end

local function label(id)
	local enc = ns.Encounters[id]
	return enc and string.format("%d (%s)", id, enc.name) or tostring(id)
end

for id in pairs(ns.Optional) do
	if not ns.Encounters[id] then
		problem("optional encounter %d does not exist in Data.lua", id)
	end
end

for mapID, wings in pairs(ns.Wings) do
	if not ns.Dungeons[mapID] then
		problem("wings defined for map %d, which is not a dungeon in Data.lua", mapID)
	else
		local seen = {}
		for _, wing in ipairs(wings) do
			for _, id in ipairs(wing.encounters) do
				local enc = ns.Encounters[id]
				if not enc then
					problem("%s: encounter %d does not exist in Data.lua", wing.name, id)
				elseif enc.map ~= mapID then
					problem("%s: encounter %s belongs to map %d, not %d", wing.name, label(id), enc.map, mapID)
				end
				if seen[id] then
					problem("%s: encounter %s is also in %s", wing.name, label(id), seen[id])
				end
				if ns.Optional[id] then
					problem("%s: encounter %s is both in a wing and optional", wing.name, label(id))
				end
				seen[id] = wing.name
			end
		end
		for _, id in ipairs(ns.Dungeons[mapID].encounters) do
			if not seen[id] and not ns.Optional[id] then
				problem("%s: encounter %s is in no wing and not optional", ns.Dungeons[mapID].name, label(id))
			end
		end
	end
end

for mapID in pairs(ns.Disabled) do
	if not ns.Dungeons[mapID] then
		problem("disabled map %d is not a dungeon in Data.lua", mapID)
	end
end

local dungeonCount, encounterCount = 0, 0
for mapID, dungeon in pairs(ns.Dungeons) do
	dungeonCount = dungeonCount + 1
	local counted = 0
	for _, id in ipairs(dungeon.encounters) do
		encounterCount = encounterCount + 1
		if not ns.Optional[id] then
			counted = counted + 1
		end
	end
	if counted == 0 then
		problem("%s (%d) has no counted encounters", dungeon.name, mapID)
	end
end

if #problems > 0 then
	table.sort(problems)
	for _, line in ipairs(problems) do
		print(line)
	end
	os.exit(1)
end
print(string.format("ok: %d dungeons, %d encounters", dungeonCount, encounterCount))
