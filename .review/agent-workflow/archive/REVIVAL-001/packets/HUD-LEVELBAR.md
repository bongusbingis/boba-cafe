---
id: HUD-LEVELBAR
title: HUD level pill and XP bar above the Shift pill
priority: P1
role: Mason
worker_tier: sonnet
release_gate: before
depends_on: [HUD-BOTTOMLEFT]
status: READY
source_commit: 098175c
read_scope:
  - src/shared/UI/Components/Core/Hud/CafeRating.luau (Track, Fill, Banner primitives to copy)
  - src/shared/UI/Components/Core/Hud/BottomLeft.luau (CurrencyPanel children, ShiftTimer, Notification)
  - src/shared/UI/Components/Buttons/Banner.luau
  - src/shared/Configuration/Progression.luau (XpToNext, MAX_LEVEL)
  - src/shared/UI/Styles.luau, docs/STYLE.md (1.1, 1.2, 2.4, 4.3, 5)
write_scope:
  - src/shared/UI/Components/Core/Hud/LevelBar.luau (new)
  - src/shared/UI/Components/Core/Hud/BottomLeft.luau (one require, one child inside CurrencyPanel)
invariants:
  - DEC-013 / STYLE rule 0: only Styles tokens, Banner, Pane and CafeRating's Track/Fill geometry; no new color, font, radius, spring or asset
  - client display only; reads the replicated profile, writes nothing, no new remote or profile field
  - HUD element rules of STYLE 4.3 (RunService:IsRunning guard, snapshot then listen, disconnect in cleanup)
  - HUD-LEVELBAR owns LevelBar.luau until SOUNDS (SOUNDS adds LevelUp, falling back to Success, on a Level rise; the flash and the LevelUp cue fire together, FEEDBACK-VOICE 4)
acceptance:
  - a pill reading "Lv N" with an XP bar sits directly above the "Shift k/N" pill (or above Clock In/Out when the Shift pill is absent) in the bottom-left column, below the toast
  - the bar fill springs to XP / XpToNext(Level) with SPRING_STANDARD whenever XP or Level replicates
  - at MAX_LEVEL the bar is full and reads "MAX"
  - `LevelBar.Flash()` exists and, when called, flashes the Lv pill brighter gold for 0.8 s
checks:
  - wsl bash -lc 'cd /mnt/c/Users/jackc/desktop/boba-cafe && . .review/agent-workflow/tools/wsl/env.sh && gate src/shared/UI/Components/Core/Hud/LevelBar.luau src/shared/UI/Components/Core/Hud/BottomLeft.luau' (stylua the new file; BottomLeft only if stylua --check passes at HEAD)
  - rojo build default.project.json -o <path outside the repo>
evidence_dir: .review/agent-workflow/tasks/REVIVAL-001/HUD-LEVELBAR
forbidden: [see WORKER-PRIMER 8, any Progression.luau or ProgressionService edit, any new sound, editing Hud/init.luau]
---

Read [WORKER-PRIMER](_meta/WORKER-PRIMER.md) first. Anchor edits by symbol, not line.

## 1. Source excerpt
- P4: HUD level pill + XP bar above the Shift pill (CafeRating Track/Fill/Banner primitives), filled from the replicated profile XP/Level with SPRING_STANDARD. Why: the strongest constant pull; every serve visibly moves it. Files: new Hud/LevelBar.luau, BottomLeft.luau. Effort M, Risk Low. Tag JACK (new HUD element, Q-G4, approved: pill and bar above the Shift pill from CafeRating primitives).

