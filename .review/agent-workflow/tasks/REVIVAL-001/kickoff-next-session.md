# REVIVAL-001: Kickoff for Next Session (M4 UI & Pre-Release Hardening)
Written: 2026-10-18 (following Milestone 4 completion & DEC-032)

## Current Repository State
- Branch: `uhweifh` (preserve all uncommitted working tree changes; do not reset, clean, or discard files).
- Milestones M1, M2, M3, and M4 are 100% complete and recorded in `completed.ndjson`.
- Decisions DEC-001 through DEC-032 are on record in `decisions.md`.
- Studio: Connected to "jacks project" (placeId: 89999123284040). Jack does in-game testing (DEC-019).
- WSL gate environment: `. .review/agent-workflow/tools/wsl/env.sh && gate <files>`

---

## Session Objectives (Options A & B)

### Part A: Milestone 4 UI Presentation (Daily Rewards Modal & Daily Quests Card)
1. **Daily Rewards Modal**:
   - Location: `src/shared/UI/Pages/DailyRewards/` or `src/shared/UI/Components/Popups/DailyRewardsDialog.luau` integrated with `AppDialogs.luau`.
   - UI Rules: Follow `docs/STYLE.md` strictly (DEC-013). Use existing tokens, font (`Styles.FONT_FREDOKA`), pane cards, and normal buttons.
   - Behavior:
     - Checks `DailyRewardService.Client:GetRewardStatus()`. If `CanClaim == true`, pops automatically on join.
     - Also accessible via a button in `BottomLeft.luau` or `TopBar.luau` / Menu.
     - Renders 7-day progression cards with reward icons (BobaBucks, Day 4 Regular Capsule, Day 7 Rare Capsule, VIP 2× indicator).
     - "Claim" button calls `DailyRewardService.Client:ClaimReward()`, plays reward feedback, and updates UI state.
2. **Daily Quests HUD / Menu Card**:
   - Location: `src/shared/UI/Components/Core/Hud/QuestCard.luau` or `src/shared/UI/Pages/Quests/`.
   - Behavior:
     - Queries `QuestService.Client:GetQuests()`. Listens to `QuestsUpdated` client signal.
     - Displays the 3–4 daily quest cards with progress bars (`Progress / Target`), task description, and rewards (BobaBucks + XP).
     - "Claim" button calls `QuestService.Client:ClaimQuest(index)`.
     - Reroll button (with free or 50 BB tag) calls `QuestService.Client:RerollQuest(index)`.

### Part B: Sentry Remote Security Audit & Legacy Scripts Audit
1. **Sentry Remote Exploit & Authority Audit**:
   - Review every client-exposed Knit remote function and event across:
     - `QuestService.luau`
     - `DailyRewardService.luau`
     - `TreasureHuntService.luau`
     - `EventService.luau`
     - `ShiftService.luau`
     - `OrderService.luau`
     - `CurrencyService.luau`
     - `CapsuleService.luau`
     - `RealOrderService.luau`
   - Verify rate limiting, distance validation, parameter type checking, and server authority (zero trust of client arguments).
   - Document any vulnerabilities or hardening in `.review/agent-workflow/tasks/REVIVAL-001/R2-SECURITY/review.md`.
2. **Legacy Scripts Audit (`Workspace.OldScriptables`)**:
   - Inspect the 17 legacy scripts in `Workspace.OldScriptables` (Elevator, Zipline, Fruits Freezer `StockRandom`, IslandTeleporter, ad boards).
   - Verify none conflict with the revival loop or trigger deprecated gamepasses/products.
   - Document recommendations in `.review/agent-workflow/tasks/REVIVAL-001/LEGACY-AUDIT/audit.md`.

---

## Workflow Rules & Guidelines
- Run WSL gates on all edited files: `. .review/agent-workflow/tools/wsl/env.sh && gate <files>`
- No new Selene findings, StyLua formatted, Rojo build passed.
- Maintain board and ledger: update `board.json` and append to `completed.ndjson`.
