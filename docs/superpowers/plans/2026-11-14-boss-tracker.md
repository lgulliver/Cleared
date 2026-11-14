# Boss Tracker Frame Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An always-on panel inside supported dungeons listing each boss as dead or alive, retail style.

**Architecture:** A pure `Progress.TrackerView(run)` decides what to show (unit-tested under luajit); a new `Tracker.lua` draws that view in a movable, collapsible frame; `Cleared.lua` refreshes it on every state change and adds a setting and `/cleared resetpos`.

**Tech Stack:** Lua 5.1 (WoW Forever client, interface 16001), luajit test runner in `tests/run.lua`, luacheck.

**Spec:** `docs/superpowers/specs/2026-11-14-boss-tracker-design.md`

## Global Constraints

- Interface 16001; no Blizzard objective-tracker code; plain non-secure frames only.
- Optional bosses are listed under "Bonus" and never count towards the header total.
- Setting key `tracker`, label "Boss list", default `true`.
- Slash subcommand `resetpos` restores the default position (TOPRIGHT of UIParent, under the minimap).
- Saved per character in `ClearedCharDB`: `trackerPos = { point, relPoint, x, y }`, `trackerCollapsed` boolean.

## Review Focus

1. A `/cleared reset` or restart while the panel is collapsed — must stay collapsed and show the reset counts.
2. Leaving the dungeon mid-run, then `/reload` outside — panel must be hidden, not show stale data.
3. Turning the "Boss list" setting off and on in the Settings panel without a reload — hides and reappears immediately.
4. A saved position that ends up off-screen (resolution change) — `/cleared resetpos` must bring it back; frame uses `SetClampedToScreen(true)`.
5. BRD (16 counted + 5 bonus rows) — frame height grows to fit all rows; no row overlaps.

---

### Task 1: `Progress.TrackerView`

**Files:**
- Modify: `Cleared/Progress.lua` (append after `Progress.Status`)
- Test: `tests/test_progress.lua`

**Interfaces:**
- Produces: `Progress.TrackerView(run) -> view` where
  `view = { title = string, done = number|nil, total = number|nil, completed = boolean, bosses = { {name, killed} }, wings = nil | { {name, done, total, completed} }, bonus = { {name, killed} } }`.
  Overview (winged map, no counted kill yet): `wings` set, `bosses` empty, `done`/`total` nil, `completed` false.
  Active wing = wing containing the counted kill with the highest `run.killed` timestamp. Bonus = every `ns.Optional` encounter on `run.map`, in `ns.Dungeons[map].encounters` order. Wing short name strips a leading `"<dungeon name>: "`.

- [ ] **Step 1: Write the failing tests** (add to the returned table)

```lua
tracker_plain = function(ns, t)
	local v = ns.Progress.TrackerView(ns.Progress.New(43, 0))
	t.eq(v.title, "Wailing Caverns", "title")
	t.eq(v.done, 0, "done"); t.eq(v.total, 6, "total"); t.eq(v.completed, false, "completed")
	t.eq(#v.bosses, 6, "bosses"); t.eq(v.bosses[1].name, "Lady Anacondra", "first")
	t.eq(v.bosses[3].name, "Lord Pythas", "skips optional Kresh")
	t.eq(#v.bonus, 2, "bonus"); t.eq(v.bonus[1].name, "Kresh", "bonus first")
	t.eq(v.wings, nil, "no wings")
end,

tracker_plain_kills = function(ns, t)
	local run = ns.Progress.New(43, 0)
	ns.Progress.OnEncounterEnd(run, 588, 1, 10)
	ns.Progress.OnEncounterEnd(run, 589, 1, 20)
	local v = ns.Progress.TrackerView(run)
	t.eq(v.done, 1, "bonus not counted")
	t.eq(v.bosses[3].killed, true, "Pythas dead"); t.eq(v.bosses[1].killed, false, "Anacondra alive")
	t.eq(v.bonus[2].killed, true, "Skum dead"); t.eq(v.bonus[1].killed, false, "Kresh alive")
end,

tracker_completed = function(ns, t)
	local run = ns.Progress.New(43, 0)
	for i, id in ipairs({ 585, 586, 588, 590, 591, 592 }) do
		ns.Progress.OnEncounterEnd(run, id, 1, i * 100)
	end
	t.eq(ns.Progress.TrackerView(run).completed, true, "completed")
end,

tracker_winged_overview = function(ns, t)
	local run = ns.Progress.New(189, 0)
	ns.Progress.OnEncounterEnd(run, 2799, 1, 10) -- not on this map: ignored
	local v = ns.Progress.TrackerView(run)
	t.eq(v.title, "Scarlet Monastery", "title")
	t.eq(#v.wings, 4, "wings"); t.eq(v.wings[2].name, "Library", "short name")
	t.eq(v.wings[2].total, 2, "wing total"); t.eq(v.wings[2].done, 0, "wing done")
	t.eq(#v.bosses, 0, "no bosses"); t.eq(v.done, nil, "no header count")
end,

tracker_winged_active = function(ns, t)
	local run = ns.Progress.New(189, 0)
	ns.Progress.OnEncounterEnd(run, 446, 1, 10)
	local v = ns.Progress.TrackerView(run)
	t.eq(v.title, "Scarlet Monastery: Library", "library"); t.eq(v.done, 1, "done"); t.eq(v.total, 2, "total")
	t.eq(v.wings, nil, "expanded")
	ns.Progress.OnEncounterEnd(run, 449, 1, 500)
	t.eq(ns.Progress.TrackerView(run).title, "Scarlet Monastery: Cathedral", "follows latest kill")
end,

tracker_winged_bonus_only = function(ns, t)
	local run = ns.Progress.New(329, 0)
	ns.Progress.OnEncounterEnd(run, 2799, 1, 10)
	local v = ns.Progress.TrackerView(run)
	t.ok(v.wings, "bonus kill does not pick a wing")
	t.eq(#v.bonus, 7, "all map optionals"); t.eq(v.wings[1].name, "Live", "short name")
end,
```

