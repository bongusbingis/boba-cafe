# M4-LEADERBOARDS: Monthly Leaderboards & Statues
Model: sonnet / spark   Studio: no   Depends on: none   Size: M

## Goal
Implement the Monthly Leaderboards system (revival-plan §4.7, DEC-032):
- Manages 5 monthly OrderedDataStores: `MostTips`, `MostBobaBucks`, `OrdersServed` (replaces retired Staff Points per DEC-032), `MostActive`, and `TopDonators`.
- Automated monthly reset by prefixing DataStore keys with `YYYY_MM_` (e.g. `2026_10_OrdersServed`).
- Updates player board scores asynchronously.
- Refreshes in-world `SurfaceGui` leaderboards in `Workspace.OldScriptables.LeaderboardsFolder.Monthly` every 120 seconds.
- Updates the top barista statues in `Workspace.OldScriptables.LeaderboardsFolder.Statues`.

## Read (only these)
- `docs/AI_AGENT_WORKFLOW.md`
- `docs/CONVENTIONS.md`
- `src/shared/Utility/WorldPath.luau`
- `.review/agent-workflow/decisions.md` (DEC-032)
- `src/server/Modules/CurrencyService.luau`
- `src/server/Modules/CustomerService/init.luau`

## Write scope
- `src/shared/Configuration/LeaderboardConfig.luau` (new)
- `src/server/Modules/LeaderboardService.luau` (new)
- `src/server/Tests/LeaderboardService.spec.luau` (new)
- `.review/agent-workflow/tasks/REVIVAL-001/M4-LEADERBOARDS/evidence.md` (new)

## Steps
1. Create `src/shared/Configuration/LeaderboardConfig.luau`:
   - `BOARDS`:
     - `MostTips`: `{ BoardName = "Most Tips", ModelName = "Most Tips", Metric = "BobaBucks" }`
     - `MostBobaBucks`: `{ BoardName = "Most Boba Bucks", ModelName = "Most Boba Bucks", Metric = "BobaBucks" }`
     - `OrdersServed`: `{ BoardName = "Most Orders Served", ModelName = "Most Staff Points", Metric = "Orders" }` (replaces Most Staff Points per DEC-032)
     - `MostActive`: `{ BoardName = "Most Active", ModelName = "Most Active", Metric = "Minutes" }`
     - `TopDonators`: `{ BoardName = "Top Donators", ModelName = "Top Donators", Metric = "Robux" }`
   - `REFRESH_INTERVAL_SECONDS = 120`
   - `TOP_LIMIT = 10`
   - `Pure helper LeaderboardConfig.GetMonthKey(boardType: string, timestamp: number): string`: returns `os.date("%Y_%m_", timestamp) .. boardType`
2. Create `src/server/Modules/LeaderboardService.luau`:
   - Knit service named `"LeaderboardService"`.
   - Methods:
     - `IncrementStat(player: Player, boardType: string, delta: number)`:
       Enqueues or asynchronously updates player's score in the current month's `OrderedDataStore`.
     - `GetTopEntries(boardType: string, limit: number?): { { UserId: number, Name: string, Value: number } }`:
       Queries `OrderedDataStore:GetSortedAsync(false, limit or 10)` and retrieves usernames safely via `Players:GetNameFromUserIdAsync` (cached).
     - `RefreshBoards()`:
       Resolves `Workspace.OldScriptables.LeaderboardsFolder.Monthly` via `WorldPath.find`.
       For each board, queries `GetTopEntries` and updates the labels in `Part.SurfaceGui`.
       If `OrdersServed` board: updates title label from legacy "Most Staff Points" to "Most Orders Served".
     - `RefreshStatues()`:
       Queries `#1` player in `OrdersServed` / `MostTips`, resolves `LeaderboardsFolder.Statues`, and applies the winner's `HumanoidDescription` via `Players:GetHumanoidDescriptionFromUserId`.
   - In `KnitStart`:
     - Resolves `LeaderboardsFolder` with a bounded wait (continued-play rule: disables cleanly if absent).
     - Starts periodic refresh task (every 120s).
3. Create `src/server/Tests/LeaderboardService.spec.luau`:
   - Unit tests covering key generation, month rollover formatting, and score accumulation / ranking.
4. Run WSL gate and verify clean output.

## Done when
- `LeaderboardConfig.luau` maps the 5 approved boards and provides monthly key derivation.
- `LeaderboardService.luau` manages updates and SurfaceGui refreshing.
- `LeaderboardService.spec.luau` passes.
- WSL gate check passes cleanly.

## Checks to run
- `. .review/agent-workflow/tools/wsl/env.sh && gate src/shared/Configuration/LeaderboardConfig.luau src/server/Modules/LeaderboardService.luau src/server/Tests/LeaderboardService.spec.luau`

## STOP-AND-ASK
- none

## Evidence
`tasks/REVIVAL-001/M4-LEADERBOARDS/evidence.md`
