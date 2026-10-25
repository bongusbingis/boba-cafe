RESULT: PASS
Files changed:
- src/shared/Configuration/LeaderboardConfig.luau
- src/server/Modules/LeaderboardService.luau
- src/server/Tests/LeaderboardService.spec.luau

Gate check output:
```
PASS  src/shared/Configuration/LeaderboardConfig.luau  selene new=0 (baseline[empty]=0 now=0)  stylua=ok
PASS  src/server/Modules/LeaderboardService.luau  selene new=0 (baseline[empty]=0 now=0)  stylua=ok
PASS  src/server/Tests/LeaderboardService.spec.luau  selene new=0 (baseline[empty]=0 now=0)  stylua=ok
PASS  rojo build -> /mnt/c/Users/jackc/AppData/Local/Temp/boba-gate/gate-build.rbxl
GATE: PASS
```

Notes on behavior:
- `LeaderboardConfig.luau`: Configures the 5 approved monthly boards (`MostTips`, `MostBobaBucks`, `OrdersServed` [replaces legacy Most Staff Points per DEC-032], `MostActive`, `TopDonators`) with `REFRESH_INTERVAL_SECONDS = 120` and `TOP_LIMIT = 10`. Provides pure helper `LeaderboardConfig.GetMonthKey(boardType, timestamp?)` deriving `os.date("%Y_%m_", t) .. boardType` (e.g. `2026_10_OrdersServed`) for automated monthly rollover and reset.
- `LeaderboardService.luau`: Knit service managing the 5 monthly OrderedDataStores asynchronously.
  - `IncrementStat(player, boardType, delta)`: Asynchronously increments the player's monthly score in `UpdateAsync` with `math.max(0, math.floor(current + delta))` clamping.
  - `GetTopEntries(boardType, limit)`: Queries `OrderedDataStore:GetSortedAsync(false, limit or 10)`, maps entries with cached username lookups (`Players:GetNameFromUserIdAsync` and server player lookup).
  - `RefreshBoards()`: Resolves `Workspace.OldScriptables.LeaderboardsFolder.Monthly` via `WorldPath.find`, queries top entries for all 5 boards, renames legacy `"Most Staff Points"` model to `"Most Orders Served"`, updates title label (`TimePeriod`/`Title`) to `"Most Orders Served"`, and updates entries TextLabel with formatted ranking lines (`1. PlayerName - Score`, `i. ---` placeholders).
  - `RefreshStatues()`: Resolves `Workspace.OldScriptables.LeaderboardsFolder.Statues`, queries `#1` winners in `OrdersServed` / `MostTips` (and `TopDonators`), and applies the winner's `HumanoidDescription` via `Players:GetHumanoidDescriptionFromUserId` and updates `DisplayName`.
  - `KnitStart`: Resolves `Workspace.OldScriptables.LeaderboardsFolder` with bounded wait (10s), disables cleanly if absent (continued-play rule), and starts the 120s periodic refresh loop.
- `LeaderboardService.spec.luau`: Unit tests covering:
  - Month key derivation and rollover formatting across month and year boundaries.
  - Score accumulation and descending ranking across multiple players.
  - Limit capping and username caching.
  - Leaderboard text entry and placeholder formatting.
