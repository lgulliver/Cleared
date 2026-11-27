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

	-- Gnomeregan: only appears in the Emi Shortfuse escort event
	[2768] = true, -- Grubbis

	-- Scholomance: summoned
	[2805] = true, -- Kirtonos (Blood of Innocents)
	[3055] = true, -- Kormok (ritual candles)

	-- Zul'Farrak: summoned with the Mallet
	[594] = true, -- Gahz'rilla

	-- Sunken Temple: statue puzzle and Blood of Hakkar event
	[3582] = true, -- Atal'alarion
	[3583] = true, -- Avatar of Hakkar

	-- Maraudon: off the main route (Wicked Grotto) and the Earth Song Falls bonus boss
	[427] = true, -- Tinkerer Gizlock
	[428] = true, -- Rotgrip

	-- Karazhan Crypts: summoned by the book on the altar, three Mysterious Relics, Warlock-only dialogue
	[3143] = true, -- Kharon
	[3145] = true, -- Dark Rider
	[3152] = true, -- Unk'omon

	-- Molten Core: not a boss kill
	[3018] = true, -- The Molten Core

	-- Zul'Gurub: summoned
	[788] = true, -- Edge of Madness
	[790] = true, -- Gahz'ranka

	-- Ahn'Qiraj Temple: not needed to reach C'Thun
	[710] = true, -- Silithid Royalty
	[713] = true, -- Viscidus
	[716] = true, -- Ouro
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
	[349] = {
		{ name = "Maraudon: Orange", encounters = { 422, 423 } },
		{ name = "Maraudon: Purple", encounters = { 424, 425 } },
		{ name = "Maraudon: Inner", encounters = { 426, 429 } },
	},
	[229] = {
		{ name = "Lower Blackrock Spire", encounters = { 267, 268, 269, 270, 272, 275 } },
		{ name = "Upper Blackrock Spire", encounters = { 3062, 3063, 3068, 3069 } },
	},
}

-- Encounters where only one of several bosses can be fought per run. Each group counts as one boss,
-- killed when any member dies, and sits where its first member is in the dungeon's order.
ns.OneOf = {
	-- Karazhan Crypts: Opera of Malediction rotates daily (Three Little Wolves is assumed to be the
	-- Trizivast variant); the Portcullis Key frees one of the three Failed Apprentices per run.
	{ name = "Opera of Malediction", encounters = { 3144, 3168, 3169 } },
	{ name = "The Failed Apprentice", encounters = { 3170, 3171, 3172 } },
}

-- Dungeons switched off until their bosses are confirmed to fire ENCOUNTER_END.
-- [mapID] = "reason shown in chat"
ns.Disabled = {}