## 2. Decisions made
- D1: Mount inside `BottomLeft`'s `CurrencyPanel` children (the vertical stack that holds `Notification`, `ShiftTimer`, `Shift`, `Recipes`, `Bucks`) as `LevelBar = c(LevelBar, { LayoutOrder = -1 })`, placed right after the `Notification` child. `Hud/init.luau` is NOT edited. Why: LayoutOrder -1 sits between the toast (-6) and the Shift pill (0), so the bar is above the Shift pill by construction at any stack height; a separate absolute mount in `Hud/init.luau` would overlap whenever the hatch button or admin rows change the stack.
- D2: Data: profile fields `Level` (number) and `XP` (XP gained inside the current level, resets on level-up; `ProgressionService` writes both with `SetValue`). Snapshot from `Knit.GetController("DataController"):GetDataAsync()` then `playerData:ListenToChange({ "XP" }, ...)` and `({ "Level" }, ...)`, same pattern as `BottomLeft`. Defaults before data arrives: Level 1, XP 0.
- D3: Fraction = `XP / Progression.XpToNext(Level)` clamped to [0,1]; XP curve is 60 + 25L + 2L^2 (read from `Progression.XpToNext`, never re-implemented). At `Level >= Progression.MAX_LEVEL` the fraction is 1 and the label is `MAX`.
- D4: Fill animates with `ReactSpring.useSpring({ alpha = fraction, config = Styles.SPRING_STANDARD })` and `Size = styles.alpha:map(function(a) return UDim2.fromScale(a, 1) end)`. On a level-up the XP value wraps down, so the fill springs back to the new small fraction; no extra fill-up animation. Why: matches the other HUD springs, no new motion.
- D5: Look is CafeRating's: same outer `Pane` (AspectRatio 5, no `UISizeConstraint`, see D6), `Track` frame (OFFWHITE, bottom, size (0.9,0.38), `UICorner` 0.5), `Fill` frame (`Styles.GOLD`, `UICorner` 0.5; gold is reserved for rank, FEEDBACK-VOICE 5), centered label in the track (Fredoka, GREEN_DEEP, TextScaled), and a `Banner` for the level pill on top at Position (0.5,0.3), Size (0.7,0.55). Banner Color is `Styles.GOLD_MID` (distinct from the green Cafe Rating banner). Why: replicate the existing meter; gold reads as "level".
- D6: Size in the stack: `Size = UDim2.fromScale(1, 1)` with `AspectRatio = 5` and no `UISizeConstraint`, exactly like `NormalButton`'s wrapper (width of the column, height follows the ratio). Why: the column width is 0.6 x 0.3 of the screen, a pixel min/max would break the stack.
- D7: Shown always (clocked in or out); XP progress is relevant to both. Not interactive (`Active = false` on the outer Pane, Track, Fill and label, no click), so touches on it reach the mobile thumbstick underneath.
- D8: Flash: module-level BindableEvent `flashEvent`; `LevelBar.Flash()` fires it; the component connects in its effect (disconnect in cleanup) and sets `flashing = true` for 0.8 s via `task.delay`. While flashing: the Banner Color switches from `Styles.GOLD_MID` to `Styles.GOLD` and the outer `Pane` `Scale` springs to 1.08 with `Styles.SPRING_STANDARD`, then back to 1. No sound in this packet (SOUNDS adds `SFX.UI.Success`/LevelUp inside the same hook, DEC-054). Nobody calls `Flash()` yet; the call from the level-up toast path belongs to SOUNDS.
- D9: The module returns a table `{ Component = LevelBarComponent, Flash = Flash }` (the `SmallNotification.Component` / `SmallNotification.Push` pattern already used in this folder). BottomLeft mounts `LevelBar.Component`.

## 3. Exact strings
- Pill text: `` `Lv {level}` `` (for example `Lv 7`).
- Bar label: `` `{math.floor(xp)}/{math.floor(need)}` `` (for example `32/150`); at max level `MAX`.
- Tokens: Banner `Styles.GOLD_MID`; track `Styles.OFFWHITE`; fill `Styles.GOLD` (flash: Banner `Styles.GOLD`); label `Styles.GREEN_DEEP`; font `Styles.FONT_FREDOKA`.

## 4. Exact numbers
- `FLASH_SECONDS = 0.8`, `FLASH_SCALE = 1.08`, `LAYOUT_ORDER = -1`.
- Geometry as in D5 (AspectRatio 5; Track (0.9,0.38); Banner (0.7,0.55) at (0.5,0.3); label (0.5,0.8) in the track).
- Spring: `Styles.SPRING_STANDARD` {mass 1, tension 10000, friction 150}.

