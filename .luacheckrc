std = "lua51"
max_line_length = false

-- Globals the addon assigns to.
globals = {
	"ClearedCharDB",
	"SlashCmdList",
	"SLASH_CLEARED1",
}

-- WoW API the addon reads.
read_globals = {
	"C_Timer",
	"CreateFrame",
	"GetInstanceInfo",
	"INSTANCE_RESET_SUCCESS",
	"GetTime",
	"InCombatLockdown",
	"PlaySound",
	"Settings",
	"UIParent",
	"issecretvalue",
	"time",
}

-- Dev tooling runs under plain LuaJIT, not the WoW client.
files["tools/"] = { std = "luajit" }
files["tests/"] = { std = "luajit" }
