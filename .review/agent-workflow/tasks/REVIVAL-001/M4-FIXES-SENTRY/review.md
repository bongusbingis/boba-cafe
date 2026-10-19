VERDICT: PASS

# M4-FIXES Sentry review
Scope: uncommitted diff on branch uhweifh (src/ only). Read-only static review; no Studio, Play or TestEZ (DEC-019). No P1 or P2 findings. Four P3 items, two of which need a Jack decision.

## Findings

### P3-1 Promo-code BB and item-sell BB feed MostBobaBucks (Jack decision)
- src/server/Scripts/PromoCodes.server.luau:89 calls `Modify(player, reward.Currency, reward.Amount)` with no reason. src/shared/Inventory/InventoryItem.luau:165 (item sell) also passes no reason. Neither is in `LEADERBOARD_EXCLUDED_REASONS` (src/server/Modules/CurrencyService.luau:16), so both count on the board.
- Scenario: a 250 BB promo code, or selling a pet obtained from a Robux-bought capsule, lifts a player's monthly MostBobaBucks. The packet only required excluding refunds and Robux pack receipts, so this matches the spec. DEC-035 Q4 says "BB earned", which a promo grant arguably is not.
- Fix: give those two callers reasons ("PromoCode", "ItemSell") and add them to the exclusion map, or accept as is. Jack's call.

### P3-2 Refusal notice is spammable
- src/server/Modules/TreasureHuntService.luau:285-288. Each refused trigger sends a DialogService notification with no per-player throttle. The ProximityPrompt hold is 1s, so repeated holds send a toast about once a second to that player only.
- Fix: keep a per-player `_lastCooldownNotice` timestamp and notify at most once per ~5s. Cosmetic.

### P3-3 Failed flush drops the delta
- src/server/Modules/LeaderboardService.luau:122-141 (`_flushPending`) clears `pending` before the write. `_updatePlayerStat` pcalls and only warns on failure, so a DataStore error loses that batch.
- It was equally lossy before (fire-and-forget). It is acceptable for a monthly board, but it contradicts "can't be lost" for a failed write.
- Fix: on a false return, add the delta back into `_pending`, except during BindToClose.

### P3-4 MostBobaBucks floors fractional pay
- src/server/Modules/LeaderboardService.luau:`_updatePlayerStat` floors `current + delta`. Fractional `Modify` amounts (NPC pay multipliers) are summed in a batch first, so loss is under 1 per flush. Cosmetic.

## Checks (all pass unless listed above)
1. Currency: `Modify` is unchanged for every caller. The new feed (CurrencyService.luau:55-60) runs after `SetValue`, inside `pcall`, with a lazy `_getService`. `IncrementStat` is synchronous and only touches memory, so it can't yield or block. It runs only when `type == "BobaBucks" and amount > 0`, so negatives never feed the board. The only exclusion is QuestRerollRefund. CapsuleService refunds use `SetValues` directly, not `Modify`, so they never reach the board.
   Modify callers and reasons:
   - CustomerService:732 "Gameplay"
   - ShiftService:203 "Gameplay"
   - DailyRewardService:165 "DailyReward"
   - QuestService:203 "QuestReward"
   - QuestService:287 "QuestReroll" (negative)
   - QuestService:300 "QuestRerollRefund" (excluded)
   - TreasureHuntService:300 "TreasureChest"
   - RealOrderService:251 (no reason)
   - PromoCodes.server:89 (no reason; see P3-1)
   - InventoryItem:165 (no reason; see P3-1)
   - Spill.luau:159 is Points, not fed.
   Robux BB packs are not wired yet, so there is no receipt caller.
2. Chest cooldown: it is server-only, with no client time and no new remote. `GetDataAsync` is awaited with a 10s timeout and a refusal if the profile isn't loaded. After the await it re-checks `_claimedChests`, checks the cooldown, then writes `LastTreasureChestTime` and sets `_claimedChests` with no yield in between. Two chests triggered at once: the second resumes, sees the new timestamp and is refused. The refused chest stays. The timestamp is written before the grant. No grant path skips the check; `ClaimChest` is the only path. The distance check runs before the yield (negligible).
3. Profile: `LastTreasureChestTime: number` is in the type and defaults to 0, following the DEC-031 pattern. There is no store-name change and no migration. The code also guards a non-number value.
4. Leaderboard batching: `IncrementStat` only adds into `pending`. `_flushPending` swaps out the user's table before spawning one `_updatePlayerStat` per (user, board). A new increment during a flush lands in a fresh table, so nothing double-counts. Flushes run every REFRESH_INTERVAL_SECONDS, on PlayerRemoving, and in BindToClose (25s wait, under Roblox's 30s limit). `pending` is bounded by the flush loop, including late `Modify` callbacks after a player leaves. Hidden boards are rejected in `IncrementStat` and skipped (not queried) in `RefreshBoards`. MostActive adds +1 per minute for the players currently in the server. It uses UpdateAsync, which is correct for read-modify-write on OrderedDataStore. The loops start before the world wait, so they run even if the board folder is missing. If KnitStart were called twice, BindToClose and PlayerRemoving would connect twice, but the swap makes a second flush a no-op.
5. Badges: LEGACY_BADGES is exactly the 5 IDs (2124640229, 2124640231, 2124640232, 2124774046, 2124837610). FirstStaff is still in `Service.Badges`, and the join award at BadgeService:291 is unchanged.
6. Statues: the mapping matches DEC-037 Q13. The name "Most Tips", the name "Most Boba Bucks", a role containing Tip or Boba Bucks, and index fallback 2 all give the MostBobaBucks winner. Donator statues are left alone. Fallback 1 is OrdersServed only. `topWinners` queries only OrdersServed and MostBobaBucks.
7. DailyRewardsDialog: `local promiseOk, claimOk, reason, grantResult` matches the repo convention (DailyRewardController:37 `ok, status = ...:await()`). A refusal toasts: InventoryFull gets its specific message, anything else gets the generic one. The status is not touched, so the claim stays available. The existing `Toast` is used, with no new UI.
8. Economy: DailyReward is 30/45/60/60/90/120/180 with capsules unchanged. Chest values are 20/40 BB with a 0.10 capsule chance. The QuestConfig arrays match DEC-036. Both generators index with `targetIndex`. REROLL_COST is 20. The server uses the config value (QuestService:275/282/287/300). QuestCard uses `QuestConfig.REROLL_COST_BOBABUCKS`. The remaining "50" in QuestCard:45 is preview sample data only. Existing in-profile quests keep their old rewards (expected).
9. No new remotes and no client-trusted input.
10. Specs: they compile logically. The mock store is synchronous, so asserting right after `FlushAll` (which uses `task.spawn`) works. The BadgeService, DailyRewardService, TreasureHuntService and QuestService changes are consistent with the source. The TreasureHuntService spec adds the `Promise` require, and its fakes cover DataService, DialogService and CapsuleService. I found nothing that will obviously fail in TestEZ. It still hasn't been run (DEC-019), and Jack should run it.

## Needs Jack
- P3-1: should promo-code and item-sell BB count toward MostBobaBucks?
- Place content: any statue 2 sign still reading "Most Tips" needs a Studio relabel (already in DEC-037).
