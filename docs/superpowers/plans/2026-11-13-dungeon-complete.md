# ForeverDungeonComplete Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A WoW Forever addon that shows a toast for each dungeon boss killed (with progress) and a "Dungeon Complete" banner once every counted boss in the dungeon or wing is dead.

**Architecture:** A Python generator turns the wago.tools `DungeonEncounter` and `Map` tables into `Data.lua`. A hand-maintained `Overrides.lua` marks optional bosses, splits maps into wings and disables dungeons. A pure-Lua `Progress.lua` (no WoW API, so it runs under `luajit` tests) owns the run state machine. `UI.lua` draws the toasts and banner. `ForeverDungeonComplete.lua` wires events, saved variables, settings and slash commands.

**Tech Stack:** Lua 5.1 (WoW client, tested with `luajit`), luacheck, Python 3 stdlib (`unittest`, `urllib`, `csv`), GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-11-13-dungeon-complete-design.md`

## Global Constraints

- `## Interface: 16001`. Forever data only (product `wowf`, current build `1.60.1.70938`). Never use Classic Era IDs.
- Data URLs: `https://wago.tools/db2/<Table>/csv?build=<build>`, `https://wago.tools/api/builds`.
- No runtime library dependencies. No network at runtime. The generator uses Python stdlib only.
- The addon folder is `ForeverDungeonComplete/`. The saved variable is `ForeverDungeonCompleteCharDB` (per character). The slash command is `/fdc`.
- Addon files share state through the `local ADDON, ns = ...` namespace. The only globals are the saved variable and the slash command entries.
- Layout, `.editorconfig`, `.gitignore`, `LICENSE`, CI pinning style and the release zip naming (`<Addon>-<version>-forever.zip`) are copied from `~/repos/forever-skills`.
- Tabs for indentation in Lua (as in forever-skills).
- Completion fires at most once per unit (dungeon or wing) per instance copy. Runs older than 86400 s are pruned on login.
- Toasts: up to 3 stacked, about 3 s each. Banner: about 5 s, with sound, delayed so it doesn't land on top of the last toast.

**Deviation from the spec (my call):** the spec says `gen_data.py` checks overrides against the data. Parsing Lua from Python is fragile, so the check lives in `tools/check_data.lua` (run with `luajit`). `gen_data.py` calls it after writing and exits non-zero if it fails, and CI runs it too. The behaviour is the same.

**Data fact found while planning:** BRD's Ring of Law is a single encounter (`230`), so the spec's worry about random Ring bosses doesn't apply.

## Review Focus

1. **The same boss reports `ENCOUNTER_END success=1` twice** (event re-fire, or `/reload` mid-fight): count it once, one toast, never two banners. Test in Task 3.
2. **A second wing in the same copy** (DM East then West): West counts `1/5` independently, gets its own banner, and East's completed state is untouched. Test in Task 3.
3. **`/reload` after the banner:** a resumed run must not fire the banner again. Test in Task 3 (`completed` survives a round trip through a plain saved table).
4. **A kill whose encounter isn't on the active map, or a failed attempt (`success=0`):** ignored, no toast. Test in Task 3.
5. **A kill before the instance key resolves** (no creature GUID seen yet): it's still recorded in memory and kept when the key resolves. If a saved run with that key already exists, the saved kills and the new ones are merged. Test in Task 3 (`Progress.Merge`).

---

## File map

| File | Responsibility |
|------|----------------|
| `tools/gen_data.py` | Fetch CSVs, filter, render `Data.lua`, run `check_data.lua` |
| `tools/test_gen_data.py` | unittest for filter/render |
| `tools/check_data.lua` | Overrides ↔ Data integrity check, exits 1 on failure |
| `ForeverDungeonComplete/Data.lua` | Generated: `ns.Build`, `ns.Dungeons`, `ns.Encounters` |
| `ForeverDungeonComplete/Overrides.lua` | `ns.Optional`, `ns.Wings`, `ns.Disabled` |
| `ForeverDungeonComplete/Progress.lua` | Pure run logic: `ns.Progress` |
| `tests/run.lua` | Tiny test harness: loads addon files into a fake `ns`, runs `tests/test_*.lua` |
| `tests/test_progress.lua` | Progress tests |
| `ForeverDungeonComplete/UI.lua` | `ns.UI.Toast`, `ns.UI.Banner` |
| `ForeverDungeonComplete/ForeverDungeonComplete.lua` | Events, key resolution, SavedVariables, settings, slash |
| `ForeverDungeonComplete/ForeverDungeonComplete.toc` | Load order: Data, Overrides, Progress, UI, main |

