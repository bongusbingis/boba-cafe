# GAMEPLAY-PROGRESS-CALLOUTS: level-ups say what opened; the shift card shows tips, XP to the next level and the next unlock
Model: sonnet (Mason, Studio: no)   Depends on: GAMEPLAY-REVIEW P1-P3, H1 (OBVIOUS); run AFTER UI-TICKET-DAILY-MENU Part A (it may move `ShiftCard`); best after GAMEPLAY-TOASTS (so level-up toasts are not overwritten)   Size: S

## Goal
- **Level-up toast names the unlocks at that level**, read from shared config (never hand-typed): a new title (`Progression.TITLES[level]`), more ticket slots (`Progression.TICKET_SLOTS[level]`), more items per order (`CustomerConfig.ITEM_COUNT_BY_LEVEL[level]`), a customer variant whose `CustomerConfig.VARIANTS[name].MinLevel == level` ("VIP customers", "Karen customers"), and the nametag already named today (`Progression.COSMETIC_REWARDS`).
- **Shift card**: rows merged so the card never overflows (max 6 rows), Tips shown (it is computed but never rendered), walkouts shown, "Level N · x/y XP" and "Next: Level M · <unlock>".
- **Break areas**: a toast when the player's level crosses `AreaController.OPEN_LEVEL` (3) during play, not on join.
- Existing components only (toast, ShiftCard rows). No new visual.

## Verified facts
- `ProgressionService:_onLevelUp(player, level, proxy)` builds `Level up! You are now level {level}` plus ` · New nametag: {Name}` and sends `Notify(player, { Text = text, SoundEnabled = true })` (`ProgressionService.luau:96-116`). It runs inside `AddXp`'s `andThen` (async; not on any serve path).
- The `ShiftEnding` listener (`:142-168`) predicts `LevelAfter` with a local `xp` remainder loop (`:153-162`); at the end of that loop `xp` is the XP into level `after`. Summary fields may be added by listeners (`ShiftService.luau:73-75,179-195`).
- `ShiftCard.buildLines` (`ShiftCard.luau:34-51`): stars, "Customers served", "Pay: X  Bonus: Y", "Best combo: x N", "XP: +N", optional "Level up! Level N", optional "Next shift starts now". Rows are `Size (0.95, 0.12)` with padding 0.02 in a container 0.72 tall, so 6 rows fit and 7 overflow. `summary.Tips` and `summary.Walkouts` exist and are not rendered.
- `Progression.XpToNext(level)` is shared. `CustomerConfig` is shared (`src/shared/Configuration`).
- `AreaController.luau` applies or destroys the local gates on every `Level` attribute change (`:32-55,65-70`). The attribute is nil until the profile loads, so the first refresh after join must not toast.

## Write scope
- `src/server/Modules/ProgressionService.luau` (level-up text; summary fields `XpIntoLevel`, `XpForLevel`, `NextUnlock`)
- `src/shared/UI/Components/Core/Hud/ShiftCard.luau` (`buildLines` only; no layout, Position or Size change)
- `src/client/Modules/AreaController.luau` (one toast)
- `docs/SYSTEMS.md` M2 table row for ShiftService/ProgressionService: note the new summary fields (one line)
Not touched: `Progression.luau`, `CustomerConfig.luau` or any config value, `ShiftService.luau`, `CustomerService`, `RealOrderService`, `Styles.luau`.

