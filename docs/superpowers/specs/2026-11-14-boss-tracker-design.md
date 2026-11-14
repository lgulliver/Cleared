# Boss tracker frame — design

Short design (small change), approved 2026-11-14.

## Intent

Retail shows a running list of a dungeon's bosses while you're inside. Cleared! already tracks
every kill but only shows it in passing (toasts) or on demand (`/cleared status`). A small
always-on panel lets you see at a glance what's dead and what's left.

## Approaches

- **Its own frame (chosen).** A small panel near the minimap, styled to look native. Self-contained,
  can't break when Blizzard changes the quest tracker. Picked by the user.
- **Inside Blizzard's objective tracker.** Most retail-like, but depends on Blizzard code that may not
  exist or may change on Forever, and risks taint. Rejected.
- **Chat or tooltip only.** Not always on screen, which is the point. Rejected.

## Design

What you see:

```
Wailing Caverns          3/6
 ✓ Lady Anacondra
 ✓ Lord Cobrahn
 ✓ Lord Pythas
 · Lord Serpentis
 · Verdan the Everliving
 · Mutanus the Devourer
 Bonus
 · Kresh
 ✓ Skum
```

- Shown only inside a supported dungeon; hidden elsewhere.
- Header: dungeon or wing name plus `done/total`. Turns green when that unit is complete; the panel
  stays up.
- One row per counted boss, in encounter order. Dead: ready-check tick, white text. Alive: grey dot,
  grey text.
- Optional bosses are listed (user's call) under a small "Bonus" sub-heading, same tick/dot style.
  They never count towards the header total.
- Winged maps: before any counted kill on the map, the panel shows the map name and one line per
  wing with its count (`Library 0/2`). After a counted kill it shows the wing of the most recent
  counted kill, expanded.
- Clicking the header collapses the panel to the header line; click again to expand. Collapsed
  state is saved.
- Drag the header to move. Position saved per character. `/cleared resetpos` restores the default
  spot under the minimap.
- Settings checkbox "Boss list", on by default. Turning it off hides the panel immediately.
- Updates on every kill, zone change, restart detection and `/cleared reset`.
- Plain (non-secure) frame, so it updates and hides fine in combat.

## Builder's calls

- On winged maps the Bonus list holds every optional boss on the map, not only the current wing's:
  optional bosses aren't assigned to wings, and assigning them is data work for little gain.
- The pure "what to show" logic lives in `Progress.TrackerView(run)` and is unit-tested; `Tracker.lua`
  only draws it.
- Wing lines in the overview drop the map prefix (`Scarlet Monastery: Library` → `Library`).
