-- Minimal test runner for the addon's pure-Lua files. Run from the repo root:
--   luajit tests/run.lua
-- Each tests/test_*.lua returns { name = function(ns, t) ... end }. Every test gets a fresh ns.

local ADDON_FILES = { "Data.lua", "Overrides.lua", "Progress.lua" }
local TEST_FILES = { "tests/test_progress.lua" }

local function loadNamespace()
	local ns = {}
	for _, file in ipairs(ADDON_FILES) do
		local chunk = assert(loadfile("ForeverDungeonComplete/" .. file))
		chunk("ForeverDungeonComplete", ns)
	end
	return ns
end

local function show(v)
	return type(v) == "string" and string.format("%q", v) or tostring(v)
end

local t = {}
function t.eq(actual, expected, msg)
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", msg or "eq", show(expected), show(actual)), 2)
	end
end
function t.ok(value, msg)
	if not value then
		error((msg or "ok") .. ": expected truthy, got " .. show(value), 2)
	end
end

local passed, failed = 0, 0
for _, path in ipairs(TEST_FILES) do
	local tests = assert(loadfile(path))()
	local names = {}
	for name in pairs(tests) do
		names[#names + 1] = name
	end
	table.sort(names)
	for _, name in ipairs(names) do
		local ok, err = pcall(tests[name], loadNamespace(), t)
		if ok then
			passed = passed + 1
		else
			failed = failed + 1
			print("FAIL " .. name .. ": " .. tostring(err))
		end
	end
end

print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
