# M4-UI-DAILY-REWARD Evidence

RESULT: PASS

## Files changed
- `src/shared/UI/Components/Dialogs/DailyRewardsDialog.luau` (new)
- `src/client/Modules/DailyRewardController.luau` (new)
- `src/shared/UI/Components/Core/Hud/BottomLeft.luau` (modified)

## Gate check output
```
PASS  src/shared/UI/Components/Dialogs/DailyRewardsDialog.luau  selene new=0 (baseline[empty]=0 now=0)  stylua=ok
PASS  src/client/Modules/DailyRewardController.luau  selene new=0 (baseline[empty]=0 now=0)  stylua=ok
PASS  src/shared/UI/Components/Core/Hud/BottomLeft.luau  selene new=0 (baseline[HEAD]=1 now=1)  stylua=ok
PASS  rojo build -> /mnt/c/Users/jackc/AppData/Local/Temp/boba-gate/gate-build.rbxl
GATE: PASS
```

## Notes on behavior
1. **`DailyRewardsDialog.luau`**:
   - Styled modal wrapped in `Page` spring animation with a darkened click-catcher backdrop (`ZIndex = 50`, `BackgroundTransparency = 0.5`).
   - Title header banner in `Styles.GREEN` with white Fredoka text: "Daily Login Rewards", accompanied by standard `CloseButton` at the top right.
   - Dynamic subtitle displaying current streak count and live claim status or remaining cooldown time.
   - 7-day calendar row displaying Days 1 to 7 based on `DailyRewardConfig.REWARDS`:
     - BobaBucks amounts (50, 75, 100, 125, 150, 200, 300).
     - Day 4 features `Regular Pet Capsule` (`rbxassetid://6073658218`).
     - Day 7 features `Rare Pet Capsule` (`rbxassetid://7621095542`).
     - When `status.IsVIP == true`, displays `"2x VIP"` pill badge on each card and doubles the BobaBucks reward amount.
   - Visual card states:
     - `Claimed`: `"✓ Claimed"` checkmark glyph in `Styles.GREEN` and muted `Styles.GRAY` stroke.
     - `CanClaim`: highlighted `Styles.GOLD` stroke (3.5px thickness), active claim indication, and clickable.
     - `Locked`: upcoming days with `"Locked"` status or live cooldown countdown.
   - Live 1-second interval countdown for cooldown timer when next reward is locked.
   - Primary "Claim" button at the bottom of the dialog invokes `DailyRewardService.Client:ClaimReward()`, plays `"Success"` audio feedback, updates UI state to Claimed immediately, and displays a toast notification (`DialogController:Toast`).

2. **`DailyRewardController.luau`**:
   - Knit client controller registering `"DailyRewardController"`.
   - On `KnitStart`: queries `DailyRewardService.Client:GetRewardStatus()`. When `CanClaim == true`, pops the daily reward dialog automatically on join.
   - Exposes `OpenDailyRewards(initialStatus)` method for manual opening.
   - Guards against opening duplicate dialog instances simultaneously.

3. **`BottomLeft.luau`**:
   - Added a "Daily" HUD button (`LayoutOrder = 3`) styled with `Styles.GOLD_MID` token and BobaBucks icon.
   - Clicking invokes `DailyRewardController:OpenDailyRewards()`.
