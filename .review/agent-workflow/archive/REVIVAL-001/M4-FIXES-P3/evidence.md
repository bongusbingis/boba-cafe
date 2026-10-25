# M4-FIXES-P3 evidence

## Changed files
- src/server/Modules/CurrencyService.luau (exclusion map + comment only)
- src/server/Scripts/PromoCodes.server.luau ("PromoCode" reason)
- src/shared/Inventory/InventoryItem.luau ("ItemSell" reason)
- src/server/Modules/TreasureHuntService.luau, src/shared/Configuration/TreasureHuntConfig.luau (COOLDOWN_NOTICE_SECONDS = 5, throttle, PlayerRemoving)
- src/server/Modules/LeaderboardService.luau (+ new helper _settleFlush), src/shared/Configuration/LeaderboardConfig.luau (FLUSH_MAX_ATTEMPTS = 3)
- src/server/Modules/RealOrderService.luau (barista.Parent guard, CountsForTeamChain)
- Specs: CurrencyService, TreasureHuntService, LeaderboardService, RealOrder

## Gate
stylua + gate on all 12 files: GATE: PASS (selene new=0 each; PromoCodes baseline 1 unchanged; rojo build ok). No Play/TestEZ run.

## Notes
- Analytics side effect: promo-code and item-sell BB now log LogEconomyEvent transactionType "PromoCode"/"ItemSell" instead of default "Shop". Not blocking; dashboards filtering "Shop" will see these drop out.
- Leaderboard retry logic was put in a small helper `_settleFlush` called from the spawned task, before `_inflight -= 1`; no pcall around the re-queue.
- Serve path: no yielding call added in CustomerService (untouched) or RealOrderService payout. `.Parent` read and the pure helper do not yield. NPC path (_onServeTriggered) re-checks IsClockedIn/position after its entry yield, so no change needed.
- CurrencyService spec: Modify runs via a resolved Promise andThen; specs use one task.wait() before asserting. Jack must confirm that timing in TestEZ.
- Throttled real serves: still paid and still get ApplyTeamCombo; they just do not advance/reset the chain (per packet; PENDING JACK if combo pay should be removed).
- No unit spec for the departed-barista guard (needs Knit services).

## Test for Jack (Play)
1. Redeem a Robux-free promo code worth BB (check the board before and after): MostBobaBucks does not rise; the wallet does. A Points code still works.
2. Sell a pet or nametag: the wallet rises by the sell value, MostBobaBucks does not. Serve an NPC order and open a chest: MostBobaBucks does rise by the pay / chest BB.
3. Open one chest, then hold E on a second chest repeatedly for 10 s: at most 2 "Next treasure chest in N min" toasts appear (one per 5 s), and no chest opens. Leave and rejoin: the first refusal toasts again.
4. Leaderboard retry (Studio Output): with API access off (or the DataStore blocked), earn BB, wait one refresh interval: a "Failed to update stat" warning appears, then a retry on each interval, then a single "Dropping" warning after the third. Re-enable access before the first retry: the score appears once, not twice.
5. With two players, make a real order, have the barista leave the server right after picking up the drink: no error in Output; the barista pay behaviour is as before.
6. Two accounts: fill the Team Combo chain to 8, then have the same barista serve the same real customer 4 times in 10 minutes: the 4th serve pays x1 (no real-customer x2) and the chain count does not move; a normal NPC serve still advances it.

## Gate correction
PromoCodes.server.luau and InventoryItem.luau have pre-existing StyLua drift (DEC-001 baseline). StyLua initially reformatted them, so both were restored from HEAD and only the one-line reason argument re-applied (2-line diff). Gate on them: PASS, selene new=0, stylua=pre-existing drift (not new). The other 10 files are StyLua-formatted.