## Steps
1. In `ProgressionService`, add a local `unlocksAt(level): { string }` that returns, in this order and only when present: `New title: {TITLES[level]}` (only if level > 1), `{TICKET_SLOTS[level]} order tickets`, `Orders with {ITEM_COUNT_BY_LEVEL[level]} items`, `VIP customers` / `Karen customers` for variants whose `MinLevel == level`, `New nametag: {COSMETIC_REWARDS[level].Name}`. Require `CustomerConfig` from `Shared.Configuration`.
2. `_onLevelUp`: text = `Level up! You are now level {level}` plus ` · ` and the first two `unlocksAt(level)` entries joined with ` · `. Keep the nametag grant code unchanged. Keep `SoundEnabled = true` (it is unused today).
3. A local `nextUnlock(level): string?` that scans `level + 1 .. Progression.MAX_LEVEL` and returns `Level {n} · {first entry of unlocksAt(n)}` for the first non-empty one.
4. In the `ShiftEnding` listener, after the prediction loop: `summary.XpIntoLevel = xp`, `summary.XpForLevel = Progression.XpToNext(after)` (omit both when `after >= MAX_LEVEL`), and `summary.NextUnlock = nextUnlock(after)`. If `state == nil` leave them nil. All inside the existing pcall.
5. `ShiftCard.buildLines` returns at most 6 rows:
   1. stars (unchanged)
   2. `Served {Served}` plus ` · Walkouts {Walkouts}` when Walkouts > 0
   3. `Pay {Pay} · Bonus {Bonus}` plus ` · Tips {Tips}` when Tips > 0
   4. `Best combo x {BestCombo}` only when BestCombo >= 2
   5. `XP +{Xp}` plus ` · Level {LevelAfter} ({XpIntoLevel}/{XpForLevel})` when present; when `LevelAfter > LevelBefore` use `Level up! Level {LevelAfter} ({XpIntoLevel}/{XpForLevel})` instead
   6. `Next: {NextUnlock}` when present, else `Next shift starts now` when `First`
   Every field is nil-safe (the card must render with an older summary shape).
6. `AreaController`: track `lastLevel` (number or nil). In `refresh`, when `lastLevel` is a number below `OPEN_LEVEL` and the new level is >= `OPEN_LEVEL`, call `Knit.GetController("DialogController"):Toast("Break areas are open!")` inside a pcall. Then set `lastLevel`. The join path (nil to n) never toasts.
7. Gate and `rojo build`.

## Hard constraints
- Agents never run Play or TestEZ (DEC-019; Jack does). No Studio, no commits.
- Serve-path invariant: nothing may yield between the serve guards and the payout in `CustomerService:_onServeTriggered` or the `RealOrderService` payout. This lane touches neither; `ProgressionService` code runs in `AddXp`'s async callback and the `ShiftEnding` listener, both off the serve path. Add no yield to the `ShiftEnding` listener (it must stay synchronous: the summary is sent right after it).
- Studio-authored content (`workspace.Assets`, `Ordering System`, `ReplicatedStorage.SelectorModels`, `ReplicatedStorage.Networking`, `SoundService.SFX`) is not in the Rojo tree and is not edited. No sounds added.
- DEC-013: existing ShiftCard rows and toast only; no new row style, colour, font or element.
- Economy untouched: every number comes from config or the summary; never hand-type an amount or level.
- Gate on every changed Luau file (stylua only if no DEC-001 drift; otherwise gate alone with no new findings): `wsl bash -lc 'cd /mnt/c/Users/jackc/desktop/boba-cafe && . .review/agent-workflow/tools/wsl/env.sh && stylua <files> && gate <files>'`, plus `rojo build default.project.json -o <path outside the repo>`.

## Done when
- In evidence, list the level-up text for levels 2, 3, 5, 6, 10 and 15 as computed from the current config, and the next-unlock line for levels 1 to 6.
- The ShiftCard renders at most 6 rows for every combination (first shift, walkouts, tips, level-up).
- Gate shows no new findings; `rojo build` succeeds; SYSTEMS line updated.
- Evidence in `tasks/REVIVAL-001/GAMEPLAY-PROGRESS-CALLOUTS/evidence.md`.

## STOP-AND-ASK
- If any unlock string would need a value that is not in shared config (for example the break-area level, which lives only in a client module): leave it out and report; do not duplicate the number on the server.
- If UI-TICKET-DAILY-MENU changed `ShiftCard` row geometry: re-check the 6-row fit and report.

## Test for Jack (Play, his Studio)
- Reach level 5: the toast reads like "Level up! You are now level 5 · New title: Barista · 2 order tickets".
- End a shift with a tip pass or pet: the card shows "Tips N". With a walkout: "Walkouts 1". The card shows "Level N (x/y)" and "Next: Level M · ...".
- Cross level 3 during play: "Break areas are open!". Rejoin at level 3+: no such toast.
