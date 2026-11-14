-- Hand-maintained exceptions to the generated Data.lua.
-- After editing, run `luajit tools/check_data.lua` from the repo root.
local _, ns = ...

-- Encounters that get a "(bonus)" toast but never count towards completion.
ns.Optional = {
	-- Wailing Caverns: wanders in the water / side cave, often skipped
	[587] = true, -- Kresh
	[589] = true, -- Skum

	-- Stratholme: rares and quest summons
	[473] = true, -- Hearthsinger Forresten
	[2795] = true, -- Black Guard Swordsmith
	[2796] = true, -- Crimson Hammersmith
	[2797] = true, -- Ezra Grimm
	[2798] = true, -- Postmaster Malown
	[2799] = true, -- Skul
	[2800] = true, -- Stonespine

	-- Dire Maul: rare, summon and chase boss
	[2792] = true, -- Pusillin
	[2793] = true, -- Lord Hel'nurath
	[2794] = true, -- Tsu'zee

	-- Lower Blackrock Spire: quest summon and side area
	[271] = true, -- Urok Doomhowl
	[273] = true, -- Gizrul the Slavener
	[274] = true, -- Halycon

	-- Upper Blackrock Spire: summoned
	[3070] = true, -- Lord Valthalak

	-- Blackrock Depths: events, rares and off-path bosses
	[238] = true, -- Hurley Blackbreath
	[240] = true, -- Ribbly Screwspigot
	[241] = true, -- Plugger Spazzring
	[2789] = true, -- Princess Moira Bronzebeard
	[2791] = true, -- The Vault
}

-- Maps split into separately completed wings. Each wing tracks its own progress and banner.
-- Every encounter on these maps must be in exactly one wing or in ns.Optional.
ns.Wings = {
	[189] = {
		{ name = "Scarlet Monastery: Graveyard", encounters = { 444, 2779 } },
		{ name = "Scarlet Monastery: Library", encounters = { 446, 447 } },
		{ name = "Scarlet Monastery: Armory", encounters = { 448 } },
		{ name = "Scarlet Monastery: Cathedral", encounters = { 449, 450 } },
	},
	[429] = {
		{ name = "Dire Maul: East", encounters = { 343, 344, 345, 346 } },
		{ name = "Dire Maul: West", encounters = { 350, 347, 348, 349, 361 } },
		{ name = "Dire Maul: North", encounters = { 362, 363, 364, 365, 366, 367, 368 } },
	},
	[329] = {
		{ name = "Stratholme: Live", encounters = { 474, 475, 477, 478, 476, 472 } },
		{ name = "Stratholme: Undead", encounters = { 479, 480, 481, 482, 483, 484 } },
	},
	[229] = {
		{ name = "Lower Blackrock Spire", encounters = { 267, 268, 269, 270, 272, 275 } },
		{ name = "Upper Blackrock Spire", encounters = { 3062, 3063, 3068, 3069 } },
	},
}

-- Dungeons switched off until their bosses are confirmed to fire ENCOUNTER_END.
-- [mapID] = "reason shown in chat"
ns.Disabled = {}