---

### Task 1: Data generator

**Files:**
- Create: `tools/gen_data.py`, `tools/test_gen_data.py`, `ForeverDungeonComplete/Data.lua` (generated), `.gitignore`, `.editorconfig`, `LICENSE` (copied from forever-skills)

**Interfaces:**
- Produces (Python): `filter_data(map_rows: list[dict], enc_rows: list[dict]) -> dict[int, dict]` mapping mapID → `{"name": str, "encounters": [ {"id", "name", "order", "flags"} ]}`, with encounters sorted by `(order, id)`. `render_lua(data: dict, build: str) -> str`. `main(argv) -> int`.
- Produces (Lua, `Data.lua`):
  ```lua
  ns.Build = "1.60.1.70938"
  ns.Dungeons = { [mapID] = { name = "…", encounters = { id, … } } }   -- encounters in order
  ns.Encounters = { [id] = { map = mapID, name = "…", order = n, flags = n } }
  ```

- [ ] **Step 1: Write failing tests** in `tools/test_gen_data.py` (unittest, inline CSV-shaped dict rows):
  - `test_keeps_only_dungeons`: a map with `InstanceType "2"` is absent, and `"1"` is present.
  - `test_drops_non_zero_difficulty`: encounter rows with `DifficultyID` `198`, `201` or `215` are dropped. Only the `0` row for BFD survives.
  - `test_drops_world_and_test_maps`: maps `0` and `13` are absent even if `InstanceType` is 1. So is an encounter whose map isn't in the Map rows (like `3002`).
  - `test_sorts_by_order_including_negative`: orders `-3000, -6000, 1000` come out as `-6000, -3000, 1000`.
  - `test_render_escapes`: a name `Zul'Farrak "X" \ é` renders as a valid Lua string. Assert the output contains `"Zul'Farrak \"X\" \\ é"`, and that `luajit -e 'local ns={} loadstring(io.read("*a"))("x", ns)'` exits 0 on the rendered text (skip if `luajit` isn't on PATH).
  - `test_render_is_stable`: rendering the same data twice gives identical strings, with keys in ascending numeric order.
- [ ] **Step 2: Run** `python3 -m unittest tools/test_gen_data.py -v`. Expected: FAIL (ImportError).
- [ ] **Step 3: Implement** `tools/gen_data.py` with the signatures above. Write Lua strings with non-ASCII kept as UTF-8 bytes, escaping only `\` and `"`. Header line: `-- Generated by tools/gen_data.py from wago.tools build <build>. Do not edit.`, then `local _, ns = ...`. CLI: `--build` (default: newest `wowf` entry from `/api/builds`), `--out` (default `ForeverDungeonComplete/Data.lua`), `--skip-check`. After writing, unless `--skip-check` is passed, run `luajit tools/check_data.lua` and return its exit code. Until Task 2 exists, treat a missing checker as a printed warning, not a failure.
- [ ] **Step 4: Run tests.** Expected: PASS.
- [ ] **Step 5: Generate** with `python3 tools/gen_data.py --build 1.60.1.70938`. Expected: the file is written, `grep -c '^\s*\[' ForeverDungeonComplete/Data.lua` is non-zero, `[230]` has 21 encounters, and `[2747]` is VanCleef with `map = 36`.
- [ ] **Step 6: Commit** `feat: add wago data generator and generated Data.lua`

### Task 2: Overrides and data integrity check

**Files:**
- Create: `ForeverDungeonComplete/Overrides.lua`, `tools/check_data.lua`

**Interfaces:**
- Consumes: `ns.Dungeons`, `ns.Encounters` (Task 1).
- Produces:
  ```lua
  ns.Optional = { [encID] = true }
  ns.Wings    = { [mapID] = { { name = "Scarlet Monastery: Library", encounters = { 446, 447 } }, … } }
  ns.Disabled = { [mapID] = "reason" }   -- starts empty
  ```
- `tools/check_data.lua`: `luajit tools/check_data.lua` loads Data.lua and Overrides.lua into one `ns` and prints one line per problem. It exits 1 if anything is wrong, otherwise 0 with `ok: N dungeons, M encounters`.

- [ ] **Step 1: Write the checker first.** Rules:
  1. Every ID in `ns.Optional` and in any wing exists in `ns.Encounters`.
  2. Every wing encounter belongs to that wing's map.
  3. On a map listed in `ns.Wings`, every encounter is in exactly one wing XOR in `ns.Optional`.
  4. Every key in `ns.Disabled` is a key of `ns.Dungeons`.
  5. Every dungeon has at least one non-optional encounter.
- [ ] **Step 2: Run** with an `Overrides.lua` containing only empty tables. Expected: exit 0. Then temporarily add `ns.Wings[189] = { { name = "x", encounters = { 446 } } }` and expect exit 1, listing 444, 2779, 447, 448, 449 and 450 as unassigned.
- [ ] **Step 3: Fill in `Overrides.lua`** with the starter lists (IDs from the Forever build):
  - Wings
    - 189: Graveyard `444, 2779`; Library `446, 447`; Armory `448`; Cathedral `449, 450`
    - 429: Dire Maul: East `343, 344, 345, 346`; West `350, 347, 348, 349, 361`; North `362, 363, 364, 365, 366, 367, 368`
    - 329: Stratholme: Live `474, 475, 477, 478, 476, 472`; Undead `479, 480, 481, 482, 483, 484`
    - 229: Lower Blackrock Spire `267, 268, 269, 270, 272, 275`; Upper Blackrock Spire `3062, 3063, 3068, 3069`
  - Optional
    - Stratholme `473, 2795, 2796, 2797, 2798, 2799, 2800`
    - DM `2792, 2793, 2794`
    - LBRS `271` (Urok, summoned), `273, 274` (Gizrul/Halycon side area)
    - UBRS `3070`
    - BRD `238` (Hurley, event), `240, 241` (Ribbly, Plugger), `2789` (Moira), `2791` (The Vault)
  - Add a one-line comment per group saying why. Wing names are `"<Dungeon>: <Wing>"`.
- [ ] **Step 4: Run** `luajit tools/check_data.lua`. Expected: `ok: …`, exit 0. Then run `python3 tools/gen_data.py --build 1.60.1.70938`. Expected: exit 0 and Data.lua unchanged (`git diff --exit-code ForeverDungeonComplete/Data.lua`).
- [ ] **Step 5: Commit** `feat: add overrides for wings and optional bosses with integrity check`

### Task 3: Progress logic (pure Lua)

**Files:**
- Create: `ForeverDungeonComplete/Progress.lua`, `tests/run.lua`, `tests/test_progress.lua`

**Interfaces:**
- Consumes: `ns.Dungeons`, `ns.Encounters`, `ns.Optional`, `ns.Wings`.
- Produces `ns.Progress`:
  - `Units(mapID) -> { { name = string, encounters = {ids} } }`. A map without wings gives one unit named after the dungeon, with every non-optional encounter.
  - `New(mapID, now) -> run`, where `run = { map = mapID, entered = now, killed = { [encID] = time }, done = { [unitName] = true } }`. This is a plain table, so it can be stored in SavedVariables as-is.
  - `OnEncounterEnd(run, encID, success, now) -> result | nil`. Returns nil if `success ~= 1`, if the encounter isn't on `run.map`, or if it's already in `run.killed`. Otherwise it records the kill and returns `{ name = bossName, optional = bool, unit = unitName|nil, done = n, total = n, completed = bool, elapsed = seconds|nil }`. For an optional boss, `unit`, `done` and `total` are nil and `completed` is false. `completed` is true only on the kill that finishes the unit, at which point it sets `run.done[unit] = true`. `elapsed = now - run.entered` when completed.
  - `Status(run) -> { { name, done, total, remaining = {bossNames} } }`. Lists only units that have at least one kill. If none do, it lists the units of a map without wings.
  - `Merge(saved, pending) -> run`. Keeps `saved.entered`, unions `killed`, ORs `done`.
  - `KeyFromGUID(guid) -> string | nil`. For `"Creature-0-SSSS-MMM-ZZZZ-NNN-XXXX"` it returns `"MMM:ZZZZ"`. Also accepts the `Vehicle` and `GameObject` prefixes. `Player-…` and nil give nil.
  - `Prune(runs, now, maxAge)`. Removes entries where `now - run.entered > maxAge`.
  - `FormatElapsed(sec) -> string`. `≥ 3600` gives `"1h 42m"`, otherwise `"18m 04s"`.
- `tests/run.lua`: builds `ns`, loads the addon files in toc order with `loadfile(path)("ForeverDungeonComplete", ns)` (Data, Overrides, Progress), then runs each `tests/test_*.lua` chunk with `(ns, t)`, where `t.eq(a, b, msg)` and `t.ok(v, msg)` are provided. Prints `N passed, M failed` and exits 1 on any failure. Run it with `luajit tests/run.lua`.

- [ ] **Step 1: Write failing tests** in `tests/test_progress.lua` against the real data:
  - `units_plain`: `Units(36)` has 1 unit named `"Deadmines"`, and the 2747 kill brings it to `total` 8.
  - `units_winged`: `Units(189)` has 4 units, and Library's encounters are `{446, 447}`.
  - `kill_counts`: on a new run for 189, killing 446 gives `{unit = "Scarlet Monastery: Library", done = 1, total = 2, completed = false}`.
  - `wing_completes`: killing 446 then 447 makes the second result `completed = true`, sets `elapsed = now - entered`, and sets `run.done["Scarlet Monastery: Library"]`.
  - `duplicate_ignored` (Review Focus 1): calling 447 a second time after completion returns nil.
  - `second_wing_independent` (Review Focus 2): on map 429, finishing East and then killing 350 gives `{unit = "Dire Maul: West", done = 1, total = 5}`, and East stays done.
  - `failed_and_foreign_ignored` (Review Focus 4): `success = 0` returns nil, and encounter 227 (BRD) on a 36 run returns nil.
  - `optional_kill`: on map 329, encounter 2799 gives `optional = true`, `completed = false`, and the Undead count doesn't change.
  - `saved_roundtrip` (Review Focus 3): after completing Library, copy the run through a serializer that keeps only plain tables, numbers, strings and booleans. On the copy, 447 returns nil and `done` is still set.
  - `merge` (Review Focus 5): saved `{entered = 100, killed = {446 = 150}}` merged with pending `{entered = 200, killed = {447 = 210}}` gives `entered = 100` and both kills.
  - `guid_key`: `KeyFromGUID("Creature-0-4372-189-12345-3974-0000ABCDEF")` gives `"189:12345"`. A `Player-…` GUID or nil gives nil.
  - `prune`: an entry entered at `now - 90000` is removed, and one at `now - 100` is kept (maxAge 86400).
  - `format`: `65` gives `"1m 05s"`, `6120` gives `"1h 42m"`.
- [ ] **Step 2: Run** `luajit tests/run.lua`. Expected: FAIL (Progress is nil).
- [ ] **Step 3: Implement `Progress.lua`** to the interfaces above. Cache `Units(mapID)` per map. Use no WoW API calls; time is always passed in.
- [ ] **Step 4: Run** `luajit tests/run.lua`. Expected: all pass, exit 0.
- [ ] **Step 5: Commit** `feat: add pure run-progress logic with tests`

### Task 4: Toast and banner UI

**Files:**
- Create: `ForeverDungeonComplete/UI.lua`

**Interfaces:**
- Consumes: `ns.Progress.FormatElapsed`.
- Produces `ns.UI`:
  - `Toast(text: string, right: string)`. `right` is `"2/21"` or `"(bonus)"`. Toasts appear top centre below the zone text, stack up to 3 (the oldest is dropped when a 4th arrives), fade out after about 3 s, and show a skull icon (`Interface\\TargetingFrame\\UI-TargetingFrame-Skull`).
  - `Banner(title: string, subtitle: string, detail: string, playSound: bool)`. The title is `DUNGEON COMPLETE`, the subtitle is the unit name, and the detail is `"N/N · 18m 04s"`. It's shown at screen centre, fades in, holds about 5 s, then fades out. If a toast was shown in the last 1.5 s, it waits until then (`C_Timer.After`). The sound is `PlaySound(SOUNDKIT.UI_LEVEL_UP_NOTIFICATION or 888)`, or the builder can pick another celebratory kit that exists in the 16001 client. Fall back to `SOUNDKIT.IG_QUEST_LIST_COMPLETE`.
- Use plain `CreateFrame`, font strings and `UIFrameFadeIn`/`UIFrameFadeOut` or an AnimationGroup. Frames are created lazily on first use.

- [ ] **Step 1: Implement `UI.lua`.**
- [ ] **Step 2: Lint** with `luacheck ForeverDungeonComplete`. Expected: 0 warnings. Add any WoW globals used to `read_globals` in `.luacheckrc` (this file is created in Task 5; create it now if missing, copied from forever-skills and with its globals replaced).
- [ ] **Step 3: Commit** `feat: add toast and completion banner frames`

Visual check happens in Task 6 via `/fdc test`.

### Task 5: Addon wiring, settings, slash commands, packaging

**Files:**
- Create: `ForeverDungeonComplete/ForeverDungeonComplete.lua`, `ForeverDungeonComplete/ForeverDungeonComplete.toc`, `.luacheckrc`, `.github/workflows/lint.yml`, `.github/workflows/release.yml`, `README.md`, `CHANGELOG.md`

**Interfaces:**
- Consumes: everything above.
- toc: `## Interface: 16001`, `## Title: ForeverDungeonComplete`, `## Notes: Boss kill progress toasts and a Dungeon Complete banner. Built for WoW Forever.`, `## IconTexture: Interface\Icons\INV_Misc_Head_Dragon_01` (or similar), `## Version: @project-version@`, `## SavedVariablesPerCharacter: ForeverDungeonCompleteCharDB`. Files in order: Data, Overrides, Progress, UI, main.
- Saved variable shape: `{ settings = { toasts = true, banner = true, sound = true, debug = false }, runs = { [key] = run } }`.

Behaviour (state lives in file locals: `active` = `{ map, key | nil, run }` or nil):
- `ADDON_LOADED` (own addon): init the DB with defaults, `Progress.Prune(db.runs, time(), 86400)`, and register the settings.
- `PLAYER_ENTERING_WORLD` and `ZONE_CHANGED_NEW_AREA`: read `GetInstanceInfo()`. If `instanceType == "party"` and `ns.Dungeons[instanceMapID]`:
  - If the map is in `ns.Disabled`, print one chat line, `ForeverDungeonComplete: <name> isn't supported yet (<reason>).`, and leave `active` nil.
  - Otherwise, if `active` isn't already this map, set `active = { map, key = nil, run = Progress.New(map, time()) }`.
  - Leaving to a non-dungeon clears `active`.
- Key resolution: while `active.key` is nil, `PLAYER_TARGET_CHANGED`, `UPDATE_MOUSEOVER_UNIT`, `NAME_PLATE_UNIT_ADDED` (unit arg) and the start of `ENCOUNTER_END` handling try `UnitGUID` on `target`, `mouseover`, the nameplate unit and `boss1`. The first `Progress.KeyFromGUID` result whose map part equals `tostring(active.map)` becomes the key. Then `active.run = db.runs[key] and Progress.Merge(db.runs[key], active.run) or active.run`, and `db.runs[key] = active.run`. Once the key is set, unregister the three unit events.
- `ENCOUNTER_END(encID, name, diff, size, success)`:
  - If `debug` is on, print every event (also in disabled dungeons): `[fdc] ENCOUNTER_END id=… name=… success=…`.
  - If `active`, call `r = Progress.OnEncounterEnd(active.run, encID, success, time())`.
  - If `r` and toasts are on: `UI.Toast(r.name .. " defeated", r.optional and "(bonus)" or (r.done .. "/" .. r.total))`.
  - If `r.completed` and the banner is on: `UI.Banner("DUNGEON COMPLETE", r.unit, r.total .. "/" .. r.total .. " · " .. Progress.FormatElapsed(r.elapsed), settings.sound)`.
- Settings: register through `Settings.RegisterVerticalLayoutCategory("ForeverDungeonComplete")` with checkboxes for toasts, banner and sound, the same pattern as `forever-skills/ForeverSkillManager/ForeverSkillManager.lua:416-458`.
- `/fdc` subcommands:
  - none: open settings (blocked in combat, like FSM)
  - `status`: one line per `Progress.Status` unit, as `Name: d/t — remaining: a, b`, or `not in a supported dungeon`
  - `test`: a sample toast, then a banner `Scarlet Monastery: Cathedral`, `2/2 · 18m 04s`
  - `reset`: clear `db.runs[active.key]` and restart `active.run`
  - `debug`: toggle and print the new state
  - anything else: print the usage

- [ ] **Step 1: Write the toc and main file** to the behaviour above.
- [ ] **Step 2: `.luacheckrc`**: copy from forever-skills, set `globals` to `ForeverDungeonCompleteCharDB`, `SlashCmdList` and `SLASH_FOREVERDUNGEONCOMPLETE1`, and set `read_globals` to the API actually used. Exclude `tests/` and `tools/` from the addon run, or give them their own std.
- [ ] **Step 3: Lint and tests.** Run `luacheck ForeverDungeonComplete`, then `luajit tests/run.lua`, then `luajit tools/check_data.lua`, then `python3 -m unittest tools/test_gen_data.py`. Expected: all clean or passing.
- [ ] **Step 4: CI**: copy `lint.yml` with `args: ForeverDungeonComplete`. Add a `test` job in the same file: checkout, `sudo apt-get install -y luajit`, run the three test commands from Step 3. Copy `release.yml` with `ForeverSkillManager` replaced by `ForeverDungeonComplete` throughout. Keep the action SHAs pinned exactly as the source has them.
- [ ] **Step 5: README and CHANGELOG** in the forever-skills style: what it does, install (symlink into `_forever_/Interface/AddOns/`), the command table, how to regenerate data (`python3 tools/gen_data.py`), the wing/optional rules, and limitations (dungeons only; disabled list). CHANGELOG gets `0.1.0 - Unreleased`.
- [ ] **Step 6: Commit** `feat: wire events, persistence, settings and /fdc commands`

### Task 6: In-game verification and release gate (user plays, builder assists)

Can't be automated. The builder prepares the checklist and the symlink command. The user runs it in the Forever client and reports the `/fdc debug` output.

- [ ] **Step 1: Symlink** the folder into `World of Warcraft/_forever_/Interface/AddOns/` and log in. Expected: no Lua errors (`/console scriptErrors 1`).
- [ ] **Step 2: `/fdc test`.** Expected: the toast and then the banner, with sound, laid out as in the spec sketch.
- [ ] **Step 3: Check that the GUID format assumption holds.** In any dungeon, run `/run print(UnitGUID("target"))` on a mob. Expected: the 4th field equals the instance map ID, and the 5th field changes after an instance reset. If not, fix `KeyFromGUID` and its test.
- [ ] **Step 4: Debug run per the spec's release gate.** Do at least one classic dungeon (Deadmines or RFC), one winged one (an SM wing) and one Forever-only one, with `/fdc debug` on. Expected: every counted boss prints `ENCOUNTER_END` with an ID in Data.lua, the toasts count correctly, and the banner fires on the last one. Also `/reload` mid-run, and a reset then re-enter.
- [ ] **Step 5: Record the results.** Any dungeon where a counted boss didn't fire goes in `ns.Disabled` with a reason. Bosses found to be optional in practice go in `ns.Optional`. Re-run `luajit tools/check_data.lua`.
- [ ] **Step 6: Commit** `chore: record in-game verification results`, then tag `v0.1.0` only when the user says so.
