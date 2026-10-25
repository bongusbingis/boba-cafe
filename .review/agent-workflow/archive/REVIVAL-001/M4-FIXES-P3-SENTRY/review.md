VERDICT: PASS-WITH-P3

# M4-FIXES-P3 Sentry review
Scope: uncommitted src/ diff, branch uhweifh. Static read-only review; no Studio/Play/TestEZ. No P1/P2. No CapsuleService/InventoryServer/Utility/PerkService/Perks changes in the diff (M3-REM-D untouched).

## Findings

### P3-1 Failure counter is per (user, board), not per delta
- src/server/Modules/LeaderboardService.luau:130-158. A newer delta merged into a re-queued one inherits the older attempt count, so it may get fewer than FLUSH_MAX_ATTEMPTS tries. Two concurrent in-flight writes for the same key (PlayerRemoving flush plus the periodic flush) share one counter: one success clears the other's count (extra retry, bounded).
- Scenario: delta A fails twice (count 2), new delta B merges in, one more failure drops A+B together. Loss is small, bounded, monthly board.

### P3-2 In-flight failures after BindToClose starts are dropped by design
- LeaderboardService.luau:144. Writes already in flight when _closing flips, and any that fail during the FLUSH_ON_CLOSE_WAIT_SECONDS wait, are dropped, not retried. Intended and documented; noting only.

### P3-3 Team Combo pay still applies to throttled serves
- RealOrderService.luau:267-269. A throttled (x1) serve still gets the active combo bonus on its x1 pay; it just does not advance the chain. Not new, pay is still below a fresh serve, no exploit.

## Checks
1. Serve path: PASS. barista.Parent is a plain property read, no yield. GetTipBonus is the only yield and is resolved before PayMultiplier/Record/ApplyTeamCombo/TakeTipExtra/Modify (RealOrderService.luau:222-285). When the guard skips (barista left), no tip extra; pay, Modify and history are otherwise unchanged. CustomerService is not in the diff.
2. Flush re-queue: PASS. _pending[userId] is cleared at snapshot time, so a delta lives in exactly one place (in flight or pending); success does not re-add, so no double count. Failure re-queue adds into _pending (merges with newer deltas, spec covers 4+3=7). Bounded by FLUSH_MAX_ATTEMPTS=3 and by users x boards. _inflight is incremented before spawn and decremented after _settleFlush; _settleFlush has no throwing path (config key exists, warn is a string), so it cannot go negative or stick. _updatePlayerStat pcalls and returns false on error; a missing store returns true (unchanged). BindToClose sets _closing before FlushAll, so no re-queue lands in a dead server. Residual: UpdateAsync throwing after commit could double-write; accepted, documented.
3. Reason tagging: PASS. Exclusions are QuestRerollRefund, PromoCode, ItemSell only. All Modify callers audited: CustomerService/ShiftService "Gameplay", TreasureHunt "TreasureChest", DailyReward, QuestReward, RealOrderService (no reason) still count. Only InventoryItem:165 and PromoCodes:89 changed, and the reason also changes the Economy analytics label (known). No other behavior reads reason.
4. Chest notice: PASS. The throttle wraps only _notifyPlayer; the refusal still reaches return false (TreasureHuntService.luau:285-295) and nothing is granted. Stamp is os.clock-based and server-side. PlayerRemoving is dispatched by src/server/init.server.luau:29-35 for any service with that method. Spamming the trigger yields at most one toast per 5s; the stamp table is bounded by players.
5. Team Combo: PASS. multiplier is computed before Record; CountsForTeamChain(multiplier>1) gates only RecordTeamServe. Throttled serves neither advance nor reset the chain; NPC path (CustomerService:818, 944) untouched. No economy values changed (COOLDOWN_NOTICE_SECONDS is UI, FLUSH_MAX_ATTEMPTS is not economy).
6. Specs: PASS on reading. Currency specs use task.wait() after the resolved-Promise andThen, fake services cover DataService/LeaderboardService/AnalyticsEvents/StatisticsService. Leaderboard specs: failFirst patches the cached mock store; the failed write returns synchronously through pcall, so synchronous assertions after FlushAll hold, and the drop/closing/merge cases match the code. Treasure specs: successful claims do not notify, so notify count 1 then 1 then 2 is correct; the 6s back-dated stamp exceeds the 5s window. RealOrder specs match PayMultiplier (3 counted, 4th throttled).
