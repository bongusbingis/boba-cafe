# M4-FIXES-P3: Sentry P3 follow-ups (leaderboard reasons, chest notice, flush re-queue, tip remainder, Team Combo farming)
Model: sonnet   Studio: no   Depends on: M4-FIXES, M3-REM-B, M3-REM-C (all built)   Size: M

## Goal
Close five small Sentry P3 findings without changing any economy value: promo-code and item-sell BB stop counting toward MostBobaBucks (Q14=A), the chest cooldown toast stops spamming, a failed leaderboard write is retried a bounded number of times, a departed barista no longer re-creates a `_tipRemainder` entry, and farm-throttled real-order serves no longer advance Team Combo.

## Hard constraints
- Never run Play or TestEZ (DEC-019); Jack does that.
- Gate: `wsl bash -lc 'cd /mnt/c/Users/jackc/desktop/boba-cafe && . .review/agent-workflow/tools/wsl/env.sh && stylua <files> && gate <files>'` on every changed Luau file. No new Selene/StyLua findings in changed files (DEC-001).
- No economy value changes (prices, amounts, probabilities) beyond what the decisions listed say (DEC-038 Q14=A only). Anything else is STOP-AND-ASK.

## Serve-path invariant (M3-REM-B)
Nothing may yield between the serve guards and the payout in `CustomerService:_onServeTriggered` or in the RealOrderService payout. No new yielding calls (WaitForChild, task.wait, DataStore/MessagingService, remote InvokeClient, Promise:await, :Wait()) in those spans.

## Money code
A Sentry review follows the build (`tasks/REVIVAL-001/M4-FIXES-P3-SENTRY/`).

## Already built (verified)
- Exclusion list lives in CurrencyService, not LeaderboardService: `CurrencyService.luau` `LEADERBOARD_EXCLUDED_REASONS` (:16-18) holds only `QuestRerollRefund = true`. `CurrencyService:Modify(player, type, amount, reason)` (:36) reads it at the MostBobaBucks feed (`if type == "BobaBucks" and amount > 0 and not LEADERBOARD_EXCLUDED_REASONS[reason or ""]`, :55), inside a pcall. The same `reason` also goes to `AnalyticsEvents:Economy(..., reason or "Shop")` (:64); `AnalyticsEvents:Economy` (AnalyticsEvents.luau:60) passes it straight to `LogEconomyEvent` as the free-text transactionType. No other code reads the reason (grepped every `Modify(` caller and every `"Shop"` string).
- Untagged `Modify` callers: `PromoCodes.server.luau` `applyRewards` (:89, `Modify(player, reward.Currency, reward.Amount)`; Currency can also be Points, where the reason is ignored by the feed) and `InventoryItem.Prototype:Sell` (`InventoryItem.luau:165`, `Modify(self._player, "BobaBucks", sellValue)`). Other callers already tag: CustomerService:802 "Gameplay", ShiftService:206 "Gameplay", DailyRewardService:165 "DailyReward", QuestService:203 "QuestReward", :287 "QuestReroll", :300 "QuestRerollRefund", TreasureHuntService:300 "TreasureChest". RealOrderService:277 is untagged and must stay counted (play-earned). Spill.luau:159 is Points.
- Chest refusal: `TreasureHuntService:ClaimChest` (TreasureHuntService.luau:~280-290) calls `self:_notifyPlayer(player, "Treasure Chest", "Next treasure chest in N min")` on every refused trigger with no throttle. The service has no `PlayerRemoving` method. `server/init.server.luau:30-34` calls `service:PlayerRemoving(player)` on every service that defines one. `TreasureHuntConfig.luau` holds `PLAYER_COOLDOWN_SECONDS = 15 * 60` (:15).
- Leaderboard flush: `LeaderboardService:_flushPending` (:120) moves `_pending[userId]` into a snapshot and clears it, then `task.spawn`s one `_updatePlayerStat` per (user, board) tracked by `_inflight`. `_updatePlayerStat` (:79) pcalls `UpdateAsync` and returns `false` after a warn on failure. The return value is ignored by `_flushPending`, so the delta is lost. Flush triggers: `Players.PlayerRemoving` (:~363), `game:BindToClose` (:~367, waits up to `FLUSH_ON_CLOSE_WAIT_SECONDS = 25` for `_inflight` to reach 0), and the `REFRESH_INTERVAL_SECONDS` loop (:~379). `IncrementStat` (:180) only adds into `_pending`.
- Tip remainder: `PerkService.luau` `_tipRemainder` (:33), written by `PerkService:TakeTipExtra` (:78-86), cleared by `PerkService:PlayerRemoving` (:97). In `RealOrderService:_onOrderPickedUp` the `GetTipBonus` call (:~221) is the entry-time yield; after it, `TakeTipExtra(barista, pay, tipBonus)` (:~267) can run for a barista who left during the yield, and that re-creates the entry after `PlayerRemoving` already cleared it (small leak, no money impact). The NPC path is safe: `CustomerService:_onServeTriggered` re-checks `IsClockedIn` and the character position after its entry yield, so a departed player returns before `TakeTipExtra`.
- Team Combo feed: `RealOrderService:_onOrderPickedUp` computes `multiplier = RealOrderService.PayMultiplier(...)` (:255, returns `RealOrderConfig.PAY_MULT` = 2 or 1 when the pair has 3 serves in the window, DEC-024) then `Record` (:256), and later calls `customerService:RecordTeamServe(grade or "Close")` (:~281) for every non-self serve. `CustomerService:RecordTeamServe(grade)` (init.luau:419) advances the chain; only `RecordTeamServe(nil)` (walkout) resets it. `ApplyTeamCombo` (pay bonus) is applied separately (:~263).
- Specs to extend: `CurrencyService.spec.luau` (fake `_getService`, `makePlayerData`; no Modify cases yet), `TreasureHuntService.spec.luau` ("refuses a second chest within the player cooldown", :295, asserts `#mockNotifyCalls == 1`), `LeaderboardService.spec.luau` (mock store with `UpdateAsync`; "batches increments", :195), `RealOrder.spec.luau` (pure `PayMultiplier` cases only).

