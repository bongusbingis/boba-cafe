# Sentry review: M4-FIX-REALORDER-QUEST
Verdict: FAIL (one P2, fixable by moving the call)

## Findings
- P2 RealOrderService.luau:247 - customer AdvanceQuest sits BEFORE the history Record (262), payout (285) and XP (297). AdvanceQuest can yield: QuestService.luau:63 `GetDataAsync():timeout():await()` and, on first call of a day, _ensureDailyQuests -> _hasPass (QuestService.luau:56-58, 85, 92) calls PlayerOwnsPassAsync (MarketplaceService). Previously a silent no-op, so this change introduces a yield between the guards and the payout, violating the packet's serve-path invariant. Effects: barista may leave mid-yield (pay/AddXp/Notify on departed player; tip guard at 273 only covers the earlier yield), PayMultiplier/Record race across concurrent pickups, delayed pay. The pcall does not prevent yielding. Fix: run the customer advance after the barista advance (and before the early return at 252-254 via restructure), or wrap in task.spawn.
- Self-serve: OK. Early return at 216-222 precedes all quest calls; no customer==barista quest credit.
- Double counting: none. Customer and barista each advance once for their own player (247, 300); different players.
- P3 exploit: customer advance has no history throttle (PayMultiplier at 261 only throttles pay, and runs after the customer branch). Two colluding accounts (or alt) can loop orders to finish RegularOrders quests, same exposure as barista advance at 300. Bounded: daily quest slots, Progress capped at Target, each quest claimable once. Check OrderService create-side limits (OrderService.luau:554) if tighter control is wanted.

## Re-review
Verdict: PASS-WITH-P3

1. No yield between guards and payout/Record/XP: the customer advance is in task.spawn, so the caller resumes after the spawned thread's first yield. The synchronous prefix is only pcall(function) -> AdvanceQuest -> _getPlayerData, which touches no _onOrderPickedUp state, and any error is caught by the pcall. Order is unchanged: tip bonus, Record, pay, XP. The trailing barista AdvanceQuest (line ~300) can still yield, but nothing follows it.
2. Customer leaving mid-yield: the pcall is inside the spawned thread, so an error cannot reach the caller. QuestService has `player.Parent` guards, and a departed customer is bounded by quest Target caps.
3. Self-serve: the early return at 216-222 precedes everything, so it is unchanged.
4. Double counting: none. The customer and barista are different players, each advanced once. The old `quests.Progress` guard is now `AdvanceQuest` (Progress is an alias), so behaviour is equivalent.

Remaining P3 (carried over): the customer advance has no collusion throttle. It is bounded by daily quest slots and Target caps.
