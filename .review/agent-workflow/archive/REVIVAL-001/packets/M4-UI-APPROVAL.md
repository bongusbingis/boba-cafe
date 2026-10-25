# M4-UI-APPROVAL: Edit-mode screenshots of the three M4 UI pieces for Jack's approval
Model: sonnet (Lens)   Studio: YES (exclusive)   Depends on: M4-FIXES   Size: S

## Goal
- Jack approves (DEC-013, DEC-035 Q6=A) the daily rewards dialog, the quest card and the Daily button from screenshots.
- Produce one screenshot per state below, showing DEC-036/037 amounts, with no lasting change to the place.

## Read (only these)
- `docs/STYLE.md` (tokens only) and `default.project.json` lines 1-12 (`src/shared` -> `ReplicatedStorage.Shared`; Packages -> `ReplicatedStorage.Packages`).
- `src/shared/UI/Components/Dialogs/DailyRewardsDialog.luau` (props `Status`, `OnClose`; status shape lines 93-105), `src/client/Modules/DailyRewardController.luau`.
- `src/shared/UI/Components/Core/Hud/QuestCard.luau` (props `Quests`, `Preview`), `src/shared/UI/Components/Core/Hud/BottomLeft.luau` lines 59-75 and 364-382.
- `src/shared/Configuration/DailyRewardConfig.luau`, `src/shared/Configuration/QuestConfig.luau`.
- `.review/agent-workflow/tasks/REVIVAL-001/M4-UI-DAILY-REWARD/evidence.md`, `M4-UI-QUESTS/evidence.md`.

## Write scope
- `.review/agent-workflow/tasks/REVIVAL-001/M4-UI-APPROVAL/` (screenshots, evidence.md) only.
- Studio: a temporary `StarterGui._LensPreview` ScreenGui, destroyed before you finish. No repo or script edits.

## Hard constraints
- Studio target: instance "jacks project" (placeId 89999123284040). Studio is exclusive; no one else may use it meanwhile.
- Edit mode only. Never start Play, never run TestEZ (DEC-019). If `get_studio_state` shows Play, STOP and report it.
- Rojo serve is not running, so Studio copies may be stale. Do not sync, edit or save the place.

## Steps
1. **Staleness check.** With `script_read` (or hash via `execute_luau`) compare Studio source with the repo for `DailyRewardsDialog`, `QuestCard`, `BottomLeft`, `DailyRewardConfig`, `QuestConfig` (under `ReplicatedStorage.Shared...`). Any difference: STOP, report BLOCKED with the differences.
2. **Mount helper** (`execute_luau`, edit mode). Require `ReplicatedStorage.Packages.React` and `ReactRoblox`, and components via `ReplicatedStorage.Shared.UI.Components.Dialogs.DailyRewardsDialog`, `...Core.Hud.QuestCard`, `...Core.Hud.BottomLeft`, configs via `ReplicatedStorage.Shared.Configuration.*`. Create `StarterGui._LensPreview` (ScreenGui, IgnoreGuiInset true), `ReactRoblox.createRoot(gui)`, `root:render(React.createElement(...))`, wait ~1s, `screen_capture`, then `root:unmount()` and `gui:Destroy()`. One state per run. `Knit.GetService/GetController` calls are pcall-wrapped or gated on `RunService:IsRunning()` in these files; if a module still errors for lack of Knit, report it, don't stub Knit globally.
3. **Dialog** (`Status` built from `DailyRewardConfig.REWARDS[n]`, never hand-typed amounts; fields as in the dialog's fallback status):
   - (a) Day 3 CanClaim, VIP off: `CanClaim=true, DayToClaim=3, CurrentStreak=2, SecondsUntilNextClaim=0, Expired=false, IsVIP=false, DataLoaded=true`.
   - (b) same with `IsVIP=true` (2x pill, doubled amounts).
   - (c) Claimed: `CanClaim=false, DayToClaim=4, CurrentStreak=3, SecondsUntilNextClaim=43200, IsVIP=false`.
   - Confirm day 1-7 BobaBucks read 30/45/60/60/90/120/180 (x2 for VIP) and the capsule days still show.
4. **Quest card:** `Quests` = 3 entries built from `QuestConfig` (template `Targets`/`BobaBucks`/`XP` at one index, `QuestConfig.GetQuestTitle`): one mid-progress (e.g. 1 of target), one Completed unclaimed (Claim button), one Claimed. Capture expanded; also collapsed if feasible. Reroll button must read `QuestConfig.REROLL_COST_BOBABUCKS` (20 BB), not 50.
5. **Daily button:** mount `BottomLeft` with `CurrentPage=nil`, `SetCurrentPage=function() end`. It has no claim-available indicator in code; capture once, crop/describe the Daily button, and state "no indicator exists".
6. **Cleanup check:** after each run confirm `StarterGui:FindFirstChild("_LensPreview") == nil` and that nothing else changed (child counts of StarterGui and ReplicatedStorage before/after). Do not save.

## Done when
- Screenshots (a)-(c), quest card, Daily button captured and listed; amounts match DEC-036/037.
- Staleness result and cleanup check recorded.
- Every visual element not from `docs/STYLE.md` tokens is listed (or "none").

## STOP-AND-ASK
- Studio in Play mode, stale modules, a component that cannot mount without Knit, or any need to edit a script or save: stop and report BLOCKED.

## Evidence
`.review/agent-workflow/tasks/REVIVAL-001/M4-UI-APPROVAL/evidence.md`. Save screenshots there as files if the tool allows (`screen_capture` output path); otherwise describe each capture precisely (layout, text, colors, amounts).
