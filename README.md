<h1 align="center">Cleared!</h1>

An addon for [World of Warcraft: Forever](https://worldofwarcraft.blizzard.com/) that tells you when you've finished a dungeon or raid, the way retail does.

- **A toast for every boss.** Each kill shows the boss name and your progress, e.g. `Lord Roccor defeated  2/16`.
- **A banner when you're done.** Once every counted boss in the dungeon (or wing) is dead, you get a `DUNGEON COMPLETE` banner (`RAID COMPLETE` in raids) with the elapsed time and a sound.
- **A boss list on screen.** While you're in a dungeon or raid, a small panel under the minimap lists every boss with a tick once it's dead, plus optional bosses under "Bonus". Drag the header to move it, click it to collapse it.
- **Wings count separately.** Scarlet Monastery, Dire Maul, Stratholme, Blackrock Spire and Maraudon are split into their wings, and each one gets its own count and banner.
- **Survives reloads.** Progress is saved per dungeon. Coming back within 30 minutes (after a `/reload`, disconnect or run-back) picks up where you left off. Raid progress is kept for a week, so a raid split across nights carries on. A reset message, or a boss you'd already killed dying again, starts a fresh count.

## Install

Requires the WoW Forever client (interface `16001`).

1. Download this repo (Code > Download ZIP, or `git clone`), then copy or symlink the `Cleared` folder into
   `World of Warcraft/_forever_/Interface/AddOns/`.
2. Start the game, or `/reload` if it's already running.

For development, a symlink means edits in this repo show up in the game folder immediately:

```sh
ln -s "$PWD/Cleared" "/path/to/World of Warcraft/_forever_/Interface/AddOns/Cleared"
```

## Usage

| Command | What it does |
|---------|--------------|
| `/cleared` | Open the settings panel (not available in combat) |
| `/cleared status` | Show the current dungeon, wing or raid, bosses killed and bosses remaining |
| `/cleared test` | Show a sample toast and banner |
| `/cleared reset` | Forget progress for the current instance |
| `/cleared resetpos` | Move the boss list back under the minimap |
| `/cleared debug` | Print every boss encounter event with its ID (useful for reporting a boss that isn't counted) |

## Settings

Esc > Options > AddOns > Cleared!. Saved per character: boss kill toasts, the Complete banner, the banner sound and the boss list, each on or off.

## Which bosses count

Boss data comes from the Forever client's own `DungeonEncounter` table (via [wago.tools](https://wago.tools)), so every dungeon and raid in the game is covered without hand-typed boss lists. `Overrides.lua` adjusts it:

- **Optional bosses** (rares, quest summons, event bosses such as Skul, Lord Valthalak or Hurley Blackbreath, and raid bosses you can skip such as Ouro or Gahz'ranka) get a `(bonus)` toast but never count towards completion.
- **Wings**: maps that hold several dungeons are split, and each wing completes on its own.
- **One-of groups**: where only one of several bosses can be fought per run (Karazhan Crypts' Opera of Malediction and Failed Apprentice), killing any one of them counts.
- **Disabled dungeons**: dungeons whose bosses don't report kills are switched off with a chat note until they're supported.

## Regenerating the data

After a Forever patch:

```sh
python3 tools/gen_data.py            # newest Forever build on wago.tools
python3 tools/gen_data.py --build 1.60.1.70938
```

This rewrites `Cleared/Data.lua` and then runs `luajit tools/check_data.lua`. The check fails if a boss on a winged map isn't assigned to a wing or marked optional, or if an override points at a boss that no longer exists.

Tests:

```sh
luajit tests/run.lua
luajit tools/check_data.lua
python3 -m unittest tools/test_gen_data.py
luacheck Cleared tools tests
```

## Limitations

- Kills are detected through the game's encounter events. A boss that doesn't fire one can't be counted, and its dungeon is listed as disabled.
- The client hides which instance copy you're in, so a reset is detected by the reset message or by an already-killed boss dying again. If you reset without seeing the message and re-enter within 30 minutes, counts start from the old run until you kill a boss you'd already killed. Bosses killed before that point add to the old run, so the banner can fire early. `/cleared reset` fixes it by hand.
