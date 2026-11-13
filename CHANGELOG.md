# Changelog

All notable changes to ForeverDungeonComplete. Format follows [Keep a Changelog](https://keepachangelog.com/).

## [0.1.0] - Unreleased

First release.

### Added
- A toast for each boss kill showing progress, with a `(bonus)` tag for optional bosses.
- A Dungeon Complete banner with elapsed time and sound once every counted boss in the dungeon or wing is dead.
- Separate wings for Scarlet Monastery, Dire Maul, Stratholme and Blackrock Spire.
- Progress saved per instance copy, surviving `/reload` and disconnects.
- `/fdc` settings panel, plus `/fdc status`, `test`, `reset` and `debug`.
- Boss data generated from the Forever client's DungeonEncounter table (`tools/gen_data.py`), with an overrides integrity check.
- Lint, test and release workflows.
