std = "lua51"
max_line_length = false

-- Globals the addon assigns to.
globals = {
	"ForeverDungeonCompleteCharDB",
	"SlashCmdList",
	"SLASH_FOREVERDUNGEONCOMPLETE1",
}

-- WoW API the addon reads.
read_globals = {
	"C_Timer",
	"CreateFrame",
	"GetInstanceInfo",
	"GetTime",
	"InCombatLockdown",
	"PlaySound",
	"Settings",
	"UIParent",
	"UnitGUID",
	"issecretvalue",
	"time",
}

-- Dev tooling runs under plain LuaJIT, not the WoW client.
files["tools/"] = { std = "luajit" }
files["tests/"] = { std = "luajit" }