- [ ] **Step 2: Run, expect FAIL** — `luajit tests/run.lua` → 6 failures, "attempt to call field 'TrackerView' (a nil value)".
- [ ] **Step 3: Implement `Progress.TrackerView(run)`** in `Cleared/Progress.lua`, reusing `Progress.Units` and `countKilled`.
- [ ] **Step 4: Run, expect PASS** — `luajit tests/run.lua` → `25 passed, 0 failed`; `luacheck Cleared tools tests` → 0 warnings.
- [ ] **Step 5: Commit** — `feat: add TrackerView for the boss list`.

### Task 2: `Tracker.lua` frame

**Files:**
- Create: `Cleared/Tracker.lua`
- Modify: `Cleared/Cleared.toc` (add `Tracker.lua` after `UI.lua`), `.luacheckrc` (read_globals as needed)

**Interfaces:**
- Consumes: `view` from Task 1.
- Produces: `ns.Tracker.Show(view, opts)` where `opts = { pos = table|nil, collapsed = boolean, onMoved = function(pos), onToggle = function(collapsed) }`; `ns.Tracker.Hide()`; `ns.Tracker.ResetPosition()` (moves to default, returns nothing; caller clears saved pos).

- [ ] **Step 1: Build the frame**, created on first `Show`, matching `UI.lua` idiom:
  - Width 220, background `SetColorTexture(0, 0, 0, 0.45)`, `SetClampedToScreen(true)`, `SetMovable(true)`.
  - Default anchor: `TOPRIGHT, UIParent, TOPRIGHT, -40, -230`.
  - Header: a `Button`, height 20; left FontString `GameFontNormal` (title), right FontString `GameFontNormal` (`done/total`, blank in overview). Title and count colour green (`0.1, 1, 0.1`) when `view.completed`.
  - Header `RegisterForDrag("LeftButton")`: OnDragStart → `frame:StartMoving()`; OnDragStop → `StopMovingOrSizing()`, read `GetPoint(1)`, call `opts.onMoved({point, relPoint, x, y})`. OnClick → toggle collapsed, call `opts.onToggle`, re-layout.
  - Rows: pooled frames, height 16. Icon 12×12: killed → `Interface\RaidFrame\ReadyCheck-Ready`; alive → no texture, text prefixed `· `. Text `GameFontHighlightSmall`; alive rows `SetTextColor(0.6, 0.6, 0.6)`.
  - Wing overview rows: `name` left, `done/total` right, green when completed.
  - "Bonus" sub-heading row (`GameFontNormalSmall`) only when `#view.bonus > 0`, followed by bonus rows.
  - Collapsed: hide all rows; height = header only. Expanded: height = header + rows × 16 + 6 padding.
- [ ] **Step 2: Verify** — `luacheck Cleared tools tests` → 0 warnings; `luajit tests/run.lua` → `25 passed, 0 failed`.
- [ ] **Step 3: Commit** — `feat: add boss list frame`.

### Task 3: Wiring, setting, command, docs

**Files:**
- Modify: `Cleared/Cleared.lua`, `README.md`, `CHANGELOG.md`

**Interfaces:**
- Consumes: Task 1 `Progress.TrackerView`, Task 2 `ns.Tracker.*`.

- [ ] **Step 1: Add `RefreshTracker()`** in `Cleared.lua`: hide when `not active` or `not db.settings.tracker`; else `Tracker.Show(Progress.TrackerView(active.run), { pos = db.trackerPos, collapsed = db.trackerCollapsed, onMoved = …store db.trackerPos, onToggle = …store db.trackerCollapsed })`.
- [ ] **Step 2: Call it** at the end of `UpdateZone` (both enter and leave paths), after a recorded kill in `OnEncounterEnd`, after `/cleared reset`.
- [ ] **Step 3: Setting** — add `tracker = true` to `DEFAULTS`; `Check("tracker", "Boss list", "Show the list of bosses while inside a dungeon.")`; if `Settings.SetOnValueChangedCallback` exists, register it for `Cleared_tracker` to call `RefreshTracker`.
- [ ] **Step 4: Command** — `resetpos`: `db.trackerPos = nil; Tracker.ResetPosition()`; print "boss list moved back under the minimap."; add to the help line.
- [ ] **Step 5: Docs** — README feature bullet + `/cleared resetpos` row + settings line; CHANGELOG "Added" entry.
- [ ] **Step 6: Verify** — `luajit tests/run.lua` → `25 passed, 0 failed`; `luajit tools/check_data.lua` → `ok`; `luacheck Cleared tools tests` → 0 warnings.
- [ ] **Step 7: Commit** — `feat: show the boss list in dungeons`.
- [ ] **Step 8: In-game check (user)** — Wailing Caverns: panel appears, ticks on kill, bonus rows, collapse, drag, `/reload` keeps position, `/cleared resetpos`, setting toggle; Scarlet Monastery overview → wing after first kill.
