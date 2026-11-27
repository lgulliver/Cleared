# Changelog

All notable changes to Cleared!. Format follows [Keep a Changelog](https://keepachangelog.com/).

## [0.2.0] - 2026-11-27

### Added
- Raid support: Molten Core, Onyxia's Lair, Blackwing Lair, Zul'Gurub, both Ahn'Qiraj raids, Naxxramas and the Forever raids (Nightmare Grove, Scarlet Enclave and the world boss maps). Raids show a `RAID COMPLETE` banner, and raid progress is kept for a week so a lockout split across nights carries on.
- Maraudon is split into Orange, Purple and Inner wings, each with its own count and banner.
- One-of boss groups: where only one of several bosses can be fought per run, killing any of them counts. Used for Karazhan Crypts' Opera of Malediction and The Failed Apprentice.

### Changed
- More summoned and event bosses are optional (bonus toast, not counted): Grubbis, Kirtonos, Kormok, Gahz'rilla, Atal'alarion, Avatar of Hakkar, Tinkerer Gizlock, Rotgrip, Kharon, Dark Rider, Unk'omon, Edge of Madness, Gahz'ranka, Silithid Royalty, Viscidus and Ouro.

### Fixed
- Blackfathom Deeps was missing Old Serra'kis, Twilight Lord Kelris and Aku'mai, and Gnomeregan was missing Grubbis.
- The Searing Basin, a Blizzard test map, is no longer listed as a dungeon.

## [0.1.0] - 2026-11-14

First release.

### Added
- A toast for each boss kill showing progress, with a `(bonus)` tag for optional bosses.
- A Dungeon Complete banner with elapsed time and sound once every counted boss in the dungeon or wing is dead.
- A boss list panel inside dungeons: ticks for dead bosses, optional bosses under "Bonus", draggable and collapsible, with a "Boss list" setting and `/cleared resetpos`.
- Separate wings for Scarlet Monastery, Dire Maul, Stratholme and Blackrock Spire.
- Progress saved per dungeon, surviving `/reload` and disconnects.
- `/cleared` settings panel, plus `/cleared status`, `test`, `reset` and `debug`.
- Boss data generated from the Forever client's DungeonEncounter table (`tools/gen_data.py`), with an overrides integrity check.
- Lint, test and release workflows.