## 5. Signatures and names
- `LevelBar.Component` : React function component, props `{ LayoutOrder: number? }` (applied to the outer Pane's `Native.LayoutOrder`).
- `LevelBar.Flash(): ()` fires the module BindableEvent; safe to call before mount (no-op) and from any client script.
- BottomLeft: `local LevelBar = require(script.Parent.LevelBar)`; child `LevelBar = c(LevelBar.Component, { LayoutOrder = -1 })` (add the require in the `---> components` block).
- No remote, no attribute, no profile field.

## 6. UI spec (STYLE 4.3 checklist)
- Anchor and size: child of `BottomLeft` stack (anchor (0,1), pos (10 px, 0.985), width 0.3 of screen; CurrencyPanel width 0.6 of that). Pill is full column width, height = width / 5.
- States: default (Level, XP known); loading (Level 1, XP 0, fill 0); max level ("MAX", fill 1); flash (Banner GOLD, scale 1.08 for 0.8 s).
- HUD zone check against STYLE 2.4: inside the existing bottom-left stack, no new zone, no overlap with Bottom right, ticket column (upper right), queue (bottom centre) or top bar; sits under the toast (LayoutOrder -6).
- 844x390 phone (style review, computed from source at 098175c): CurrencyPanel is 0.6 x 0.3 x 844 = 152 px wide and 60 px tall, bottom-aligned, list `Padding UDim.new(0.2, 0)` = 12 px (not the outer stack's 4 px). NormalButton pills are 152/7 = 22 px tall. The pill is 152 x 30 px; the stack grows 42 px (30 + one 12 px gap). With HUD-BOTTOMLEFT (Points removed), clocked in: Bucks/Recipe/Clock Out/Shift pills occupy y 250-384, LevelBar y 219-249, a shown toast (135 px) y 72-207, below the Roblox top bar (about 58 px) and left of the TopBar (x >= 227): no overlap. Clocked out the bar sits at y 241-271. The whole bottom-left stack already lies in the thumbstick zone (x < 253, bottom 45 %, per UI-TICKET-DAILY-MENU evidence); the bar must stay `Active = false` on every frame so touches pass through to the thumbstick (D7). Legibility: track 0.38 x 30 = 11.6 px, label 0.8 of that = about 9 px text, smaller than CafeRating (whose 38 px min height gives about 11.5 px) and the 13 px NormalButton text; see Open items. Do not add a `UISizeConstraint` (a 190 px min would overflow the 152 px column off-screen at x < 0).

## 7. Studio checks (Prime batches for Jack)
- S1: Join: pill shows `Lv 1`, empty bar, label `0/87` (XpToNext(1) = 60+25+2 = 87).
- S2: Phone emulator 844x390: pill is above the Shift pill, left edge not under the thumbstick dead zone, text readable; toast still appears above the pill.
- S3: Serve one customer: fill springs forward by the earned XP (10 per item + 5 Perfect + 5 Fast); label updates.
- S4: Cross a level: pill reads the new `Lv`, fill drops to the leftover XP fraction. Run `require(...LevelBar).Flash()` from the command bar (client): gold flash, 0.8 s.
- S5: Clock out and in: pill stays visible and unchanged.

## 8. Asset prerequisites
None (Banner images and Track/Fill are existing). SOUNDS adds `SoundService.SFX.UI.Success` lookups later.

## 9. Open items
- PENDING JACK (style review, not blocking the build): at 844x390 the `32/150` XP label renders about 9 px tall, below every other HUD text. If S2 shows it unreadable, choose: (a) keep it; (b) drop the numeric label on the bar (fill + `Lv N` pill only, `MAX` moves into the pill text); (c) give the bar AspectRatio 4 instead of 5 (about 38 px tall, label about 11.5 px, same as CafeRating; stack grows 8 px more). Worker builds as specified (AspectRatio 5, label shown) until answered; no other geometry.

## Summary
- New `Hud/LevelBar.luau`: gold `Lv N` Banner over a CafeRating-style Track and gold Fill, fill = XP / XpToNext(Level) via SPRING_STANDARD.
- Mounted in BottomLeft's CurrencyPanel at LayoutOrder -1 (above the Shift pill, below the toast); Hud/init.luau untouched on purpose.
- Reads profile `Level` and `XP` through DataController ListenToChange; MAX shown at level 50.
- `LevelBar.Flash()` exported (Banner to GOLD, scale 1.08, 0.8 s); no sound, SOUNDS packet calls it.
- Phone 844x390: about 152 x 30 px; thumbstick overlap check is a Studio check.
- No new tokens, assets, remotes or profile fields.
