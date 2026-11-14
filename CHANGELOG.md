# Changelog

All notable changes to Cleared!. Format follows [Keep a Changelog](https://keepachangelog.com/).

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
