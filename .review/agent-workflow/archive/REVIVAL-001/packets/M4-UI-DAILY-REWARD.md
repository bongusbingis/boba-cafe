# M4-UI-DAILY-REWARD: Daily Rewards 7-Day Calendar Modal
Model: sonnet / spark   Studio: no   Depends on: M4-DAILY-STREAK   Size: M

## Goal
Implement the Daily Rewards 7-day calendar modal dialog and client controller (revival-plan §4.7, DEC-013, DEC-032):
- Follows `docs/STYLE.md` exactly: tokens (`Styles.GREEN`, `Styles.OFFWHITE`, `Styles.GOLD`, `Styles.ROSE`), font (`Styles.FONT_FREDOKA`), and Pane cards.
- On join, `DailyRewardController` checks `DailyRewardService.Client:GetRewardStatus()`. If `CanClaim == true`, pops the Daily Rewards modal automatically.
- Accessible at any time via a dedicated button in `BottomLeft.luau` or `TopBar.luau` / Menu.
- Renders 7 day cards showing Day 1-7 BobaBucks (50, 75, 100, 125, 150, 200, 300), Day 4 Regular Pet Capsule, Day 7 Rare Pet Capsule, VIP 2× bonus indicator, and claimed/available/locked status.
- "Claim" button invokes `DailyRewardService.Client:ClaimReward()`, plays UI audio feedback (`Success`), and updates UI state to claimed.

## Read (only these)
- `docs/AI_AGENT_WORKFLOW.md`
- `docs/STYLE.md` (sections 0, 1, 2, 3: tokens, fonts, pane cards, buttons)
- `src/shared/Configuration/DailyRewardConfig.luau`
- `src/server/Modules/DailyRewardService.luau` (client methods: GetRewardStatus, ClaimReward)
- `src/client/Modules/AppDialogs.luau`
- `src/shared/UI/Components/Core/Hud/BottomLeft.luau`

## Write scope
- `src/shared/UI/Components/Dialogs/DailyRewardsDialog.luau` (new)
- `src/client/Modules/DailyRewardController.luau` (new)
- `src/shared/UI/Components/Core/Hud/BottomLeft.luau` (mount Daily Rewards button)
- `.review/agent-workflow/tasks/REVIVAL-001/M4-UI-DAILY-REWARD/evidence.md` (new)

## Steps
1. Create `src/shared/UI/Components/Dialogs/DailyRewardsDialog.luau`:
   - React component wrapped in `OpenableMenu` or styled `Pane` modal with dark backdrop.
   - Header with `Styles.GREEN` banner and `Styles.OFFWHITE` Fredoka text: "Daily Login Rewards".
   - Subtitle indicating current streak and status.
   - Grid or horizontal list of 7 Day Cards (using `DailyRewardConfig.REWARDS`):
     - Each card displays Day number ("Day 1" .. "Day 7").
     - Reward amount: BobaBucks icon/text (with "2x VIP" tag if VIP).
     - Capsule icon/text on Day 4 and Day 7.
     - Visual states:
       - `Claimed`: checkmark glyph, dimmed/muted stroke.
       - `CanClaim`: highlighted with `Styles.GOLD` stroke and active "Claim" button.
       - `Locked`: upcoming days with countdown or locked indicator.
   - "Claim" button: calls `DailyRewardService.Client:ClaimReward()`, updates state, plays sound, closes or displays reward toast.
   - Close button (`CloseButton`) to dismiss.
2. Create `src/client/Modules/DailyRewardController.luau`:
   - Knit controller named `"DailyRewardController"`.
   - In `KnitStart`:
     - Queries `DailyRewardService.Client:GetRewardStatus()`.
     - If `CanClaim == true`, mounts or opens `DailyRewardsDialog`.
     - Exposes `OpenDailyRewards()` method for manual opening.
3. Update `src/shared/UI/Components/Core/Hud/BottomLeft.luau`:
   - Add a "Daily" button in `BottomLeft.luau` (or connect through existing HUD button set) that invokes `DailyRewardController:OpenDailyRewards()`.
4. Run WSL gate check on all modified/new files.

## Done when
- `DailyRewardsDialog.luau` renders all 7 reward days according to `docs/STYLE.md`.
- `DailyRewardController.luau` handles on-join checking and modal opening.
- Claim action successfully invokes `DailyRewardService` and grants rewards.
- WSL gate check passes cleanly.

## Checks to run
- `. .review/agent-workflow/tools/wsl/env.sh && gate src/shared/UI/Components/Dialogs/DailyRewardsDialog.luau src/client/Modules/DailyRewardController.luau src/shared/UI/Components/Core/Hud/BottomLeft.luau`

## STOP-AND-ASK
- none

## Evidence
`tasks/REVIVAL-001/M4-UI-DAILY-REWARD/evidence.md`