## Read (only these)
- `decisions.md` DEC-038; `M4-FIXES-SENTRY/review.md` P3-1..P3-3; `M3-REM-B-SENTRY/review.md` (re-review P3 on `_tipRemainder`); `M3-REM-C-SENTRY/review.md` P3-1
- `src/server/Modules/CurrencyService.luau`
- `src/server/Scripts/PromoCodes.server.luau:80-100`; `src/shared/Inventory/InventoryItem.luau:155-175`
- `src/server/Modules/TreasureHuntService.luau` (`ClaimChest`, `_notifyPlayer`, lifecycle); `src/shared/Configuration/TreasureHuntConfig.luau`
- `src/server/Modules/LeaderboardService.luau:25-45, 75-140, 175-205, 355-385`; `src/shared/Configuration/LeaderboardConfig.luau`
- `src/server/Modules/RealOrderService.luau:40-90, 196-295`
- The four spec files above (fixture style only)

## Write scope
- `src/server/Modules/CurrencyService.luau` (exclusion map only)
- `src/server/Scripts/PromoCodes.server.luau`, `src/shared/Inventory/InventoryItem.luau` (reason argument only; keep each file's existing indentation style)
- `src/server/Modules/TreasureHuntService.luau`, `src/shared/Configuration/TreasureHuntConfig.luau`
- `src/server/Modules/LeaderboardService.luau`, `src/shared/Configuration/LeaderboardConfig.luau`
- `src/server/Modules/RealOrderService.luau`
- `src/server/Tests/CurrencyService.spec.luau`, `TreasureHuntService.spec.luau`, `LeaderboardService.spec.luau`, `RealOrder.spec.luau`
- Do NOT touch `CustomerService/init.luau` (serve-path invariant) or `PerkService.luau`.

## Steps
### a. Promo-code and item-sell reasons (DEC-038 Q14=A)
1. `PromoCodes.server.luau` `applyRewards`: `CurrencyService:Modify(player, reward.Currency, reward.Amount, "PromoCode")`.
2. `InventoryItem.luau` `Sell`: `currencyService:Modify(self._player, "BobaBucks", sellValue, "ItemSell")`.
3. `CurrencyService.luau`: add `PromoCode = true` and `ItemSell = true` to `LEADERBOARD_EXCLUDED_REASONS`, and extend the comment above it to name them (DEC-038 Q14). Do not touch the Modify body. The reason already reaches the feed and the analytics event; side effect to note in evidence: those two grants now log as transactionType "PromoCode"/"ItemSell" instead of the default "Shop".
4. Spec (`CurrencyService.spec.luau`, new `describe("Modify leaderboard feed")`): extend the fake `_getService` with a `LeaderboardService` fake that records `IncrementStat(player, board, amount)` calls (and an `AnalyticsEvents` stub; the feed is pcall-wrapped but the existing fake errors on unknown names). Cases: reasons `PromoCode`, `ItemSell`, `QuestRerollRefund` do not feed; `Gameplay`, `TreasureChest`, `DailyReward` and a nil reason do feed `MostBobaBucks`; Points and negative amounts never feed. `Modify` runs through a resolved Promise's `andThen`, so yield one `task.wait()` before asserting, and note in evidence that Jack must confirm the timing.

### b. Chest-notice throttle (Sentry P3-2)
5. `TreasureHuntConfig.luau`: add `COOLDOWN_NOTICE_SECONDS = 5` (UI throttle, not an economy value).
6. `TreasureHuntService`: add `_lastCooldownNotice = {} :: { [Player]: number }`. In the refusal branch of `ClaimChest`, send the notice only if `os.clock() - (self._lastCooldownNotice[player] or -math.huge) >= COOLDOWN_NOTICE_SECONDS`, and set the stamp when sent. The refusal itself (return false) is unchanged for every trigger.
7. Add `function TreasureHuntService:PlayerRemoving(player)` that clears `_lastCooldownNotice[player]` (the loader at `server/init.server.luau:30` picks it up).
8. Spec: after the first refusal (1 notice) a second refusal inside the window adds no notice but still returns false and grants nothing; set `_lastCooldownNotice[fakePlayer] = os.clock() - 6` and the next refusal notifies again; `PlayerRemoving` clears the entry. Keep the existing `#mockNotifyCalls == 1` assertion valid.

### c. Leaderboard flush re-queue (Sentry P3-3)
9. `LeaderboardConfig.luau`: add `FLUSH_MAX_ATTEMPTS = 3` (total write attempts per delta, one per flush cycle).
10. `LeaderboardService`: add `_closing = false` and `_flushFailures = {} :: { [number]: { [string]: number } }` (failed attempts per user/board). In `BindToClose`, set `self._closing = true` before `FlushAll()`.
11. In the spawned task inside `_flushPending`: `local ok = self:_updatePlayerStat(...)`. On success, clear `_flushFailures[userId][boardType]` (and the user table if empty). On failure: if `self._closing`, or the attempt count reaches `FLUSH_MAX_ATTEMPTS`, warn once ("dropping N after M attempts"), clear the counter, and drop the delta. Otherwise increment the counter and add the delta back into `self._pending[userId][boardType]` (create the tables as `IncrementStat` does, adding to any newer delta). Do the re-queue before `self._inflight -= 1`.
12. Why this is safe: a delta lives in exactly one place at a time (pending or in flight), so a re-queue cannot double-count; the flush loop revisits all users, including ones who left, so a re-queued entry is retried by the periodic flush and dropped after 3 attempts, which bounds the queue at users x boards and prevents unbounded growth. Document the one residual case in the code comment: if `UpdateAsync` throws after Roblox already committed it, a retry could add the delta twice; accepted (rare, monthly board). Do not add a pcall around the re-queue that could swallow a real error.
13. Spec (`LeaderboardService.spec.luau`; reset `_flushFailures` and `_closing` in `beforeEach`/`afterEach`): (i) store `UpdateAsync` errors once: `FlushAll`, the delta is back in `_pending` and the board is unchanged; second `FlushAll` writes it once, value equals the delta; (ii) always-failing store: after 3 flushes the entry is gone from `_pending` and counters are cleared; (iii) `_closing = true`: a failed flush re-queues nothing; (iv) an increment arriving between the failure and the retry is summed into one write. The mock store is synchronous, so spawned tasks finish inside `FlushAll`.

### d. Departed barista guard (M3-REM-B Sentry P3)
14. `RealOrderService:_onOrderPickedUp`: wrap the existing `TakeTipExtra` block so it only runs while `barista.Parent ~= nil` (e.g. `if tipBonus > 0 and barista.Parent ~= nil then`). A `.Parent` read does not yield. Pay, `Modify`, history and everything else stay as they are. `PerkService` is not changed (its specs use plain-table players with no `Parent`).
15. No unit spec is feasible (the handler needs Knit services). Add the case to the "Test for Jack" list and state the NPC path was checked and needs no change.

### e. Team Combo ignores farm-throttled real serves (M3-REM-C Sentry P3-1)
16. `RealOrderService.luau`: add a pure helper next to `PayMultiplier`: `function RealOrderService.CountsForTeamChain(multiplier: number): boolean return multiplier > 1 end` with a comment: a pair already throttled by the E5 repeat-pair rule (multiplier 1) is not a fresh serve, so it neither advances nor resets the chain.
17. In `_onOrderPickedUp`, change the `if okCombo then ... RecordTeamServe(grade or "Close")` block to `if okCombo and RealOrderService.CountsForTeamChain(multiplier) then`. The throttled serve is still paid and still receives `ApplyTeamCombo` while a window is open (pay unchanged; Q below). No other chain behaviour changes; walkouts still reset it.
18. Spec (`RealOrder.spec.luau`): `CountsForTeamChain(2)` is true, `CountsForTeamChain(1)` is false, and over `PayMultiplier`/`Record` for one pair the first 3 serves count and the 4th does not.

### Finish
19. Run the gate on every changed Luau file (specs included). Write evidence.

## Done when
- Promo-code and item-sell BB never reach MostBobaBucks; gameplay, chest, daily and real-order BB still do; no other reason string changed.
- A repeated chest trigger inside 5 s shows at most one toast and still refuses; the cooldown itself is unchanged.
- A failed leaderboard write is retried at most 3 times, never double-counted by the code paths above, never kept after shutdown begins.
- A barista who leaves mid-serve leaves no `_tipRemainder` entry behind.
- A throttled real-order pair (4th serve in 10 min) does not move the Team Combo chain.
- No file outside Write scope changed; no yield added on either serve path.

## Test for Jack (Play; Mason and Sentry never run Play)
1. Redeem a Robux-free promo code worth BB (check the board before and after): MostBobaBucks does not rise; the wallet does. A Points code still works.
2. Sell a pet or nametag: the wallet rises by the sell value, MostBobaBucks does not. Serve an NPC order and open a chest: MostBobaBucks does rise by the pay / chest BB.
3. Open one chest, then hold E on a second chest repeatedly for 10 s: at most 2 "Next treasure chest in N min" toasts appear (one per 5 s), and no chest opens. Leave and rejoin: the first refusal toasts again.
4. Leaderboard retry (Studio Output): with API access off (or the DataStore blocked), earn BB, wait one refresh interval: a "Failed to update stat" warning appears, then a retry on each interval, then a single "dropping" warning after the third. Re-enable access before the first retry: the score appears once, not twice.
5. With two players, make a real order, have the barista leave the server right after picking up the drink: no error in Output; the barista pay behaviour is as before.
6. Two accounts (or one plus a friend): fill the Team Combo chain to 8, then have the same barista serve the same real customer 4 times in 10 minutes: the 4th serve pays x1 (no real-customer x2) and the chain count does not move; a normal NPC serve still advances it.

## Checks to run
- The gate command above on each changed file. Never Play or TestEZ (DEC-019).

## STOP-AND-ASK
- Throttled real serves: this packet makes them neither advance nor reset the chain and still pay the Team Combo bonus. If Jack wants them to also lose the combo pay bonus, that is a pay change (PENDING JACK; Prime recommends leave as built).
- Whether a `PromoCode` or `ItemSell` analytics label change matters to existing dashboards: not blocking; report in evidence.
- Any change to prices, amounts, probabilities or the 5 s / 3 attempt tuning that Mason thinks is wrong: stop and ask; do not widen scope.

Evidence
`tasks/REVIVAL-001/M4-FIXES-P3/evidence.md` (RUNBOOK step 5), including the "Test for Jack" list above.
